use std::io::{self, Write};

use grimoire_core::{
    ApplyOutcome, CheckReport, ContextReport, InstalledStatus, Plan, ProjectionMode, SourceDiff,
    SourceInfo, SourceSummary, TrustCatalog, WorldObservation,
};

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
            if source.link { "link" } else { "pinned" },
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
            "{}\t{}\tauthority={}\tall={}\treceipts={}",
            record.source_key,
            record
                .identity
                .canonical_utf8()
                .unwrap_or("<non-UTF-8 local identity>"),
            if record.all_snapshots {
                "all-snapshots"
            } else if !record.receipts.is_empty() {
                "snapshot"
            } else {
                "none"
            },
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

pub fn context_report(report: &ContextReport, output: &mut dyn Write) -> io::Result<()> {
    for root in &report.desired_roots {
        writeln!(
            output,
            "desired\t{}\t{}\tmode={}",
            root.root.lock_value(),
            root.source,
            projection_mode(root.mode),
        )?;
    }
    for skill in &report.skills {
        let requested_by = skill
            .requested_by
            .iter()
            .map(|root| root.lock_value())
            .collect::<Vec<_>>()
            .join(",");
        writeln!(
            output,
            "skill\t{}\t{}\tmode={}\tprojection={}\tinventory={}\tinstalled={}\trequested_by={}",
            skill.name,
            skill.source,
            projection_mode(skill.mode),
            skill
                .vendor_path
                .as_deref()
                .unwrap_or_else(|| { skill.snapshot.as_deref().unwrap_or("live") }),
            skill.inventory.as_deref().unwrap_or("-"),
            installed_status(skill.installed),
            requested_by
        )?;
    }
    for unavailable in &report.unavailable {
        writeln!(
            output,
            "unavailable\t{}\t{}",
            unavailable.pack, unavailable.skill
        )?;
    }
    for inherited in &report.inherited {
        writeln!(
            output,
            "inherited\t{}\t{}\tshadowed={}",
            inherited.name, inherited.source, inherited.shadowed
        )?;
    }
    for blocker in &report.blockers {
        writeln!(output, "blocker\t{}\t{:?}", blocker.code, blocker.details)?;
    }
    render_findings(&report.findings, output)
}

fn projection_mode(mode: ProjectionMode) -> &'static str {
    match mode {
        ProjectionMode::Link => "link",
        ProjectionMode::Vendor => "copy",
    }
}

pub fn check_report(report: &CheckReport, output: &mut dyn Write) -> io::Result<()> {
    render_findings(&report.findings, output)
}

pub fn observations(findings: &[WorldObservation], output: &mut dyn Write) -> io::Result<()> {
    for finding in findings {
        writeln!(output, "finding\t{}\t{:?}", finding.code, finding.details)?;
    }
    Ok(())
}

fn render_findings(
    findings: &[grimoire_core::CheckFinding],
    output: &mut dyn Write,
) -> io::Result<()> {
    for finding in findings {
        writeln!(
            output,
            "finding\t{:?}\t{}\t{:?}",
            finding.severity, finding.code, finding.details
        )?;
    }
    Ok(())
}

fn installed_status(status: InstalledStatus) -> &'static str {
    match status {
        InstalledStatus::Current => "current",
        InstalledStatus::Missing => "missing",
        InstalledStatus::Drift => "drift",
        InstalledStatus::ForeignFile => "foreign-file",
        InstalledStatus::ForeignDirectory => "foreign-directory",
    }
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
