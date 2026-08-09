# Deprecation policy

Deprecation protects users from silent abandonment while avoiding promises the
maintainers cannot keep.

## Reasons

A project or public contract may be deprecated when it has no validated user
value, duplicates a better-maintained alternative, cannot be made safe or
correct within available capacity, has lost an accountable maintainer, or is
being replaced or merged.

## Required record

A deprecation decision records:

- The affected project, versions, interfaces, and user workflows.
- Evidence and rationale, including alternatives considered.
- The recommended replacement or an honest statement that none exists.
- Migration steps, compatibility risks, and data-export needs.
- What remains supported, what stops immediately, and the end condition.
- The accountable decision maker and a review event or date.

There is no universal fixed support window. Timing is chosen from real usage,
security risk, ecosystem constraints, migration complexity, and maintenance
capacity. A critical security or legal risk may require immediate withdrawal;
the public notice should still explain the safe facts.

## Communication

Announce deprecation in the project's README, changelog, release notes when a
release exists, and relevant issue or migration documentation. Update English
and Chinese guidance together. Never fabricate a final release only to carry a
notice.

Before archiving, preserve license and attribution, provide a final status and
replacement, disable misleading deployments or package links, and confirm that
secrets and private incident data are not in history. Archive settings or other
remote changes require explicit authorization; this policy does not authorize
them.

## Reversal

Reactivation requires current user evidence, an accountable maintainer, a
security and dependency review, restored checks, and a new lifecycle decision.
Prior stability or popularity is not sufficient evidence.
