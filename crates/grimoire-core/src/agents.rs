//! The agent table: where each harness keeps its skills.
//!
//! **Provenance.** These four rows are ported from the `skill` crate
//! (qntx/skill 0.8.3, `skill/src/agents/builtin.rs`) — the line references on
//! each row make a future re-check a diff rather than an investigation. We
//! vendor rather than depend: a pinned `=0.8.3` would freeze the very table a
//! dependency was for, and upstream's 47 rows contradict spec §3, whose global
//! scope recognizes exactly the four dirs below
//! (`grimoire_pack::lock::AGENT_DIRS`). The Phase 2 plan's *Finding 2* records
//! the full argument; `target::tests::every_agent_is_globally_scoped` is the
//! invariant that keeps the two halves in step.
//!
//! Adding an agent here therefore means adding it to `AGENT_DIRS` too — that
//! test fails loudly if only one side is edited.

use std::path::{Path, PathBuf};

/// The ecosystem's universal skills directory (upstream `types.rs:297`).
/// Most harnesses read it at *project* scope while keeping their own dir at
/// global scope — that asymmetry is upstream's, and deliberate.
pub const UNIVERSAL_SKILLS_DIR: &str = ".agents/skills";

/// The environment the table resolves against — a **parameter**, so the crate
/// reads no ambient state during an operation and tests stay hermetic.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AgentEnv {
    pub home: PathBuf,
    /// `$CLAUDE_CONFIG_DIR`, else `<home>/.claude`.
    pub claude: PathBuf,
    /// `$CODEX_HOME`, else `<home>/.codex`.
    pub codex: PathBuf,
}

impl AgentEnv {
    /// Every path derived from one root. **The** test constructor.
    #[must_use]
    pub fn rooted(home: impl Into<PathBuf>) -> Self {
        let home = home.into();
        Self {
            claude: home.join(".claude"),
            codex: home.join(".codex"),
            home,
        }
    }

    /// Reads `HOME`, `CLAUDE_CONFIG_DIR`, `CODEX_HOME`.
    ///
    /// **For a binary's convenience only — no operation in this crate calls
    /// it** (`tests/boundary.rs` asserts that). Empty values count as unset,
    /// matching upstream's `env_override` (`builtin.rs:87-93`) and
    /// xdg-basedir behavior.
    #[must_use]
    pub fn from_process() -> Self {
        let home = std::env::var_os("HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("."));
        let override_dir = |key: &str| {
            std::env::var(key)
                .ok()
                .filter(|v| !v.trim().is_empty())
                .map(PathBuf::from)
        };
        Self {
            claude: override_dir("CLAUDE_CONFIG_DIR").unwrap_or_else(|| home.join(".claude")),
            codex: override_dir("CODEX_HOME").unwrap_or_else(|| home.join(".codex")),
            home,
        }
    }
}

/// One agent harness, as this crate models it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Agent {
    /// Machine-readable id, e.g. `claude-code`.
    pub id: String,
    pub display_name: String,
    /// Project-*relative* skills dir, e.g. `.claude/skills`.
    pub project_skills_dir: PathBuf,
    /// Absolute global skills dir, resolved against an [`AgentEnv`].
    pub global_skills_dir: PathBuf,
    detect_paths: Vec<PathBuf>,
}

impl Agent {
    /// Is this harness present on the machine? Best-effort existence probe: an
    /// unreadable path counts as absent (upstream swallows probe failures the
    /// same way — `agents/mod.rs:98-122`), so detection never fails an
    /// operation.
    #[must_use]
    pub fn detected(&self) -> bool {
        self.detect_paths
            .iter()
            .any(|p| p.try_exists().unwrap_or(false))
    }

    /// Does this agent read the universal `.agents/skills` at project scope?
    #[must_use]
    pub fn is_universal(&self) -> bool {
        self.project_skills_dir == Path::new(UNIVERSAL_SKILLS_DIR)
    }

    #[must_use]
    pub fn detect_paths(&self) -> &[PathBuf] {
        &self.detect_paths
    }
}

/// The four targets spec §3 recognizes, resolved against `env`. Pure.
#[must_use]
pub fn table(env: &AgentEnv) -> Vec<Agent> {
    vec![
        // upstream builtin.rs:159-166
        Agent {
            id: "claude-code".into(),
            display_name: "Claude Code".into(),
            project_skills_dir: PathBuf::from(".claude/skills"),
            global_skills_dir: env.claude.join("skills"),
            detect_paths: vec![env.claude.clone()],
        },
        // upstream builtin.rs (id "codex"): universal at project scope
        Agent {
            id: "codex".into(),
            display_name: "Codex".into(),
            project_skills_dir: PathBuf::from(UNIVERSAL_SKILLS_DIR),
            global_skills_dir: env.codex.join("skills"),
            detect_paths: vec![env.codex.clone(), PathBuf::from("/etc/codex")],
        },
        // upstream builtin.rs (id "cursor")
        Agent {
            id: "cursor".into(),
            display_name: "Cursor".into(),
            project_skills_dir: PathBuf::from(UNIVERSAL_SKILLS_DIR),
            global_skills_dir: env.home.join(".cursor").join("skills"),
            detect_paths: vec![env.home.join(".cursor")],
        },
        // The canonical/universal location itself — not an agent upstream
        // models, but the one `install.sh` and this machine actually use, and
        // §3's shared global lock lives beside it.
        Agent {
            id: "universal".into(),
            display_name: "Universal (.agents)".into(),
            project_skills_dir: PathBuf::from(UNIVERSAL_SKILLS_DIR),
            global_skills_dir: env.home.join(".agents").join("skills"),
            detect_paths: vec![env.home.join(".agents")],
        },
    ]
}

/// One agent by id.
#[must_use]
pub fn get(env: &AgentEnv, id: &str) -> Option<Agent> {
    table(env).into_iter().find(|a| a.id == id)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn table_resolves_every_row_against_the_env() {
        let env = AgentEnv::rooted("/home/u");
        let t = table(&env);
        assert_eq!(t.len(), 4);
        let by = |id: &str| t.iter().find(|a| a.id == id).unwrap().clone();
        assert_eq!(
            by("claude-code").global_skills_dir,
            Path::new("/home/u/.claude/skills")
        );
        assert_eq!(by("codex").global_skills_dir, Path::new("/home/u/.codex/skills"));
        assert_eq!(
            by("cursor").global_skills_dir,
            Path::new("/home/u/.cursor/skills")
        );
        assert_eq!(
            by("universal").global_skills_dir,
            Path::new("/home/u/.agents/skills")
        );
    }

    #[test]
    fn only_claude_is_non_universal_at_project_scope() {
        let env = AgentEnv::rooted("/home/u");
        let t = table(&env);
        assert!(!t.iter().find(|a| a.id == "claude-code").unwrap().is_universal());
        for id in ["codex", "cursor", "universal"] {
            assert!(
                t.iter().find(|a| a.id == id).unwrap().is_universal(),
                "{id} should read the universal dir at project scope"
            );
        }
    }

    #[test]
    fn rooted_env_overrides_propagate_to_dir_and_probe() {
        // A redirected CLAUDE_CONFIG_DIR must move BOTH the install dir and
        // the detection probe — moving only one is the subtle port bug.
        let env = AgentEnv {
            home: PathBuf::from("/home/u"),
            claude: PathBuf::from("/elsewhere/claude"),
            codex: PathBuf::from("/home/u/.codex"),
        };
        let claude = get(&env, "claude-code").unwrap();
        assert_eq!(
            claude.global_skills_dir,
            Path::new("/elsewhere/claude/skills")
        );
        assert_eq!(claude.detect_paths(), [PathBuf::from("/elsewhere/claude")]);
    }

    #[test]
    fn detection_is_existence_and_never_errors() {
        let tmp = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(tmp.path().join(".claude")).unwrap();
        let env = AgentEnv::rooted(tmp.path());
        assert!(get(&env, "claude-code").unwrap().detected());
        assert!(!get(&env, "cursor").unwrap().detected());
    }

    #[test]
    fn get_is_none_for_an_unknown_id() {
        assert!(get(&AgentEnv::rooted("/home/u"), "no-such-agent").is_none());
    }
}
