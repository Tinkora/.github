# Release policy

## Remote release controls

| Setting | Current | Target | Apply when |
| --- | --- | --- | --- |
| Release automation | `cert_viewer`, `cron_maker`, `curl_builder`, `developer_primitives`, `diff_viz`, `dmg_background`, `encoding_toolbox`, `image_to_icns`, `jwt_inspector`, `mcp_doctor`, `qr_forge`, and `tool_call_trace` have project-specific, tag-triggered workflows; the organization reusable workflow remains read-only | Build and verify reproducibly, then publish from a protected tag with least privilege and project-owned verification | A project has stable hosted checks, immutable release inputs, a documented artifact contract, and explicit owner authorization |
| Versioning | Published releases are `tool_call_trace` at `v0.2.0`; `cert_viewer` and `jwt_inspector` at `v0.1.1`; `curl_builder` at `v0.1.0-alpha.1`; and `cron_maker`, `developer_primitives`, `diff_viz`, `dmg_background`, `encoding_toolbox`, `image_to_icns`, `mcp_doctor`, and `qr_forge` at `v0.1.0` | Use Semantic Versioning for public versions and document pre-`1.0.0` instability | A project declares a public contract and its first release is authorized |
| Changelog | This governance repository contains only an `Unreleased` section | Maintain Keep a Changelog categories and move entries to a dated version only during release | A reviewed release candidate is approved; do not create historical entries without release evidence |
| Git tags | Every published release above has a `vMAJOR.MINOR.PATCH` tag; repository rules protect current release tags from deletion or mutation | Use protected, immutable `vMAJOR.MINOR.PATCH` tags that point to the reviewed release commit | Tag protection is verified, the release commit and version agree, and tag creation is explicitly authorized |
| Artifacts | Release assets and verification material are project-specific; binary projects publish checksums, SBOMs, and attestations defined by their release contract | Publish platform artifacts with cryptographic checksums, an SBOM, and provenance appropriate to the build system | Artifact generation is reproducible, consumer verification instructions exist, and the release is approved |
| Release approval | The solo owner may authorize a release after reviewing the exact commit and hosted evidence; this is not independent approval | Require non-author approval for privileged publication | A second real, trusted owner is active and the protected release role or environment has been tested |

## Release requirements

A release candidate must have:

- A version consistent with [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
- A changelog based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
  with no fabricated history.
- Passing checks for every supported build target and documented limitations
  for targets that cannot be executed in the release environment.
- Reviewed licensing, dependency, security, privacy, and compatibility impact.
- Reproducible build inputs and an inventory of generated artifacts.
- Checksums, an SBOM, and provenance whose creation and verification commands
  are documented.
- Upgrade, downgrade, rollback, and deprecation notes when contracts change.

Tags and published assets are immutable. A broken release is superseded by a
new version; its tag or artifacts are not silently replaced. A compromised
artifact may be removed to protect users, but the incident and replacement
version must be documented without exposing sensitive investigation data.

## Solo-stage authorization

During the solo stage, the organization owner may authorize a project release
only when all requirements above are met and the exact release commit has
passed its required hosted checks. Authorization is the owner's deliberate push
of the protected release tag after verifying the commit SHA, version metadata,
tag rules, release Environment, and workflow permissions. A scheduled event,
ordinary branch push, or unattended dispatch must not publish a Release.

The workflow must keep repository contents read-only by default. Only the final
publication job may receive `contents: write`; provenance or SBOM jobs may
receive only the identity and attestation permissions they require. The release
Environment records the privilege boundary, but an Environment without a real
non-author reviewer is not an approval control. Local checks supplement hosted
evidence and never replace it.

This limited authorization does not satisfy the machine policy's
`releaseAutomation` gate. That gate covers organization-wide reusable or
unattended publication, which remains pending. After a second independent,
trusted owner is active, release publication must require non-author approval
and a tested recovery and revocation path. Releases have no fixed cadence;
evidence and maintenance capacity determine readiness.

The solo-stage decision and rejected alternatives are recorded in
[ADR-0002](decisions/0002-solo-release-authorization.md).
