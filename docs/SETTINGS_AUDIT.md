# GitHub settings audit

## Permanent safety boundary

`scripts/github_settings_audit.rb` is a permanently read-only audit tool. It
compares visible GitHub organization and public-repository settings with
[`config/github-settings-policy.json`](../config/github-settings-policy.json).
It cannot apply, repair, or stage a remote setting change. `--dry-run` only
makes the non-disableable `READ_ONLY` mode explicit.

Any future settings application must be a different tool with a separate
authorization decision, implementation review, operator log, rollback plan,
and post-change verification. Adding an apply mode to this auditor is not an
allowed evolution path.

The live transport resolves `gh` only from fixed system installation paths,
rejects non-regular, non-executable, or group/world-writable binaries, fixes
every command to `github.com`, and removes `GH_*` target and credential
overrides from the child environment. It runs only `gh auth status`, fixed
allowlisted REST `GET` requests, and one compile-time GraphQL read query for
the organization Projects count. Each child process has a 30-second timeout,
is terminated and reaped on failure, and may return at most 4 MiB across
stdout and stderr. Pagination uses explicit `page` requests with 100 items per
page and fails closed after 100 full pages. The transport never asks `gh` to
reveal or refresh a token, runs Git, writes a cache or raw response, or creates
or changes a remote resource.

## Running an audit

The default policy expects organization `tinkora`, operator `tinkeragora`,
GitHub Free, the `solo-public` stage, and an explicit `.github` repository
entry. Add another repository only after its source, topics, interaction state,
and release target have been reviewed.

```shell
ruby scripts/github_settings_audit.rb audit \
  --policy config/github-settings-policy.json \
  --format human \
  --dry-run
```

Use repeated `--repo NAME` arguments for an explicit public set, or
`--all-public` to enumerate only public repositories. `--org` overrides the
organization only for an authorized diagnostic run. `--format json` emits the
versioned schema, and `--strict` also makes any `UNKNOWN` result exit with
status 1. Without `--strict`, warnings and unknowns remain visible but only a
`FAIL` returns status 1.

Repository names are validated before any transport starts. In particular,
`.` and `..` are rejected so an API path can never contain a repository dot
segment.

`repositoryScope.defaults` defines shared controls. Each key in
`repositoryScope.repositories` opts one public repository into management and
provides partial overrides; `sourcePublished`, `topics`, `issues`, and
`releases` are mandatory per repository. An explicitly requested or discovered
public repository that is absent from this map is `UNMANAGED/FAIL` and is not
compared with unrelated defaults.

The remaining exit statuses are:

- `0`: no `FAIL`, and no `UNKNOWN` when strict mode is active.
- `1`: at least one `FAIL`, or at least one `UNKNOWN` in strict mode.
- `2`: invalid CLI, policy, attestation, or schema-controlled input.
- `3`: authentication or the initial viewer control probe could not start.

Run `gh auth status -h github.com` before a live audit. Missing `admin:org` or
`read:project` scope makes an applicable affected check `UNKNOWN`; a pending or
not-applicable gate remains `WARN`. The audit does not refresh authorization.
Live audits are operator-run diagnostics and do not run in pull-request CI.

After authenticating, an operator can run the PR-excluded live smoke. It keeps
the JSON output in a temporary directory, accepts audit drift exit status `1`,
validates the output with the fixed local Ajv installation, checks the
`READ_ONLY` and redaction declarations, and removes the temporary output:

```shell
scripts/smoke_github_settings_audit.sh
```

## Stage and gate semantics

The policy distinguishes present obligations from future adoption gates.
`CURRENT` targets have no `gate` field. Every `FUTURE_GATE` target names one of
the four policy gates. `sourcePublication` and `publicInteraction` are
independent: source can be public while organization-wide Issues and
Discussions remain closed. An explicitly reviewed project override may enable
its own Issues or Discussions without satisfying the organization-wide gate;
the audit keeps that exception visible in the repository-specific policy.
`releaseAutomation` covers
organization-wide reusable or unattended publication; a deliberately
authorized project-specific protected-tag workflow does not satisfy that gate.
A pending gate yields `GATED/WARN` regardless of the currently visible value; a
satisfied gate yields `APPLICABLE` and is evaluated as `PASS`, `FAIL`, or
`UNKNOWN`; and a `not_applicable` gate yields
`NOT_APPLICABLE/WARN`, never a false pass. Current targets are emitted as
`APPLICABLE`. The `multi-maintainer` stage is rejected unless the independent
second-owner gate is satisfied. Missing visibility for an applicable target is
always `UNKNOWN`, never `PASS`.

This distinction preserves the safe Solo hold. One visible owner and disabled
organization-wide 2FA can satisfy the current Solo safety posture while the
independent-second-owner and organization-2FA adoption checks remain warnings.
Two visible owners do not prove that the second owner is independent or has a
tested recovery path, so that gate remains a manual check.

On GitHub Free, unsupported organization Rulesets and Audit Log APIs are
capabilities, not drift. The auditor does not request the Audit Log and marks
the organization Rulesets adoption gate as a non-blocking warning. Public
repository rulesets or branch protection remain the applicable enforcement
surface. A successful empty rulesets response (`200 []`) is positive evidence
of zero rules; while the publication gate is pending this remains a gate
warning, and after the gate is satisfied it can prove a mismatch. Two
ambiguous `404` responses cannot prove that a non-empty repository has no rule
and remain unknown. A selected-Actions endpoint `409` is not applicable only
when the readable parent policy is not `selected`.

## Coverage

Organization checks cover the plan, base permission, member repository
creation/deletion/visibility/invitation, Solo and future 2FA states, Projects,
security defaults, Actions enablement scope, allowed-action mode, full-SHA
pinning requirement, all three selected-action fields, workflow defaults, the current operator membership,
and counts for owners, members, public members, outside collaborators, and
Teams. Only counts are retained for people and Teams.

Public repository checks cover explicit management, source publication, default branch,
topics, Issues, Discussions, Wiki, Projects, merge methods, merged-branch
deletion, `security_and_analysis`, private vulnerability reporting,
vulnerability alerts, automated fixes, secret scanning, push protection, code
scanning through configured CodeQL default setup or a clean advanced CodeQL
analysis for the current default-branch HEAD, rulesets or branch protection,
Actions enablement, allowed-action mode and all three selected-action fields,
community profile, CODEOWNERS errors, and release count. An advanced analysis
from another tool or for another branch or commit, an analysis with an error,
or malformed analysis data does not prove code scanning is configured. A
repository proven empty by `pushed_at: null`, with no default branch and absent
CodeQL default setup, is explicitly `not-configured`.

Source publication uses a syntactically valid, non-null GitHub `pushed_at`
timestamp instead of the approximate and asynchronously updated repository
`size`. A null timestamp means an empty repository; a missing or malformed
timestamp produces `UNKNOWN`.

API access cannot prove several operational controls. The policy therefore
defines manual attestations for an independent second owner and 2FA recovery,
the reporter-facing private-vulnerability flow, a separate conduct-reporting
channel, Funding recipient control, domain control, Audit Log review, PAT/App
and secret inventory, rules behavior, fork-secret behavior, scanning coverage
and triage, and rendered community-file inheritance. An omitted current
attestation is `UNKNOWN`; an omitted future-gate attestation is `WARN`. A
manual attestation is evidence supplied by an authorized operator, never an
inference from an API response.

Policy `manualAttestations` is an object map whose `manual.*` key is the
attestation ID and whose value contains `applicability`, `severity`, and a
`gate` only for `FUTURE_GATE`. The object model makes IDs unique, and checks
are generated in sorted key order. Standard JSON parsing uses the last value
when source text repeats a key; both Ruby and JSON Schema therefore validate
the resulting single-key object and do not attempt an unreliable raw-text
duplicate scan.

An optional attestation file has this shape:

```json
{
  "schemaVersion": "1.0",
  "attestations": {
    "manual.pvr_reporter_flow": true,
    "manual.audit_log_review": false
  }
}
```

## Output and redaction

Human output always begins with `READ-ONLY GITHUB SETTINGS AUDIT` and uses a
deterministic status and check order. JSON output conforms to
[`schemas/github-settings-audit.schema.json`](../schemas/github-settings-audit.schema.json).
It contains only:

- run organization, expected/public operator login, visible plan, and audited
  public repository count;
- four status counts and sorted checks;
- booleans, fixed enums, counts, and validated public repository metadata;
- endpoint IDs, status codes, and normalized reason codes.

Output excludes tokens, email addresses, IP addresses, member identities,
private repository names, raw bodies, error text, request IDs, Audit Log data,
PAT/App/secret names, and cache files. Transport errors are reduced to fixed
reason codes. API responses are held only in process memory long enough to
derive allowed values and counts.

Offline fixture tests deliberately include fake sensitive lures, pagination,
partial and malformed responses, and hostile strings. Run them with:

```shell
ruby scripts/test_github_settings_audit.rb
ruby scripts/check_github_settings_audit.rb
```

Both commands run through `scripts/check_all.sh` in governance CI. The live
audit is deliberately excluded from CI.

## GitHub 设置审计（中文）

### 永久安全边界

`scripts/github_settings_audit.rb` 是永久只读审计工具。它只比较 GitHub 组织与公开仓库的可见设置和
[`config/github-settings-policy.json`](../config/github-settings-policy.json) 中的分阶段期望，不应用、修复或预演任何远端设置变更。`--dry-run` 仅用于显式确认不可关闭的 `READ_ONLY` 模式。

未来如需应用设置，必须另建工具，并重新经过独立授权、实现审查、操作记录、回滚计划和变更后验证；不得给本审计器增加 apply 模式。

Live transport 只从固定系统安装路径解析 `gh`，拒绝非普通文件、不可执行文件以及 group/world writable 文件；所有命令固定访问 `github.com`，并从子进程环境移除会覆盖目标或凭据的 `GH_*` 变量。它只运行 `gh auth status`、固定白名单 REST `GET`，以及一条编译期固定的组织 Projects 计数 GraphQL 只读 query。每个子进程最多运行 30 秒，失败后会终止并回收整个进程组；stdout 与 stderr 合计不得超过 4 MiB。分页只发送显式 `page` 参数，每页 100 条，连续 100 个满页后 fail closed。它不会要求 `gh` 显示或刷新 token，不运行 Git，不写缓存或原始响应，也不创建或修改远端资源。

### 运行方式

默认 policy 面向 `tinkora`、预期操作者 `tinkeragora`、GitHub Free、`solo-public` 阶段，并显式登记 `.github`。只有在逐仓库审查源码发布、topics、互动状态和 release 目标后，才登记其他仓库。

```shell
ruby scripts/github_settings_audit.rb audit \
  --policy config/github-settings-policy.json \
  --format json \
  --dry-run
```

可重复使用 `--repo NAME` 指定公开仓库，或用 `--all-public` 仅枚举公开仓库。仓库名会在 transport 启动前校验，并明确拒绝 `.` 与 `..`，确保 API 路径不含仓库 dot segment。`--org` 只用于已授权的诊断覆盖；`--strict` 会让任何 `UNKNOWN` 返回退出码 1，但不会把 pending gate 的 `GATED/WARN` 升级为失败。默认模式下，只有明确 `FAIL` 返回 1。CLI/policy/attestation/schema 输入错误返回 2；认证或初始 viewer 控制探针无法启动返回 3。

`repositoryScope.defaults` 保存公共控制；`repositoryScope.repositories` 以 map 显式登记受管公开仓库并提供 partial override。每个仓库必须独立声明 `sourcePublished`、`topics`、`issues` 和 `releases`。显式请求或自动发现但未登记的公开仓库输出 `UNMANAGED/FAIL`，不会套用其他仓库的目标。

Live 审计前应运行 `gh auth status -h github.com`。缺少 `admin:org` 或 `read:project` 时，适用的受影响检查为 `UNKNOWN`，pending 或 not-applicable gate 仍为 `WARN`；审计器不会刷新授权。Live 审计只由操作者执行，不进入 Pull Request CI。

完成认证后，操作者可手工运行不进入 PR CI 的 live smoke：

```shell
scripts/smoke_github_settings_audit.sh
```

该脚本只把 JSON 写入临时目录，允许审计因发现漂移返回 `1`，随后用本地固定 Ajv 校验输出，检查 `READ_ONLY`、脱敏声明与敏感值模式，并清理临时文件。

### 阶段、能力与状态

Policy 中的 `CURRENT` 目标不得包含 `gate`；每个 `FUTURE_GATE` 目标必须绑定四个固定 gate 之一。`sourcePublication` 与 `publicInteraction` 相互独立：源码可以公开，而组织级 Issues 与 Discussions 仍可保持关闭。经过明确审查的项目 override 可以单独开启自己的 Issues 或 Discussions，但不会满足组织级 gate；审计会在项目专属 policy 中保留这一例外。`releaseAutomation` 覆盖组织级可复用或无人值守发布。gate 为 `pending` 时输出 `GATED/WARN`，不因当前值碰巧符合而伪装成 `PASS`；为 `satisfied` 时输出 `APPLICABLE`，再按证据得到 `PASS`、`FAIL` 或 `UNKNOWN`；为 `not_applicable` 时输出 `NOT_APPLICABLE/WARN`。当前目标也输出 `APPLICABLE`。`multi-maintainer` 阶段必须已满足独立第二 owner gate。对适用目标，缺少 scope、认证失败、限流、网络错误、5xx、字段错误、GraphQL partial 或无法消歧的 `404` 一律为 `UNKNOWN`。

Solo 阶段的一位可见 owner 和关闭的组织强制 2FA 可以构成当前安全保持状态；独立第二 owner 与组织 2FA 的采用门禁仍为 `WARN`。API 即使看到两位 owner，也不能证明第二位 owner 独立可信并完成恢复测试，因此仍需人工证明。

GitHub Free 不支持的组织级 Rulesets 与 Audit Log API 属于套餐能力边界，不是当前漂移。审计器不请求 Audit Log；组织 Rulesets 采用门禁为非阻塞警告，公开仓库仍检查 repository-level rulesets 或 branch protection。rulesets `200 []` 是零条规则的明确证据：publication gate pending 时仍为门禁警告，gate satisfied 后可据此判定不符合；非空仓库的两次歧义 `404` 仍是 `UNKNOWN`。只有父级 Actions policy 已成功读取且不是 `selected` 时，selected-actions 的 `409` 才是 `NOT_APPLICABLE`。

### 覆盖范围与人工项

组织检查包括套餐、base permission、成员创建/删除/visibility/invite、Solo 与未来 2FA、Projects、安全默认配置、Actions 启用仓库范围、allowed-actions 模式、完整 SHA 强制、selected-actions 三个字段、workflow 默认权限、当前操作者 membership，以及 owner、member、公开 member、outside collaborator 和 Team 数量。人员和 Team 只保留数量。

公开仓库检查包括显式登记、源码发布状态、default branch、topics、Issues、Discussions、Wiki、Projects、merge methods、合并后删分支、`security_and_analysis`、PVR、vulnerability alerts、automated fixes、secret scanning、push protection、code scanning、rulesets/branch protection、Actions 启用状态、allowed-actions 模式与 selected-actions 三个字段、Community Profile、CODEOWNERS errors 和 Releases 数量。Code scanning 可由已配置的 CodeQL Default setup，或当前默认分支 HEAD 上没有错误的 Advanced CodeQL analysis 证明；其他工具、分支或 commit、带错误或结构异常的 analysis 不构成已配置证据。由 `pushed_at: null` 证明为空、没有默认分支且不存在 CodeQL Default setup 的仓库明确为 `not-configured`。

源码发布状态以 GitHub `pushed_at` 的非空合法时间戳为证据，不使用近似且异步更新的仓库 `size`。时间戳为 `null` 表示空仓库；字段缺失或格式错误时输出 `UNKNOWN`。

API 无法证明的第二 owner 独立性与 2FA 恢复、PVR 报告者流程、独立行为举报通道、Funding 收款、域名控制、Audit Log 复核、PAT/App/secrets、规则行为测试、fork secret、扫描覆盖与 triage、网页继承呈现均列为 manual attestations。当前阶段未提供的人工证明是 `UNKNOWN`，未来门禁未提供时是 `WARN`；只有授权操作者提供的人工证据才可满足人工项。

Policy 的 `manualAttestations` 是对象 map：`manual.*` key 即人工项 ID，value 包含 `applicability`、`severity`，且仅 `FUTURE_GATE` 包含 `gate`。对象模型保证同一 ID 不能共存，审计按 key 排序生成检查。标准 JSON parser 遇到重复文本 key 时采用最后一个值；Ruby 与 JSON Schema 都校验解析后的单键对象，不增加不可靠的原始文本重复扫描。

### 输出与脱敏

Human 输出固定以 `READ-ONLY GITHUB SETTINGS AUDIT` 开头并确定性排序。JSON 遵循
[`schemas/github-settings-audit.schema.json`](../schemas/github-settings-audit.schema.json)，只包含组织、公开 login、套餐、审计范围内的公开仓库数量、四类状态摘要、排序后的 checks、布尔值、闭集枚举、计数、校验过的公开元数据，以及 endpoint ID、状态码和规范化 reason code。

输出禁止 token、邮箱、IP、成员身份、私有仓库名、raw body、错误正文、request ID、Audit Log 数据、PAT/App/secret 名和缓存。离线 fixtures 含虚构敏感诱饵、分页、partial/字段错误与敌意字符串，并通过 `scripts/check_all.sh` 接入治理 CI；Live 审计明确不在 CI 中运行。
