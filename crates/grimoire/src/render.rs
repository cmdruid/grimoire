use std::io::{self, Write};

use grimoire_core::{ApplyOutcome, Plan, SourceInfo};

pub fn plan(plan: &Plan, output: &mut dyn Write) -> io::Result<()> {
    output.write_all(
        &plan
            .to_bytes()
            .map_err(|error| io::Error::other(error.to_string()))?,
    )
}

pub fn source_info(info: &SourceInfo, output: &mut dyn Write) -> io::Result<()> {
    writeln!(output, "source {}", info.alias)?;
    writeln!(output, "  declared: {}", info.declared)?;
    writeln!(
        output,
        "  kind: {}",
        info.candidate.identity.kind().as_str()
    )?;
    writeln!(
        output,
        "  commit: {}",
        info.candidate.commit.as_deref().unwrap_or("live")
    )?;
    writeln!(output, "  inventory: {}", info.candidate.inventory)?;
    writeln!(output, "  review: {}", info.export.root.display())?;
    writeln!(output, "  trust: {:?}", info.trust)?;
    writeln!(output, "  skills: {}", info.inventory.skills.len())?;
    writeln!(output, "  packs: {}", info.inventory.packs.len())?;
    for finding in &info.inventory.findings {
        writeln!(
            output,
            "  finding: {} ({:?})",
            finding.code, finding.severity
        )?;
    }
    Ok(())
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
