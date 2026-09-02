use std::io::{self, Write};

use grimoire_core::{ApplyOutcome, Plan};

pub fn plan(plan: &Plan, output: &mut dyn Write) -> io::Result<()> {
    output.write_all(
        &plan
            .to_bytes()
            .map_err(|error| io::Error::other(error.to_string()))?,
    )
}

pub fn apply_outcome(outcome: &ApplyOutcome, output: &mut dyn Write) -> io::Result<()> {
    match outcome {
        ApplyOutcome::Applied { changed: true } => writeln!(output, "Applied."),
        ApplyOutcome::Applied { changed: false } => writeln!(output, "Already up to date."),
        ApplyOutcome::Cancelled => writeln!(output, "Cancelled; no changes applied."),
        ApplyOutcome::Interrupted { checkpoint } => {
            writeln!(
                output,
                "Interrupted at transaction checkpoint `{checkpoint}`."
            )
        }
    }
}
