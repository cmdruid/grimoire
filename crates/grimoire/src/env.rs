//! Everything ambient, resolved once — the app's whole surface onto the outside
//! world.
//!
//! `grimoire-core` is deliberately **homeless and clockless**: `home`, the agent
//! env overrides, and `installed_at` all arrive as parameters, so its operations
//! are hermetic. That purity has one consequence the binary must handle
//! carefully: `AgentEnv::from_process` reads `HOME` for the agent table, while
//! `Target::global(&agent, home)` takes `home` again, separately. Nothing
//! structural stops the two from disagreeing, and a disagreement misclassifies
//! scope silently — `scope_for` is lexical, so a wrong `home` simply yields the
//! wrong answer with no error.
//!
//! So there is exactly one `AppEnv`, built once at startup, and it is the only
//! constructor of a [`Target`] in this crate. The two homes cannot disagree
//! because there is only one. `tests/boundary.rs` enforces that this file is the
//! only one that reads the environment or names `Target::`.
//!
//! It also supplies the three other facts core refuses to invent: the clock, the
//! library's git ref, and where the config lives.

use std::path::{Path, PathBuf};
use std::process::Command;

use grimoire_core::agents::{self, Agent, AgentEnv};
use grimoire_core::target::Target;
use grimoire_core::time::Timestamp;

pub struct AppEnv {
    agents: AgentEnv,
    config_home: PathBuf,
}

impl AppEnv {
    /// The one place this crate reads the process environment.
    #[must_use]
    pub fn from_process() -> Self {
        let agents = AgentEnv::from_process();
        // XDG, with the usual fallback. Read here rather than in `config` so the
        // whole environment lands in one struct.
        let config_home = std::env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .filter(|p| !p.as_os_str().is_empty())
            .unwrap_or_else(|| agents.home.join(".config"));
        Self {
            agents,
            config_home,
        }
    }

    /// Every path derived from one root — the test constructor, mirroring
    /// [`AgentEnv::rooted`].
    #[must_use]
    pub fn rooted(home: impl Into<PathBuf>) -> Self {
        let agents = AgentEnv::rooted(home);
        Self {
            config_home: agents.home.join(".config"),
            agents,
        }
    }

    #[must_use]
    pub fn home(&self) -> &Path {
        &self.agents.home
    }

    #[must_use]
    pub fn config_home(&self) -> &Path {
        &self.config_home
    }

    /// The four targets spec §3 recognizes, resolved against this environment.
    #[must_use]
    pub fn agents(&self) -> Vec<Agent> {
        agents::table(&self.agents)
    }

    #[must_use]
    pub fn agent(&self, id: &str) -> Option<Agent> {
        agents::get(&self.agents, id)
    }

    /// The agent's global destination. Note `home` is not a parameter: it is
    /// *this* environment's home, which is the entire point.
    #[must_use]
    pub fn global_target(&self, agent: &Agent) -> Target {
        Target::global(agent, self.home())
    }

    #[must_use]
    pub fn project_target(&self, agent: &Agent, project_root: &Path) -> Target {
        Target::project(agent, project_root, self.home())
    }

    /// Now, in the exact shape the lock takes.
    ///
    /// A clock crate was tried and dropped. `Timestamp` accepts only the 20-byte
    /// `date -u +%Y-%m-%dT%H:%M:%SZ` shape `install.sh` writes — no fractional
    /// seconds, no offsets — so a general RFC3339 formatter is both more than
    /// this needs and, with `time`'s `Rfc3339`, actively wrong: `now_utc()`
    /// carries nanoseconds and that formatter emits them, which
    /// [`Timestamp::parse`] rejects outright. What is left is one civil-date
    /// conversion, which is [`utc_from_epoch`]. Same reasoning core's own
    /// `time.rs` and `config.rs` give for their floors: the job is smaller than
    /// the dependency.
    ///
    /// A clock before the epoch falls back to the epoch rather than refusing an
    /// install — a wrong system clock is not this tool's problem to adjudicate.
    #[must_use]
    pub fn now(&self) -> Timestamp {
        let secs = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_or(0, |d| d.as_secs());
        Timestamp::parse(&utc_from_epoch(secs)).expect("utc_from_epoch emits the canonical shape")
    }

    /// The library's commit, for the lock's `ref` — `install.sh` shells
    /// `git rev-parse --short HEAD` and core never shells, so the binary does.
    /// A library that is not a git checkout simply has no ref, which the lock
    /// treats as optional.
    #[must_use]
    pub fn source_ref(&self, library_root: &Path) -> Option<String> {
        let out = Command::new("git")
            .args(["-C"])
            .arg(library_root)
            .args(["rev-parse", "--short", "HEAD"])
            .output()
            .ok()?;
        if !out.status.success() {
            return None;
        }
        let text = String::from_utf8(out.stdout).ok()?;
        let text = text.trim();
        (!text.is_empty()).then(|| text.to_string())
    }
}

/// Seconds since the Unix epoch → `YYYY-MM-DDTHH:MM:SSZ`.
///
/// Civil-from-days after Howard Hinnant's `chrono`-compatible algorithm, with
/// the era arithmetic that makes the Gregorian leap rules fall out rather than
/// being special-cased. Proleptic and UTC — no leap seconds, exactly like
/// `date -u`, which is the oracle this has to match (`install.sh` writes the
/// same shape, and `tests/parity.rs` pins the two implementations together).
#[must_use]
pub fn utc_from_epoch(secs: u64) -> String {
    let days = (secs / 86_400) as i64;
    let time_of_day = secs % 86_400;

    // Shift the epoch to 0000-03-01 so leap day lands at the end of the cycle.
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let day_of_era = z - era * 146_097; // [0, 146096]
    let year_of_era =
        (day_of_era - day_of_era / 1460 + day_of_era / 36_524 - day_of_era / 146_096) / 365; // [0, 399]
    let year = year_of_era + era * 400;
    let day_of_year = day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100); // [0, 365]
    let mp = (5 * day_of_year + 2) / 153; // [0, 11], March-based
    let day = day_of_year - (153 * mp + 2) / 5 + 1; // [1, 31]
    let month = if mp < 10 { mp + 3 } else { mp - 9 }; // [1, 12]
    let year = year + i64::from(month <= 2);

    format!(
        "{year:04}-{month:02}-{day:02}T{:02}:{:02}:{:02}Z",
        time_of_day / 3600,
        (time_of_day % 3600) / 60,
        time_of_day % 60,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Vectors generated with `date -u -r <epoch> +%Y-%m-%dT%H:%M:%SZ`, the same
    /// command `install.sh` uses. Both leap-day cases are here on purpose: 2024
    /// (ordinary leap year) and 2000 (the divisible-by-400 exception that a
    /// naive rule gets wrong), plus 2100 (divisible by 100, NOT a leap year) —
    /// the one that catches an implementation that stopped at "every 4 years".
    #[test]
    fn matches_date_u() {
        for (secs, want) in [
            (0u64, "1970-01-01T00:00:00Z"),
            (1_000_000_000, "2001-09-09T01:46:40Z"),
            (1_767_225_600, "2026-01-01T00:00:00Z"),
            (1_709_208_000, "2024-02-29T12:00:00Z"),
            (951_825_600, "2000-02-29T12:00:00Z"),
            (4_102_444_800, "2100-01-01T00:00:00Z"),
        ] {
            assert_eq!(utc_from_epoch(secs), want, "epoch {secs}");
        }
    }

    /// The contract that matters at the call site: whatever the clock says,
    /// `Timestamp` accepts it. A formatter that drifts from the canonical shape
    /// would otherwise fail at the first real install, not here.
    #[test]
    fn every_output_is_a_valid_timestamp() {
        // Every hour across four years, which covers a leap day and a year roll.
        for hour in 0..(4 * 365 * 24) {
            let secs = 1_700_000_000 + hour * 3600;
            let text = utc_from_epoch(secs);
            assert!(
                Timestamp::parse(&text).is_ok(),
                "Timestamp rejected {text} (epoch {secs})"
            );
        }
    }

    #[test]
    fn the_clock_produces_something_parseable() {
        let env = AppEnv::rooted("/home/u");
        let now = env.now();
        assert_eq!(now.as_str().len(), 20, "{}", now.as_str());
    }
}
