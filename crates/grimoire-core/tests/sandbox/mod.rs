//! A throwaway world for the integration tests: a fixture library, a FAKE
//! home, and a fake project — all inside one `TempDir`.
//!
//! Nothing here touches the developer's real agent directories. The agent set
//! comes from `AgentEnv::rooted(<tmp>/home)`, never `AgentEnv::from_process()`
//! — that is the whole reason the crate takes its environment as a parameter.

#![allow(dead_code)] // each test binary uses a different subset

use std::path::{Path, PathBuf};

use grimoire_core::agents::{self, Agent, AgentEnv};
use grimoire_core::library::Library;
use grimoire_core::target::Target;
use grimoire_core::time::Timestamp;

pub struct Sandbox {
    pub dir: tempfile::TempDir,
}

impl Sandbox {
    /// A library holding one faced pack (`alpha`: face + required `beta` +
    /// optional `gamma`) and one loose skill (`solo`).
    pub fn new() -> Self {
        let sandbox = Self {
            dir: tempfile::tempdir().unwrap(),
        };
        sandbox.write_skill("alpha", "the pack face");
        sandbox.write_manifest("alpha", "1.0.0", "the alpha pack", "beta", Some("gamma"));
        sandbox.write_skill("beta", "a required member");
        sandbox.write_skill("gamma", "an optional member");
        sandbox.write_skill("solo", "a loose skill in no pack");
        std::fs::create_dir_all(sandbox.home()).unwrap();
        std::fs::create_dir_all(sandbox.project()).unwrap();
        sandbox
    }

    pub fn library_root(&self) -> PathBuf {
        self.dir.path().join("library")
    }

    pub fn library(&self) -> Library {
        Library::open(self.library_root())
    }

    pub fn home(&self) -> PathBuf {
        self.dir.path().join("home")
    }

    pub fn project(&self) -> PathBuf {
        self.dir.path().join("project")
    }

    pub fn env(&self) -> AgentEnv {
        AgentEnv::rooted(self.home())
    }

    pub fn agent(&self, id: &str) -> Agent {
        agents::get(&self.env(), id).expect("known agent id")
    }

    /// The global target for an agent, rooted in the fake home.
    pub fn global_target(&self, agent_id: &str) -> Target {
        Target::global(&self.agent(agent_id), &self.home())
    }

    /// The project target for an agent, rooted in the fake project.
    pub fn project_target(&self, agent_id: &str) -> Target {
        Target::project(&self.agent(agent_id), &self.project(), &self.home())
    }

    pub fn skill_dir(&self, name: &str) -> PathBuf {
        self.library_root().join("skills").join(name)
    }

    pub fn write_skill(&self, name: &str, description: &str) {
        let dir = self.skill_dir(name);
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(
            dir.join("SKILL.md"),
            format!("---\nname: {name}\ndescription: {description}\n---\nbody\n"),
        )
        .unwrap();
    }

    pub fn write_manifest(
        &self,
        pack: &str,
        version: &str,
        description: &str,
        required: &str,
        optional: Option<&str>,
    ) {
        let dir = self.skill_dir(pack);
        std::fs::create_dir_all(&dir).unwrap();
        let optional = optional.map_or(String::new(), |o| format!("optional: {o}\n"));
        std::fs::write(
            dir.join("PACK.md"),
            format!(
                "---\nname: {pack}\nversion: {version}\ndescription: \"{description}\"\n\
                 required: {required}\n{optional}---\nrunbook\n"
            ),
        )
        .unwrap();
    }

    /// Add a second pack sharing `beta` with `alpha` — the refcount fixture.
    pub fn add_sharing_pack(&self) {
        self.write_skill("delta", "a second pack face");
        self.write_manifest("delta", "2.0.0", "the delta pack", "beta", None);
    }

    pub fn timestamp(&self) -> Timestamp {
        // Fixed, because the crate is clockless and a test that reads the wall
        // clock is a test that can differ between runs.
        Timestamp::parse("2026-08-18T12:00:00Z").unwrap()
    }

    /// Read a link's target, failing loudly if it is not a symlink — the
    /// assertion that keeps copy semantics from creeping back in.
    pub fn resolve_link(&self, link: &Path) -> PathBuf {
        let meta = std::fs::symlink_metadata(link)
            .unwrap_or_else(|e| panic!("no entry at {}: {e}", link.display()));
        assert!(
            meta.file_type().is_symlink(),
            "{} is not a symlink — install must never copy (install.sh parity)",
            link.display()
        );
        std::fs::canonicalize(link).unwrap()
    }
}

/// Install `alpha` at a target with the standard request.
pub fn install_alpha(
    sandbox: &Sandbox,
    target: &Target,
    skip_optional: Vec<String>,
) -> grimoire_core::install::InstallOutcome {
    let library = sandbox.library();
    grimoire_core::install::install(grimoire_core::install::InstallRequest {
        library: &library,
        pack: "alpha",
        target,
        installed_at: sandbox.timestamp(),
        source_ref: Some("abc1234".to_string()),
        skip_optional,
    })
    .expect("install alpha")
}
