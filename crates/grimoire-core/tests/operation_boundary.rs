use std::collections::BTreeMap;
use std::fmt::Debug;
use std::hash::Hash;

use grimoire_core::{
    apply, Action, ApplyOutcome, Approval, Blocker, ByteHash, CheckFinding, CheckReport,
    CheckSeverity, CoreError, ExitClass, FaultDisposition, Plan, Preconditions,
    RecoveryDisposition, RecoveryOutcome, Scope, SnapshotKey, SourceKey, TransactionRuntime,
};
use serde::de::DeserializeOwned;
use serde::Serialize;

const CORE_CARGO: &str = include_str!("../Cargo.toml");
const CORE_LIB: &str = include_str!("../src/lib.rs");
const CORE_MODEL: &str = include_str!("../src/model.rs");
const PLANNER: &str = include_str!("../src/plan.rs");
const CHECKER: &str = include_str!("../src/check.rs");
const EXECUTOR: &str = include_str!("../src/apply.rs");
const PROJECTS: &str = include_str!("../src/projects.rs");
const PRUNE: &str = include_str!("../src/prune.rs");
const TRANSACTION: &str = concat!(
    include_str!("../src/transaction/mod.rs"),
    include_str!("../src/transaction/journal.rs"),
);
const SOURCE_MUTATION: &str = concat!(
    include_str!("../src/source/candidate.rs"),
    include_str!("../src/source/workflow.rs"),
    include_str!("../src/store.rs"),
    include_str!("../src/store/repair.rs"),
    include_str!("../src/trust.rs"),
);
const APP_LIB: &str = include_str!("../../grimoire/src/lib.rs");
const APP_RUNTIME: &str = include_str!("../../grimoire/src/runtime.rs");
const OPERATION_TESTS: &str = concat!(
    include_str!("transaction_tracer.rs"),
    include_str!("apply_matrix.rs"),
    include_str!("transaction_recovery.rs"),
    include_str!("world.rs"),
    include_str!("check.rs"),
    include_str!("project_index.rs"),
    include_str!("transaction_concurrency.rs"),
    include_str!("prune.rs"),
    include_str!("../src/locks.rs"),
    include_str!("../src/transaction/journal.rs"),
    include_str!("operation_boundary.rs"),
);

struct GuardRow {
    guard: &'static str,
    test: &'static str,
    red_arm_evidence: &'static str,
    disabled_mechanism: &'static str,
    forbidden_observation: &'static str,
}

const GUARDS: &[GuardRow] = &[
    GuardRow {
        guard: "locked precondition revalidation",
        test: "stale_and_foreign_state_are_inert",
        red_arm_evidence: "fs::write(paths.manifest_path(), b\"foreign\\n\")",
        disabled_mechanism: "skip the manifest byte-hash comparison",
        forbidden_observation: "a stale plan creates its link",
    },
    GuardRow {
        guard: "blocked, wrong-scope, and mixed-plan preflight",
        test: "malformed_blocked_and_wrong_scope_plans_are_inert",
        red_arm_evidence: "let mixed_prune = Plan",
        disabled_mechanism: "supply a blocked, cross-scope, or mixed prune plan",
        forbidden_observation: "an invalid plan creates its manifest",
    },
    GuardRow {
        guard: "final link-parent and occupancy revalidation",
        test: "final_link_revalidation_preserves_a_racing_foreign_entry",
        red_arm_evidence: "Runtime::racing(destination.clone())",
        disabled_mechanism: "omit the final parent and destination check",
        forbidden_observation: "a racing foreign entry is replaced",
    },
    GuardRow {
        guard: "destructive approval",
        test: "prepared_source_registration_and_removal_cross_only_the_action_interpreter",
        red_arm_evidence: "Approval::Declined",
        disabled_mechanism: "execute a destructive plan without Granted",
        forbidden_observation: "source state disappears after cancellation",
    },
    GuardRow {
        guard: "plan-gated snapshot preparation",
        test: "planned_snapshot_preparation_materializes_and_repairs_before_link_activation",
        red_arm_evidence: "Some(Action::PrepareSnapshot",
        disabled_mechanism: "start with an absent store and apply the emitted preparation action",
        forbidden_observation: "a link activates before its verified snapshot exists",
    },
    GuardRow {
        guard: "fault-prefix recovery",
        test: "every_scope_fault_prefix_recovers_to_exact_before_or_complete_after",
        red_arm_evidence: "(\"journal-created\", 1, false)",
        disabled_mechanism: "crash at each durable transaction checkpoint",
        forbidden_observation: "recovery leaves a mixed before/after state",
    },
    GuardRow {
        guard: "canonical transaction journal",
        test: "transaction_journal_bytes_are_exact_and_deterministic",
        red_arm_evidence: "grimoire/transaction@1",
        disabled_mechanism: "change a journal field, order, or trailing newline",
        forbidden_observation: "a non-canonical journal encoding passes its golden",
    },
    GuardRow {
        guard: "manifest-candidate-trust commit order",
        test: "source_registration_never_recovers_trust_without_manifest_and_candidate",
        red_arm_evidence: "if paths.trust_path().exists()",
        disabled_mechanism: "crash after each ordered state mutation",
        forbidden_observation: "trust exists without manifest and candidate",
    },
    GuardRow {
        guard: "candidate-removal recovery",
        test: "candidate_removal_faults_recover_exact_before_or_complete_after",
        red_arm_evidence: "Action::RemoveCandidate",
        disabled_mechanism: "crash after each manifest/candidate removal prefix",
        forbidden_observation: "recovery loses prior candidate bytes or mixes removal state",
    },
    GuardRow {
        guard: "repoint and remove rollback",
        test: "repoint_and_remove_faults_restore_the_exact_owned_link",
        red_arm_evidence: "for operation in [\"repoint\", \"remove\"]",
        disabled_mechanism: "crash after link mutation and after its journal mark",
        forbidden_observation: "an uncommitted owned-link change survives recovery",
    },
    GuardRow {
        guard: "standalone trust atomicity",
        test: "standalone_trust_faults_are_atomic_and_need_no_scope_recovery",
        red_arm_evidence: "before-standalone-trust",
        disabled_mechanism: "crash immediately before and after the atomic trust rename",
        forbidden_observation: "standalone trust requires scope recovery or exposes partial bytes",
    },
    GuardRow {
        guard: "journal-derived containment",
        test: "tampered_journal_identity_cannot_nominate_an_outside_path",
        red_arm_evidence: "value[\"links\"][0][\"skill\"]",
        disabled_mechanism: "replace a journal skill with a parent traversal",
        forbidden_observation: "recovery changes the outside canary",
    },
    GuardRow {
        guard: "world loading never fetches",
        test: "candidate_without_its_private_cache_is_an_observation_not_a_fetch",
        red_arm_evidence: "assert_eq!(git.0.load(Ordering::SeqCst), 0)",
        disabled_mechanism: "remove the candidate cache before loading",
        forbidden_observation: "world loading invokes Git",
    },
    GuardRow {
        guard: "world state no-follow reads",
        test: "world_loader_rejects_symlinked_state_files_without_reading_through_them",
        red_arm_evidence: "symlink(&manifest, paths.manifest_path())",
        disabled_mechanism: "replace manifest and lock with outside symlinks",
        forbidden_observation: "world loading accepts state through a symlink",
    },
    GuardRow {
        guard: "check is read-only",
        test: "healthy_world_has_no_findings_and_check_is_read_only",
        red_arm_evidence: "before_manifest",
        disabled_mechanism: "snapshot every managed state file around check",
        forbidden_observation: "check changes a managed byte",
    },
    GuardRow {
        guard: "check never follows foreign entries",
        test: "findings_are_stable_sorted_and_do_not_follow_foreign_entries",
        red_arm_evidence: "fs::write(&canary, b\"untouched\\n\")",
        disabled_mechanism: "place a foreign file beside an outside canary",
        forbidden_observation: "check reads through or changes the canary",
    },
    GuardRow {
        guard: "strict project-index identity",
        test: "malformed_or_cross_keyed_project_indexes_fail_closed",
        red_arm_evidence: "let duplicate = br#\"{",
        disabled_mechanism: "supply duplicate and cross-keyed project records",
        forbidden_observation: "an ambiguous project record is accepted",
    },
    GuardRow {
        guard: "project-index no-follow reads",
        test: "project_index_refresh_rejects_a_symlinked_index_without_touching_its_target",
        red_arm_evidence: "symlink(&outside, paths.projects_path())",
        disabled_mechanism: "replace projects.json with an outside symlink",
        forbidden_observation: "refresh follows or overwrites the outside index",
    },
    GuardRow {
        guard: "project generation revalidation",
        test: "successful_loads_refresh_utf8_and_raw_project_records_deterministically",
        red_arm_evidence: "let stale_plan",
        disabled_mechanism: "refresh another project after planning",
        forbidden_observation: "the stale project plan commits",
    },
    GuardRow {
        guard: "committed project-index recovery",
        test: "committed_apply_keeps_its_journal_until_project_refresh_recovers",
        red_arm_evidence: "crashing_before_refresh",
        disabled_mechanism: "crash before the committed project refresh",
        forbidden_observation: "the journal is removed before the index is durable",
    },
    GuardRow {
        guard: "independent scope concurrency",
        test: "project_and_global_transactions_overlap_under_shared_custody",
        red_arm_evidence: "global_release_tx",
        disabled_mechanism: "hold both scope transactions at journal creation",
        forbidden_observation: "unrelated scopes serialize on a global exclusive lock",
    },
    GuardRow {
        guard: "typed lock order",
        test: "typed_order_accepts_forward_acquisition_and_rejects_inversion",
        red_arm_evidence: ".join(\"trust.lock\")",
        disabled_mechanism: "request trust custody after the later scope rank",
        forbidden_observation: "an inverted lock acquisition succeeds",
    },
    GuardRow {
        guard: "candidate mutex is first",
        test: "candidate_mutex_cannot_be_acquired_under_shared_state",
        red_arm_evidence: ".join(\"candidate.lock\")",
        disabled_mechanism: "request candidate custody while store custody is held",
        forbidden_observation: "candidate waits while holding a later-ranked lock",
    },
    GuardRow {
        guard: "same-scope serialization",
        test: "same_scope_transactions_serialize_and_the_waiter_revalidates",
        red_arm_evidence: "assert!(!second.is_finished())",
        disabled_mechanism: "pause the first transaction while starting the second",
        forbidden_observation: "both same-scope plans commit",
    },
    GuardRow {
        guard: "shared apply versus exclusive trust",
        test: "trust_writes_wait_for_an_apply_shared_lease",
        red_arm_evidence: "assert!(!trust.is_finished())",
        disabled_mechanism: "pause apply while starting a trust writer",
        forbidden_observation: "trust changes during apply revalidation",
    },
    GuardRow {
        guard: "exclusive prune versus shared apply",
        test: "apply_waits_while_prune_holds_exclusive_store_custody",
        red_arm_evidence: "assert!(!scope_apply.is_finished())",
        disabled_mechanism: "pause prune before deletion while starting apply",
        forbidden_observation: "apply crosses an in-progress prune",
    },
    GuardRow {
        guard: "complete prune reachability",
        test: "removing_a_reference_source_exposes_its_snapshot_in_the_red_arm",
        red_arm_evidence: "fs::remove_file(&candidate.candidate_path)",
        disabled_mechanism: "remove each candidate, repair, or project reference source",
        forbidden_observation: "a referenced snapshot remains proven reachable without its source",
    },
    GuardRow {
        guard: "prune generation revalidation",
        test: "stale_store_or_candidate_generation_aborts_before_deletion",
        red_arm_evidence: "for mutate in [\"candidate\", \"projects\", \"repair\", \"journal\"]",
        disabled_mechanism: "mutate each reachability input after planning",
        forbidden_observation: "a stale prune deletes the isolated snapshot",
    },
    GuardRow {
        guard: "bounded no-follow prune",
        test: "racing_snapshot_swap_cannot_redirect_directory_relative_prune",
        red_arm_evidence: "SwapAtPrune",
        disabled_mechanism: "swap the planned snapshot to an outside-directory symlink",
        forbidden_observation: "prune follows the symlink or touches the canary",
    },
];

fn test_body(name: &str) -> Option<&'static str> {
    let marker = format!("fn {name}");
    let start = OPERATION_TESTS.find(&marker)?;
    let source = &OPERATION_TESTS[start..];
    let opening = source.find('{')?;
    let mut depth = 0usize;
    for (offset, byte) in source[opening..].bytes().enumerate() {
        match byte {
            b'{' => depth += 1,
            b'}' => {
                depth -= 1;
                if depth == 0 {
                    return Some(&source[..opening + offset + 1]);
                }
            }
            _ => {}
        }
    }
    None
}

#[test]
fn every_operation_guard_names_its_executable_red_arm_and_forbidden_observation() {
    let mut names = std::collections::BTreeSet::new();
    for row in GUARDS {
        assert!(names.insert(row.guard), "duplicate guard: {}", row.guard);
        let body = test_body(row.test)
            .unwrap_or_else(|| panic!("missing executable guard test: {}", row.test));
        assert!(
            body.contains(row.red_arm_evidence),
            "{} does not contain its controlled red arm: {}",
            row.test,
            row.red_arm_evidence
        );
        assert!(!row.disabled_mechanism.is_empty());
        assert!(!row.forbidden_observation.is_empty());
    }
}

#[test]
fn core_keeps_planning_pure_and_mutation_behind_named_authorities() {
    for forbidden in [
        "clap",
        "ratatui",
        "tokio",
        "reqwest",
        "git2",
        "std::env",
        "Command::new",
        "std::process::Command",
        "stdin",
        "stdout",
        "is_terminal",
    ] {
        let core = format!(
            "{CORE_CARGO}\n{CORE_LIB}\n{CORE_MODEL}\n{PLANNER}\n{CHECKER}\n{EXECUTOR}\n{PROJECTS}\n{PRUNE}\n{TRANSACTION}\n{SOURCE_MUTATION}"
        );
        assert!(
            !core.contains(forbidden),
            "forbidden core dependency: {forbidden}"
        );
    }

    for forbidden in [
        "std::fs",
        "GitRunner",
        "TransactionRuntime",
        "LockCoordinator",
        "SystemTime",
    ] {
        assert!(
            !PLANNER.contains(forbidden),
            "planner reached an impure authority: {forbidden}"
        );
    }

    for mutation in [
        "fs::write",
        "fs::rename",
        "fs::remove_file",
        "fs::remove_dir",
    ] {
        assert!(!CORE_LIB.contains(mutation));
        assert!(!CORE_MODEL.contains(mutation));
        assert!(!PLANNER.contains(mutation));
        assert!(!CHECKER.contains(mutation));
    }
    assert!(EXECUTOR.contains("fs::remove_file"));
    assert!(TRANSACTION.contains("fs::rename"));
    assert!(PROJECTS.contains("write_locked"));
    assert!(PRUNE.contains("remove_snapshot"));
    assert!(SOURCE_MUTATION.contains("CandidateWorkflow"));
    assert!(CORE_LIB.contains("mod apply;"));
    assert!(CORE_LIB.contains("mod projects;"));
    assert!(CORE_LIB.contains("mod prune;"));
    assert!(CORE_LIB.contains("mod transaction;"));
    assert!(!CORE_LIB.contains("pub mod apply;"));
    assert!(!CORE_LIB.contains("pub mod transaction;"));
    assert!(!CORE_LIB.contains("mod inventory;"));
    assert!(CORE_LIB.contains("pub use grimoire_pack::inventory;"));
}

#[test]
fn production_runtime_construction_stays_in_the_adapter() {
    let core = format!(
        "{CORE_LIB}\n{CORE_MODEL}\n{PLANNER}\n{CHECKER}\n{EXECUTOR}\n{PROJECTS}\n{PRUNE}\n{TRANSACTION}\n{SOURCE_MUTATION}"
    );
    for production in ["SystemRuntime", "SystemTime::now"] {
        assert!(!core.contains(production));
        assert!(APP_RUNTIME.contains(production));
    }
    assert!(APP_RUNTIME.contains("std::process::id"));
    assert!(CORE_MODEL.contains("pub trait TransactionRuntime"));
    assert!(APP_RUNTIME.contains("impl TransactionRuntime for SystemRuntime"));
    assert_eq!(APP_LIB.matches("pub mod runtime;").count(), 1);
}

#[test]
fn phase_four_public_values_keep_the_required_trait_floor() {
    fn value<T: Debug + Clone + PartialEq + Eq>() {}
    fn ordered<T: Debug + Clone + PartialEq + Eq + PartialOrd + Ord>() {}
    fn hash<T: Debug + Clone + PartialEq + Eq + Hash>() {}
    fn wire<T: Debug + Clone + PartialEq + Eq + Serialize + DeserializeOwned>() {}

    wire::<Action>();
    wire::<Plan>();
    wire::<Preconditions>();
    wire::<grimoire_core::StorePrecondition>();
    wire::<ApplyOutcome>();
    wire::<RecoveryOutcome>();
    wire::<CheckReport>();
    ordered::<RecoveryDisposition>();
    hash::<ByteHash>();
    value::<grimoire_core::ProjectIndex>();
    value::<grimoire_core::ReachabilityObservation>();
}

#[test]
fn malformed_blocked_and_wrong_scope_plans_are_inert() {
    struct Runtime;
    impl TransactionRuntime for Runtime {
        fn transaction_nonce(&self) -> grimoire_core::Result<String> {
            Ok("operation-boundary".into())
        }

        fn unix_time(&self) -> grimoire_core::Result<i64> {
            Ok(1_700_000_000)
        }

        fn checkpoint(&self, _name: &'static str) -> grimoire_core::Result<FaultDisposition> {
            Ok(FaultDisposition::Continue)
        }
    }

    let temporary = tempfile::tempdir().unwrap();
    let root = temporary.path().canonicalize().unwrap();
    let project = root.join("project");
    std::fs::create_dir_all(&project).unwrap();
    let paths = grimoire_core::Paths::project(project, root.join("home")).unwrap();
    let action = Action::CreateManifest {
        scope: Scope::Project,
        after: b"schema = \"grimoire/manifest@1\"\n".to_vec(),
    };

    let blocked = Plan {
        actions: vec![action.clone()],
        blockers: vec![Blocker::new("controlled-blocker", [])],
        preconditions: Preconditions::absent(),
        facts: Vec::new(),
        exit_class: ExitClass::Blocked,
    };
    assert!(matches!(
        apply(&paths, &blocked, Approval::NotRequired, &Runtime),
        Err(CoreError::BlockedPlan)
    ));
    assert!(!paths.manifest_path().exists());

    let wrong_scope = Plan {
        actions: vec![Action::CreateManifest {
            scope: Scope::Global,
            after: b"schema = \"grimoire/manifest@1\"\n".to_vec(),
        }],
        blockers: Vec::new(),
        preconditions: Preconditions::absent(),
        facts: Vec::new(),
        exit_class: ExitClass::Success,
    };
    assert!(matches!(
        apply(&paths, &wrong_scope, Approval::NotRequired, &Runtime),
        Err(CoreError::Transaction(_))
    ));
    assert!(!paths.manifest_path().exists());

    let mixed_prune = Plan {
        actions: vec![
            action,
            Action::PruneSnapshot {
                source_key: SourceKey::parse("1".repeat(64)).unwrap(),
                snapshot_key: SnapshotKey::parse("2".repeat(64)).unwrap(),
            },
        ],
        blockers: Vec::new(),
        preconditions: Preconditions {
            reachability: Some(ByteHash::of(b"generation")),
            ..Preconditions::absent()
        },
        facts: Vec::new(),
        exit_class: ExitClass::Success,
    };
    assert!(matches!(
        apply(&paths, &mixed_prune, Approval::Granted, &Runtime),
        Err(CoreError::Transaction(_))
    ));
    assert!(!paths.manifest_path().exists());
}

#[test]
fn operation_wire_values_have_exact_deterministic_bytes() {
    let source_key = SourceKey::parse("1".repeat(64)).unwrap();
    let snapshot_key = SnapshotKey::parse("2".repeat(64)).unwrap();
    let preconditions = Preconditions {
        stores: BTreeMap::from([(
            "repo".try_into().unwrap(),
            grimoire_core::StorePrecondition {
                source_key: source_key.clone(),
                snapshot_key: snapshot_key.clone(),
                inventory: format!("sha256:{}", "3".repeat(64)),
                state: grimoire_core::SnapshotStore::Valid,
            },
        )]),
        ..Preconditions::absent()
    };
    let expected_preconditions = format!(
        concat!(
            "{{\"manifest\":null,\"lock\":null,\"candidates\":{{}},\"stores\":{{",
            "\"repo\":{{\"source_key\":\"{}\",\"snapshot_key\":\"{}\",",
            "\"inventory\":\"sha256:{}\",\"state\":\"valid\"}}}},",
            "\"trust\":null,\"projects\":null,\"reachability\":null,\"links\":{{}}}}"
        ),
        "1".repeat(64),
        "2".repeat(64),
        "3".repeat(64),
    );
    assert_eq!(
        serde_json::to_string(&preconditions).unwrap(),
        expected_preconditions
    );
    let actions = vec![
        Action::ReplaceCandidate {
            scope: Scope::Project,
            alias: "repo".try_into().unwrap(),
            source_key: source_key.clone(),
            before: None,
            after: b"new".to_vec(),
        },
        Action::RemoveCandidate {
            scope: Scope::Project,
            alias: "repo".try_into().unwrap(),
            source_key: source_key.clone(),
            before: b"old".to_vec(),
        },
        Action::PruneSnapshot {
            source_key,
            snapshot_key,
        },
    ];
    let expected_actions = format!(
        concat!(
            "[{{\"kind\":\"replace_candidate\",\"scope\":\"project\",",
            "\"alias\":\"repo\",\"source_key\":\"{}\",\"before\":null,",
            "\"after\":[110,101,119]}},",
            "{{\"kind\":\"remove_candidate\",\"scope\":\"project\",",
            "\"alias\":\"repo\",\"source_key\":\"{}\",",
            "\"before\":[111,108,100]}},",
            "{{\"kind\":\"prune_snapshot\",\"source_key\":\"{}\",",
            "\"snapshot_key\":\"{}\"}}]"
        ),
        "1".repeat(64),
        "1".repeat(64),
        "1".repeat(64),
        "2".repeat(64),
    );
    assert_eq!(serde_json::to_string(&actions).unwrap(), expected_actions);

    let report = CheckReport {
        findings: vec![CheckFinding {
            code: "foreign-file".into(),
            severity: CheckSeverity::Error,
            details: BTreeMap::from([("skill".into(), "one".into())]),
        }],
    };
    assert_eq!(
        serde_json::to_string(&report).unwrap(),
        "{\"findings\":[{\"code\":\"foreign-file\",\"severity\":\"error\",\"details\":{\"skill\":\"one\"}}]}"
    );
    assert_eq!(
        serde_json::to_string(&ApplyOutcome::Applied { changed: true }).unwrap(),
        "{\"status\":\"applied\",\"changed\":true}"
    );
    assert_eq!(
        serde_json::to_string(&RecoveryOutcome {
            dispositions: vec![RecoveryDisposition::RolledBack {
                scope_key: "global".into(),
            }],
        })
        .unwrap(),
        "{\"dispositions\":[{\"disposition\":\"rolled_back\",\"scope_key\":\"global\"}]}"
    );
}
