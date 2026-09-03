use std::fs::{self, File, OpenOptions};
use std::io;
use std::path::{Path, PathBuf};

use grimoire_pack::inventory::{scan_skill_tree, Severity};

use crate::source::HeldDirectoryReader;
use crate::{
    CoreError, LockSkill, Paths, ProjectionMode, Result, SkillName, VendorPrecondition, VendorState,
};

pub fn verify_vendor_tree(root: &Path, expected_name: &SkillName) -> Result<String> {
    let metadata = fs::symlink_metadata(root).map_err(|error| io_error(root, error))?;
    if metadata.file_type().is_symlink() || !metadata.is_dir() {
        return Err(CoreError::Source(format!(
            "vendor root `{}` is not a regular directory",
            root.display()
        )));
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mode = metadata.permissions().mode() & 0o7777;
        if mode != 0o755 {
            return Err(CoreError::Source(format!(
                "vendor root `{}` has non-normalized mode {mode:04o}",
                root.display()
            )));
        }
    }

    let reader = HeldDirectoryReader::open(root)?;
    let inventory = scan_skill_tree(&reader, expected_name.as_str())
        .map_err(|error| CoreError::Source(error.to_string()))?;
    reader.revalidate()?;
    let errors = inventory
        .findings
        .iter()
        .filter(|finding| finding.severity == Severity::Error)
        .map(|finding| {
            finding.path.as_ref().map_or_else(
                || finding.code.clone(),
                |path| format!("{}:{}", finding.code, path),
            )
        })
        .collect::<Vec<_>>();
    if !errors.is_empty() {
        return Err(CoreError::Source(format!(
            "vendor tree `{}` is structurally invalid: {}",
            root.display(),
            errors.join(",")
        )));
    }
    inventory
        .skill
        .map(|skill| skill.content_digest.to_string())
        .ok_or_else(|| CoreError::Source("vendor tree has no verified skill".into()))
}

pub(crate) fn observe_vendor(
    paths: &Paths,
    name: &SkillName,
    incumbent: &LockSkill,
) -> Result<VendorPrecondition> {
    observe_vendor_at(paths, &incumbent.source, name, Some(incumbent))
}

pub(crate) fn observe_vendor_at(
    paths: &Paths,
    source: &crate::SourceAlias,
    name: &SkillName,
    incumbent: Option<&LockSkill>,
) -> Result<VendorPrecondition> {
    observe_vendor_path(&paths.vendor_path(source, name)?, name, incumbent)
}

fn observe_vendor_path(
    path: &Path,
    name: &SkillName,
    incumbent: Option<&LockSkill>,
) -> Result<VendorPrecondition> {
    let metadata = match fs::symlink_metadata(path) {
        Ok(metadata) => metadata,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            return Ok(VendorPrecondition {
                state: VendorState::Absent,
                content: None,
            });
        }
        Err(error) => return Err(io_error(path, error)),
    };
    let Some(incumbent) = incumbent else {
        return Ok(VendorPrecondition {
            state: VendorState::Foreign,
            content: None,
        });
    };
    if incumbent.mode != ProjectionMode::Vendor
        || metadata.file_type().is_symlink()
        || !metadata.is_dir()
    {
        return Ok(VendorPrecondition {
            state: VendorState::Foreign,
            content: None,
        });
    }
    match verify_vendor_tree(path, name) {
        Ok(content) if content == incumbent.content => Ok(VendorPrecondition {
            state: VendorState::OwnedUnchanged,
            content: Some(content),
        }),
        Ok(content) => Ok(VendorPrecondition {
            state: VendorState::Drifted,
            content: Some(content),
        }),
        Err(_) => Ok(VendorPrecondition {
            state: VendorState::Drifted,
            content: None,
        }),
    }
}

pub(crate) fn prepare_from_store(
    store_skill: &Path,
    destination: &Path,
    expected_name: &SkillName,
    expected_content: &str,
) -> Result<()> {
    if fs::symlink_metadata(destination).is_ok() {
        return Err(CoreError::Transaction(format!(
            "vendor preparation path already exists at {}",
            destination.display()
        )));
    }
    let source = fs::symlink_metadata(store_skill).map_err(|error| io_error(store_skill, error))?;
    if source.file_type().is_symlink() || !source.is_dir() {
        return Err(CoreError::Store(format!(
            "stored skill root `{}` is not a regular directory",
            store_skill.display()
        )));
    }
    fs::create_dir(destination).map_err(|error| io_error(destination, error))?;
    set_mode(destination, 0o755)?;
    if let Err(error) = copy_directory(store_skill, destination) {
        let _ = remove_tree(destination);
        return Err(error);
    }
    let observed = verify_vendor_tree(destination, expected_name)?;
    if observed != expected_content {
        let _ = remove_tree(destination);
        return Err(CoreError::Store(
            "prepared vendor content does not match the locked skill digest".into(),
        ));
    }
    sync_tree(destination)
}

fn copy_directory(source: &Path, destination: &Path) -> Result<()> {
    let mut entries = fs::read_dir(source)
        .map_err(|error| io_error(source, error))?
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(|error| io_error(source, error))?;
    entries.sort_by_key(|entry| entry.file_name());
    for entry in entries {
        let from = entry.path();
        let to = destination.join(entry.file_name());
        let metadata = fs::symlink_metadata(&from).map_err(|error| io_error(&from, error))?;
        if metadata.file_type().is_symlink() {
            let target = fs::read_link(&from).map_err(|error| io_error(&from, error))?;
            #[cfg(unix)]
            std::os::unix::fs::symlink(&target, &to).map_err(|error| io_error(&to, error))?;
        } else if metadata.is_dir() {
            fs::create_dir(&to).map_err(|error| io_error(&to, error))?;
            set_mode(&to, 0o755)?;
            copy_directory(&from, &to)?;
        } else if metadata.is_file() {
            let mut input = File::open(&from).map_err(|error| io_error(&from, error))?;
            let mut output = OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&to)
                .map_err(|error| io_error(&to, error))?;
            io::copy(&mut input, &mut output).map_err(|error| io_error(&to, error))?;
            output.sync_all().map_err(|error| io_error(&to, error))?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                set_mode(
                    &to,
                    if metadata.permissions().mode() & 0o111 == 0 {
                        0o644
                    } else {
                        0o755
                    },
                )?;
            }
        } else {
            return Err(CoreError::Store(format!(
                "stored skill contains unsupported entry `{}`",
                from.display()
            )));
        }
    }
    File::open(destination)
        .and_then(|directory| directory.sync_all())
        .map_err(|error| io_error(destination, error))
}

pub(crate) fn remove_tree(path: &Path) -> Result<()> {
    match fs::symlink_metadata(path) {
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(()),
        Err(error) => return Err(io_error(path, error)),
        Ok(metadata) if metadata.file_type().is_symlink() || !metadata.is_dir() => {
            return Err(CoreError::Transaction(format!(
                "refusing to remove non-directory vendor entry `{}`",
                path.display()
            )));
        }
        Ok(_) => {}
    }
    fs::remove_dir_all(path).map_err(|error| io_error(path, error))
}

fn sync_tree(root: &Path) -> Result<()> {
    let mut directories = vec![root.to_path_buf()];
    collect_directories(root, &mut directories)?;
    directories.sort_by_key(|path| std::cmp::Reverse(path.components().count()));
    for directory in directories {
        File::open(&directory)
            .and_then(|file| file.sync_all())
            .map_err(|error| io_error(&directory, error))?;
    }
    Ok(())
}

fn collect_directories(directory: &Path, output: &mut Vec<PathBuf>) -> Result<()> {
    for entry in fs::read_dir(directory)
        .map_err(|error| io_error(directory, error))?
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(|error| io_error(directory, error))?
    {
        let path = entry.path();
        let metadata = fs::symlink_metadata(&path).map_err(|error| io_error(&path, error))?;
        if metadata.is_dir() && !metadata.file_type().is_symlink() {
            output.push(path.clone());
            collect_directories(&path, output)?;
        }
    }
    Ok(())
}

#[cfg(unix)]
fn set_mode(path: &Path, mode: u32) -> Result<()> {
    use std::os::unix::fs::PermissionsExt;
    fs::set_permissions(path, fs::Permissions::from_mode(mode))
        .map_err(|error| io_error(path, error))
}

fn io_error(path: &Path, error: std::io::Error) -> CoreError {
    CoreError::Io {
        path: path.display().to_string(),
        message: error.to_string(),
    }
}
