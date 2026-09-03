use std::collections::BTreeMap;
use std::io::{Cursor, Read};
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::{Duration, Instant};

use grimoire_pack::inventory::{
    InventoryError, SourcePath, TreeEntry, TreeEntryKind, TreeReader, VisitDecision,
};

use super::{validate_ref, CanonicalIdentity};
use crate::{CoreError, Result};

pub const PRIVATE_REF: &str = "refs/grimoire/candidate";
pub const CONTROL_LIMIT: usize = 1024 * 1024;
const FETCH_DEADLINE: Duration = Duration::from_secs(600);

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum GitCommand {
    InitBare {
        repository: PathBuf,
    },
    LsRemote {
        repository: String,
    },
    Fetch {
        bare_repository: PathBuf,
        repository: String,
        source_ref: String,
    },
    RevParse {
        bare_repository: PathBuf,
        revision: String,
    },
    LsTree {
        bare_repository: PathBuf,
        tree: String,
    },
    CatBlob {
        bare_repository: PathBuf,
        object: String,
    },
    WorktreeInfo {
        worktree: PathBuf,
    },
    WorktreeStatus {
        worktree: PathBuf,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GitResult {
    pub stdout: Vec<u8>,
    pub stderr: Vec<u8>,
}

pub trait GitRunner {
    fn run(&self, command: GitCommand) -> Result<GitResult>;

    fn run_until(&self, command: GitCommand, _deadline: Instant) -> Result<GitResult> {
        self.run(command)
    }

    fn verify_cache(&self, _path: &Path) -> Result<()> {
        Err(CoreError::Source(
            "Git runner does not provide cache verification".into(),
        ))
    }

    fn stream(
        &self,
        command: GitCommand,
        maximum_chunk: usize,
        visitor: &mut dyn FnMut(&[u8]) -> Result<bool>,
    ) -> Result<GitResult> {
        let result = self.run(command)?;
        for chunk in result.stdout.chunks(maximum_chunk.max(1)) {
            if !visitor(chunk)? {
                break;
            }
        }
        Ok(GitResult {
            stdout: Vec::new(),
            stderr: result.stderr,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GitSnapshot {
    pub identity: CanonicalIdentity,
    pub requested_ref: Option<String>,
    pub fetched_ref: String,
    pub commit: String,
    pub tree: String,
    pub bare_repository: PathBuf,
}

pub struct GitTreeReader<'a> {
    runner: &'a dyn GitRunner,
    bare_repository: PathBuf,
    tree: String,
    blobs: Mutex<BTreeMap<SourcePath, String>>,
}

impl<'a> GitTreeReader<'a> {
    pub fn new(runner: &'a dyn GitRunner, snapshot: &GitSnapshot) -> Self {
        Self {
            runner,
            bare_repository: snapshot.bare_repository.clone(),
            tree: snapshot.tree.clone(),
            blobs: Mutex::new(BTreeMap::new()),
        }
    }

    fn walk_tree(
        &self,
        tree: &str,
        prefix: &SourcePath,
        visitor: &mut dyn FnMut(TreeEntry) -> std::result::Result<VisitDecision, InventoryError>,
    ) -> std::result::Result<bool, InventoryError> {
        let mut pending = Vec::new();
        let mut stopped = false;
        let mut inventory_error = None;
        let result = self.runner.stream(
            GitCommand::LsTree {
                bare_repository: self.bare_repository.clone(),
                tree: tree.to_owned(),
            },
            64 * 1024,
            &mut |chunk| {
                pending.extend_from_slice(chunk);
                while let Some(end) = pending.iter().position(|byte| *byte == 0) {
                    let record = pending.drain(..=end).collect::<Vec<_>>();
                    if record.len() == 1 {
                        continue;
                    }
                    let (entry, object) = match parse_tree_record(
                        &record[..record.len() - 1],
                        prefix,
                        self.runner,
                        &self.bare_repository,
                    ) {
                        Ok(parsed) => parsed,
                        Err(error) => {
                            inventory_error = Some(error);
                            return Err(CoreError::Source("invalid streamed Git tree".into()));
                        }
                    };
                    if entry.kind == TreeEntryKind::File {
                        self.blobs
                            .lock()
                            .expect("blob map mutex poisoned")
                            .insert(entry.path.clone(), object.clone());
                    }
                    let directory = (entry.kind == TreeEntryKind::Directory)
                        .then(|| (entry.path.clone(), object));
                    match visitor(entry) {
                        Ok(VisitDecision::Continue) => {
                            if let Some((path, object)) = directory {
                                match self.walk_tree(&object, &path, visitor) {
                                    Ok(true) => {}
                                    Ok(false) => {
                                        stopped = true;
                                        return Ok(false);
                                    }
                                    Err(error) => {
                                        inventory_error = Some(error);
                                        return Err(CoreError::Source(
                                            "inventory visitor rejected Git tree".into(),
                                        ));
                                    }
                                }
                            }
                        }
                        Ok(VisitDecision::SkipSubtree) => {}
                        Ok(VisitDecision::Stop) => {
                            stopped = true;
                            return Ok(false);
                        }
                        Err(error) => {
                            inventory_error = Some(error);
                            return Err(CoreError::Source(
                                "inventory visitor rejected Git tree".into(),
                            ));
                        }
                    }
                }
                Ok(true)
            },
        );
        if let Some(error) = inventory_error {
            return Err(error);
        }
        result.map_err(core_tree_error)?;
        if !stopped && !pending.is_empty() {
            return Err(tree_message("unterminated ls-tree record"));
        }
        Ok(!stopped)
    }
}

impl TreeReader for GitTreeReader<'_> {
    fn visit_entries(
        &self,
        visitor: &mut dyn FnMut(TreeEntry) -> std::result::Result<VisitDecision, InventoryError>,
    ) -> std::result::Result<(), InventoryError> {
        self.blobs.lock().expect("blob map mutex poisoned").clear();
        self.walk_tree(&self.tree, &SourcePath::from(""), visitor)?;
        Ok(())
    }

    fn open<'a>(
        &'a self,
        path: &SourcePath,
    ) -> std::result::Result<Box<dyn Read + 'a>, InventoryError> {
        let object = self
            .blobs
            .lock()
            .expect("blob map mutex poisoned")
            .get(path)
            .cloned()
            .ok_or_else(|| InventoryError::Tree {
                path: path.clone(),
                message: "blob was not enumerated".into(),
            })?;
        let bytes = self
            .runner
            .run(GitCommand::CatBlob {
                bare_repository: self.bare_repository.clone(),
                object,
            })
            .map_err(core_tree_error)?
            .stdout;
        Ok(Box::new(Cursor::new(bytes)))
    }

    fn read_chunks(
        &self,
        path: &SourcePath,
        maximum_chunk: usize,
        visitor: &mut dyn FnMut(&[u8]) -> std::result::Result<bool, InventoryError>,
    ) -> std::result::Result<(), InventoryError> {
        let object = self
            .blobs
            .lock()
            .expect("blob map mutex poisoned")
            .get(path)
            .cloned()
            .ok_or_else(|| InventoryError::Tree {
                path: path.clone(),
                message: "blob was not enumerated".into(),
            })?;
        let mut inventory_error = None;
        self.runner
            .stream(
                GitCommand::CatBlob {
                    bare_repository: self.bare_repository.clone(),
                    object,
                },
                maximum_chunk,
                &mut |chunk| match visitor(chunk) {
                    Ok(keep_reading) => Ok(keep_reading),
                    Err(error) => {
                        inventory_error = Some(error);
                        Err(CoreError::Source(
                            "inventory visitor rejected Git blob".into(),
                        ))
                    }
                },
            )
            .map_err(|error| {
                inventory_error
                    .take()
                    .unwrap_or_else(|| core_tree_error(error))
            })?;
        Ok(())
    }
}

fn parse_tree_record(
    record: &[u8],
    prefix: &SourcePath,
    runner: &dyn GitRunner,
    bare_repository: &Path,
) -> std::result::Result<(TreeEntry, String), InventoryError> {
    let separator = record
        .iter()
        .position(|byte| *byte == b'\t')
        .ok_or_else(|| tree_message("malformed ls-tree record"))?;
    let (header, path_with_tab) = record.split_at(separator);
    let path = &path_with_tab[1..];
    let fields: Vec<_> = header
        .split(|byte| *byte == b' ')
        .filter(|field| !field.is_empty())
        .collect();
    if fields.len() != 4 {
        return Err(tree_message("malformed ls-tree header"));
    }
    let mode = std::str::from_utf8(fields[0])
        .ok()
        .and_then(|mode| u32::from_str_radix(mode, 8).ok())
        .ok_or_else(|| tree_message("invalid ls-tree mode"))?;
    let kind = std::str::from_utf8(fields[1]).map_err(|_| tree_message("invalid ls-tree kind"))?;
    let object = std::str::from_utf8(fields[2])
        .map_err(|_| tree_message("invalid ls-tree object"))?
        .to_owned();
    super::identity::validate_object_id(&object).map_err(core_tree_error)?;
    let source_path = if prefix.as_bytes().is_empty() {
        SourcePath::new(path.to_vec())
    } else {
        prefix.join(path)
    };
    match (mode, kind) {
        (0o120000, "blob") => {
            let mut target = Vec::new();
            runner
                .stream(
                    GitCommand::CatBlob {
                        bare_repository: bare_repository.to_path_buf(),
                        object: object.clone(),
                    },
                    64 * 1024,
                    &mut |chunk| {
                        if target.len().saturating_add(chunk.len()) > 128 * 1024 * 1024 {
                            return Err(CoreError::Source("Git link target limit exceeded".into()));
                        }
                        target.extend_from_slice(chunk);
                        Ok(true)
                    },
                )
                .map_err(core_tree_error)?;
            Ok((TreeEntry::symlink(source_path, target), object))
        }
        (0o160000, "commit") => Ok((
            TreeEntry {
                path: source_path,
                kind: TreeEntryKind::Submodule,
                mode,
                size: None,
                link_target: None,
                submodule_commit: Some(object.clone()),
            },
            object,
        )),
        (0o040000, "tree") => {
            let mut entry = TreeEntry::directory(source_path);
            entry.mode = mode;
            Ok((entry, object))
        }
        (_, "blob") => {
            let size = std::str::from_utf8(fields[3])
                .ok()
                .and_then(|size| size.parse::<u64>().ok())
                .ok_or_else(|| tree_message("invalid ls-tree size"))?;
            let mut entry = TreeEntry::file(source_path, mode);
            entry.size = Some(size);
            Ok((entry, object))
        }
        _ => Err(tree_message("unsupported ls-tree entry")),
    }
}

pub fn fetch_remote(
    runner: &dyn GitRunner,
    declared: &str,
    reference: Option<&str>,
    temporary_bare: &Path,
) -> Result<GitSnapshot> {
    let deadline = Instant::now() + FETCH_DEADLINE;
    let identity = CanonicalIdentity::remote(declared)?;
    let repository = identity
        .repository()
        .expect("remote identity has transport")
        .to_owned();
    let source_ref = match reference {
        Some(reference) => validate_ref(reference)?,
        None => resolve_head(runner, &repository, deadline)?,
    };
    runner.run_until(
        GitCommand::InitBare {
            repository: temporary_bare.to_path_buf(),
        },
        deadline,
    )?;
    runner.run_until(
        GitCommand::Fetch {
            bare_repository: temporary_bare.to_path_buf(),
            repository,
            source_ref: source_ref.clone(),
        },
        deadline,
    )?;
    let commit = one_line(
        runner
            .run_until(
                GitCommand::RevParse {
                    bare_repository: temporary_bare.to_path_buf(),
                    revision: format!("{PRIVATE_REF}^{{commit}}"),
                },
                deadline,
            )?
            .stdout,
        "candidate commit",
    )?;
    super::identity::validate_object_id(&commit)?;
    let tree = one_line(
        runner
            .run_until(
                GitCommand::RevParse {
                    bare_repository: temporary_bare.to_path_buf(),
                    revision: format!("{PRIVATE_REF}^{{tree}}"),
                },
                deadline,
            )?
            .stdout,
        "candidate tree",
    )?;
    super::identity::validate_object_id(&tree)?;
    Ok(GitSnapshot {
        identity,
        requested_ref: reference.map(str::to_owned),
        fetched_ref: source_ref,
        commit,
        tree,
        bare_repository: temporary_bare.to_path_buf(),
    })
}

fn resolve_head(runner: &dyn GitRunner, repository: &str, deadline: Instant) -> Result<String> {
    let result = runner.run_until(
        GitCommand::LsRemote {
            repository: repository.into(),
        },
        deadline,
    )?;
    if result.stdout.len() > CONTROL_LIMIT || result.stderr.len() > CONTROL_LIMIT {
        return Err(CoreError::Source(
            "ls-remote control output limit exceeded".into(),
        ));
    }
    let text = std::str::from_utf8(&result.stdout)
        .map_err(|_| CoreError::Source("ls-remote output is not UTF-8".into()))?;
    let mut symref = None;
    let mut oid = None;
    for line in text.lines() {
        if let Some(value) = line
            .strip_prefix("ref: ")
            .and_then(|line| line.strip_suffix("\tHEAD"))
        {
            if symref.replace(value.to_owned()).is_some() {
                return Err(CoreError::Source("conflicting HEAD symrefs".into()));
            }
        } else if let Some((value, reported)) = line.split_once('\t') {
            if reported == "HEAD" && oid.replace(value.to_owned()).is_some() {
                return Err(CoreError::Source("conflicting HEAD object IDs".into()));
            }
        }
    }
    let symref = symref.ok_or_else(|| CoreError::Source("missing exact HEAD symref".into()))?;
    let oid = oid.ok_or_else(|| CoreError::Source("missing exact HEAD object ID".into()))?;
    super::identity::validate_object_id(&oid)?;
    validate_ref(&symref)
}

fn one_line(bytes: Vec<u8>, name: &str) -> Result<String> {
    if bytes.len() > CONTROL_LIMIT {
        return Err(CoreError::Source(format!("{name} output limit exceeded")));
    }
    let text = std::str::from_utf8(&bytes)
        .map_err(|_| CoreError::Source(format!("{name} is not UTF-8")))?;
    let line = text.trim_end_matches('\n');
    if line.is_empty() || line.contains('\n') {
        return Err(CoreError::Source(format!("{name} must be one line")));
    }
    Ok(line.into())
}

fn core_tree_error(error: CoreError) -> InventoryError {
    InventoryError::Tree {
        path: SourcePath::from(""),
        message: error.to_string(),
    }
}

fn tree_message(message: &str) -> InventoryError {
    InventoryError::Tree {
        path: SourcePath::from(""),
        message: message.into(),
    }
}
