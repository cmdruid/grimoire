use std::fs::{self, File, OpenOptions};
use std::path::Path;

use rustix::fs::{flock, FlockOperation};

use crate::{CoreError, Result};

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub(crate) enum LockRank {
    Candidate,
    Cache,
    Store,
    Trust,
    Projects,
    Scope,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum LockMode {
    Shared,
    Exclusive,
}

pub(crate) struct LockCoordinator {
    held: Vec<HeldLock>,
}

struct HeldLock {
    file: File,
    rank: LockRank,
}

impl LockCoordinator {
    pub(crate) fn new() -> Self {
        Self { held: Vec::new() }
    }

    pub(crate) fn acquire(&mut self, path: &Path, rank: LockRank, mode: LockMode) -> Result<()> {
        if self.held.last().is_some_and(|held| rank <= held.rank) {
            return Err(CoreError::Locking(format!(
                "lock order inversion: {:?} after {:?}",
                rank,
                self.held.last().expect("checked").rank
            )));
        }
        if rank == LockRank::Candidate && !self.held.is_empty() {
            return Err(CoreError::Locking(
                "candidate mutex must be acquired first".into(),
            ));
        }
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(|error| io_error(parent, error))?;
        }
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(path)
            .map_err(|error| io_error(path, error))?;
        flock(
            &file,
            match mode {
                LockMode::Shared => FlockOperation::LockShared,
                LockMode::Exclusive => FlockOperation::LockExclusive,
            },
        )
        .map_err(|error| CoreError::Locking(error.to_string()))?;
        self.held.push(HeldLock { file, rank });
        Ok(())
    }

    pub(crate) fn release_last(&mut self, rank: LockRank) -> Result<()> {
        let held = self
            .held
            .pop()
            .ok_or_else(|| CoreError::Locking("no lock held".into()))?;
        if held.rank != rank {
            self.held.push(held);
            return Err(CoreError::Locking("lock release order mismatch".into()));
        }
        flock(&held.file, FlockOperation::Unlock)
            .map_err(|error| CoreError::Locking(error.to_string()))
    }
}

impl Drop for HeldLock {
    fn drop(&mut self) {
        let _ = flock(&self.file, FlockOperation::Unlock);
    }
}

fn io_error(path: &Path, error: std::io::Error) -> CoreError {
    CoreError::Io {
        path: path.display().to_string(),
        message: error.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use tempfile::tempdir;

    use super::*;

    #[test]
    fn typed_order_accepts_forward_acquisition_and_rejects_inversion() {
        let temporary = tempdir().unwrap();
        let mut locks = LockCoordinator::new();
        locks
            .acquire(
                &temporary.path().join("candidate.lock"),
                LockRank::Candidate,
                LockMode::Exclusive,
            )
            .unwrap();
        locks
            .acquire(
                &temporary.path().join("cache.lock"),
                LockRank::Cache,
                LockMode::Exclusive,
            )
            .unwrap();
        locks
            .acquire(
                &temporary.path().join("store.lock"),
                LockRank::Store,
                LockMode::Shared,
            )
            .unwrap();
        locks
            .acquire(
                &temporary.path().join("scope.lock"),
                LockRank::Scope,
                LockMode::Exclusive,
            )
            .unwrap();
        assert!(locks
            .acquire(
                &temporary.path().join("trust.lock"),
                LockRank::Trust,
                LockMode::Exclusive,
            )
            .is_err());
    }

    #[test]
    fn candidate_mutex_cannot_be_acquired_under_shared_state() {
        let temporary = tempdir().unwrap();
        let mut locks = LockCoordinator::new();
        locks
            .acquire(
                &temporary.path().join("store.lock"),
                LockRank::Store,
                LockMode::Shared,
            )
            .unwrap();
        assert!(locks
            .acquire(
                &temporary.path().join("candidate.lock"),
                LockRank::Candidate,
                LockMode::Exclusive,
            )
            .is_err());
    }
}
