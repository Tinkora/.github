# Changelog

All notable changes to this repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project intends to use [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
when releases begin.

## [Unreleased]

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

### Changed

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
- Aligned release governance with the published `image_to_icns v0.1.0` release
  and the still-unreleased QR Forge and Cron Maker repositories.
- Clarified that the pending organization interaction gate does not block a
  separately reviewed project's Issues or Discussions.

### Fixed

- Separated the Rust toolchain used to compile current CI utilities from the
  caller-selected project toolchain in coverage and WASM jobs.
- Allowed the standard `.gitignore` emitted by pinned `wasm-pack 0.15.0` in
  reusable WASM artifacts while retaining the unknown-file and special-node
  output guards.
