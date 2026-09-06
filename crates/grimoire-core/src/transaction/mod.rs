pub(crate) mod journal;

use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::path::Path;

use crate::{CoreError, FaultDisposition, Result, TransactionRuntime};

pub(crate) const STATE_LIMIT: u64 = 16 * 1024 * 1024;

pub(crate) fn checkpoint(runtime: &dyn TransactionRuntime, name: &'static str) -> Result<bool> {
    Ok(matches!(runtime.checkpoint(name)?, FaultDisposition::Crash))
}

pub(crate) fn write_new(path: &Path, bytes: &[u8], mode: Option<u32>) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|error| io_error(parent, error))?;
    }
    let mut options = OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    if let Some(mode) = mode {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(mode);
    }
    let mut file = options.open(path).map_err(|error| io_error(path, error))?;
    file.write_all(bytes)
        .map_err(|error| io_error(path, error))?;
    file.sync_all().map_err(|error| io_error(path, error))?;
    Ok(())
}

pub(crate) fn replace(path: &Path, bytes: &[u8], nonce: &str, mode: Option<u32>) -> Result<()> {
    let parent = path
        .parent()
        .ok_or_else(|| CoreError::Transaction("state path has no parent".into()))?;
    fs::create_dir_all(parent).map_err(|error| io_error(parent, error))?;
    let name = path
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or_else(|| CoreError::Transaction("state filename is not UTF-8".into()))?;
    let temporary = parent.join(format!(".{name}.{nonce}.tmp"));
    remove_file_if_present(&temporary)?;
    write_new(&temporary, bytes, mode)?;
    fs::rename(&temporary, path).map_err(|error| io_error(path, error))?;
    sync_directory(parent)
}

pub(crate) fn remove_file_if_present(path: &Path) -> Result<()> {
    match fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(io_error(path, error)),
    }
}

pub(crate) fn read_optional_bounded(path: &Path, limit: u64) -> Result<Option<Vec<u8>>> {
    let descriptor = match rustix::fs::open(
        path,
        rustix::fs::OFlags::RDONLY | rustix::fs::OFlags::CLOEXEC | rustix::fs::OFlags::NOFOLLOW,
        rustix::fs::Mode::empty(),
    ) {
        Ok(descriptor) => descriptor,
        Err(rustix::io::Errno::NOENT) => return Ok(None),
        Err(error) => {
            return Err(CoreError::Io {
                path: path.display().to_string(),
                message: error.to_string(),
            })
        }
    };
    let file = File::from(descriptor);
    let metadata = file.metadata().map_err(|error| io_error(path, error))?;
    if !metadata.is_file() || metadata.len() > limit {
        return Err(CoreError::Io {
            path: path.display().to_string(),
            message: "state is not a bounded regular file".into(),
        });
    }
    let mut bytes = Vec::with_capacity(metadata.len() as usize);
    file.take(limit + 1)
        .read_to_end(&mut bytes)
        .map_err(|error| io_error(path, error))?;
    if bytes.len() as u64 > limit {
        return Err(CoreError::Io {
            path: path.display().to_string(),
            message: "state file grew beyond its limit while reading".into(),
        });
    }
    Ok(Some(bytes))
}

pub(crate) fn read_required_bounded(path: &Path, limit: u64) -> Result<Vec<u8>> {
    read_optional_bounded(path, limit)?.ok_or_else(|| CoreError::Io {
        path: path.display().to_string(),
        message: "not found".into(),
    })
}

pub(crate) fn sync_directory(path: &Path) -> Result<()> {
    File::open(path)
        .and_then(|file| file.sync_all())
        .map_err(|error| io_error(path, error))
}

pub(crate) fn io_error(path: &Path, error: std::io::Error) -> CoreError {
    CoreError::Io {
        path: path.display().to_string(),
        message: error.to_string(),
    }
}
