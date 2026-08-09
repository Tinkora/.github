# ADR-0002: Authorize evidence-gated solo releases

## Status

Accepted

## Date

2026-08-09

## Context

Tinkora currently has one real organization owner and uses GitHub Free. Waiting
for a second independent owner would provide stronger review and recovery, but
it would also prevent otherwise verified public tools from publishing stable,
immutable artifacts for an unbounded period. Creating a second account
controlled by the same person would not add independence.

The first release candidate already has a project-owned workflow that builds on
hosted runners, validates version metadata, runs the complete quality suite,
creates checksums and CycloneDX SBOMs, attests provenance, and grants
`contents: write` only to the final publication job. The repository also has a
protected `v*` tag namespace. The previous organization policy prohibited any
solo-stage Release despite those controls, while the project release guide
described a solo authorization path. The policies therefore conflicted.

## Decision

Permit a project-specific release during the solo stage when all of these are
true:

- the exact release commit is on protected `main` and all required hosted checks
  have passed;
- version metadata, changelog, supported targets, licenses, security, privacy,
  compatibility, and rollback consequences have been reviewed;
- a protected immutable `vMAJOR.MINOR.PATCH` tag is the only publication trigger;
- ordinary branch pushes, schedules, and unattended dispatches cannot publish;
- the workflow is read-only by default and only the final publication job has
  `contents: write`;
- release archives have checksums, an SBOM, provenance, documented consumer
  verification, and an asset immutability check;
- the owner deliberately pushes the tag only after verifying the exact commit
  SHA and records the resulting workflow and Release evidence.

The tag push is explicit owner authorization. It is not an independent review,
and the release Environment does not become an approval control merely because
it exists. The organization reusable release workflow stays permanently
read-only. The machine policy's `releaseAutomation` gate continues to represent
organization-wide reusable or unattended publication and remains pending.

After a second independent, trusted owner is active, protected release
publication must require non-author approval and a tested recovery and
revocation path.

## Alternatives considered

### Block all releases until a second owner exists

This maximizes separation of duties but ties basic artifact availability to an
unknown staffing date. It was rejected because immutable tags, hosted evidence,
least privilege, and post-publication verification can bound the current risk
without claiming nonexistent independence.

### Treat a second account or self-approved Environment as independent review

This was rejected because it changes presentation, not control. Accounts under
one person's control share the same failure and recovery boundary.

### Upload artifacts manually with a personal token

This was rejected because it weakens provenance, reproducibility, permission
scoping, and auditability compared with a tag-triggered GitHub Actions workflow.

## Consequences

- A solo maintainer can publish a verified useful tool without fabricating a
  second reviewer.
- Each project must earn release authorization with project-specific evidence;
  source publication alone is insufficient.
- A deliberate tag push remains a high-impact, irreversible action because
  release tags and assets are immutable.
- The organization must upgrade publication to non-author approval when a real
  second owner becomes available.
