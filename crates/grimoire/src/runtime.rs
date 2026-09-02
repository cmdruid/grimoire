use std::ffi::{OsStr, OsString};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::atomic::{AtomicU64, Ordering as AtomicOrdering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

use grimoire_core::source::{GitCommand, GitResult, GitRunner};
use grimoire_core::{CoreError, FaultDisposition, Result, TransactionRuntime};

const CONTROL_LIMIT: usize = 1024 * 1024;
const PAYLOAD_LIMIT: usize = 128 * 1024 * 1024 + 1;
const DEADLINE: Duration = Duration::from_secs(600);
const PRIVATE_REF: &str = "refs/grimoire/candidate";
const CACHE_LIMIT: u64 = 256 * 1024 * 1024;
const METADATA_LIMIT: u64 = 1024 * 1024;
#[cfg(target_os = "macos")]
const GROUP_RSS_LIMIT: u64 = 384 * 1024 * 1024;

type PayloadVisitor<'a> = dyn FnMut(&[u8]) -> Result<bool> + 'a;

static TRANSACTION_SEQUENCE: AtomicU64 = AtomicU64::new(0);

#[derive(Debug, Default, Clone, Copy)]
pub struct SystemRuntime;

impl TransactionRuntime for SystemRuntime {
    fn transaction_nonce(&self) -> Result<String> {
        let sequence = TRANSACTION_SEQUENCE.fetch_add(1, AtomicOrdering::Relaxed);
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_err(|error| CoreError::Transaction(error.to_string()))?
            .as_nanos();
        Ok(format!("{}-{nanos}-{sequence}", std::process::id()))
    }

    fn unix_time(&self) -> Result<i64> {
        let seconds = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_err(|error| CoreError::Transaction(error.to_string()))?
            .as_secs();
        i64::try_from(seconds).map_err(|_| CoreError::Transaction("system time exceeds i64".into()))
    }

    fn checkpoint(&self, _name: &'static str) -> Result<FaultDisposition> {
        Ok(FaultDisposition::Continue)
    }
}

#[derive(Debug, Clone)]
pub struct SystemGitRunner {
    executable: PathBuf,
    ssh_agent_socket: Option<PathBuf>,
    askpass: Option<PathBuf>,
}

impl Default for SystemGitRunner {
    fn default() -> Self {
        Self {
            executable: PathBuf::from("git"),
            ssh_agent_socket: None,
            askpass: None,
        }
    }
}

impl SystemGitRunner {
    pub fn new(executable: PathBuf) -> Result<Self> {
        validate_os(&executable, "Git executable")?;
        Ok(Self {
            executable,
            ssh_agent_socket: None,
            askpass: None,
        })
    }

    pub fn with_ssh_agent(mut self, socket: PathBuf) -> Result<Self> {
        validate_os(&socket, "SSH agent socket")?;
        if !socket.is_absolute() {
            return Err(CoreError::Source(
                "SSH agent socket must be absolute".into(),
            ));
        }
        self.ssh_agent_socket = Some(socket);
        Ok(self)
    }

    pub fn with_askpass(mut self, askpass: PathBuf) -> Result<Self> {
        validate_os(&askpass, "askpass callback")?;
        if !askpass.is_absolute() {
            return Err(CoreError::Source(
                "askpass callback must be absolute".into(),
            ));
        }
        self.askpass = Some(askpass);
        Ok(self)
    }

    fn execute(&self, request: GitCommand) -> Result<GitResult> {
        let parts = command_parts(request)?;
        self.execute_parts(parts, 64 * 1024, None, Instant::now() + DEADLINE)
    }

    fn execute_parts(
        &self,
        parts: CommandParts,
        maximum_chunk: usize,
        mut visitor: Option<&mut PayloadVisitor<'_>>,
        deadline: Instant,
    ) -> Result<GitResult> {
        let mut command = Command::new(&self.executable);
        command.args(&parts.args).env_clear();
        command.env("GIT_CONFIG_NOSYSTEM", "1");
        command.env("GIT_CONFIG_GLOBAL", null_device());
        command.env("GIT_TERMINAL_PROMPT", "0");
        command.env("GIT_OPTIONAL_LOCKS", "0");
        command.env("GIT_CONFIG_COUNT", sanitized_config().len().to_string());
        for (index, (key, value)) in sanitized_config().iter().enumerate() {
            command.env(format!("GIT_CONFIG_KEY_{index}"), key);
            command.env(format!("GIT_CONFIG_VALUE_{index}"), value);
        }
        if let Some(socket) = &self.ssh_agent_socket {
            command.env("SSH_AUTH_SOCK", socket);
        }
        if let Some(askpass) = &self.askpass {
            command.env("GIT_ASKPASS", askpass);
        }
        if let Some(directory) = parts.directory {
            command.current_dir(directory);
        }
        command
            .stdin(if parts.stdin.is_some() {
                Stdio::piped()
            } else {
                Stdio::null()
            })
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        install_child_limits(&mut command);

        let mut child = command
            .spawn()
            .map_err(|error| CoreError::Transport(format!("cannot start Git: {error}")))?;
        let pid = child.id() as i32;
        if let Some(bytes) = parts.stdin {
            child
                .stdin
                .take()
                .expect("piped stdin")
                .write_all(&bytes)
                .map_err(|error| {
                    CoreError::Transport(format!("cannot write Git stdin: {error}"))
                })?;
        }
        let stdout = child.stdout.take().expect("piped stdout");
        let stderr = child.stderr.take().expect("piped stderr");
        set_nonblocking(&stdout)?;
        let stdout_limit = if parts.payload {
            PAYLOAD_LIMIT
        } else {
            CONTROL_LIMIT
        };
        let exceeded = Arc::new(AtomicBool::new(false));
        let stderr_exceeded = Arc::clone(&exceeded);
        let stderr_thread =
            thread::spawn(move || read_capped(stderr, CONTROL_LIMIT, stderr_exceeded));

        let mut stdout = stdout;
        let mut stdout_bytes = Vec::new();
        let mut stdout_eof = false;
        let mut status = None;
        let mut buffer = vec![0u8; maximum_chunk.clamp(1, 64 * 1024)];
        loop {
            let mut progressed = false;
            if !stdout_eof {
                match stdout.read(&mut buffer) {
                    Ok(0) => stdout_eof = true,
                    Ok(read) => {
                        progressed = true;
                        if let Some(visitor) = visitor.as_mut() {
                            match visitor(&buffer[..read]) {
                                Ok(true) => {}
                                Ok(false) => {
                                    kill_group(pid);
                                    let _ = child.wait();
                                    let stderr = stderr_thread.join().map_err(|_| {
                                        CoreError::Transport("Git stderr reader panicked".into())
                                    })??;
                                    return Ok(GitResult {
                                        stdout: Vec::new(),
                                        stderr,
                                    });
                                }
                                Err(error) => {
                                    kill_group(pid);
                                    let _ = child.wait();
                                    let _ = stderr_thread.join();
                                    return Err(error);
                                }
                            }
                        } else if stdout_bytes.len().saturating_add(read) > stdout_limit {
                            kill_group(pid);
                            let _ = child.wait();
                            let _ = stderr_thread.join();
                            return Err(CoreError::Transport("Git output limit exceeded".into()));
                        } else {
                            stdout_bytes.extend_from_slice(&buffer[..read]);
                        }
                    }
                    Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {}
                    Err(error) => {
                        kill_group(pid);
                        let _ = child.wait();
                        let _ = stderr_thread.join();
                        return Err(CoreError::Transport(format!(
                            "cannot read Git output: {error}"
                        )));
                    }
                }
            }
            if status.is_none() {
                status = child.try_wait().map_err(|error| {
                    CoreError::Transport(format!("cannot wait for Git: {error}"))
                })?;
            }
            if status.is_some() && stdout_eof {
                break;
            }
            if Instant::now() >= deadline {
                kill_group(pid);
                let _ = child.wait();
                return Err(CoreError::Transport(
                    "Git workflow deadline exceeded".into(),
                ));
            }
            if exceeded.load(Ordering::Acquire) {
                kill_group(pid);
                let _ = child.wait();
                return Err(CoreError::Transport("Git output limit exceeded".into()));
            }
            #[cfg(target_os = "macos")]
            match process_group_resident_bytes(pid) {
                Ok(bytes) if bytes <= GROUP_RSS_LIMIT => {}
                Ok(_) => {
                    kill_group(pid);
                    let _ = child.wait();
                    return Err(CoreError::Transport(
                        "Git process-group resident-memory limit exceeded".into(),
                    ));
                }
                Err(error) => {
                    if let Some(exit_status) = child.try_wait().map_err(|wait_error| {
                        CoreError::Transport(format!("cannot wait for Git: {wait_error}"))
                    })? {
                        status = Some(exit_status);
                    } else if process_group_exists(pid) {
                        kill_group(pid);
                        let _ = child.wait();
                        return Err(error);
                    }
                }
            }
            if !progressed {
                thread::sleep(Duration::from_millis(5));
            }
        }
        let stderr = stderr_thread
            .join()
            .map_err(|_| CoreError::Transport("Git stderr reader panicked".into()))??;
        let status = status.expect("process exited before stdout closed");
        if !status.success() {
            return Err(CoreError::Transport(format!(
                "Git exited with {status}: {}",
                String::from_utf8_lossy(&stderr)
            )));
        }
        if let Some(cache) = parts.verify_cache {
            verify_bare_cache(&cache)?;
        }
        Ok(GitResult {
            stdout: stdout_bytes,
            stderr,
        })
    }
}

impl GitRunner for SystemGitRunner {
    fn run(&self, command: GitCommand) -> Result<GitResult> {
        self.execute(command)
    }

    fn run_until(&self, command: GitCommand, deadline: Instant) -> Result<GitResult> {
        self.execute_parts(command_parts(command)?, 64 * 1024, None, deadline)
    }

    fn verify_cache(&self, path: &Path) -> Result<()> {
        verify_bare_cache(path)
    }

    fn stream(
        &self,
        command: GitCommand,
        maximum_chunk: usize,
        visitor: &mut dyn FnMut(&[u8]) -> Result<bool>,
    ) -> Result<GitResult> {
        let parts = command_parts(command)?;
        if !parts.payload {
            return Err(CoreError::Source(
                "only Git payload commands may use streaming output".into(),
            ));
        }
        self.execute_parts(
            parts,
            maximum_chunk,
            Some(visitor),
            Instant::now() + DEADLINE,
        )
    }
}

struct CommandParts {
    directory: Option<PathBuf>,
    args: Vec<OsString>,
    stdin: Option<Vec<u8>>,
    payload: bool,
    verify_cache: Option<PathBuf>,
}

fn command_parts(command: GitCommand) -> Result<CommandParts> {
    let mut args = Vec::new();
    let mut stdin = None;
    let mut payload = false;
    let mut verify_cache = None;
    match command {
        GitCommand::InitBare { repository } => {
            validate_os(&repository, "bare repository")?;
            args.extend([OsString::from("init"), OsString::from("--bare")]);
            args.push(repository.into_os_string());
        }
        GitCommand::LsRemote { repository } => {
            validate_scalar(&repository, "repository")?;
            args.extend([
                "ls-remote".into(),
                "--symref".into(),
                "--exit-code".into(),
                repository.into(),
            ]);
        }
        GitCommand::Fetch {
            bare_repository,
            repository,
            source_ref,
        } => {
            validate_os(&bare_repository, "bare repository")?;
            verify_cache = Some(bare_repository.clone());
            validate_scalar(&repository, "repository")?;
            validate_scalar(&source_ref, "source ref")?;
            args.push(format!("--git-dir={}", bare_repository.display()).into());
            args.extend([
                "fetch".into(),
                "--keep".into(),
                "--depth=1".into(),
                "--no-tags".into(),
                "--no-recurse-submodules".into(),
                "--no-write-fetch-head".into(),
                "--no-write-commit-graph".into(),
                "--no-auto-maintenance".into(),
                "--no-progress".into(),
                "--stdin".into(),
                repository.into(),
            ]);
            stdin = Some(format!("+{source_ref}:{PRIVATE_REF}\n").into_bytes());
        }
        GitCommand::RevParse {
            bare_repository,
            revision,
        } => {
            validate_os(&bare_repository, "bare repository")?;
            validate_scalar(&revision, "revision")?;
            args.extend([
                format!("--git-dir={}", bare_repository.display()).into(),
                "rev-parse".into(),
                "--verify".into(),
                "--end-of-options".into(),
                revision.into(),
            ]);
        }
        GitCommand::LsTree {
            bare_repository,
            tree,
        } => {
            validate_os(&bare_repository, "bare repository")?;
            validate_scalar(&tree, "tree")?;
            args.extend([
                format!("--git-dir={}", bare_repository.display()).into(),
                "ls-tree".into(),
                "-rz".into(),
                "-r".into(),
                "-l".into(),
                "--full-tree".into(),
                tree.into(),
            ]);
            payload = true;
        }
        GitCommand::CatBlob {
            bare_repository,
            object,
        } => {
            validate_os(&bare_repository, "bare repository")?;
            validate_scalar(&object, "object")?;
            args.extend([
                format!("--git-dir={}", bare_repository.display()).into(),
                "cat-file".into(),
                "blob".into(),
                object.into(),
            ]);
            payload = true;
        }
        GitCommand::WorktreeInfo { worktree } => {
            validate_os(&worktree, "Git worktree")?;
            args.extend([
                "-C".into(),
                worktree.into_os_string(),
                "rev-parse".into(),
                "--path-format=absolute".into(),
                "--show-toplevel".into(),
                "--absolute-git-dir".into(),
                "--git-common-dir".into(),
            ]);
        }
        GitCommand::WorktreeStatus { worktree } => {
            validate_os(&worktree, "Git worktree")?;
            args.extend([
                "-C".into(),
                worktree.into_os_string(),
                "status".into(),
                "--porcelain=v1".into(),
                "-z".into(),
                "--untracked-files=all".into(),
                "--ignore-submodules=none".into(),
            ]);
        }
    }
    for argument in &args {
        validate_os(Path::new(argument), "Git argument")?;
    }
    Ok(CommandParts {
        directory: None,
        args,
        stdin,
        payload,
        verify_cache,
    })
}

fn sanitized_config() -> [(&'static str, &'static str); 9] {
    [
        ("pack.writeReverseIndex", "false"),
        ("pack.threads", "1"),
        ("core.deltaBaseCacheLimit", "16m"),
        ("core.bigFileThreshold", "16m"),
        ("fetch.unpackLimit", "0"),
        // Core rejects file transports for user-declared remotes. Keeping the plumbing protocol
        // available here permits pinned-local object access and hermetic local transport tests.
        ("protocol.file.allow", "always"),
        ("protocol.ext.allow", "never"),
        ("credential.helper", ""),
        ("core.hooksPath", null_device()),
    ]
}

fn read_capped(mut reader: impl Read, limit: usize, exceeded: Arc<AtomicBool>) -> Result<Vec<u8>> {
    let mut output = Vec::new();
    let mut buffer = [0u8; 64 * 1024];
    loop {
        let read = reader
            .read(&mut buffer)
            .map_err(|error| CoreError::Transport(format!("cannot read Git output: {error}")))?;
        if read == 0 {
            return Ok(output);
        }
        if output.len().saturating_add(read) > limit {
            exceeded.store(true, Ordering::Release);
            continue;
        }
        output.extend_from_slice(&buffer[..read]);
    }
}

#[cfg(unix)]
fn set_nonblocking(file: &impl std::os::fd::AsRawFd) -> Result<()> {
    let descriptor = file.as_raw_fd();
    let flags = unsafe { libc::fcntl(descriptor, libc::F_GETFL) };
    if flags < 0 || unsafe { libc::fcntl(descriptor, libc::F_SETFL, flags | libc::O_NONBLOCK) } < 0
    {
        Err(CoreError::Transport(format!(
            "cannot make Git payload nonblocking: {}",
            std::io::Error::last_os_error()
        )))
    } else {
        Ok(())
    }
}

fn verify_bare_cache(root: &Path) -> Result<()> {
    fn walk(
        root: &Path,
        directory: &Path,
        total: &mut u64,
        metadata_total: &mut u64,
        packs: &mut usize,
        indexes: &mut usize,
    ) -> Result<()> {
        let mut entries = std::fs::read_dir(directory)
            .map_err(|error| CoreError::Transport(format!("cannot inspect Git cache: {error}")))?
            .collect::<std::result::Result<Vec<_>, _>>()
            .map_err(|error| CoreError::Transport(format!("cannot inspect Git cache: {error}")))?;
        entries.sort_by_key(|entry| entry.file_name());
        for entry in entries {
            let path = entry.path();
            let metadata = std::fs::symlink_metadata(&path).map_err(|error| {
                CoreError::Transport(format!("cannot inspect Git cache: {error}"))
            })?;
            if metadata.file_type().is_symlink() {
                return Err(CoreError::Transport("Git cache contains a symlink".into()));
            }
            if metadata.is_dir() {
                walk(root, &path, total, metadata_total, packs, indexes)?;
                continue;
            }
            if !metadata.is_file() || metadata.len() > CACHE_LIMIT {
                return Err(CoreError::Transport("Git cache file limit exceeded".into()));
            }
            *total = total.saturating_add(metadata.len());
            let relative = path
                .strip_prefix(root)
                .map_err(|_| CoreError::Transport("Git cache path escaped root".into()))?;
            let extension = path.extension().and_then(OsStr::to_str);
            let in_pack_directory = relative
                .parent()
                .is_some_and(|parent| parent == Path::new("objects/pack"));
            match (in_pack_directory, extension) {
                (true, Some("pack")) => *packs += 1,
                (true, Some("idx")) => *indexes += 1,
                (true, Some("rev" | "keep" | "bitmap")) => {
                    return Err(CoreError::Transport(
                        "Git cache contains disabled pack metadata".into(),
                    ))
                }
                _ => *metadata_total = metadata_total.saturating_add(metadata.len()),
            }
        }
        Ok(())
    }

    let mut total = 0;
    let mut metadata_total = 0;
    let mut packs = 0;
    let mut indexes = 0;
    walk(
        root,
        root,
        &mut total,
        &mut metadata_total,
        &mut packs,
        &mut indexes,
    )?;
    if total > CACHE_LIMIT || metadata_total > METADATA_LIMIT {
        return Err(CoreError::Transport("Git cache size limit exceeded".into()));
    }
    if packs != 1 || indexes != 1 {
        return Err(CoreError::Transport(
            "Git cache must contain exactly one pack and index".into(),
        ));
    }
    Ok(())
}

#[cfg(target_os = "macos")]
fn process_group_resident_bytes(group: i32) -> Result<u64> {
    const MAX_PIDS: usize = 1024;

    let mut pids = [0i32; MAX_PIDS];
    let bytes = unsafe {
        libc::proc_listpgrppids(
            group,
            pids.as_mut_ptr().cast(),
            std::mem::size_of_val(&pids) as i32,
        )
    };
    if bytes <= 0 || bytes as usize >= pids.len() {
        return Err(CoreError::Transport(
            "cannot enforce Git process-group memory limit".into(),
        ));
    }
    let count = bytes as usize;
    let mut resident = 0u64;
    let mut sampled = 0usize;
    let mut last_error = None;
    for pid in pids[..count].iter().copied().filter(|pid| *pid > 0) {
        let mut info = std::mem::MaybeUninit::<libc::rusage_info_v4>::uninit();
        let result =
            unsafe { libc::proc_pid_rusage(pid, libc::RUSAGE_INFO_V4, info.as_mut_ptr().cast()) };
        if result != 0 {
            last_error = Some(std::io::Error::last_os_error());
            continue;
        }
        sampled += 1;
        let info = unsafe { info.assume_init() };
        resident = resident.saturating_add(info.ri_resident_size.max(info.ri_phys_footprint));
    }
    if sampled == 0 {
        Err(CoreError::Transport(format!(
            "cannot sample Git process-group memory{}",
            last_error.map_or(String::new(), |error| format!(": {error}"))
        )))
    } else {
        Ok(resident)
    }
}

#[cfg(unix)]
fn install_child_limits(command: &mut Command) {
    use std::os::unix::process::CommandExt;

    unsafe {
        command.pre_exec(|| {
            if libc::setpgid(0, 0) != 0 {
                return Err(std::io::Error::last_os_error());
            }
            let file = libc::rlimit {
                rlim_cur: 256 * 1024 * 1024,
                rlim_max: 256 * 1024 * 1024,
            };
            if libc::setrlimit(libc::RLIMIT_FSIZE, &file) != 0 {
                return Err(std::io::Error::last_os_error());
            }
            #[cfg(target_os = "linux")]
            {
                let address = libc::rlimit {
                    rlim_cur: 512 * 1024 * 1024,
                    rlim_max: 512 * 1024 * 1024,
                };
                if libc::setrlimit(libc::RLIMIT_AS, &address) != 0 {
                    return Err(std::io::Error::last_os_error());
                }
            }
            Ok(())
        });
    }
}

#[cfg(unix)]
fn kill_group(pid: i32) {
    unsafe {
        libc::killpg(pid, libc::SIGKILL);
    }
}

#[cfg(unix)]
fn process_group_exists(pid: i32) -> bool {
    if unsafe { libc::killpg(pid, 0) } == 0 {
        return true;
    }
    std::io::Error::last_os_error().raw_os_error() == Some(libc::EPERM)
}

fn validate_scalar(value: &str, name: &str) -> Result<()> {
    if value.is_empty() || value.bytes().any(|byte| matches!(byte, 0 | b'\n' | b'\r')) {
        Err(CoreError::Source(format!("invalid {name}")))
    } else {
        Ok(())
    }
}

fn validate_os(value: &Path, name: &str) -> Result<()> {
    if value.as_os_str().is_empty()
        || os_bytes(value.as_os_str())
            .iter()
            .any(|byte| matches!(byte, 0 | b'\n' | b'\r'))
    {
        Err(CoreError::Source(format!("invalid {name}")))
    } else {
        Ok(())
    }
}

#[cfg(unix)]
fn os_bytes(value: &OsStr) -> &[u8] {
    use std::os::unix::ffi::OsStrExt;
    value.as_bytes()
}

#[cfg(target_os = "windows")]
fn os_bytes(_value: &OsStr) -> &[u8] {
    &[]
}

#[cfg(unix)]
const fn null_device() -> &'static str {
    "/dev/null"
}
