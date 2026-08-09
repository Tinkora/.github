# Project lifecycle

Lifecycle labels describe evidence, not aspiration. Moving forward requires
the stated gate; moving backward is acceptable when evidence changes.

| Stage | Meaning | Exit gate |
| --- | --- | --- |
| Idea | A real workflow is being researched; no product repository is justified | Proposal identifies users, evidence, at least three alternatives, differentiation, success measures, stop conditions, and an accountable maintainer |
| Draft | Code or design exists, but build, test, documentation, repository, or maintenance gates remain incomplete | Supported paths run, critical tests pass, claims match behavior, and a usable demonstration exists |
| Alpha | A usable demonstration has baseline CI and bilingual documentation; contracts may change | Security and privacy boundaries, compatibility tests, release procedure, and feedback evidence are established |
| Beta | Required checks and a versioned prerelease exist; known limitations are explicit | Real users validate the workflow, contracts stabilize, and maintenance capacity is demonstrated |
| Stable | A supported contract, real-user evidence, release history, and accountable maintenance exist | Continue meeting support and governance requirements; stability is reviewed rather than permanent |
| Deprecated | New adoption is discouraged and a replacement or reason is documented | Announced migration obligations are complete or continuing support is no longer safe or feasible |
| Archived | Active maintenance has ended and repository state is read-only or clearly inactive | Reopen only with new evidence, an accountable maintainer, and a fresh lifecycle review |

## Current portfolio baseline

The organization profile lists only repositories whose public location and
current lifecycle evidence have been verified. Local prototypes, schemas, and
planning notes do not create public projects or stability commitments.

## Starting a project

A proposal uses the project-proposal Issue Form and must show:

- A repeated, real user workflow and evidence of its cost.
- At least three credible alternatives, including established tools or doing
  nothing.
- A narrow difference worth maintaining instead of contributing upstream.
- The smallest validation scope, measurable success criteria, and stop
  conditions.
- A real person accountable for maintenance, security, and deprecation.

Proposal acceptance does not authorize a GitHub repository, domain, deployment,
release, funding link, or public product claim. Each remote action requires its
own review and explicit authorization.

## Frontend evidence gate

Every project template and new project must copy the `Frontend Design
Requirement` from this repository's `AGENTS.md` before frontend work begins.
Creating, modifying, reviewing, or debugging HTML or another user-visible
frontend requires the `ui-ux-pro-max` skill. Run its `--design-system` search
first, then the relevant stack and UX searches before making design decisions.

The review record must include real-browser evidence at 375, 768, 1024, and
1440 pixel widths. At each relevant width, verify console output, keyboard
operation, accessibility, and horizontal overflow. A template or project must
not mark its frontend checklist complete when the skill was unavailable or any
of these checks was skipped.

## Lifecycle review

The accountable maintainer reviews stage claims before a public release, after
a significant incident, when support capacity changes, and when evidence shows
that users prefer another solution. The review records actual commands,
released artifacts, user evidence, known limitations, and a continue, merge,
pause, deprecate, or archive decision.

Agent-callability is a separate verified capability: it requires a runnable
transport, discovery and invocation behavior, installation instructions, and
integration tests. A schema or skill document alone is a draft contract.

Deprecation follows [DEPRECATION_POLICY.md](DEPRECATION_POLICY.md), and releases
follow [RELEASE_POLICY.md](RELEASE_POLICY.md).
