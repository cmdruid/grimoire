use std::collections::{BTreeMap, BTreeSet};
use std::fmt;
use std::marker::PhantomData;

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine as _;
use serde::de::{MapAccess, Visitor};
use serde::{de, Deserialize, Deserializer, Serialize, Serializer};

use crate::source::{CanonicalIdentity, SourceKey, SourceKind};
use crate::{CoreError, Result};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum TrustMode {
    Untrusted,
    Snapshot,
    All,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize)]
pub struct TrustReceipt {
    pub commit: String,
    pub tree: String,
    pub inventory: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct TrustBaseline {
    pub commit: Option<String>,
    pub tree: Option<String>,
    pub inventory: String,
    pub review_tree: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrustRecord {
    pub identity: CanonicalIdentity,
    pub receipts: BTreeSet<TrustReceipt>,
    pub all_snapshots: bool,
    pub baseline: Option<TrustBaseline>,
}

impl TrustRecord {
    pub fn mode_for(&self, receipt: Option<&TrustReceipt>) -> TrustMode {
        if self.all_snapshots {
            TrustMode::All
        } else if receipt.is_some_and(|receipt| self.receipts.contains(receipt)) {
            TrustMode::Snapshot
        } else {
            TrustMode::Untrusted
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct TrustStore {
    pub records: BTreeMap<SourceKey, TrustRecord>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrustMutation {
    pub before: Option<Vec<u8>>,
    pub after: Vec<u8>,
    pub create_mode: u32,
}

impl TrustStore {
    pub fn parse(bytes: &[u8]) -> Result<Self> {
        let dto: TrustDto = serde_json::from_slice(bytes)?;
        if dto.schema != "grimoire/trust@1" {
            return Err(CoreError::Trust("unsupported trust schema".into()));
        }
        let mut records = BTreeMap::new();
        for (outer_key, dto) in dto.records.0 {
            let source_key = SourceKey::parse(outer_key)?;
            let record = dto.try_into_record()?;
            if SourceKey::derive(&record.identity) != source_key {
                return Err(CoreError::Trust("trust source-key mismatch".into()));
            }
            records.insert(source_key, record);
        }
        Ok(Self { records })
    }

    pub fn to_bytes(&self) -> Result<Vec<u8>> {
        let records = self
            .records
            .iter()
            .map(|(key, record)| (key.to_string(), TrustRecordDto::from(record)))
            .collect();
        let mut bytes = serde_json::to_vec_pretty(&TrustDto {
            schema: "grimoire/trust@1".into(),
            records: UniqueMap(records),
        })?;
        bytes.push(b'\n');
        Ok(bytes)
    }

    pub fn grant_exact(
        &self,
        identity: CanonicalIdentity,
        receipt: TrustReceipt,
        baseline: TrustBaseline,
        before: Option<Vec<u8>>,
    ) -> Result<TrustMutation> {
        if identity.kind() == SourceKind::Live {
            return Err(CoreError::Trust(
                "live sources require all-snapshots trust".into(),
            ));
        }
        validate_receipt(&receipt)?;
        validate_baseline(identity.kind(), &baseline)?;
        if baseline.commit.as_ref() != Some(&receipt.commit)
            || baseline.tree.as_ref() != Some(&receipt.tree)
            || baseline.inventory != receipt.inventory
        {
            return Err(CoreError::Trust(
                "exact trust receipt and baseline describe different snapshots".into(),
            ));
        }
        let mut next = self.clone();
        let key = SourceKey::derive(&identity);
        let record = next.records.entry(key).or_insert(TrustRecord {
            identity: identity.clone(),
            receipts: BTreeSet::new(),
            all_snapshots: false,
            baseline: None,
        });
        ensure_identity(record, &identity)?;
        record.receipts.insert(receipt);
        record.baseline = Some(baseline);
        mutation(before, next.to_bytes()?)
    }

    pub fn grant_all(
        &self,
        identity: CanonicalIdentity,
        exact: Option<TrustReceipt>,
        baseline: TrustBaseline,
        before: Option<Vec<u8>>,
    ) -> Result<TrustMutation> {
        validate_baseline(identity.kind(), &baseline)?;
        match (identity.kind(), exact.as_ref()) {
            (SourceKind::Git, Some(receipt)) => {
                validate_receipt(receipt)?;
                if baseline.commit.as_ref() != Some(&receipt.commit)
                    || baseline.tree.as_ref() != Some(&receipt.tree)
                    || baseline.inventory != receipt.inventory
                {
                    return Err(CoreError::Trust(
                        "all-trust receipt and baseline describe different snapshots".into(),
                    ));
                }
            }
            (SourceKind::Git, None) => {
                return Err(CoreError::Trust(
                    "pinned all-trust requires the reviewed exact receipt".into(),
                ))
            }
            (SourceKind::Live, Some(_)) => {
                return Err(CoreError::Trust(
                    "live all-trust cannot contain an exact receipt".into(),
                ))
            }
            (SourceKind::Live, None) => {}
        }
        let mut next = self.clone();
        let key = SourceKey::derive(&identity);
        let record = next.records.entry(key).or_insert(TrustRecord {
            identity: identity.clone(),
            receipts: BTreeSet::new(),
            all_snapshots: false,
            baseline: None,
        });
        ensure_identity(record, &identity)?;
        record.all_snapshots = true;
        if let Some(receipt) = exact {
            record.receipts.insert(receipt);
        }
        record.baseline = Some(baseline);
        mutation(before, next.to_bytes()?)
    }

    pub fn revoke(&self, key: &SourceKey, before: Option<Vec<u8>>) -> Result<TrustMutation> {
        let mut next = self.clone();
        let record = next
            .records
            .get_mut(key)
            .ok_or_else(|| CoreError::Trust("unknown source key".into()))?;
        record.receipts.clear();
        record.all_snapshots = false;
        mutation(before, next.to_bytes()?)
    }

    pub fn advance_baseline(
        &self,
        key: &SourceKey,
        baseline: TrustBaseline,
        before: Option<Vec<u8>>,
    ) -> Result<TrustMutation> {
        let mut next = self.clone();
        let record = next
            .records
            .get_mut(key)
            .ok_or_else(|| CoreError::Trust("unknown source key".into()))?;
        if !record.all_snapshots {
            return Err(CoreError::Trust(
                "only all-snapshots trust advances on activation".into(),
            ));
        }
        validate_baseline(record.identity.kind(), &baseline)?;
        record.baseline = Some(baseline);
        mutation(before, next.to_bytes()?)
    }
}

fn ensure_identity(record: &TrustRecord, identity: &CanonicalIdentity) -> Result<()> {
    if &record.identity == identity {
        Ok(())
    } else {
        Err(CoreError::Trust("canonical identity mismatch".into()))
    }
}

fn validate_receipt(receipt: &TrustReceipt) -> Result<()> {
    crate::source::identity::validate_object_id(&receipt.commit)?;
    crate::source::identity::validate_object_id(&receipt.tree)?;
    crate::source::identity::validate_digest(&receipt.inventory)
        .map_err(|error| CoreError::Trust(error.to_string()))
}

fn validate_baseline(kind: SourceKind, baseline: &TrustBaseline) -> Result<()> {
    match kind {
        SourceKind::Git => {
            crate::source::identity::validate_object_id(
                baseline
                    .commit
                    .as_deref()
                    .ok_or_else(|| CoreError::Trust("Git baseline requires commit".into()))?,
            )?;
            crate::source::identity::validate_object_id(
                baseline
                    .tree
                    .as_deref()
                    .ok_or_else(|| CoreError::Trust("Git baseline requires tree".into()))?,
            )?;
        }
        SourceKind::Live if baseline.commit.is_some() || baseline.tree.is_some() => {
            return Err(CoreError::Trust(
                "live baseline cannot contain Git object IDs".into(),
            ));
        }
        SourceKind::Live => {}
    }
    crate::source::identity::validate_digest(&baseline.inventory)
        .map_err(|error| CoreError::Trust(error.to_string()))?;
    crate::source::identity::validate_digest(&baseline.review_tree)
        .map_err(|error| CoreError::Trust(error.to_string()))
}

fn mutation(before: Option<Vec<u8>>, after: Vec<u8>) -> Result<TrustMutation> {
    Ok(TrustMutation {
        before,
        after,
        create_mode: 0o600,
    })
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct TrustDto {
    schema: String,
    records: UniqueMap<TrustRecordDto>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct TrustRecordDto {
    kind: String,
    canonical: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    canonical_bytes_base64: Option<String>,
    receipts: Vec<TrustReceiptDto>,
    all_snapshots: bool,
    baseline: Option<TrustBaselineDto>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct TrustReceiptDto {
    commit: String,
    tree: String,
    inventory: String,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct TrustBaselineDto {
    commit: Option<String>,
    tree: Option<String>,
    inventory: String,
    review_tree: String,
}

impl TrustRecordDto {
    fn try_into_record(self) -> Result<TrustRecord> {
        let kind = match self.kind.as_str() {
            "git" => SourceKind::Git,
            "live" => SourceKind::Live,
            _ => return Err(CoreError::Trust("invalid trust source kind".into())),
        };
        let canonical = match (self.canonical, self.canonical_bytes_base64) {
            (Some(text), None) => text.into_bytes(),
            (None, Some(raw)) => BASE64
                .decode(raw)
                .map_err(|_| CoreError::Trust("invalid canonical base64".into()))?,
            _ => {
                return Err(CoreError::Trust(
                    "trust identity requires one canonical projection".into(),
                ))
            }
        };
        let identity = CanonicalIdentity::from_parts(kind, canonical)?;
        let receipts: Vec<_> = self.receipts.into_iter().map(TrustReceipt::from).collect();
        if !receipts.windows(2).all(|pair| pair[0] < pair[1]) {
            return Err(CoreError::Trust(
                "trust receipts must be strictly sorted".into(),
            ));
        }
        if kind == SourceKind::Live && !receipts.is_empty() {
            return Err(CoreError::Trust(
                "live trust cannot contain exact receipts".into(),
            ));
        }
        for receipt in &receipts {
            validate_receipt(receipt)?;
        }
        let baseline = self.baseline.map(TrustBaseline::from);
        if let Some(baseline) = &baseline {
            validate_baseline(kind, baseline)?;
        }
        Ok(TrustRecord {
            identity,
            receipts: receipts.into_iter().collect(),
            all_snapshots: self.all_snapshots,
            baseline,
        })
    }
}

impl From<&TrustRecord> for TrustRecordDto {
    fn from(record: &TrustRecord) -> Self {
        let (canonical, canonical_bytes_base64) = match record.identity.canonical_utf8() {
            Some(text) => (Some(text.into()), None),
            None => (None, Some(BASE64.encode(record.identity.canonical_bytes()))),
        };
        Self {
            kind: record.identity.kind().as_str().into(),
            canonical,
            canonical_bytes_base64,
            receipts: record.receipts.iter().map(TrustReceiptDto::from).collect(),
            all_snapshots: record.all_snapshots,
            baseline: record.baseline.as_ref().map(TrustBaselineDto::from),
        }
    }
}

impl From<TrustReceiptDto> for TrustReceipt {
    fn from(receipt: TrustReceiptDto) -> Self {
        Self {
            commit: receipt.commit,
            tree: receipt.tree,
            inventory: receipt.inventory,
        }
    }
}

impl From<&TrustReceipt> for TrustReceiptDto {
    fn from(receipt: &TrustReceipt) -> Self {
        Self {
            commit: receipt.commit.clone(),
            tree: receipt.tree.clone(),
            inventory: receipt.inventory.clone(),
        }
    }
}

impl From<TrustBaselineDto> for TrustBaseline {
    fn from(baseline: TrustBaselineDto) -> Self {
        Self {
            commit: baseline.commit,
            tree: baseline.tree,
            inventory: baseline.inventory,
            review_tree: baseline.review_tree,
        }
    }
}

impl From<&TrustBaseline> for TrustBaselineDto {
    fn from(baseline: &TrustBaseline) -> Self {
        Self {
            commit: baseline.commit.clone(),
            tree: baseline.tree.clone(),
            inventory: baseline.inventory.clone(),
            review_tree: baseline.review_tree.clone(),
        }
    }
}

#[derive(Debug)]
struct UniqueMap<V>(BTreeMap<String, V>);

impl<V: Serialize> Serialize for UniqueMap<V> {
    fn serialize<S: Serializer>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error> {
        self.0.serialize(serializer)
    }
}

impl<'de, V: Deserialize<'de>> Deserialize<'de> for UniqueMap<V> {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> std::result::Result<Self, D::Error> {
        struct UniqueMapVisitor<V>(PhantomData<V>);

        impl<'de, V: Deserialize<'de>> Visitor<'de> for UniqueMapVisitor<V> {
            type Value = UniqueMap<V>;

            fn expecting(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
                formatter.write_str("an object with unique keys")
            }

            fn visit_map<A: MapAccess<'de>>(
                self,
                mut map: A,
            ) -> std::result::Result<Self::Value, A::Error> {
                let mut values = BTreeMap::new();
                while let Some((key, value)) = map.next_entry::<String, V>()? {
                    if values.insert(key.clone(), value).is_some() {
                        return Err(de::Error::custom(format!("duplicate object key `{key}`")));
                    }
                }
                Ok(UniqueMap(values))
            }
        }

        deserializer.deserialize_map(UniqueMapVisitor(PhantomData))
    }
}
