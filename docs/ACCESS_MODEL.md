# Access model

This policy separates observed access from intended controls. Its baseline is
2026-08-11. Nothing in the `Target` column states that a GitHub setting is
already enabled.

The [permanently read-only settings audit](SETTINGS_AUDIT.md) reports visible
counts and settings without retaining member identities. Future-gate warnings
must not be converted into current failures merely because they appear in a
`Target` column.

## Organization access

| Setting | Current | Target | Apply when |
| --- | --- | --- | --- |
| Owners | One owner and one total member; a single point of recovery and administration | At least two independent, long-term trusted owners before high-impact governance | A real person accepts continuity duties, uses secure 2FA, verifies access, and the change receives explicit authorization; another account controlled by the current owner does not qualify |
| Mandatory 2FA | Organization enforcement is off | Require secure 2FA for all organization members and outside collaborators | A second trusted owner is active, every affected person has been checked and notified, recovery is tested, and enforcement is explicitly authorized |
| Base permission | `read` | `none`, with repository access granted explicitly by role | Before a second member joins, after repository access has been audited, and with explicit authorization |
| Repository creation | Non-owner members cannot create public or private repositories; the API reports repository creation type `none` | Keep repository creation limited to owners or an explicitly delegated trusted role under the documented project checklist | Re-evaluate only when a real maintainer role requires delegated creation |
| Deletion and visibility | Only owners may delete, transfer, or change repository visibility | Keep deletion, transfer, and visibility changes limited to owners | Re-evaluate only after a multi-owner recovery path and explicit authorization exist |
| Teams | Closed `maintainers` and `security` Teams exist; both currently contain only `tinkeragora`; `security` is the organization security manager; non-owner members cannot create Teams | Keep repository grants narrow and add only real contributors who need the role | Membership, actual Team slug, repository permission and review date are verified; Team creation does not satisfy the independent-owner gate |
| Outside collaborators | There are no outside collaborators; GitHub still permits repository administrators to send invitations | Owners or an explicitly delegated trusted maintainer approve repository-specific access | A real collaboration requires access and the approver, scope, and review date are recorded; tighten the organization switch when GitHub exposes a supported control |

## Repository access and merge controls

| Setting | Current | Target | Apply when |
| --- | --- | --- | --- |
| Special `.github` repository | The public profile and community health files are published on `main`; Issues and Discussions remain disabled | Keep the governance repository read-only while product repositories provide scoped intake | Remote checks pass and publication claims remain limited to verified evidence |
| Pull request requirement | Solo-owner maintenance happens directly on `main`; no remote rule requires a pull request | External changes use pull requests; require maintainer PRs only after independent review exists | Required checks are stable, an emergency recovery path is documented, and the rule is explicitly authorized |
| Required approvals | No remote rule exists | Solo stage: `0`; multi-maintainer stage: at least one non-author approval | Keep `0` while one owner would otherwise self-lock; increase only after a second trusted owner and a real reviewer can independently approve |
| Required checks | No remote rule exists | Require the repository's verified formatting, test, build, documentation, and security checks | Each named check has run reliably on default-branch and pull-request events and rule activation is explicitly authorized |
| Conversation resolution | No remote rule exists | Require all review conversations to be resolved | Pull request protection is enabled and maintainers have verified the merge workflow |
| Direct push, force push, and deletion | The sole owner may push normal commits directly to `main`; force pushes and deletion are not routine operations | Block force pushes and deletion; move maintainer changes to required pull requests when independent review exists | Pull request checks and owner recovery have been tested and the rule is explicitly authorized |
| CODEOWNERS | Product repositories use either their maintainer team or the current owner; the teams currently contain only the sole owner | Protect sensitive paths with review from a real, populated maintainer role | At least two appropriate reviewers exist, Team permissions and slugs are verified, and CODEOWNER review is explicitly authorized |
| Administration bypass | Only the current owner could recover from a bad initial rule | Limit bypass to documented emergencies and record the reason | Rules are tested, at least two trusted owners can recover access, and the narrowed bypass is explicitly authorized |

## Release access

| Setting | Current | Target | Apply when |
| --- | --- | --- | --- |
| Release publishers | Only the organization owner may deliberately create a protected project release tag; no organization-wide or unattended publisher is authorized | Separate build verification from least-privilege release publication | A project reaches its documented release gate, the exact commit and hosted evidence are reviewed, and tag creation is separately authorized |
| High-privilege automation | `cert_viewer`, `color_atlas`, `cron_maker`, `curl_builder`, `developer_primitives`, `diff_viz`, `dmg_background`, `encoding_toolbox`, `favicon_kit`, `image_to_icns`, `json_yaml_swiss`, `jwt_inspector`, `mcp_doctor`, `md_porter`, `pe_version_info`, `qr_forge`, and `tool_call_trace` limit `contents: write` to their final tag-triggered publication jobs; their release Environments have no independent reviewer on GitHub Free | Require a protected Environment or appropriately scoped GitHub App with non-author approval | A second trusted owner is active, credentials and recovery are tested, and the exact automation is explicitly authorized |

During the solo stage, a deliberate protected-tag push is an accountable owner
authorization, not independent review. It is permitted only under
[the release policy](RELEASE_POLICY.md). The machine policy's pending
`releaseAutomation` gate continues to cover organization-wide reusable or
unattended publication rather than this narrowly scoped project workflow.

## Reviews

Access is reviewed when a person's responsibilities change, after a security
event, before enabling a new privileged automation, and on a regular cadence
once the organization has more than one maintainer. Public documentation may
record roles and decisions, but must not contain recovery codes, tokens,
private contact details, raw Audit Log data, or member IP addresses.
