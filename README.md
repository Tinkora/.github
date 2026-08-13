# Tinkora community health repository

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

This special repository maintains Tinkora's public organization profile,
default community health files, reusable GitHub Actions workflows, and
governance policies.

## What this repository provides

- The organization profile in [`profile/`](profile/README.md).
- Default contribution, conduct, security, and support guidance for public
  repositories that do not define their own files.
- A default Ko-fi funding link for repositories that do not define their own
  sponsorship options.
- Issue Forms and a pull request template for repositories that inherit them.
- Maintainer, access, release, security, lifecycle, and translation policies.
- Architecture decisions, including the
  [source publication boundary](docs/decisions/0001-source-publication-boundary.md).
- Evidence-gated product intake, including the current
  [Agent workflow pain-point review](docs/agent-workflow-pain-points-2026-08.md).
- Reviewed reusable workflows for Rust, WebAssembly, supply-chain checks,
  GitHub Pages, and release-candidate validation.
- A permanently read-only
  [GitHub settings audit](docs/SETTINGS_AUDIT.md) for checking documented
  organization and repository controls.

## Repository inheritance

GitHub can inherit supported community health files from a public special
`.github` repository. A file in a project repository takes precedence over the
organization default. Licenses are never inherited: every project must include
and verify its own `LICENSE` file.

## Projects

Only repositories that have passed source, documentation, CI, security, and
maintenance review are listed on the organization profile. Planning documents
and local prototypes are not public product commitments.

## Contributing and security

Read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing a change. Follow
[SECURITY.md](SECURITY.md) for private vulnerability reporting, and never
disclose suspected vulnerabilities in public issues, pull requests, or
Discussions.

## License

Repository-authored content is available under the [MIT License](LICENSE).
Third-party documents retain any attribution stated in their files.
