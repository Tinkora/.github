# Changelog

All notable changes to this repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project intends to use [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
when releases begin.

## [Unreleased]

- Registered the evidence-backed `agent_context_doctor` repository, its first
  alpha release, and its cross-host static context diagnostics in the profile,
  settings policy, audit contracts, and release policy.

### Added

- Initial local Tinkora organization profile, community health files, and
  governance policies.
- Public Issue Form for non-sensitive usage and integration questions.
- Reusable Rust, WASM, supply-chain, Pages, and gated release workflows with
  local security and schema contracts.
- Documentation quality and governance audit workflows with bilingual,
  required-file, local-link, and workflow pin checks.
- Dependabot configuration for Actions under this repository's
  `.github/workflows` directory.
- Official-schema validation for release SPDX SBOMs and fixed RustSec auditing.
- A permanently read-only GitHub settings audit with stage-aware policy,
  offline adversarial fixtures, redacted versioned output, and governance CI
  contracts.
- An ADR separating source-only publication from moderated public interaction.
- An ADR authorizing evidence-gated project releases during solo maintenance
  without misrepresenting owner authorization as independent approval.
- The verified Cron Maker repository, browser-local Unix cron workbench,
  bundled IANA time-zone preview, public Pages application, and settings policy
  registration.
- The verified Tool Call Trace repository, browser preview, and settings policy
  registration on the public organization profile.
- The verified DMG Background repository, browser tool, schema endpoint, and
  settings policy registration on the public organization profile.
- The verified QR Forge repository, browser-local generator, public Pages
  application, community channels, and settings policy registration.
- The verified Cert Viewer and JWT Inspector repositories, browser tools,
  versioned releases, and explicit project interaction policy overrides.
- The verified MCP Doctor repository, cross-platform CLI release, and settings
  policy registration on the public organization profile.
- The verified Diff Viz repository, browser-local application, Pages site,
  supply-chain release, and settings policy registration.
- The verified Curl Builder prerelease and Encoding Toolbox release, including
  browser applications, supply-chain evidence, and settings policy registration.
- The verified Developer Primitives `v0.1.0` release, browser-local UUID/ULID
  workbench, cross-platform CLI, and settings policy registration.
- The verified Favicon Kit `v0.1.0` release, browser-local asset generator,
  public Pages application, and settings policy registration.
- The first DMG Background and Tool Call Trace supply-chain releases with
  checksums, SPDX SBOMs, license inventories, and artifact attestations.
- A bilingual evidence review of recurring Agent workflow failures and bounded
  product intake for MCP diagnostics, trace redaction, and context budgets.
- An organization-wide Ko-fi funding link with bilingual guidance that keeps
  financial support optional and independent from access, support priority,
  and roadmap decisions.

### Changed

- Registered Agent Worktree Doctor `v0.1.0-alpha.3` and Eval Split Guard
  `v0.1.0-alpha.4` in the bilingual organization profile, release policy, and
  settings audit after their immutable releases and supply-chain evidence were
  verified, including the removal of runner-local SBOM references.
- Synchronized MCP Doctor `v0.1.17`, including bounded offline transcript
  linting and a verified immutable release with four platform archives,
  per-asset checksums, aggregate `SHA256SUMS`, a CycloneDX SBOM, provenance,
  and SBOM attestations.
- Synchronized PE Version Info `v0.1.0-alpha.2` publication governance and
  recorded MCP Doctor's evidence-backed JSONC compatibility increment without
  relaxing the static no-execution boundary.
- Registered the verified Color Atlas and MD Porter Alpha releases in the
  bilingual organization profile, settings policy, and release governance.
- Documented dependency-update review gates: Dependabot is proposal-only,
  patch/minor groups use full checks, and coupled Rust major upgrades require a
  coordinated migration with dependency-graph and compatibility evidence.
- Registered Data Toolbox and JSON YAML Swiss in the public settings policy,
  synchronized PE Version Info's `v0.1.0-alpha.1` release, and enabled the
  missing JSON YAML Swiss secret-scanning controls.
- Synchronized the settings policy and release policy with CSV Sculptor's
  verified `v0.1.0-alpha.1` release and protected `main` branch.
- Synchronized Developer Primitives `v0.2.0`, including its browser-local IANA
  time-zone module, dual CLI archives, release evidence, and discovery topics.
- Synchronized governance evidence with Tool Call Trace `v0.2.0` and its
  second published release.
- Synchronized MCP Doctor `v0.1.13`, including its Node.js runtime diagnostic,
  release assets, SBOM, provenance, and attestation evidence.
- Made settings-audit gates control effective applicability, split Actions
  parent and selected fields into independent checks, and tightened ambiguous
  API and policy-schema decisions.
- Unified manual-attestation policy validation around an ID-keyed object map
  shared by Ruby and JSON Schema.
- Hardened the settings-audit transport with a trusted `gh` executable,
  fixed-host environment isolation, bounded child processes and pagination,
  dot-segment rejection, gate-aware failures, and registry-owned evidence IDs.
- Added a seven-day Dependabot cooldown for routine GitHub Actions version
  updates without delaying security updates.
- Made the current Release workflow permanently read-only, excluded control
  metadata from all release evidence and subjects, and fixed all workspace and
  special-node boundaries in Rust and WASM jobs.
- Made governance CI run every repository contract with package-lock-pinned
  SPDX validation and an explicitly prepared Rust toolchain.
- Overrode `ajv-cli`'s vulnerable `fast-json-patch` dependency with patched
  version `3.1.1` and retained real draft-07 validation coverage.
- Limited external-link checks to visible Markdown so code examples and
  placeholder URLs are not treated as live destinations.
- Made a separate controlled private conduct-reporting channel a prerequisite
  for opening community interaction or enforcing the Code of Conduct.
- Replaced shared repository targets with reviewed defaults and explicit
  per-repository overrides; unregistered public repositories now fail audit.
- Added an auditable `ui-ux-pro-max` gate to every project and template's
  frontend startup checklist.
- Clarified that project-owned, protected-tag publication may use a final
  least-privilege write job while organization-wide or unattended release
  automation remains gated.
- Aligned release governance with the current Cert Viewer, Cron Maker,
  image_to_icns, JWT Inspector, MCP Doctor, and QR Forge releases, including
  JWT Inspector's project-owned supply-chain workflow.
- Restricted non-owner repository creation, deletion, transfer, visibility
  changes, and Team creation in the live organization settings.
- Enabled dependency graph, Dependabot alerts and security updates, secret
  scanning, and push protection by default for newly created repositories.
- Clarified that the pending organization interaction gate does not block a
  separately reviewed project's Issues or Discussions.

### Fixed

- Separated the Rust toolchain used to compile current CI utilities from the
  caller-selected project toolchain in coverage and WASM jobs.
- Allowed the standard `.gitignore` emitted by pinned `wasm-pack 0.15.0` in
  reusable WASM artifacts while retaining the unknown-file and special-node
  output guards.
