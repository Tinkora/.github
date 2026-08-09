# Translation policy

## Default language and pairs

English files are the default GitHub-recognized entry points. A Chinese peer
uses the `.zh-CN.md` suffix and both files link to each other near the top.
Translations convey equivalent commitments, limitations, and calls to action;
they need not mirror sentence structure.

Required bilingual pairs in this repository are:

| English default | Chinese peer |
| --- | --- |
| `README.md` | `README.zh-CN.md` |
| `profile/README.md` | `profile/README.zh-CN.md` |
| `CODE_OF_CONDUCT.md` | `CODE_OF_CONDUCT.zh-CN.md` |
| `CONTRIBUTING.md` | `CONTRIBUTING.zh-CN.md` |
| `SECURITY.md` | `SECURITY.zh-CN.md` |
| `SUPPORT.md` | `SUPPORT.zh-CN.md` |

English remains the machine-discovery filename because GitHub looks for those
names. This is a routing rule, not a statement that one audience matters more.

## Change process

When user-visible meaning changes, the pull request updates both peers. If a
translator cannot complete both safely, the change must mark the stale
translation clearly in the pull request and obtain a maintainer decision before
merge; silently divergent policy is not acceptable.

Reviewers compare:

- Requirements, prohibitions, scope, prerequisites, and exceptions.
- Current versus target capability claims.
- Links, commands, identifiers, versions, and dates.
- Security, privacy, support, release, and deprecation commitments.

Code identifiers, API names, filenames, commands, and quoted errors retain
their original spelling. Source text is UTF-8 without BOM. New translation
files use stable locale suffixes rather than translated filenames so links and
automation remain predictable.

Code comments are written in English so source review has one shared language.
This rule does not require translating identifiers, protocol terms, fixture
content, or quoted external errors.

## Issue Forms and generated content

Issue Forms use English as the default machine-recognized organization
template. A localized form may be added only when it can be maintained as a
semantic peer without splitting triage. Generated API references should be
regenerated from the same source rather than translated by hand when tooling
supports it.
