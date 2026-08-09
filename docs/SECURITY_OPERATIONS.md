# Security operations

The [GitHub settings audit](SETTINGS_AUDIT.md) reads only fixed allowlisted
endpoints, emits normalized and redacted evidence, and never requests Audit
Log data. Reporter-flow, credential, rule-behavior, and triage checks remain
manual because an API setting alone cannot prove them.

## Security settings register

| Setting | Current | Target | Apply when |
| --- | --- | --- | --- |
| Private vulnerability reporting for `.github` | Enabled on the public repository and read back as `enabled=true`; independent reporter-side verification is pending | Verify the reporter-facing workflow | An independent reporter can reach and complete the intended private flow without submitting a fabricated vulnerability or real secret |
| Private reporting for public projects | Managed per repository | Enable before listing a public project and verify the reporter-facing workflow | A maintainer owns triage, supported versions are documented, the setting is read back, and an independent reporter can reach the private flow |
| Confidential contact | No private security email or other verified intake channel is published | Publish only a controlled, monitored confidential channel | Ownership, access, retention, handoff, and abuse handling are verified and publication is explicitly authorized |
| Conduct-reporting channel | No verified private conduct-reporting channel is published | Maintain a controlled private channel separate from vulnerability reporting | Ownership, least-privilege access, retention, handoff, reporter flow, and moderator responsibility are verified before Issues, contribution solicitation, Discussions, or Code of Conduct enforcement |
| Dependency alerts and updates | Vulnerability alerts and Dependabot security updates are enabled for `.github` | Enable and verify per published repository with narrowly scoped update pull requests | Manifests are accurate, a maintainer can triage findings, and feature availability is confirmed |
| Secret scanning and push protection | Enabled for `.github` | Keep enabled on public repositories and verify bypass and alert handling | Availability is confirmed, bypass responsibility is defined, and test behavior is understood |
| Code scanning | No scan is claimed as configured | Add project-appropriate analysis with reviewed queries and actionable ownership | The project builds reliably, scan permissions are minimal, results are triaged, and the workflow is explicitly authorized |
| Security roles | Closed `security` Team exists, is the organization security manager, has `write` on `.github`, and currently contains only `tinkeragora` | Add qualified independent people with least privilege; keep recovery separate from the sole operator | A second independent trusted owner and qualified maintainers exist, Team membership is verified, and access is explicitly authorized |

## Reporting boundary

The public [security policy](../SECURITY.md) is the only current reporting
guidance. Because a confidential channel is pending, reporters are instructed
not to disclose vulnerabilities publicly. Public Issue Forms and Discussions
are not substitutes for a private report. Private vulnerability reporting is
only for vulnerabilities; it does not accept harassment or sensitive Code of
Conduct reports and cannot satisfy the separate conduct-reporting gate.

## Publication boundary

Every public repository must publish an accurate security policy, enable the
security controls available for its code and plan, and keep unsupported claims
out of its README. Product source may be published while community interaction
is disabled. Enabling Issues, Discussions, or active contribution solicitation
still requires sustainable moderation and a separate conduct-reporting path.
PVR testing must not submit live credentials or a fabricated vulnerability.
This separation is defined in
[ADR-0001](decisions/0001-source-publication-boundary.md).

## Triage process

Once a private intake channel exists, the assigned maintainer should:

1. Preserve the minimum report, confirm scope, and remove unrelated personal
   data or live credentials.
2. Reproduce in an isolated environment without interacting with real users or
   production data.
3. Assess affected versions, exploitability, impact, and available mitigations.
4. Coordinate a fix, tests, advisory, release, and disclosure with least
   privilege.
5. Close access and retention tasks after publication, then record lessons that
   are safe for public documentation.

No fixed acknowledgement or remediation SLA is promised. Priority depends on
credible impact and maintainers' ability to validate and mitigate it.

## Sensitive data

Never commit reports, proof-of-concept secrets, recovery codes, private contact
details, raw Audit Log exports, member IP addresses, or release credentials.
Public records may contain sanitized timelines, affected versions, decisions,
and mitigations only after disclosure is safe.

Security incidents follow [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md).
