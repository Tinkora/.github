# Label taxonomy

This is the intended cross-repository taxonomy. It does not claim that any
label already exists. Issue Forms deliberately assign no labels so form
submission cannot depend on missing repository configuration; maintainers add
labels during triage.

| Label | Color | Use |
| --- | --- | --- |
| `type:bug` | `D73A4A` | Reproducible behavior that differs from documented outcomes |
| `type:feature` | `A2EEEF` | Validated enhancement to an existing project |
| `type:documentation` | `0075CA` | Missing, inaccurate, or unclear documentation |
| `type:project-proposal` | `5319E7` | Evidence-backed proposal for a new project |
| `status:needs-triage` | `FBCA04` | Maintainer has not yet confirmed scope or disposition |
| `status:needs-info` | `D4C5F9` | Reporter must provide specific missing evidence |
| `status:blocked` | `B60205` | Progress depends on a named prerequisite |
| `status:ready` | `0E8A16` | Scope and prerequisites are ready for implementation |
| `priority:p0` | `B60205` | Confirmed critical impact requiring immediate coordination |
| `priority:p1` | `D93F0B` | High impact on important workflows |
| `priority:p2` | `FBCA04` | Normal planned work |
| `priority:p3` | `0E8A16` | Low impact or opportunistic improvement |
| `area:security` | `B60205` | Public, sanitized security hardening work only |
| `area:ui` | `1D76DB` | User interface and accessibility |
| `area:agent` | `7057FF` | Agent contracts, transport, discovery, or integration |
| `area:release` | `006B75` | Versioning, packaging, provenance, or distribution |
| `good first issue` | `7057FF` | Small, understood work with maintainer guidance |
| `help wanted` | `008672` | Maintainer has confirmed scope and welcomes assistance |

## Application rules

- Apply one primary `type:*` label after triage; add only relevant area and
  status labels.
- Priority describes validated impact, not reporter urgency.
- `area:security` must never be used to solicit vulnerability details in a
  public issue. Suspected vulnerabilities follow `SECURITY.md`.
- `good first issue` requires clear acceptance criteria, known files or
  components, and an available reviewer.
- Create the same labels and exact colors in the `.github` repository and each
  repository expected to inherit the taxonomy before depending on them.

## Remote label configuration

| Setting | Current | Target | Apply when |
| --- | --- | --- | --- |
| Organization default labels | No shared label set is claimed as configured | Use this taxonomy consistently in participating repositories | Each target repository is inventoried, label conflicts are reviewed, and creation is explicitly authorized |
| Issue Form labels | Forms assign none | Keep forms independent of remote labels; triage adds labels | Change only after every inheriting repository has verified matching labels and the template update is explicitly authorized |
