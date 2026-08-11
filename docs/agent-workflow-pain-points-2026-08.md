# Agent Workflow Pain Points: Evidence and Intake

[简体中文](agent-workflow-pain-points-2026-08.zh-CN.md)

**Research date:** 2026-08-11

This record turns public reports into bounded product intake. A repeated
failure is not automatically a product: Tinkora starts work only when the
failure is reproducible, the smallest useful boundary is clear, and tests can
verify the result without collecting user secrets.

## Evidence

| Public report | Repeated failure | Product implication |
| --- | --- | --- |
| [MCP servers #719](https://github.com/modelcontextprotocol/servers/issues/719) | MCP initialization timed out while a local server downloaded dependencies. | Diagnostics must distinguish startup, dependency, PATH, and timeout causes. |
| [MCP servers #4199](https://github.com/modelcontextprotocol/servers/issues/4199) | A fetch server silently required Node.js and could block without a timeout. | Runtime prerequisites and subprocess limits must be explicit. |
| [MCP servers #3741](https://github.com/modelcontextprotocol/servers/issues/3741) | Production users requested private-network blocking, size/type limits, redirect validation, and fetch timeouts. | Network-capable tools need a security policy, not only a URL field. |
| [OpenAI Agents #4016](https://github.com/openai/openai-agents-python/issues/4016) | MCP credentials and query tokens appeared in errors, traces, and persisted metadata. | Redaction must happen before formatting, export, and persistence. |
| [OpenAI Agents #4353](https://github.com/openai/openai-agents-python/issues/4353) | Strict schema conversion silently removed constraints and emitted unsupported keywords. | Schema tooling needs fixture-based accept-set tests and loud failures. |
| [Trae Agent #440](https://github.com/bytedance/trae-agent/issues/440) | Long sessions accumulated messages and memory without bounded token accounting. | Context work needs explicit budgets and deterministic limits. |

These are public reports, not a statistical claim about all users. Each
project must collect Tinkora-specific feedback before moving from Alpha to
Beta.

## Prioritized intake

### P1: Trace redaction and contract checks

Extend `tool_call_trace` with an opt-in, local redaction library and a CLI
contract checker. Start with URL user-info/query/fragment, authorization
headers, API-key-like JSON values, configured paths, and strict byte/line
limits. Adversarial fixtures must prove secrets do not appear in human output,
JSON, exports, or error paths while non-secret IDs remain searchable.

Go only after three real trace fixtures from different Agent SDKs parse
correctly. Do not build hosted observability, accounts, vendor exporters, or a
claim to detect every secret.

### P2: Bounded MCP probing

Keep `mcp_doctor` static by default. An optional `--probe` may be considered
only after three external users reproduce failures that static checks cannot
explain. Any probe must execute only an explicitly selected command, enforce a
hard timeout, scrub environment and output, and never contact remote URLs.

### P3: Context budget inspector

Keep a format-agnostic transcript budget inspector as Idea until external
feedback confirms the problem for Tinkora users. Prefer import adapters in
`tool_call_trace` if vendor-specific formats dominate. Do not create a new
repository merely because context-window issues are common in public trackers.

## Decision

No new standalone repository is authorized by this record. The current
evidence supports focused iterations in `mcp_doctor` and `tool_call_trace`.
Every implementation must update its product specification, tests, bilingual
README, CHANGELOG, and release checklist.
