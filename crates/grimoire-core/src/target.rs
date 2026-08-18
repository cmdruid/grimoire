//! Where an operation happens: one scope, one agent's skills dir, one lock.
//!
//! Spec §3: "Every pack operation (install/remove/check) targets **exactly one
//! scope**." A [`Target`] is that scope made concrete. Construction is pure and
//! lexical — no I/O, no canonicalization, `home` a parameter — and every scope
//! decision routes through `grimoire_pack::lock`, which is §3's single
//! authority. Deriving the lock path here instead would be how core and
//! `install.sh` silently drift apart.

use std::path::{Path, PathBuf};

use crate::agents::Agent;
pub use grimoire_pack::lock::Scope;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Target {
    pub agent: Agent,
    pub scope: Scope,
    /// Where member links are created.
    pub skills_dir: PathBuf,
    /// Where `grimoire.lock` lives for this destination (spec §3).
    pub lock_path: PathBuf,
}

impl Target {
    /// The agent's global (per-user) skills dir.
    ///
    /// Note the §3 consequence: all four agents' global installs share ONE
    /// lock at `<home>/.agents/grimoire.lock`, regardless of which agent dir
    /// received the links.
    #[must_use]
    pub fn global(agent: &Agent, home: &Path) -> Self {
        Self::at(agent, agent.global_skills_dir.clone(), home)
    }

    /// The agent's skills dir inside a project.
    #[must_use]
    pub fn project(agent: &Agent, project_root: &Path, home: &Path) -> Self {
        Self::at(agent, project_root.join(&agent.project_skills_dir), home)
    }

    fn at(agent: &Agent, skills_dir: PathBuf, home: &Path) -> Self {
        Self {
            scope: grimoire_pack::lock::scope_for(&skills_dir, home),
            lock_path: grimoire_pack::lock::lock_path(&skills_dir, home),
            agent: agent.clone(),
            skills_dir,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::agents::{self, AgentEnv};

    #[test]
    fn global_installs_share_the_one_agents_lock() {
        let home = Path::new("/home/u");
        let env = AgentEnv::rooted(home);
        for id in ["claude-code", "codex", "cursor", "universal"] {
            let t = Target::global(&agents::get(&env, id).unwrap(), home);
            assert_eq!(
                t.lock_path,
                Path::new("/home/u/.agents/grimoire.lock"),
                "{id} must lock in the shared global lock (spec 3)"
            );
        }
    }

    /// The coherence invariant behind vendoring only four rows: every agent in
    /// the table must classify as `Scope::Global` under `grimoire-pack`'s §3
    /// rule. An agent added here without a matching `AGENT_DIRS` entry would
    /// silently write its lock into a project-scoped path — this is the test
    /// that refuses to let that happen.
    #[test]
    fn every_agent_is_globally_scoped() {
        let home = Path::new("/home/u");
        let env = AgentEnv::rooted(home);
        for agent in agents::table(&env) {
            let t = Target::global(&agent, home);
            assert_eq!(
                t.scope,
                Scope::Global,
                "{} resolved to {:?} — its global dir {} is not under a dir \
                 grimoire_pack::lock::AGENT_DIRS recognizes",
                agent.id,
                t.scope,
                agent.global_skills_dir.display()
            );
        }
    }

    #[test]
    fn project_target_locks_beside_the_agent_dir() {
        let home = Path::new("/home/u");
        let env = AgentEnv::rooted(home);
        let t = Target::project(
            &agents::get(&env, "claude-code").unwrap(),
            Path::new("/work/proj"),
            home,
        );
        assert_eq!(t.scope, Scope::Project);
        assert_eq!(t.skills_dir, Path::new("/work/proj/.claude/skills"));
        // install.sh does `dirname "$target"` (lock_dir), so parity puts the
        // lock beside the agent dir, not at the repo root.
        assert_eq!(t.lock_path, Path::new("/work/proj/.claude/grimoire.lock"));
    }

    #[test]
    fn universal_project_target_uses_the_shared_dir() {
        let home = Path::new("/home/u");
        let env = AgentEnv::rooted(home);
        let t = Target::project(
            &agents::get(&env, "codex").unwrap(),
            Path::new("/work/proj"),
            home,
        );
        assert_eq!(t.skills_dir, Path::new("/work/proj/.agents/skills"));
        assert_eq!(t.lock_path, Path::new("/work/proj/.agents/grimoire.lock"));
    }

    #[test]
    fn a_project_inside_home_is_still_project_scope() {
        // §3's rule is "is, or is under, a recognized agent dir in HOME" —
        // not "anywhere under HOME".
        let home = Path::new("/home/u");
        let env = AgentEnv::rooted(home);
        let t = Target::project(
            &agents::get(&env, "claude-code").unwrap(),
            &home.join("work/proj"),
            home,
        );
        assert_eq!(t.scope, Scope::Project);
        assert_eq!(
            t.lock_path,
            Path::new("/home/u/work/proj/.claude/grimoire.lock")
        );
    }
}
