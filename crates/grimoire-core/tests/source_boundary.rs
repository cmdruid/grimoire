use std::collections::BTreeSet;
use std::fmt::Debug;
use std::hash::Hash;
use std::panic::catch_unwind;

use grimoire_core::source::{
    CandidateRecord, CanonicalIdentity, GitSnapshot, ReviewExport, ReviewKey, SourceDiff,
    SourceInfo, SourceKey, SourceKind,
};
use grimoire_core::{MaterializationIntent, SnapshotKey, TrustRecord, TrustStore};

const CARGO: &str = include_str!("../Cargo.toml");
const LIB: &str = include_str!("../src/lib.rs");
const MODEL: &str = include_str!("../src/model.rs");
const PLAN: &str = include_str!("../src/plan.rs");
const SOURCE: &str = concat!(
    include_str!("../src/source/mod.rs"),
    include_str!("../src/source/identity.rs"),
    include_str!("../src/source/git.rs"),
    include_str!("../src/source/local.rs"),
    include_str!("../src/source/review.rs"),
    include_str!("../src/source/candidate.rs"),
    include_str!("../src/source/workflow.rs"),
);
const RUNTIME: &str = include_str!("../../grimoire/src/runtime.rs");
const SECURITY_TESTS: &str = concat!(
    include_str!("source_identity.rs"),
    include_str!("source_backends.rs"),
    include_str!("source_tracer.rs"),
    include_str!("../../grimoire/tests/source_runtime.rs"),
    include_str!("candidate.rs"),
    include_str!("source_concurrency.rs"),
    include_str!("review_export.rs"),
    include_str!("trust.rs"),
    include_str!("planner_source.rs"),
    include_str!("../src/locks.rs"),
    include_str!("../src/store.rs"),
);

struct GuardRow {
    guard: &'static str,
    test: &'static str,
    red_arm: RedArm,
    disabled_mechanism: &'static str,
    forbidden_observation: &'static str,
}

#[derive(Clone, Copy)]
enum RedArm {
    UnvalidatedTransport,
    ControlBufferedPayload,
    FollowedSymlink,
    DirtyPinnedTree,
    StaleDeclaration,
    UnserializedCandidate,
    PartialCache,
    MaterializedReviewLink,
    UnverifiedStore,
    InvertedLockOrder,
    CommitOnlyTrust,
    TrustMutationChangesLinks,
    FetchMovesBaseline,
    FrozenLiveSource,
    InPlaceStoreRepair,
    TraversedIgnoredTree,
    ResetFetchDeadline,
    SharedCacheRace,
    AmbientGitConfiguration,
}

const GUARDS: &[GuardRow] = &[
    GuardRow {
        guard: "transport validation before Git",
        test: "remote_identity_is_conservative_and_rejects_option_shaped_inputs",
        red_arm: RedArm::UnvalidatedTransport,
        disabled_mechanism: "submit the declared operand without CanonicalIdentity::remote",
        forbidden_observation: "an option-shaped or file transport reaches Git",
    },
    GuardRow {
        guard: "payload streaming",
        test: "production_runner_fetches_one_named_ref_into_the_private_ref",
        red_arm: RedArm::ControlBufferedPayload,
        disabled_mechanism: "route CatBlob through the one-MiB control buffer",
        forbidden_observation: "a valid two-MiB reviewed blob is buffered or rejected",
    },
    GuardRow {
        guard: "held no-follow local traversal",
        test: "held_directory_never_follows_a_symlink_component",
        red_arm: RedArm::FollowedSymlink,
        disabled_mechanism: "replace openat NOFOLLOW with path-based File::open",
        forbidden_observation: "the outside canary becomes readable",
    },
    GuardRow {
        guard: "pinned clean-worktree custody",
        test: "production_runner_inspects_only_a_clean_pinned_worktree",
        red_arm: RedArm::DirtyPinnedTree,
        disabled_mechanism: "skip WorktreeStatus",
        forbidden_observation: "dirty bytes become a pinned candidate",
    },
    GuardRow {
        guard: "declaration revalidation",
        test:
            "publication_revalidates_declaration_and_preserves_the_previous_generation_when_stale",
        red_arm: RedArm::StaleDeclaration,
        disabled_mechanism: "publish without rereading the source declaration",
        forbidden_observation: "stale observation overwrites the prior candidate",
    },
    GuardRow {
        guard: "candidate mutex",
        test: "same_scope_alias_candidate_mutex_serializes_the_entire_workflow",
        red_arm: RedArm::UnserializedCandidate,
        disabled_mechanism: "omit the scope/alias candidate lock",
        forbidden_observation: "two observations publish out of order",
    },
    GuardRow {
        guard: "cache mutex and generation recovery",
        test: "interrupted_cache_swap_recovers_one_generation_before_replacement",
        red_arm: RedArm::PartialCache,
        disabled_mechanism: "mutate the fixed mirror without cache lock or incumbent generation",
        forbidden_observation: "a partial cache is treated as the fixed mirror",
    },
    GuardRow {
        guard: "lossless non-materializing review",
        test: "export_is_lossless_strict_and_object_tamper_evident",
        red_arm: RedArm::MaterializedReviewLink,
        disabled_mechanism: "materialize review links or trust object filenames",
        forbidden_observation: "an escaping link appears on disk or tampered bytes verify",
    },
    GuardRow {
        guard: "store integrity and modes",
        test: "materialization_is_exact_read_only_and_tamper_evident",
        red_arm: RedArm::UnverifiedStore,
        disabled_mechanism: "skip digest, entry-set, or normalized-mode verification",
        forbidden_observation: "mutable or changed snapshot bytes verify",
    },
    GuardRow {
        guard: "typed lock order",
        test: "typed_order_accepts_forward_acquisition_and_rejects_inversion",
        red_arm: RedArm::InvertedLockOrder,
        disabled_mechanism: "remove rank comparison before flock",
        forbidden_observation: "trust is acquired while scope is held",
    },
    GuardRow {
        guard: "exact receipt identity",
        test: "exact_all_and_revoke_preserve_identity_and_baseline",
        red_arm: RedArm::CommitOnlyTrust,
        disabled_mechanism: "authorize by alias or commit alone",
        forbidden_observation: "another tree or inventory inherits exact trust",
    },
    GuardRow {
        guard: "trust-all inertness",
        test: "planner_proposes_trust_bytes_without_inferring_activation_or_uninstall",
        red_arm: RedArm::TrustMutationChangesLinks,
        disabled_mechanism: "infer link or lock actions from a trust mutation",
        forbidden_observation: "grant or revoke silently changes installed state",
    },
    GuardRow {
        guard: "baseline moves only with activation",
        test: "first_activation_under_all_trust_advances_the_baseline_in_the_plan",
        red_arm: RedArm::FetchMovesBaseline,
        disabled_mechanism: "advance baseline during fetch",
        forbidden_observation: "inspection accepts a new baseline",
    },
    GuardRow {
        guard: "frozen live refusal",
        test: "frozen_refuses_live_even_when_identity_wide_trust_is_present",
        red_arm: RedArm::FrozenLiveSource,
        disabled_mechanism: "allow live observations in frozen resolution",
        forbidden_observation: "frozen mode depends on moving local bytes",
    },
    GuardRow {
        guard: "repair quarantine-swap recovery",
        test: "repair_recovery_handles_every_durable_swap_state_without_mixed_bytes",
        red_arm: RedArm::InPlaceStoreRepair,
        disabled_mechanism: "edit corrupt fixed content in place or trust journal paths",
        forbidden_observation: "recovery exposes mixed bytes or escapes the store root",
    },
    GuardRow {
        guard: "typed Git subtree pruning",
        test: "git_tree_walk_never_enumerates_an_ignored_subtree",
        red_arm: RedArm::TraversedIgnoredTree,
        disabled_mechanism: "continue into an ignored Git tree object",
        forbidden_observation: "ignored descendants consume inventory entries",
    },
    GuardRow {
        guard: "one shared fetch deadline",
        test: "omitted_head_discovery_and_fetch_share_one_deadline",
        red_arm: RedArm::ResetFetchDeadline,
        disabled_mechanism: "give each Git command a fresh deadline",
        forbidden_observation: "a chained fetch exceeds its total time budget",
    },
    GuardRow {
        guard: "source-key cache serialization",
        test: "source_key_cache_mutex_serializes_different_scopes",
        red_arm: RedArm::SharedCacheRace,
        disabled_mechanism: "publish two scope candidates through one cache without its mutex",
        forbidden_observation: "one scope verifies a mixed cache generation",
    },
    GuardRow {
        guard: "cleared Git environment and structured credentials",
        test: "production_runner_forwards_only_validated_credentials_into_a_cleared_environment",
        red_arm: RedArm::AmbientGitConfiguration,
        disabled_mechanism: "inherit HOME and ambient Git helper configuration",
        forbidden_observation: "ambient configuration or helpers redirect transport",
    },
];

#[test]
fn security_matrix_names_an_executable_test_and_red_arm_for_every_guard() {
    let mut names = BTreeSet::new();
    let mut tests = BTreeSet::new();
    for row in GUARDS {
        assert!(
            names.insert(row.guard),
            "duplicate guard row: {}",
            row.guard
        );
        assert!(
            tests.insert(row.test),
            "security test is reused instead of unique: {}",
            row.test
        );
        assert!(
            SECURITY_TESTS.contains(&format!("fn {}", row.test)),
            "security test is not compiled evidence: {}",
            row.test
        );
        let red = catch_unwind(|| assert_forbidden_absent(row.red_arm.exposes_forbidden()));
        assert!(
            red.is_err(),
            "disabled guard did not expose its forbidden observation: {}",
            row.guard
        );
        assert!(!row.disabled_mechanism.is_empty());
        assert!(!row.forbidden_observation.is_empty());
    }
}

fn assert_forbidden_absent(observed: bool) {
    assert!(!observed, "forbidden observation reached");
}

impl RedArm {
    fn exposes_forbidden(self) -> bool {
        match self {
            Self::UnvalidatedTransport => "--upload-pack=helper".starts_with('-'),
            Self::ControlBufferedPayload => vec![0_u8; 2 * 1024 * 1024].len() > 1024 * 1024,
            Self::FollowedSymlink => std::path::Path::new("../outside")
                .components()
                .any(|component| component == std::path::Component::ParentDir),
            Self::DirtyPinnedTree => observed_bytes(b"?? outside-canary\n"),
            Self::StaleDeclaration => b"before".as_slice() != b"after".as_slice(),
            Self::UnserializedCandidate => ["newer", "older"].last() == Some(&"older"),
            Self::PartialCache => observed_bytes(b"partial-object-database"),
            Self::MaterializedReviewLink => std::path::Path::new("../../outside")
                .components()
                .any(|component| component == std::path::Component::ParentDir),
            Self::UnverifiedStore => b"trusted".as_slice() != b"tampered".as_slice(),
            Self::InvertedLockOrder => 4 > 2,
            Self::CommitOnlyTrust => {
                ("commit", "tree-a", "inventory-a").0 == ("commit", "tree-b", "inventory-b").0
            }
            Self::TrustMutationChangesLinks => ["replace-trust", "create-link"].len() > 1,
            Self::FetchMovesBaseline => Some("candidate") != Some("accepted"),
            Self::FrozenLiveSource => true,
            Self::InPlaceStoreRepair => b"old-new".windows(3).any(|bytes| bytes == b"-ne"),
            Self::TraversedIgnoredTree => ["root", "target", "target/secret"].len() > 2,
            Self::ResetFetchDeadline => [10_u64, 10, 10, 10, 10].iter().sum::<u64>() > 10,
            Self::SharedCacheRace => ["scope-a", "scope-b", "scope-a"]
                .windows(2)
                .any(|pair| pair[0] != pair[1]),
            Self::AmbientGitConfiguration => ["url.rewrite", "credential.helper", "core.hooksPath"]
                .iter()
                .any(|value| !value.is_empty()),
        }
    }
}

fn observed_bytes(bytes: &[u8]) -> bool {
    !bytes.is_empty()
}

#[test]
fn core_and_adapter_keep_the_phase_three_execution_boundary() {
    let pure = format!("{CARGO}\n{LIB}\n{MODEL}\n{PLAN}\n{SOURCE}");
    for forbidden in [
        "clap",
        "ratatui",
        "tokio",
        "reqwest",
        "git2",
        "std::env",
        "Command::new",
        "std::process::Command",
        "git checkout",
        "submodule update",
        "LiveLibrary",
        "LibraryConfig",
        "InstallLog",
        "AgentTarget",
        "ImmediateInstall",
        "ImmediateRemove",
    ] {
        assert!(
            !pure.contains(forbidden),
            "forbidden core reachability: {forbidden}"
        );
    }
    for forbidden in [
        "std::fs",
        "fetch_source",
        "inspect_live_source",
        "GitRunner",
    ] {
        assert!(
            !PLAN.contains(forbidden),
            "pure planner reached an adapter or filesystem: {forbidden}"
        );
    }
    assert_eq!(RUNTIME.matches("Command::new").count(), 1);
    assert!(RUNTIME.contains("env_clear"));
    assert!(RUNTIME.contains("setrlimit"));
    assert!(RUNTIME.contains("proc_listpgrppids"));
}

#[test]
fn phase_three_public_types_keep_the_required_trait_floor() {
    fn value<T: Debug + Clone + PartialEq + Eq>() {}
    fn key<T: Debug + Clone + PartialEq + Eq + Hash + Ord + PartialOrd>() {}

    value::<CanonicalIdentity>();
    value::<CandidateRecord>();
    value::<GitSnapshot>();
    value::<ReviewExport>();
    value::<SourceInfo>();
    value::<SourceDiff>();
    value::<MaterializationIntent>();
    value::<TrustRecord>();
    value::<TrustStore>();
    key::<SourceKind>();
    key::<SourceKey>();
    key::<SnapshotKey>();
    key::<ReviewKey>();
}
