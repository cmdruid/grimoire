//! A throwaway world for the app's tests: a fixture library, a fake home, a
//! fake project — all inside one `TempDir`.
//!
//! Deliberately a sibling of `grimoire-core`'s sandbox rather than a shared
//! crate. The two will diverge (the app needs an `AppEnv` and an `App`; core
//! needs neither), and a shared fixture would couple the two test suites at
//! exactly the seam this phase spent its effort keeping clean.

#![allow(dead_code)] // each test binary uses a different subset

use std::path::PathBuf;

use skill_grimoire::app::App;
use skill_grimoire::env::AppEnv;

pub struct World {
    pub dir: tempfile::TempDir,
}

impl World {
    /// A library holding one faced pack (`alpha`: face + required `beta` +
    /// optional `gamma`) and one loose skill (`solo`).
    pub fn new() -> Self {
        let world = Self {
            dir: tempfile::tempdir().unwrap(),
        };
        world.skill("alpha", "the pack face");
        world.manifest("alpha", "1.0.0", "beta", Some("gamma"));
        world.skill("beta", "a required member");
        world.skill("gamma", "an optional member");
        world.skill("solo", "a loose skill in no pack");
        std::fs::create_dir_all(world.home()).unwrap();
        std::fs::create_dir_all(world.project()).unwrap();
        world
    }

    pub fn library(&self) -> PathBuf {
        self.dir.path().join("library")
    }

    pub fn home(&self) -> PathBuf {
        self.dir.path().join("home")
    }

    pub fn project(&self) -> PathBuf {
        self.dir.path().join("project")
    }

    pub fn skill_dir(&self, name: &str) -> PathBuf {
        self.library().join("skills").join(name)
    }

    pub fn skill(&self, name: &str, description: &str) {
        let dir = self.skill_dir(name);
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(
            dir.join("SKILL.md"),
            format!("---\nname: {name}\ndescription: {description}\n---\nbody\n"),
        )
        .unwrap();
    }

    pub fn manifest(&self, pack: &str, version: &str, required: &str, optional: Option<&str>) {
        let optional = optional.map_or(String::new(), |o| format!("optional: {o}\n"));
        std::fs::write(
            self.skill_dir(pack).join("PACK.md"),
            format!(
                "---\nname: {pack}\nversion: {version}\ndescription: \"the {pack} pack\"\n\
                 required: {required}\n{optional}---\nrunbook\n"
            ),
        )
        .unwrap();
    }

    /// An app rooted in this world, with the project opened.
    pub fn app(&self) -> App {
        App::new(
            AppEnv::rooted(self.home()),
            self.library(),
            Some(self.project()),
        )
    }
}
