use std::ffi::CString;
use std::fs::{self, File};
use std::io::Read;
use std::path::{Component, Path, PathBuf};

use grimoire_pack::inventory::{
    InventoryError, SourcePath, TreeEntry, TreeEntryKind, TreeReader, VisitDecision,
};
use rustix::fs::{openat, readlinkat, statat, AtFlags, Dir, Mode, OFlags, Stat};

use super::{validate_ref, CanonicalIdentity, GitCommand, GitRunner, GitSnapshot, SourceKind};
use crate::{CoreError, Result};

#[cfg(unix)]
use std::os::unix::ffi::OsStrExt;
#[cfg(unix)]
use std::os::unix::fs::MetadataExt;

#[derive(Debug)]
pub struct HeldDirectoryReader {
    root: PathBuf,
    handles: Vec<File>,
    root_identity: FileIdentity,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct FileIdentity {
    device: u64,
    inode: u64,
    kind: u32,
    size: u64,
    modified_seconds: i64,
    modified_nanoseconds: i64,
    changed_seconds: i64,
    changed_nanoseconds: i64,
}

impl HeldDirectoryReader {
    pub fn open(root: &Path) -> Result<Self> {
        if !root.is_absolute() {
            return Err(CoreError::Source("held local root must be absolute".into()));
        }
        let mut handles = vec![File::open("/").map_err(|error| io_error(Path::new("/"), error))?];
        let mut resolved = PathBuf::from("/");
        for component in root.components() {
            let Component::Normal(name) = component else {
                if matches!(component, Component::RootDir) {
                    continue;
                }
                return Err(CoreError::Source(
                    "held local root must be an absolute normalized path".into(),
                ));
            };
            let name = CString::new(name.as_bytes())
                .map_err(|_| CoreError::Source("local path contains NUL".into()))?;
            let fd = openat(
                handles.last().expect("root handle"),
                &name,
                directory_flags(),
                Mode::empty(),
            )
            .map_err(|error| {
                rustix_io_error(
                    &resolved.join(std::ffi::OsStr::from_bytes(name.to_bytes())),
                    error,
                )
            })?;
            resolved.push(std::ffi::OsStr::from_bytes(name.to_bytes()));
            handles.push(fd.into());
        }
        let root_handle = handles.last().expect("root handle");
        let metadata = root_handle
            .metadata()
            .map_err(|error| io_error(&resolved, error))?;
        if !metadata.is_dir() {
            return Err(CoreError::Source(
                "held local root is not a directory".into(),
            ));
        }
        let root_identity = identity(&metadata);
        let reader = Self {
            root: resolved,
            handles,
            root_identity,
        };
        reader.revalidate()?;
        Ok(reader)
    }

    pub fn revalidate(&self) -> Result<()> {
        let held = self
            .handles
            .last()
            .expect("root handle")
            .metadata()
            .map_err(|error| io_error(&self.root, error))?;
        let named =
            fs::symlink_metadata(&self.root).map_err(|error| io_error(&self.root, error))?;
        if held.is_dir()
            && named.is_dir()
            && identity(&held) == self.root_identity
            && identity(&named) == self.root_identity
        {
            Ok(())
        } else {
            Err(CoreError::Source("held local root changed".into()))
        }
    }

    pub(crate) fn root_handle(&self) -> Result<File> {
        self.handles
            .last()
            .expect("root handle")
            .try_clone()
            .map_err(|error| io_error(&self.root, error))
    }

    fn walk(
        &self,
        directory: &File,
        relative: &SourcePath,
        visitor: &mut dyn FnMut(TreeEntry) -> std::result::Result<VisitDecision, InventoryError>,
    ) -> std::result::Result<bool, InventoryError> {
        let before = directory
            .metadata()
            .map_err(|error| tree_error(relative, error))?;
        let before_identity = identity(&before);
        if !before.is_dir() {
            return Err(tree_message(relative, "directory changed kind"));
        }

        let mut entries = Dir::read_from(directory)
            .map_err(|error| rustix_tree_error(relative, error))?
            .collect::<std::result::Result<Vec<_>, _>>()
            .map_err(|error| rustix_tree_error(relative, error))?;
        entries.retain(|entry| !matches!(entry.file_name().to_bytes(), b"." | b".."));
        entries.sort_by(|left, right| {
            left.file_name()
                .to_bytes()
                .cmp(right.file_name().to_bytes())
        });

        for child in entries {
            let name = child.file_name();
            let child_relative = relative.join(name.to_bytes());
            let before = statat(directory, name, AtFlags::SYMLINK_NOFOLLOW)
                .map_err(|error| rustix_tree_error(&child_relative, error))?;
            let kind = mode_kind(before.st_mode as u32);
            let entry = match kind {
                0o040000 => {
                    let mut entry = TreeEntry::directory(child_relative.clone());
                    entry.mode = before.st_mode as u32;
                    entry
                }
                0o100000 => {
                    let mut entry = TreeEntry::file(child_relative.clone(), before.st_mode as u32);
                    entry.size = Some(before.st_size as u64);
                    entry
                }
                0o120000 => {
                    let target = readlinkat(directory, name, Vec::new())
                        .map_err(|error| rustix_tree_error(&child_relative, error))?;
                    TreeEntry::symlink(child_relative.clone(), target.into_bytes())
                }
                _ => TreeEntry {
                    path: child_relative.clone(),
                    kind: match kind {
                        0o010000 => TreeEntryKind::Fifo,
                        0o140000 => TreeEntryKind::Socket,
                        _ => TreeEntryKind::Device,
                    },
                    mode: before.st_mode as u32,
                    size: None,
                    link_target: None,
                    submodule_commit: None,
                },
            };
            let decision = visitor(entry)?;
            if decision == VisitDecision::Stop {
                return Ok(false);
            }

            if kind == 0o040000 && decision == VisitDecision::Continue {
                let child_fd = openat(directory, name, directory_flags(), Mode::empty())
                    .map_err(|error| rustix_tree_error(&child_relative, error))?;
                let child_directory: File = child_fd.into();
                let opened = child_directory
                    .metadata()
                    .map_err(|error| tree_error(&child_relative, error))?;
                if identity(&opened) != stat_identity(&before) {
                    return Err(tree_message(
                        &child_relative,
                        "directory changed before open",
                    ));
                }
                if !self.walk(&child_directory, &child_relative, visitor)? {
                    return Ok(false);
                }
            } else {
                let after = statat(directory, name, AtFlags::SYMLINK_NOFOLLOW)
                    .map_err(|error| rustix_tree_error(&child_relative, error))?;
                if stat_identity(&after) != stat_identity(&before) {
                    return Err(tree_message(
                        &child_relative,
                        "entry changed during enumeration",
                    ));
                }
            }
        }

        let after = directory
            .metadata()
            .map_err(|error| tree_error(relative, error))?;
        if identity(&after) != before_identity {
            return Err(tree_message(
                relative,
                "directory changed during enumeration",
            ));
        }
        Ok(true)
    }

    fn open_parent(
        &self,
        path: &SourcePath,
    ) -> std::result::Result<(File, CString), InventoryError> {
        validate_relative(path)?;
        let parts = path
            .as_bytes()
            .split(|byte| *byte == b'/')
            .collect::<Vec<_>>();
        let mut directory = self
            .handles
            .last()
            .expect("root handle")
            .try_clone()
            .map_err(|error| tree_error(path, error))?;
        for part in &parts[..parts.len() - 1] {
            let name = CString::new(*part).map_err(|_| tree_message(path, "path contains NUL"))?;
            let fd = openat(&directory, &name, directory_flags(), Mode::empty())
                .map_err(|error| rustix_tree_error(path, error))?;
            directory = fd.into();
        }
        let name = CString::new(parts[parts.len() - 1])
            .map_err(|_| tree_message(path, "path contains NUL"))?;
        Ok((directory, name))
    }
}

pub fn inspect_pinned_git(
    runner: &dyn GitRunner,
    root: &Path,
    reference: Option<&str>,
) -> Result<GitSnapshot> {
    let held_root = HeldDirectoryReader::open(root)?;
    let info = runner.run(GitCommand::WorktreeInfo {
        worktree: root.to_path_buf(),
    })?;
    let [reported_root, git_dir, common_dir] = parse_three_paths(&info.stdout)?;
    if reported_root != root {
        return Err(CoreError::Source(
            "pinned local Git root does not match the held root".into(),
        ));
    }
    let held_git_dir = HeldDirectoryReader::open(&git_dir)?;
    let held_common_dir = HeldDirectoryReader::open(&common_dir)?;
    let status = runner.run(GitCommand::WorktreeStatus {
        worktree: root.to_path_buf(),
    })?;
    if !status.stdout.is_empty() {
        return Err(CoreError::Source(
            "pinned local Git worktree must be clean".into(),
        ));
    }
    revalidate_git_roots(&held_root, &held_git_dir, &held_common_dir)?;

    let revision = reference
        .map(validate_ref)
        .transpose()?
        .unwrap_or_else(|| "HEAD".into());
    let commit = parse_object_line(
        runner
            .run(GitCommand::RevParse {
                bare_repository: git_dir.clone(),
                revision: format!("{revision}^{{commit}}"),
            })?
            .stdout,
        "pinned commit",
    )?;
    let tree = parse_object_line(
        runner
            .run(GitCommand::RevParse {
                bare_repository: git_dir.clone(),
                revision: format!("{revision}^{{tree}}"),
            })?
            .stdout,
        "pinned tree",
    )?;
    revalidate_git_roots(&held_root, &held_git_dir, &held_common_dir)?;
    Ok(GitSnapshot {
        identity: CanonicalIdentity::local(SourceKind::Git, root)?,
        requested_ref: reference.map(str::to_owned),
        fetched_ref: revision,
        commit,
        tree,
        bare_repository: git_dir,
    })
}

fn revalidate_git_roots(
    root: &HeldDirectoryReader,
    git_dir: &HeldDirectoryReader,
    common_dir: &HeldDirectoryReader,
) -> Result<()> {
    root.revalidate()?;
    git_dir.revalidate()?;
    common_dir.revalidate()
}

#[cfg(unix)]
fn parse_three_paths(bytes: &[u8]) -> Result<[PathBuf; 3]> {
    use std::os::unix::ffi::OsStrExt;

    let lines = bytes
        .strip_suffix(b"\n")
        .unwrap_or(bytes)
        .split(|byte| *byte == b'\n')
        .collect::<Vec<_>>();
    if lines.len() != 3 || lines.iter().any(|line| line.is_empty()) {
        return Err(CoreError::Source(
            "Git worktree identity must contain exactly three paths".into(),
        ));
    }
    let paths = lines
        .into_iter()
        .map(|line| PathBuf::from(std::ffi::OsStr::from_bytes(line)))
        .collect::<Vec<_>>();
    if paths.iter().any(|path| !path.is_absolute()) {
        return Err(CoreError::Source(
            "Git worktree identity paths must be absolute".into(),
        ));
    }
    Ok(paths.try_into().expect("three validated paths"))
}

fn parse_object_line(bytes: Vec<u8>, name: &str) -> Result<String> {
    let text = std::str::from_utf8(&bytes)
        .map_err(|_| CoreError::Source(format!("{name} is not UTF-8")))?;
    let value = text.strip_suffix('\n').unwrap_or(text);
    if value.is_empty() || value.contains('\n') {
        return Err(CoreError::Source(format!("{name} must be one line")));
    }
    super::identity::validate_object_id(value)?;
    Ok(value.into())
}

impl TreeReader for HeldDirectoryReader {
    fn visit_entries(
        &self,
        visitor: &mut dyn FnMut(TreeEntry) -> std::result::Result<VisitDecision, InventoryError>,
    ) -> std::result::Result<(), InventoryError> {
        self.revalidate().map_err(core_to_tree)?;
        self.walk(
            self.handles.last().expect("root handle"),
            &SourcePath::from(""),
            visitor,
        )?;
        self.revalidate().map_err(core_to_tree)
    }

    fn open<'a>(
        &'a self,
        path: &SourcePath,
    ) -> std::result::Result<Box<dyn Read + 'a>, InventoryError> {
        let (parent, name) = self.open_parent(path)?;
        let before = statat(&parent, &name, AtFlags::SYMLINK_NOFOLLOW)
            .map_err(|error| rustix_tree_error(path, error))?;
        if mode_kind(before.st_mode as u32) != 0o100000 {
            return Err(tree_message(path, "entry is not a regular file"));
        }
        let fd = openat(
            &parent,
            &name,
            OFlags::RDONLY | OFlags::CLOEXEC | OFlags::NOFOLLOW,
            Mode::empty(),
        )
        .map_err(|error| rustix_tree_error(path, error))?;
        let file: File = fd.into();
        let opened = file.metadata().map_err(|error| tree_error(path, error))?;
        let expected = identity(&opened);
        if expected != stat_identity(&before) {
            return Err(tree_message(path, "entry changed before open"));
        }
        Ok(Box::new(HeldFile {
            file,
            parent,
            name,
            expected,
            source_path: path.clone(),
        }))
    }
}

struct HeldFile {
    file: File,
    parent: File,
    name: CString,
    expected: FileIdentity,
    source_path: SourcePath,
}

impl Read for HeldFile {
    fn read(&mut self, buffer: &mut [u8]) -> std::io::Result<usize> {
        let read = self.file.read(buffer)?;
        if read == 0 {
            let named = statat(&self.parent, &self.name, AtFlags::SYMLINK_NOFOLLOW)
                .map_err(std::io::Error::from)?;
            let opened = self.file.metadata()?;
            if stat_identity(&named) != self.expected || identity(&opened) != self.expected {
                return Err(std::io::Error::other(format!(
                    "{} changed during read",
                    self.source_path
                )));
            }
        }
        Ok(read)
    }
}

fn directory_flags() -> OFlags {
    OFlags::RDONLY | OFlags::DIRECTORY | OFlags::CLOEXEC | OFlags::NOFOLLOW
}

fn mode_kind(mode: u32) -> u32 {
    mode & 0o170000
}

#[cfg(unix)]
fn identity(metadata: &fs::Metadata) -> FileIdentity {
    FileIdentity {
        device: metadata.dev(),
        inode: metadata.ino(),
        kind: mode_kind(metadata.mode()),
        size: metadata.len(),
        modified_seconds: metadata.mtime(),
        modified_nanoseconds: metadata.mtime_nsec(),
        changed_seconds: metadata.ctime(),
        changed_nanoseconds: metadata.ctime_nsec(),
    }
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
fn stat_identity(stat: &Stat) -> FileIdentity {
    FileIdentity {
        device: stat.st_dev as u64,
        inode: stat.st_ino,
        kind: mode_kind(stat.st_mode as u32),
        size: stat.st_size as u64,
        modified_seconds: stat.st_mtime,
        modified_nanoseconds: stat.st_mtime_nsec,
        changed_seconds: stat.st_ctime,
        changed_nanoseconds: stat.st_ctime_nsec,
    }
}

fn validate_relative(path: &SourcePath) -> std::result::Result<(), InventoryError> {
    if path.as_bytes().is_empty()
        || path.as_bytes().starts_with(b"/")
        || path
            .as_bytes()
            .split(|byte| *byte == b'/')
            .any(|part| part.is_empty() || matches!(part, b"." | b".."))
    {
        Err(tree_message(path, "unsafe relative path"))
    } else {
        Ok(())
    }
}

fn core_to_tree(error: CoreError) -> InventoryError {
    InventoryError::Tree {
        path: SourcePath::from(""),
        message: error.to_string(),
    }
}

fn tree_message(path: &SourcePath, message: &str) -> InventoryError {
    InventoryError::Tree {
        path: path.clone(),
        message: message.into(),
    }
}

fn tree_error(path: &SourcePath, error: std::io::Error) -> InventoryError {
    tree_message(path, &error.to_string())
}

fn rustix_tree_error(path: &SourcePath, error: rustix::io::Errno) -> InventoryError {
    tree_message(path, &error.to_string())
}

fn io_error(path: &Path, error: std::io::Error) -> CoreError {
    CoreError::Io {
        path: path.display().to_string(),
        message: error.to_string(),
    }
}

fn rustix_io_error(path: &Path, error: rustix::io::Errno) -> CoreError {
    CoreError::Io {
        path: path.display().to_string(),
        message: error.to_string(),
    }
}
