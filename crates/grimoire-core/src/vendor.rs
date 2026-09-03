use std::fs;
use std::path::Path;

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
    let path = paths.vendor_path(&incumbent.source, name)?;
    let metadata = match fs::symlink_metadata(&path) {
        Ok(metadata) => metadata,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            return Ok(VendorPrecondition {
                state: VendorState::Absent,
                content: None,
            });
        }
        Err(error) => return Err(io_error(&path, error)),
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
    match verify_vendor_tree(&path, name) {
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

fn io_error(path: &Path, error: std::io::Error) -> CoreError {
    CoreError::Io {
        path: path.display().to_string(),
        message: error.to_string(),
    }
}
