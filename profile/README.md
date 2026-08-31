# Tinkora

**Tools people use. Tools agents call.**

[中文说明](README.zh-CN.md)

<!-- markdownlint-disable MD033 -->
<p align="center">
  <a href="https://ko-fi.com/tinkora" target="_blank" rel="noopener noreferrer">
    <img
      src="https://ko-fi.com/img/githubbutton_sm.svg"
      alt="Support Tinkora on Ko-fi"
      width="520"
    >
  </a>
</p>
<!-- markdownlint-enable MD033 -->

Tinkora builds focused, open-source utilities for developers and AI agents.
Projects favor clear workflows, local processing where privacy matters, stable
machine-readable contracts, and behavior that can be verified in CI.

## Projects

- [Agent Worktree Doctor](https://github.com/Tinkora/agent_worktree_doctor)
  audits Git worktree topology, stale administrative metadata, and unsafe
  redirections without modifying the repository or executing hooks.
  [View the Alpha](https://github.com/Tinkora/agent_worktree_doctor/releases/latest).
- [Cron Maker](https://github.com/Tinkora/cron_maker) is a browser-local Unix
  cron builder, validator, explainer, and time-zone-aware execution preview.
  [Open the tool](https://tinkora.github.io/cron_maker/).
- [Cert Viewer](https://github.com/Tinkora/cert_viewer) inspects X.509 PEM and
  DER certificates locally, including extensions and fingerprints.
  [Open the tool](https://tinkora.github.io/cert_viewer/).
- [Color Atlas](https://github.com/Tinkora/color_atlas) converts colors,
  extracts image palettes, checks WCAG contrast, previews color-vision
  differences, and generates CSS without uploading source images.
  [Open the Alpha](https://tinkora.github.io/color_atlas/).
- [Curl Builder](https://github.com/Tinkora/curl_builder) builds HTTP requests
  locally and generates escaped cURL, Fetch, Python, Go, Rust, and Node.js
  snippets without executing the request.
  [Open the tool](https://tinkora.github.io/curl_builder/).
- [CSV Sculptor](https://github.com/Tinkora/csv_sculptor) inspects, filters,
  sorts, and converts CSV/TSV data locally in the browser.
  [Open the Alpha](https://tinkora.github.io/csv_sculptor/).
- [Data Toolbox](https://github.com/Tinkora/data_toolbox) reports CSV/TSV
  shape, delimiter ambiguity, jagged rows, and spreadsheet-formula risks
  without silently changing the input.
  [Open the Alpha](https://tinkora.github.io/data_toolbox/).
- [Developer Primitives](https://github.com/Tinkora/developer_primitives)
  generates and inspects UUID/ULID values, converts explicit timestamps across
  IANA time zones, and exposes DST gaps and folds through a browser-local
  workbench plus the cross-platform `tinkora-id` and `tinkora-time` CLIs.
  [Open the tool](https://tinkora.github.io/developer_primitives/) or
  [download v0.2.0](https://github.com/Tinkora/developer_primitives/releases/tag/v0.2.0).
- [DMG Background](https://github.com/Tinkora/dmg_background) is a
  browser-local editor for macOS DMG background images and Finder layout
  assets. [Open the tool](https://tinkora.github.io/dmg_background/).
- [Diff Viz](https://github.com/Tinkora/diff_viz) renders unified diffs and
  structured JSON comparisons locally with explicit input limits.
  [Open the tool](https://tinkora.github.io/diff_viz/).
- [JWT Inspector](https://github.com/Tinkora/jwt_inspector) separates local
  JWT decoding, expiry inspection, and HS256/RS256 signature checks.
  [Open the tool](https://tinkora.github.io/jwt_inspector/).
- [Encoding Toolbox](https://github.com/Tinkora/encoding_toolbox) provides
  local Base64, hexadecimal, digest, HMAC, and file-checksum workflows for
  developers and agents.
  [Open the tool](https://tinkora.github.io/encoding_toolbox/).
- [Eval Split Guard](https://github.com/Tinkora/eval_split_guard) detects exact
  content, sample ID, and group leakage across explicitly declared evaluation
  split pairs without uploading or echoing dataset content.
  [View the Alpha](https://github.com/Tinkora/eval_split_guard/releases/latest).
- [Favicon Kit](https://github.com/Tinkora/favicon_kit) turns one source image
  into a validated browser, Apple Touch, PWA, and Windows favicon package,
  entirely in the browser.
  [Open the tool](https://tinkora.github.io/favicon_kit/) or
  [download v0.1.0](https://github.com/Tinkora/favicon_kit/releases/tag/v0.1.0).
- [Tool Call Trace](https://github.com/Tinkora/tool_call_trace) is a
  browser-local waterfall viewer for timestamped AI agent tool calls.
  [Open the tool](https://tinkora.github.io/tool_call_trace/).
- [image_to_icns](https://github.com/Tinkora/image_to_icns) is a privacy-first
  macOS `.icns` generator with a browser editor and an MCP server.
  [Open the tool](https://tinkora.github.io/image_to_icns/).
- [JSON YAML Swiss](https://github.com/Tinkora/json_yaml_swiss) validates,
  formats, and deliberately converts JSON, YAML, and TOML while reporting
  lossy boundaries.
  [Open the Alpha](https://tinkora.github.io/json_yaml_swiss/).
- [MD Porter](https://github.com/Tinkora/md_porter) previews a bounded GFM
  subset, checks YAML frontmatter, and exports safe self-contained HTML in the
  browser. [Open the Alpha](https://tinkora.github.io/md_porter/).
- [MCP Doctor](https://github.com/Tinkora/mcp_doctor) statically diagnoses local
  stdio MCP configuration and performs bounded, offline linting of redacted MCP
  transcript envelopes, including JSON-RPC shape, initialization order, and
  stdout pollution.
  [View the release](https://github.com/Tinkora/mcp_doctor/releases/latest).
- [MCP Timeout Guard](https://github.com/Tinkora/mcp_timeout_guard) is a bounded
  stdio JSON-RPC proxy that enforces request deadlines without executing or
  rewriting the downstream MCP server.
  [View the Alpha](https://github.com/Tinkora/mcp_timeout_guard/releases/latest).
- [MCP Schema Compat](https://github.com/Tinkora/mcp_schema_compat) checks MCP tool
  schemas against provider compatibility profiles without network access.
  [View the Alpha](https://github.com/Tinkora/mcp_schema_compat/releases/latest).
- [Prompt Smith](https://github.com/Tinkora/prompt_smith) checks prompt templates
  for missing, unused, and malformed placeholders locally, with no model or network dependency.
  [View the Alpha](https://github.com/Tinkora/prompt_smith/releases/latest).
- [PE Version Info](https://github.com/Tinkora/pe_version_info) provides the
  cross-platform `pevi` CLI for inspecting and safely updating Windows PE
  `VERSIONINFO` resources and icons.
  [Download the Alpha](https://github.com/Tinkora/pe_version_info/releases/latest).
- [QR Forge](https://github.com/Tinkora/qr_forge) is a browser-local QR,
  Code 128, and EAN-13 generator with SVG and PNG exports.
  [Open the tool](https://tinkora.github.io/qr_forge/).
- [Recoverable Delete](https://github.com/Tinkora/recoverable_delete) adds a
  Codex pre-tool guardrail for destructive cleanup and routes supported deletes
  through the operating system trash workflow.
  [View the release](https://github.com/Tinkora/recoverable_delete/releases/latest).

A repository appears here only after its implementation, documentation,
security boundary, maintenance status, and public URL have been verified. A
tool schema or planning document alone is not treated as an Agent-callable
product.

## Participate

- Read the [contribution guide](../CONTRIBUTING.md).
- Review the [project lifecycle](../docs/PROJECT_LIFECYCLE.md).
- Follow the [security policy](../SECURITY.md) and report vulnerabilities
  privately through the affected repository's Security tab.

Issues and Discussions on this governance repository remain disabled while the
organization establishes sustainable moderation and private conduct-reporting
capacity.

## Support the work

If Tinkora saves you time, you can support the work on Ko-fi. Your tip mostly
keeps the AI token meter running for research, testing, documentation, and
maintenance.

Tips are optional and never affect access, support priority, or roadmap
decisions. Using the tools, reporting reproducible issues, and contributing
improvements are equally valued ways to help.
