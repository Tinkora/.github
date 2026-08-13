# ADR-0001: Separate source publication from public community interaction

## Status

Accepted

## Date

2026-08-09

## Context

Publishing source code lets people inspect, download, and evaluate a project.
It does not require the organization to open a moderated community channel.
Issues, Discussions, active contribution solicitation, and Code of Conduct
enforcement create a different operational obligation: maintainers need a
private conduct-reporting path, assigned moderators, retention rules, and a
tested handoff process.

Private vulnerability reporting covers security vulnerabilities only. It is
not a substitute for a private conduct-reporting channel.

A single repository-wide target set also cannot describe a portfolio. A
community-health repository and a product repository can legitimately have
different topics, interaction settings, publication state, and release count.

## Decision

The settings policy uses two independent gates:

- `sourcePublication` authorizes public source when repository-specific
  documentation and security controls are accurate.
- `publicInteraction` authorizes moderated public interaction only after its
  operational prerequisites are verified.

Source may be public while `publicInteraction` remains `pending`. During that
state, organization defaults and the governance repository stay closed, while
an explicitly registered product repository may enable Issues and Discussions
after its own support, security, and moderation links are present. Reading,
downloading, forking, or independently evaluating public source does not by
itself open a Tinkora-managed interaction channel.

`repositoryScope.defaults` contains shared controls.
`repositoryScope.repositories` is an explicit map of managed public
repositories and their partial overrides. Every entry must declare its own
`sourcePublished`, `topics`, `issues`, and `releases` targets. Any public
repository discovered by an audit but absent from that map is reported as
`UNMANAGED/FAIL`.

## Alternatives considered

### Block all public source until the conduct channel exists

This would avoid distinguishing publication from interaction, but it would
prevent read-only inspection even though no moderated channel is involved.
The restriction is broader than the operational risk requires.

### Treat every public repository as having identical settings

This is simpler to serialize but produces false failures and encourages
generic topics and interaction settings that do not describe the repository.

### Automatically accept newly discovered public repositories

This avoids audit failures but silently expands governance scope. Explicit
registration is safer and makes ownership and intended settings reviewable.

## Consequences

- Source-only publication can proceed without claiming community support is
  open.
- Opening Issues, Discussions, or active contribution solicitation remains a
  separate, explicit policy change.
- Each new public repository must be registered with reviewed overrides before
  its audit can pass.
- Operators must update the policy when a repository's interaction or release
  state changes; defaults alone are intentionally insufficient for those
  repository-specific fields.
