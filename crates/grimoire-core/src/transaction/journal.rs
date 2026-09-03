use serde::{Deserialize, Serialize};

use crate::{CoreError, Result};

pub(crate) const JOURNAL_SCHEMA: &str = "grimoire/transaction@2";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct Journal {
    pub schema: String,
    pub scope_key: String,
    pub nonce: String,
    pub plan_digest: String,
    pub committed: bool,
    pub state: Vec<StateTransition>,
    pub vendors: Vec<VendorTransition>,
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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct VendorTransition {
    pub source: String,
    pub skill: String,
    pub before: Option<String>,
    pub after: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
struct JournalV1 {
    schema: String,
    scope_key: String,
    nonce: String,
    plan_digest: String,
    committed: bool,
    state: Vec<StateTransition>,
    links: Vec<LinkTransition>,
    completed: Vec<String>,
}

impl Journal {
    pub fn to_bytes(&self) -> Result<Vec<u8>> {
        let mut bytes = serde_json::to_vec_pretty(self)?;
        bytes.push(b'\n');
        Ok(bytes)
    }

    pub fn from_bytes(bytes: &[u8]) -> Result<Self> {
        let value: serde_json::Value = serde_json::from_slice(bytes)
            .map_err(|error| CoreError::Transaction(format!("invalid journal JSON: {error}")))?;
        let schema = value
            .get("schema")
            .and_then(serde_json::Value::as_str)
            .ok_or_else(|| CoreError::Transaction("journal schema is missing".into()))?;
        let journal = match schema {
            JOURNAL_SCHEMA => serde_json::from_value(value).map_err(|error| {
                CoreError::Transaction(format!("invalid journal JSON: {error}"))
            })?,
            "grimoire/transaction@1" => {
                let old: JournalV1 = serde_json::from_value(value).map_err(|error| {
                    CoreError::Transaction(format!("invalid journal JSON: {error}"))
                })?;
                if old.schema != "grimoire/transaction@1" {
                    return Err(CoreError::Transaction(
                        "unsupported transaction journal schema".into(),
                    ));
                }
                Self {
                    schema: JOURNAL_SCHEMA.into(),
                    scope_key: old.scope_key,
                    nonce: old.nonce,
                    plan_digest: old.plan_digest,
                    committed: old.committed,
                    state: old.state,
                    vendors: Vec::new(),
                    links: old.links,
                    completed: old.completed,
                }
            }
            _ => {
                return Err(CoreError::Transaction(
                    "unsupported transaction journal schema".into(),
                ))
            }
        };
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
        let mut vendors = std::collections::BTreeSet::new();
        if journal
            .vendors
            .iter()
            .any(|vendor| !vendors.insert((vendor.source.as_str(), vendor.skill.as_str())))
        {
            return Err(CoreError::Transaction(
                "journal contains duplicate vendor transitions".into(),
            ));
        }
        Ok(journal)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn transaction_journal_bytes_are_exact_and_deterministic() {
        let journal = Journal {
            schema: JOURNAL_SCHEMA.into(),
            scope_key: "global".into(),
            nonce: "journal-golden".into(),
            plan_digest: "1".repeat(64),
            committed: false,
            state: vec![StateTransition {
                name: StateName::Manifest,
                alias: None,
                source_key: None,
                before: None,
                after: Some(b"new".to_vec()),
            }],
            vendors: vec![],
            links: vec![LinkTransition {
                skill: "one".into(),
                before: Some(b"old".to_vec()),
                after: None,
            }],
            completed: vec!["manifest".into()],
        };
        assert_eq!(
            journal.to_bytes().unwrap(),
            br#"{
  "schema": "grimoire/transaction@2",
  "scope_key": "global",
  "nonce": "journal-golden",
  "plan_digest": "1111111111111111111111111111111111111111111111111111111111111111",
  "committed": false,
  "state": [
    {
      "name": "manifest",
      "alias": null,
      "source_key": null,
      "before": null,
      "after": [
        110,
        101,
        119
      ]
    }
  ],
  "vendors": [],
  "links": [
    {
      "skill": "one",
      "before": [
        111,
        108,
        100
      ],
      "after": null
    }
  ],
  "completed": [
    "manifest"
  ]
}
"#
        );
        assert_eq!(
            Journal::from_bytes(&journal.to_bytes().unwrap()).unwrap(),
            journal
        );
    }
}
