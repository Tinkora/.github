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

- [Cron Maker](https://github.com/Tinkora/cron_maker) is a browser-local Unix
  cron builder, validator, explainer, and time-zone-aware execution preview.
  [Open the tool](https://tinkora.github.io/cron_maker/).
- [Cert Viewer](https://github.com/Tinkora/cert_viewer) inspects X.509 PEM and
  DER certificates locally, including extensions and fingerprints.
  [Open the tool](https://tinkora.github.io/cert_viewer/).
- [Curl Builder](https://github.com/Tinkora/curl_builder) builds HTTP requests
  locally and generates escaped cURL, Fetch, Python, Go, Rust, and Node.js
  snippets without executing the request.
  [Open the tool](https://tinkora.github.io/curl_builder/).
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
- [MCP Doctor](https://github.com/Tinkora/mcp_doctor) statically diagnoses local
  stdio MCP server configuration, paths, environment, and transport contracts.
  [View the release](https://github.com/Tinkora/mcp_doctor/releases/latest).
- [QR Forge](https://github.com/Tinkora/qr_forge) is a browser-local QR,
  Code 128, and EAN-13 generator with SVG and PNG exports.
  [Open the tool](https://tinkora.github.io/qr_forge/).

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
