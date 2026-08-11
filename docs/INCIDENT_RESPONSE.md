# Incident response

This public policy explains process and responsibility. It intentionally omits
private contacts, credentials, recovery material, member IP addresses, raw
Audit Log data, exploit details, and internal case notes.

## Roles and authority

The current organization has one owner, so that owner initially coordinates an
incident and records the continuity risk. After a second independent, trusted
owner is active, incident lead, technical lead, and communications roles should
be assigned according to the incident rather than held by one person.

An incident declaration permits proportionate containment needed to protect
users and assets. It does not authorize unrelated organization changes or
public disclosure of sensitive evidence.

## Remote emergency controls

| Setting | Current | Target | Apply when |
| --- | --- | --- | --- |
| Emergency access restriction | No standing incident-specific remote rule is claimed | Temporarily revoke or narrow compromised access with least privilege | An authorized owner verifies a credible active risk, identifies exact affected access, records recovery privately, and approves the action |
| Workflow or release pause | Project-specific protected-tag release automation exists for `cert_viewer`, `cron_maker`, `curl_builder`, `diff_viz`, `dmg_background`, `encoding_toolbox`, `image_to_icns`, `jwt_inspector`, `mcp_doctor`, `qr_forge`, and `tool_call_trace`; organization release evidence remains read-only | Disable affected automation or publication while preserving evidence | A credible compromise could affect builds or releases, the incident lead records scope and rollback, and an authorized owner applies the pause |
| Repository interaction limits | No incident restriction is pre-authorized | Temporarily limit interactions only when abuse or disclosure cannot be contained otherwise | The incident lead documents necessity and duration, an authorized owner approves it, and restoration criteria are defined |
| Public advisory | No security advisory channel is claimed ready | Coordinate a minimal, accurate advisory and corrected release when appropriate | A private intake exists, affected scope and mitigation are understood, disclosure risk is reviewed, and publication is explicitly authorized |

## Process

1. **Detect and preserve**: record the minimum timestamped evidence in approved
   private storage; do not paste secrets or raw logs into public GitHub content.
2. **Triage**: validate the event, affected assets and versions, user impact,
   exploitability, and immediate safety needs.
3. **Contain**: revoke specific credentials or access, pause affected systems,
   and protect evidence. Avoid broad destructive actions unless necessary.
4. **Eradicate**: fix the root cause, rotate affected credentials, add tests or
   controls, and verify that persistence paths are removed.
5. **Recover**: restore service and access gradually, verify expected behavior,
   and monitor for recurrence.
6. **Communicate**: share only verified facts, useful mitigation, affected
   versions, and safe timelines. Coordinate vulnerability disclosure privately
   when a channel exists.
7. **Learn**: document contributing conditions, effective controls, follow-up
   owners, and policy changes without exposing private data.

Severity is based on actual confidentiality, integrity, availability, and user
impact rather than publicity. There is no fixed public response SLA. The
incident lead sets review frequency according to credible risk and available
capacity.

Security intake and triage are defined in
[SECURITY_OPERATIONS.md](SECURITY_OPERATIONS.md).
