use std::io::{self, Write};

use grimoire_core::{ApplyOutcome, Plan, SourceDiff, SourceInfo, SourceSummary, TrustCatalog};

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

pub fn source_list(sources: &[SourceSummary], output: &mut dyn Write) -> io::Result<()> {
    for source in sources {
        writeln!(
            output,
            "{}\t{}\tlocked={}\tcandidate={}\tcurrent={}\ttrust={:?}{}",
            source.alias,
            if source.live { "live" } else { "pinned" },
            source.locked_commit.as_deref().unwrap_or("-"),
            source.candidate_commit.as_deref().unwrap_or("-"),
            source.candidate_current,
            source.trust,
            if source.has_findings {
                "\tfindings"
            } else {
                ""
            }
        )?;
    }
    Ok(())
}

pub fn source_diff(diff: &SourceDiff, output: &mut dyn Write) -> io::Result<()> {
    writeln!(
        output,
        "commit: {} -> {}",
        diff.commit_before.as_deref().unwrap_or("empty"),
        diff.commit_after.as_deref().unwrap_or("live")
    )?;
    for change in &diff.changes {
        writeln!(output, "{}\t{}", change.kind, change.path)?;
    }
    for change in &diff.fact_changes {
        writeln!(output, "{}\t{}", change.kind, change.fact)?;
        if let Some(before) = &change.before {
            writeln!(output, "  before: {before}")?;
        }
        if let Some(after) = &change.after {
            writeln!(output, "  after: {after}")?;
        }
    }
    for root in &diff.affected_roots {
        writeln!(output, "affected\t{root}")?;
    }
    Ok(())
}

pub fn trust_catalog(catalog: &TrustCatalog, output: &mut dyn Write) -> io::Result<()> {
    for record in &catalog.records {
        writeln!(
            output,
            "{}\t{}\tall={}\treceipts={}",
            record.source_key,
            record
                .identity
                .canonical_utf8()
                .unwrap_or("<non-UTF-8 local identity>"),
            record.all_snapshots,
            record.receipts.len()
        )?;
        for usage in &record.uses {
            writeln!(output, "  use\t{}\t{}", usage.scope, usage.alias)?;
        }
    }
    for finding in &catalog.findings {
        writeln!(output, "finding\t{finding}")?;
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
