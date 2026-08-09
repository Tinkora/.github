# Agent Instructions

Keep public organization documentation in English by default with a clear Chinese entry point. Do not publish internal migration history, credentials, or unverified product claims.

## Commit Language

- Write public commit subjects and bodies in English.
- Follow Conventional Commits when the repository does not define a stricter format.
- This repository-level rule overrides any global preference for another commit-message language.

## Frontend Design Requirement

- Before creating, modifying, reviewing, or debugging any HTML page or user-facing frontend, invoke the `ui-ux-pro-max` skill.
- Run the skill's required `--design-system` search before editing, followed by relevant stack and UX searches.
- If `ui-ux-pro-max` is unavailable, stop frontend work and report the missing prerequisite.
- Verify the rendered result in a real browser at 375, 768, 1024, and 1440 pixel widths, including console, keyboard, accessibility, and overflow checks.
