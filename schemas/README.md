# Vendored schemas

`spdx-2.3.schema.json` is the unmodified official SPDX 2.3 JSON schema from
[`spdx/spdx-spec@v2.3`](https://github.com/spdx/spdx-spec/blob/v2.3/schemas/spdx-schema.json).
The annotated tag resolves to commit
`aadf3b0b8dbbabdb4d880b0fc714255fea436ff7`, whose schema Git blob is
`ee61e6686e885f8139c132647fd0b4f483b8fb81`. The upstream 45,312-byte file
has SHA-256 `239208b7ac287b3cf5d9a9af23f9d69863971102a5e1587a27a398b43490b89b`.
This repository adds the standard terminal LF required for text files; the
45,313-byte vendored file SHA-256 is
`3ec6cd5b8ba0c9a3e821da48536fa1b814567dc7e4376efe98d3e7b2a7a8d230`.

`scripts/test_spdx_sbom.rb` verifies that digest, proves the schema rejects a
File element without required checksums, generates a release-assets SBOM using
the real workflow step, and validates it with `ajv-cli 5.0.0` from
`scripts/spdx-validator/package-lock.json` in draft-07 mode. Install it with
`npm ci --ignore-scripts --prefix scripts/spdx-validator`; validation uses
`npx --no-install` and never resolves a floating package at test time. The
package manifest overrides `ajv-cli`'s vulnerable `fast-json-patch` 2.x
dependency with patched version `3.1.1`; the repository contracts exercise the
actual validation path after that override.

`github-settings-policy.schema.json` defines the machine-readable stage,
gates, organization, public-repository targets, and manual attestations used
by the permanently read-only settings auditor. It enforces exact target fields,
target-specific value enums, explicit bindings for every future gate, and the
independent-owner prerequisite for the `multi-maintainer` stage. Manual
attestations use an ID-keyed object map with strict values, so the Ruby policy
model and draft-07 Schema share the same uniqueness semantics.

`github-settings-audit.schema.json` defines its redacted output. It permits
only effective `APPLICABLE`, `GATED`, or `NOT_APPLICABLE` states, fixed
status/capability enums, booleans, counts, validated public metadata, and
normalized endpoint evidence sourced from the same endpoint registry as the
transport allowlist. Repository patterns reject `.` and `..` path segments in
both policy input and emitted resources. `scripts/check_github_settings_audit.rb`
validates the production policy and a complete offline fixture output with the
same fixed `ajv-cli` installation.
