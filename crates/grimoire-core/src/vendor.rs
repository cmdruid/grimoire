use std::ffi::CString;
use std::fs::{self, File};
use std::io::{self, Write as _};
#[cfg(unix)]
use std::os::unix::ffi::OsStrExt;
use std::path::Path;

use grimoire_pack::inventory::{scan_skill_tree, Severity};
use rustix::fs::{
    fchmod, mkdirat, openat, readlinkat, renameat_with, statat, symlinkat, unlinkat, AtFlags, Dir,
    Mode, OFlags,
};

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
    verify_vendor_reader(&reader, root, expected_name)
}

pub(crate) fn verify_vendor_tree_at(
    parent: &File,
    name: &str,
    root: &Path,
    expected_name: &SkillName,
) -> Result<String> {
    let reader = HeldDirectoryReader::open_at(parent, name, root)?;
    verify_vendor_reader(&reader, root, expected_name)
}

fn verify_vendor_reader(
    reader: &HeldDirectoryReader,
    root: &Path,
    expected_name: &SkillName,
) -> Result<String> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt;
        let root_handle = reader.root_handle()?;
        let mode = root_handle
            .metadata()
            .map_err(|error| io_error(root, error))?
            .mode()
            & 0o7777;
        if mode != 0o755 {
            return Err(CoreError::Source(format!(
                "vendor root `{}` has non-normalized mode {mode:04o}",
                root.display()
            )));
        }
    }
    let inventory = scan_skill_tree(reader, expected_name.as_str())
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
    destination_parent: &File,
    destination_name: &str,
    destination: &Path,
    expected_name: &SkillName,
    expected_content: &str,
) -> Result<()> {
    let deletion_name = c_name(&deletion_name(destination_name), destination)?;
    let destination_name = c_name(destination_name, destination)?;
    match statat(
        destination_parent,
        &destination_name,
        AtFlags::SYMLINK_NOFOLLOW,
    ) {
        Err(error) if error == rustix::io::Errno::NOENT => {}
        Ok(_) => {
            return Err(CoreError::Transaction(format!(
                "vendor preparation path already exists at {}",
                destination.display()
            )))
        }
        Err(error) => return Err(rustix_error(destination, error)),
    }
    match statat(
        destination_parent,
        &deletion_name,
        AtFlags::SYMLINK_NOFOLLOW,
    ) {
        Err(error) if error == rustix::io::Errno::NOENT => {}
        Ok(_) => {
            return Err(CoreError::RecoveryRequired(format!(
                "unfinished vendor cleanup exists beside {}",
                destination.display()
            )))
        }
        Err(error) => return Err(rustix_error(destination, error)),
    }

    let source = HeldDirectoryReader::open(store_skill)?;
    let source_root = source.root_handle()?;
    mkdirat(
        destination_parent,
        &destination_name,
        Mode::from_raw_mode(0o755),
    )
    .map_err(|error| rustix_error(destination, error))?;
    let destination_root: File = openat(
        destination_parent,
        &destination_name,
        directory_flags(),
        Mode::empty(),
    )
    .map_err(|error| rustix_error(destination, error))?
    .into();
    let destination_identity = file_identity(&destination_root, destination)?;
    let mut budget = 100_000;
    if let Err(error) = copy_directory(
        &source_root,
        &destination_root,
        store_skill,
        destination,
        0,
        &mut budget,
    )
    .and_then(|()| source.revalidate())
    {
        let _ = remove_open_tree(
            destination_parent,
            &destination_name,
            &destination_root,
            destination_identity,
            destination,
            &mut || {},
        );
        return Err(error);
    }
    let observed = verify_vendor_tree_at(
        destination_parent,
        destination_name
            .to_str()
            .map_err(|_| CoreError::Transaction("vendor preparation name is not UTF-8".into()))?,
        destination,
        expected_name,
    )?;
    if observed != expected_content {
        let _ = remove_open_tree(
            destination_parent,
            &destination_name,
            &destination_root,
            destination_identity,
            destination,
            &mut || {},
        );
        return Err(CoreError::Store(
            "prepared vendor content does not match the locked skill digest".into(),
        ));
    }
    destination_root
        .sync_all()
        .map_err(|error| io_error(destination, error))?;
    destination_parent
        .sync_all()
        .map_err(|error| io_error(destination, error))
}

fn copy_directory(
    source: &File,
    destination: &File,
    source_path: &Path,
    destination_path: &Path,
    depth: usize,
    budget: &mut usize,
) -> Result<()> {
    if depth > 64 {
        return Err(CoreError::Store("vendor copy depth limit exceeded".into()));
    }
    let mut entries = Dir::read_from(source)
        .map_err(|error| rustix_error(source_path, error))?
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(|error| rustix_error(source_path, error))?;
    entries.retain(|entry| !matches!(entry.file_name().to_bytes(), b"." | b".."));
    entries.sort_by(|left, right| {
        left.file_name()
            .to_bytes()
            .cmp(right.file_name().to_bytes())
    });
    for entry in entries {
        if *budget == 0 {
            return Err(CoreError::Store("vendor copy entry limit exceeded".into()));
        }
        *budget -= 1;
        let name = entry.file_name();
        let child_source = source_path.join(std::ffi::OsStr::from_bytes(name.to_bytes()));
        let child_destination = destination_path.join(std::ffi::OsStr::from_bytes(name.to_bytes()));
        let before = statat(source, name, AtFlags::SYMLINK_NOFOLLOW)
            .map_err(|error| rustix_error(&child_source, error))?;
        match mode_kind(before.st_mode as u32) {
            0o040000 => {
                let source_child: File = openat(source, name, directory_flags(), Mode::empty())
                    .map_err(|error| rustix_error(&child_source, error))?
                    .into();
                require_identity(&source_child, stat_identity(&before), &child_source)?;
                mkdirat(destination, name, Mode::from_raw_mode(0o755))
                    .map_err(|error| rustix_error(&child_destination, error))?;
                let destination_child: File =
                    openat(destination, name, directory_flags(), Mode::empty())
                        .map_err(|error| rustix_error(&child_destination, error))?
                        .into();
                copy_directory(
                    &source_child,
                    &destination_child,
                    &child_source,
                    &child_destination,
                    depth + 1,
                    budget,
                )?;
            }
            0o100000 => {
                let mut input: File = openat(
                    source,
                    name,
                    OFlags::RDONLY | OFlags::CLOEXEC | OFlags::NOFOLLOW,
                    Mode::empty(),
                )
                .map_err(|error| rustix_error(&child_source, error))?
                .into();
                require_identity(&input, stat_identity(&before), &child_source)?;
                let mut output: File = openat(
                    destination,
                    name,
                    OFlags::WRONLY | OFlags::CREATE | OFlags::EXCL | OFlags::CLOEXEC,
                    Mode::from_raw_mode(0o600),
                )
                .map_err(|error| rustix_error(&child_destination, error))?
                .into();
                io::copy(&mut input, &mut output)
                    .map_err(|error| io_error(&child_destination, error))?;
                output
                    .flush()
                    .map_err(|error| io_error(&child_destination, error))?;
                fchmod(
                    &output,
                    Mode::from_raw_mode(if before.st_mode as u32 & 0o111 == 0 {
                        0o644
                    } else {
                        0o755
                    }),
                )
                .map_err(|error| rustix_error(&child_destination, error))?;
                output
                    .sync_all()
                    .map_err(|error| io_error(&child_destination, error))?;
            }
            0o120000 => {
                let target = readlinkat(source, name, Vec::new())
                    .map_err(|error| rustix_error(&child_source, error))?;
                symlinkat(target.to_bytes(), destination, name)
                    .map_err(|error| rustix_error(&child_destination, error))?;
            }
            _ => {
                return Err(CoreError::Store(format!(
                    "stored skill contains unsupported entry `{}`",
                    child_source.display()
                )))
            }
        }
        let after = statat(source, name, AtFlags::SYMLINK_NOFOLLOW)
            .map_err(|error| rustix_error(&child_source, error))?;
        if stat_identity(&after) != stat_identity(&before) {
            return Err(CoreError::Store(format!(
                "stored skill entry changed during copy at {}",
                child_source.display()
            )));
        }
    }
    destination
        .sync_all()
        .map_err(|error| io_error(destination_path, error))
}

pub(crate) fn remove_verified_tree_at(
    parent: &File,
    name: &str,
    path: &Path,
    expected_name: &SkillName,
    expected_content: &str,
) -> Result<()> {
    let name = c_name(name, path)?;
    let reader = HeldDirectoryReader::open_at(parent, name.to_str().unwrap(), path)?;
    let observed = verify_vendor_reader(&reader, path, expected_name)?;
    if observed != expected_content {
        return Err(CoreError::RecoveryRequired(format!(
            "vendor transaction path `{}` changed",
            path.display()
        )));
    }
    let root = reader.root_handle()?;
    let identity = file_identity(&root, path)?;
    remove_open_tree(parent, &name, &root, identity, path, &mut || {})
}

fn remove_open_tree(
    parent: &File,
    name: &CString,
    root: &File,
    identity: (u64, u64, u32),
    path: &Path,
    before_capture: &mut dyn FnMut(),
) -> Result<()> {
    before_capture();
    // Move the verified inode out of the attacker-controlled fixed name before
    // deleting it. A replacement that wins this race is restored after the
    // identity check instead of being traversed or removed.
    let name_text = name
        .to_str()
        .map_err(|_| CoreError::Transaction("vendor cleanup name is not UTF-8".into()))?;
    let capture =
        CString::new(deletion_name(name_text)).expect("validated cleanup name has no NUL");
    renameat_with(
        parent,
        name,
        parent,
        &capture,
        rustix::fs::RenameFlags::NOREPLACE,
    )
    .map_err(|error| rustix_error(path, error))?;
    let captured = statat(parent, &capture, AtFlags::SYMLINK_NOFOLLOW)
        .map_err(|error| rustix_error(path, error))?;
    if stat_identity(&captured) != identity {
        let restored = renameat_with(
            parent,
            &capture,
            parent,
            name,
            rustix::fs::RenameFlags::NOREPLACE,
        );
        return match restored {
            Ok(()) => Err(CoreError::RecoveryRequired(format!(
                "vendor transaction path `{}` changed before removal",
                path.display()
            ))),
            Err(error) => Err(CoreError::RecoveryRequired(format!(
                "vendor transaction path `{}` changed and its replacement could not be restored: {error}",
                path.display()
            ))),
        };
    }
    let mut budget = 100_000;
    remove_tree_contents(root, path, 0, &mut budget)?;
    let named = statat(parent, &capture, AtFlags::SYMLINK_NOFOLLOW)
        .map_err(|error| rustix_error(path, error))?;
    if stat_identity(&named) != identity {
        return Err(CoreError::RecoveryRequired(format!(
            "vendor transaction path `{}` changed before removal",
            path.display()
        )));
    }
    unlinkat(parent, &capture, AtFlags::REMOVEDIR).map_err(|error| rustix_error(path, error))?;
    parent.sync_all().map_err(|error| io_error(path, error))
}

fn remove_tree_contents(
    directory: &File,
    path: &Path,
    depth: usize,
    budget: &mut usize,
) -> Result<()> {
    if depth > 64 {
        return Err(CoreError::Transaction(
            "vendor cleanup depth limit exceeded".into(),
        ));
    }
    let mut entries = Dir::read_from(directory)
        .map_err(|error| rustix_error(path, error))?
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(|error| rustix_error(path, error))?;
    entries.retain(|entry| !matches!(entry.file_name().to_bytes(), b"." | b".."));
    entries.sort_by(|left, right| {
        left.file_name()
            .to_bytes()
            .cmp(right.file_name().to_bytes())
    });
    for entry in entries {
        if *budget == 0 {
            return Err(CoreError::Transaction(
                "vendor cleanup entry limit exceeded".into(),
            ));
        }
        *budget -= 1;
        let name = entry.file_name();
        let child_path = path.join(std::ffi::OsStr::from_bytes(name.to_bytes()));
        let before = statat(directory, name, AtFlags::SYMLINK_NOFOLLOW)
            .map_err(|error| rustix_error(&child_path, error))?;
        if mode_kind(before.st_mode as u32) == 0o040000 {
            let child: File = openat(directory, name, directory_flags(), Mode::empty())
                .map_err(|error| rustix_error(&child_path, error))?
                .into();
            require_identity(&child, stat_identity(&before), &child_path)?;
            remove_tree_contents(&child, &child_path, depth + 1, budget)?;
            let after = statat(directory, name, AtFlags::SYMLINK_NOFOLLOW)
                .map_err(|error| rustix_error(&child_path, error))?;
            if stat_identity(&after) != stat_identity(&before) {
                return Err(CoreError::RecoveryRequired(format!(
                    "vendor entry `{}` changed before removal",
                    child_path.display()
                )));
            }
            unlinkat(directory, name, AtFlags::REMOVEDIR)
                .map_err(|error| rustix_error(&child_path, error))?;
        } else {
            let after = statat(directory, name, AtFlags::SYMLINK_NOFOLLOW)
                .map_err(|error| rustix_error(&child_path, error))?;
            if stat_identity(&after) != stat_identity(&before) {
                return Err(CoreError::RecoveryRequired(format!(
                    "vendor entry `{}` changed before removal",
                    child_path.display()
                )));
            }
            unlinkat(directory, name, AtFlags::empty())
                .map_err(|error| rustix_error(&child_path, error))?;
        }
    }
    directory.sync_all().map_err(|error| io_error(path, error))
}

fn c_name(name: &str, path: &Path) -> Result<CString> {
    CString::new(name).map_err(|_| {
        CoreError::Transaction(format!(
            "vendor entry name contains NUL at {}",
            path.display()
        ))
    })
}

pub(crate) fn deletion_name(name: &str) -> String {
    format!("{name}.deleting")
}

fn directory_flags() -> OFlags {
    OFlags::RDONLY | OFlags::DIRECTORY | OFlags::CLOEXEC | OFlags::NOFOLLOW
}

fn mode_kind(mode: u32) -> u32 {
    mode & 0o170000
}

fn stat_identity(stat: &rustix::fs::Stat) -> (u64, u64, u32) {
    (
        stat.st_dev as u64,
        stat.st_ino,
        mode_kind(stat.st_mode as u32),
    )
}

fn file_identity(file: &File, path: &Path) -> Result<(u64, u64, u32)> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt;
        let metadata = file.metadata().map_err(|error| io_error(path, error))?;
        Ok((metadata.dev(), metadata.ino(), mode_kind(metadata.mode())))
    }
    #[cfg(not(unix))]
    unreachable!("Grimoire supports Unix hosts")
}

fn require_identity(file: &File, expected: (u64, u64, u32), path: &Path) -> Result<()> {
    if file_identity(file, path)? == expected {
        Ok(())
    } else {
        Err(CoreError::Store(format!(
            "stored skill entry changed before open at {}",
            path.display()
        )))
    }
}

fn io_error(path: &Path, error: std::io::Error) -> CoreError {
    CoreError::Io {
        path: path.display().to_string(),
        message: error.to_string(),
    }
}

fn rustix_error(path: &Path, error: rustix::io::Errno) -> CoreError {
    CoreError::Io {
        path: path.display().to_string(),
        message: error.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cleanup_preserves_a_same_content_late_replacement_inode() {
        let temporary = tempfile::tempdir().unwrap();
        let parent_path = temporary.path().join("parent");
        let owned_path = parent_path.join("owned");
        let foreign_path = parent_path.join("foreign");
        fs::create_dir_all(&owned_path).unwrap();
        fs::create_dir(&foreign_path).unwrap();
        for path in [&owned_path, &foreign_path] {
            fs::write(path.join("SKILL.md"), "same content\n").unwrap();
        }
        let parent = File::open(&parent_path).unwrap();
        let name = CString::new("owned").unwrap();
        let root: File = openat(&parent, &name, directory_flags(), Mode::empty())
            .unwrap()
            .into();
        let identity = file_identity(&root, &owned_path).unwrap();
        let displaced = parent_path.join("displaced");

        let error = remove_open_tree(&parent, &name, &root, identity, &owned_path, &mut || {
            fs::rename(&owned_path, &displaced).unwrap();
            fs::rename(&foreign_path, &owned_path).unwrap();
        })
        .unwrap_err();

        assert!(matches!(error, CoreError::RecoveryRequired(_)));
        assert_eq!(
            fs::read(owned_path.join("SKILL.md")).unwrap(),
            b"same content\n"
        );
        assert!(displaced.is_dir());
    }
}
