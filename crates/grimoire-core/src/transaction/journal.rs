use serde::{Deserialize, Serialize};

use crate::{CoreError, Result};

pub(crate) const JOURNAL_SCHEMA: &str = "grimoire/transaction@1";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct Journal {
    pub schema: String,
    pub scope_key: String,
    pub nonce: String,
    pub plan_digest: String,
    pub committed: bool,
    pub state: Vec<StateTransition>,
    pub links: Vec<LinkTransition>,
    pub completed: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct StateTransition {
    pub name: StateName,
    pub alias: Option<String>,
    pub source_key: Option<String>,
    pub before: Option<Vec<u8>>,
    pub after: Option<Vec<u8>>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub(crate) enum StateName {
    Manifest,
    Lock,
    Trust,
    Candidate,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct LinkTransition {
    pub skill: String,
    pub before: Option<Vec<u8>>,
    pub after: Option<Vec<u8>>,
}

impl Journal {
    pub fn to_bytes(&self) -> Result<Vec<u8>> {
        let mut bytes = serde_json::to_vec_pretty(self)?;
        bytes.push(b'\n');
        Ok(bytes)
    }

    pub fn from_bytes(bytes: &[u8]) -> Result<Self> {
        let journal: Self = serde_json::from_slice(bytes)
            .map_err(|error| CoreError::Transaction(format!("invalid journal JSON: {error}")))?;
        if journal.schema != JOURNAL_SCHEMA {
            return Err(CoreError::Transaction(
                "unsupported transaction journal schema".into(),
            ));
        }
        if journal.scope_key.is_empty() || journal.nonce.is_empty() {
            return Err(CoreError::Transaction(
                "journal identity fields cannot be empty".into(),
            ));
        }
        let mut state_names = std::collections::BTreeSet::new();
        if journal
            .state
            .iter()
            .any(|state| !state_names.insert((state.name, state.alias.as_deref())))
        {
            return Err(CoreError::Transaction(
                "journal contains duplicate state transitions".into(),
            ));
        }
        let mut skills = std::collections::BTreeSet::new();
        if journal
            .links
            .iter()
            .any(|link| !skills.insert(link.skill.as_str()))
        {
            return Err(CoreError::Transaction(
                "journal contains duplicate link transitions".into(),
            ));
        }
        Ok(journal)
    }
}
