# Contributing to Tinkora

[中文说明](CONTRIBUTING.zh-CN.md)

Thank you for helping make Tinkora's utilities more reliable and useful.

Public interaction is not currently open. Issues and Discussions remain
disabled, and external contributions are not actively solicited until the
private conduct-reporting and moderation prerequisites are verified. This file
documents the process that will apply when a repository explicitly opens those
channels.

## Before opening an issue

1. Search existing issues and confirm the behavior against the latest code.
2. Remove credentials, personal data, proprietary content, and other sensitive
   material from examples.
3. Choose the structured form that matches the request. Project proposals must
   include a real user workflow, alternatives, differentiation, success
   measures, a stop condition, and a proposed maintainer.
4. Do not use a public issue for a suspected vulnerability. Follow
   [SECURITY.md](SECURITY.md).

Organization Discussions and a public Project are not configured yet. Do not
link to or depend on those channels until their availability is verified.

## Language

English is the default language for GitHub-recognized entry points and public
technical documentation. Maintained Chinese peers use the `.zh-CN.md` suffix
and link back to the English default near the top. Update both peers whenever
user-visible requirements, limitations, commands, or security guidance change.

Code comments must be written in English. Preserve identifiers, API names,
filenames, commands, protocols, and quoted error messages in their original
spelling.

Write commit subjects and bodies in English and follow
[Conventional Commits](https://www.conventionalcommits.org/). Repository-level
rules take precedence if they define a stricter format.

## Pull requests

Keep each pull request focused on one coherent outcome. Link the relevant
issue, state the scope and non-goals, and record exact verification commands.
Update English and Chinese documentation together when user-facing meaning
changes, and update [CHANGELOG.md](CHANGELOG.md) for notable changes.

External changes use pull requests and must pass the repository's checks.
During the solo-maintainer stage, the owner develops directly on `main` and no
required approval is configured, avoiding a rule that the only owner cannot
satisfy. This does not waive local review or verification. Multi-maintainer
approval and CODEOWNERS requirements may be enabled only after the access
prerequisites in [docs/ACCESS_MODEL.md](docs/ACCESS_MODEL.md) are met.

## Quality expectations

- Add outcome-focused tests for changed behavior.
- Preserve backward compatibility or document the migration and deprecation.
- Explain security, privacy, accessibility, and data-retention effects.
- Use existing project conventions and avoid unrelated refactors.
- Do not claim release, stability, deployment, or Agent-callability without
  reproducible evidence.
- For HTML or another user-visible frontend, follow the auditable
  `ui-ux-pro-max` gate in
  [docs/PROJECT_LIFECYCLE.md](docs/PROJECT_LIFECYCLE.md).

By participating, you agree to follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
