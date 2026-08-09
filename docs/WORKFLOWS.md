# Reusable workflows

These workflows centralize fixed quality gates without transferring trust from
the caller. A caller must pin the reusable workflow to a reviewed 40-character
commit SHA, grant every permission needed by the called job, and never use
`secrets: inherit`. The called workflow cannot elevate a caller token.
The organization also enforces full commit SHA pinning at the Actions policy
boundary, so an unpinned Action or reusable workflow is rejected remotely.

Local syntax and contract coverage exists, but remote reusable-workflow, fork,
Pages, Environment, release, and attestation canaries must still be run before
a project treats these workflows as production release infrastructure.

## Version and permission rules

Use a full workflow-bundle commit, never `main`, a floating major tag, or a
short SHA:

```yaml
jobs:
  quality:
    uses: tinkora/.github/.github/workflows/reusable-rust-quality.yml@<WORKFLOW_BUNDLE_SHA>
    permissions:
      contents: read
```

The top-level default in every supplied workflow is `contents: read`. Write
permissions occur only in the Pages deployment job. The current Release
workflow has no publication job or write permission. A caller must repeat any
required job permissions because GitHub intersects caller and called-workflow
permissions.

All external Actions were independently checked against GitHub's latest stable
release API and tag object on 2026-08-08. Annotated tags were dereferenced to
their commit. Every `uses:` line keeps both the full commit and exact tag
comment so update review can detect drift.

## Rust quality

`reusable-rust-quality.yml` accepts only these typed inputs:

| Input | Type | Default | Contract |
| --- | --- | --- | --- |
| `working-directory` | string | `.` | Existing relative non-symlink directory inside the workspace |
| `toolchain` | string | `stable` | Stable channel, beta/nightly, dated nightly, or Rust version |
| `features` | string | empty | Restricted comma-separated feature expression; empty omits `--features` |
| `target` | string | empty | Restricted optional target passed as one argument |
| `locked` | boolean | `true` | Adds `--locked` when true and omits it when false |
| `msrv` | string | empty | Exact `1.x.y`; runs a separate `cargo check` job |
| `coverage` | boolean | `false` | Uses fixed `cargo-llvm-cov 0.8.7` and uploads LCOV for seven days |

The primary job always runs `cargo fmt --all -- --check`, Clippy for all targets
with warnings denied, and tests for all targets. Inputs cannot replace these
commands. The caller remains responsible for selecting an actually supported
cross target; cross-compilation is not evidence that target-system tests ran.
The primary, MSRV, and coverage jobs resolve the working directory with
`realpath` and reject paths outside the workspace, including intermediate
symlink escapes.

## WASM quality

`reusable-wasm-quality.yml` fixes the Rust target to
`wasm32-unknown-unknown`, installs `wasm-pack 0.15.0` with Cargo's `--version`
and `--locked` controls, exports the selected `RUSTUP_TOOLCHAIN` for
wasm-pack's internal Cargo calls, and builds a web package. It rejects
symlinks, FIFO, socket, device, and other special nodes plus any file outside
the generated package whitelist before retaining the package for seven days.

The optional `playwright-smoke` boolean does not accept a command. It requires
the caller directory to contain `package.json`, `package-lock.json`, a local
Playwright dependency, and an npm script named exactly `test:wasm-smoke`. The
job runs `npm ci --ignore-scripts`, installs the real Chromium browser with the
local Playwright CLI, exposes the downloaded package through
`WASM_SMOKE_PACKAGE`, and invokes only that fixed script. A repository should
commit its Playwright configuration and assert a user-visible WASM behavior,
not merely that a file exists. The smoke job applies the same canonical
workspace boundary and special-node rejection to its inputs.

## Supply-chain audit

`reusable-supply-chain.yml` requires `Cargo.toml`, `Cargo.lock`, and a reviewed
`deny.toml`. It fixes `cargo-deny` to `0.20.2` and `cargo-audit` to `0.22.2`.
Independent steps check deny policy and the RustSec advisory database; either
command fails the job on a reported violation. The selected installation
toolchain must meet `cargo-audit 0.22.2`'s Rust 1.88 minimum. A separate fixed
`zizmor 1.29.0` scan audits caller workflows without online lookups or
`security-events: write`.

CodeQL and OpenSSF Scorecard are deliberately not hidden inside this general
reusable workflow. CodeQL must match each repository's languages, build mode,
query ownership, and GitHub plan. SARIF upload should be limited to trusted
events; a fork pull request must not receive unconditional
`security-events: write`. Scorecard is most useful after a public remote,
branch protection, token policy, and publication identity exist. Each project
should add those tools explicitly when its repository-specific trust boundary
and finding owner are ready.

## Pages deployment

`reusable-pages.yml` accepts only `source-artifact-name` and an optional safe
`source-subdirectory`. A fresh runner downloads the named caller artifact into
a fixed temporary directory. Empty, absolute, traversal, escaping, symlink,
special-file, and empty-tree cases fail before conversion to the standard
`github-pages` artifact.

The deployment job never runs for `pull_request`. On trusted events, the caller
job and called deployment job both need:

```yaml
permissions:
  pages: write
  id-token: write
```

The `github-pages` Environment should enforce the intended branch protection.
No deployment secret is accepted.

## Release candidate dry-run

`reusable-release.yml` accepts a named source artifact, a full SemVer version
without the `v` prefix, and compatibility boolean `publish` which defaults to
`false`. This workflow version is permanently dry-run: `publish: true` fails
immediately in its only read-only job. It requires a
`vMAJOR.MINOR.PATCH`-style tag matching the complete SemVer input, resolves
that tag to `github.sha`, and then checks a top-level
`release-metadata.json` with exactly this shape:

```json
{
  "commit": "40-character caller commit SHA",
  "version": "1.2.3"
}
```

Source assets must be top-level regular files with safe names. The dry-run job
produces `SHA256SUMS`, a file-level SPDX 2.3 `SBOM.spdx.json`, and
`LICENSES.json` containing the caller's top-level license evidence, then uploads
the complete candidate for seven days. `release-metadata.json` remains only a
control input: it is not copied into the candidate, checksums, SPDX File list,
package verification code, dry-run subjects, or any future release asset.
Every actual release asset has SHA-1 and SHA-256 checksums plus explicit
no-assertion license and copyright fields. The package verification code and
document/package/file relationships follow the official SPDX 2.3 model. A
`release-subjects` directory derived from that File list proves subject
selection without requesting an attestation. The vendored official schema,
source commit, digest, and fixed validation command are recorded in
[`schemas/README.md`](../schemas/README.md). This Actions artifact is review
input, not a GitHub Release.

This reusable workflow remains permanently dry-run. A future reusable
publication version requires a separate design decision, explicit authorization,
and remote Environment, Release, attestation, and recovery canaries. A project
may instead own a narrowly scoped tag-triggered publisher during the solo stage
when it satisfies `docs/RELEASE_POLICY.md`; that owner authorization must not be
described as independent review. After a second independent owner is active,
the publication Environment must require non-author approval. The current
reusable workflow deliberately contains no variable override, attestation,
GitHub Release command, publication Environment, or write-permission job.

## Documentation and governance

`docs-quality.yml` runs Markdown lint and fail-closed local checks for UTF-8
without BOM, required files, bilingual pairs, governance table fields, and
repository-contained links. High-variance external HTTPS checks run only for a
trusted default-branch push, schedule, or manual dispatch, never for a pull
request.

`governance-audit.yml` installs the package-lock-pinned SPDX validator with
Node.js `24.11.1`, explicitly prepares Rust `1.88.0` for the runtime fixture,
and runs the complete `scripts/check_all.sh` suite. It retains independent fixed
`actionlint 1.7.12` and zizmor scans. Zizmor annotations do not require SARIF
upload or `security-events: write`.

## Workflow templates and dependency updates

No organization workflow-template catalog is currently published. Project
repositories may call these reusable workflows only with a reviewed,
reachable 40-character commit SHA.

Dependabot only scans `.github/workflows` for the `github-actions` ecosystem;
it does not update reusable references copied into project repositories. Each
project repository still needs its own `.github/dependabot.yml`
for its local workflows and package ecosystems; the special organization
`.github` repository configuration is not inherited.

The `github-actions` entry uses `cooldown.default-days: 7` to delay routine
version updates long enough for early upstream regressions to surface. GitHub
documents that cooldown applies only to version updates, not security updates,
so a security update is not delayed by this window. See the official
[Dependabot options reference](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference#cooldown-).

Run the repository-owned checks locally with:

```console
npm ci --ignore-scripts --prefix scripts/spdx-validator
scripts/check_all.sh
```

The final verification also needs fixed actionlint, zizmor, markdownlint,
ShellCheck, YAML and JSON parsing, UTF-8/BOM and secret scans, and
`git diff --check`. Local success does not replace remote canaries for reusable
workflow resolution, fork token behavior, Pages deployment, or release
candidate artifact generation. Any future publication workflow also needs new
protected Environment, GitHub Release, and artifact attestation canaries.
