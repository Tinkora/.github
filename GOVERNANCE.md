# Governance

Tinkora uses evidence-based, maintainer-led governance while the organization
is small. This document distinguishes current controls from safeguards that
require independent people or proven operating capacity.

## Principles

- Real user workflows and reproducible evidence outweigh feature count.
- Public claims must match released, tested behavior.
- Security, privacy, accessibility, and maintenance cost are part of scope.
- Decisions and dissent are recorded in issues or pull requests once public
  channels exist; sensitive material stays out of public repositories.
- Repository rules never substitute for a trustworthy human maintainer.

## Roles

**Contributors** propose issues, changes, research, and reviews. They receive no
repository permission by default.

**Project maintainers** triage work, define project scope, review changes, and
keep support and lifecycle status accurate. Appointment requires demonstrated,
sustained contribution and explicit owner approval.

**Organization owners** control organization identity, access, repository
creation, security settings, and maintainer appointment. Owner access is not a
status reward; it is a recovery and security responsibility.

Current maintainership is recorded in [MAINTAINERS.md](MAINTAINERS.md). The
target permission model and its prerequisites are in
[docs/ACCESS_MODEL.md](docs/ACCESS_MODEL.md).

## Community interaction gate

| Setting | Current | Target | Apply when |
| --- | --- | --- | --- |
| Source publication | `.github` source is public on `main`; this does not claim that community interaction is open | Permit source-only publication with repository-specific documentation and security controls | The repository is explicitly registered in policy, its source and claims are verified, and Issues and Discussions remain off while the interaction gate is pending |
| Issues, pull requests, and Discussions | `.github` has Issues and Discussions off; external pull requests are technically possible but are not solicited | Open or solicit community interaction only with a working private conduct-reporting path | Channel ownership, least-privilege access, retention, handoff, and reporter flow are tested; moderators are assigned; activation is explicitly authorized |

The rationale and machine-policy boundary are recorded in
[ADR-0001](docs/decisions/0001-source-publication-boundary.md).

Private vulnerability reporting is a vulnerability channel, not a harassment
or Code of Conduct channel. Neither channel is currently claimed ready.

## Decisions

Routine project changes are decided by the responsible maintainer after review
of evidence and unresolved objections. Cross-project standards, public brand
claims, new repositories, releases, deprecation, and access changes require an
organization owner.

During the solo-owner stage, required approvals remain `0`, but changes still
go through pull requests, required checks, and resolved conversations once
those remote rules are authorized and configured. After a second independent,
trusted owner and appropriate maintainers are active, sensitive changes should
require non-author review. A second account controlled by the same person does
not satisfy this gate.

The solo owner may authorize a project release only through the evidence and
least-privilege controls in [the release policy](docs/RELEASE_POLICY.md). That
decision is accountable owner authorization, not independent approval. Once a
second independent, trusted owner is active, release publication must require
non-author approval. The rationale is recorded in
[ADR-0002](docs/decisions/0002-solo-release-authorization.md).

When consensus is unavailable, the decision maker records the chosen outcome,
evidence, alternatives, risks, and revisit condition. Security incidents may
temporarily restrict access or disclosure under
[docs/INCIDENT_RESPONSE.md](docs/INCIDENT_RESPONSE.md).

## Changes to governance

Governance changes use the same pull request and verification process as other
repository changes. They must update affected English and Chinese guidance,
the changelog when notable, and any conflicting operating policy.
