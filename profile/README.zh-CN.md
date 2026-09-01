# Tinkora

**人能直接用，Agent 也能调用。**

[English](README.md)

<!-- markdownlint-disable MD033 -->
<p align="center">
  <a href="https://ko-fi.com/tinkora" target="_blank" rel="noopener noreferrer">
    <img
      src="https://ko-fi.com/img/githubbutton_sm.svg"
      alt="在 Ko-fi 上支持 Tinkora"
      width="520"
    >
  </a>
</p>
<!-- markdownlint-enable MD033 -->

Tinkora 为开发者和 AI Agent 构建聚焦、开源的实用工具。项目重视清晰的工作流、在隐私敏感场景中
进行本地处理、稳定的机器可读契约，以及可以通过 CI 验证的实际行为。

## 项目

- [Agent Context Doctor](https://github.com/Tinkora/agent_context_doctor) 离线解释
  Codex、Claude Code 和 GitHub Copilot 的 instruction、settings 与 skills 哪些生效、被遮蔽或受信任门禁限制，
  不启动 host 或模型。[查看 Alpha](https://github.com/Tinkora/agent_context_doctor/releases/latest)。
- [Agent Worktree Doctor](https://github.com/Tinkora/agent_worktree_doctor)
  在不修改仓库、不执行 hooks 的前提下，检查 Git worktree 拓扑、过期管理元数据和不安全重定向。
  [查看 Alpha](https://github.com/Tinkora/agent_worktree_doctor/releases/latest)。
- [Cron Maker](https://github.com/Tinkora/cron_maker) 是一个在浏览器本地运行的
  Unix cron 构建、校验与解释工具，并按所选时区预览后续执行时间。
  [打开工具](https://tinkora.github.io/cron_maker/)。
- [Cert Viewer](https://github.com/Tinkora/cert_viewer) 在本地检查 X.509 PEM
  和 DER 证书，包括扩展和指纹。
  [打开工具](https://tinkora.github.io/cert_viewer/)。
- [Color Atlas](https://github.com/Tinkora/color_atlas) 在不上传源图片的情况下
  转换颜色、提取图片调色板、检查 WCAG 对比度、预览色觉差异并生成 CSS。
  [打开 Alpha](https://tinkora.github.io/color_atlas/)。
- [Curl Builder](https://github.com/Tinkora/curl_builder) 在本地构建 HTTP 请求，
  生成经过转义的 cURL、Fetch、Python、Go、Rust 和 Node.js 代码片段，但不会执行请求。
  [打开工具](https://tinkora.github.io/curl_builder/)。
- [CSV Sculptor](https://github.com/Tinkora/csv_sculptor) 在浏览器本地检查、筛选、
  排序和转换 CSV/TSV 数据。[打开 Alpha](https://tinkora.github.io/csv_sculptor/)。
- [Data Toolbox](https://github.com/Tinkora/data_toolbox) 检查 CSV/TSV 的结构、
  分隔符歧义、行宽不一致和电子表格公式风险，并且不会静默修改输入。
  [打开 Alpha](https://tinkora.github.io/data_toolbox/)。
- [Developer Primitives](https://github.com/Tinkora/developer_primitives) 通过
  浏览器本地工作台和跨平台 `tinkora-id`、`tinkora-time` CLI 生成并检查 UUID/ULID、
  转换显式时间戳，并明确显示 IANA 时区的 DST gap/fold。[打开工具](https://tinkora.github.io/developer_primitives/)或
  [下载 v0.2.0](https://github.com/Tinkora/developer_primitives/releases/tag/v0.2.0)。
- [DMG Background](https://github.com/Tinkora/dmg_background) 是一个在浏览器本地运行的
  macOS DMG 背景图与 Finder 布局资产编辑器。
  [打开工具](https://tinkora.github.io/dmg_background/)。
- [Diff Viz](https://github.com/Tinkora/diff_viz) 在浏览器本地渲染 unified diff
  和结构化 JSON 对比，并明确限制输入规模。[打开工具](https://tinkora.github.io/diff_viz/)。
- [JWT Inspector](https://github.com/Tinkora/jwt_inspector) 在本地分离 JWT
  解码、过期检查，以及 HS256/RS256 签名检查。
  [打开工具](https://tinkora.github.io/jwt_inspector/)。
- [Encoding Toolbox](https://github.com/Tinkora/encoding_toolbox) 提供本地
  Base64、十六进制、摘要、HMAC 和文件校验工作流，面向开发者和 Agent。
  [打开工具](https://tinkora.github.io/encoding_toolbox/)。
- [Eval Split Guard](https://github.com/Tinkora/eval_split_guard) 检测显式声明的
  evaluation split 组合间的精确内容、sample ID 和 group 泄漏，不上传或回显数据集内容。
  [查看 Alpha](https://github.com/Tinkora/eval_split_guard/releases/latest)。
- [Favicon Kit](https://github.com/Tinkora/favicon_kit) 在浏览器本地将一张原图
  转换为经过验证的浏览器、Apple Touch、PWA 和 Windows favicon 资产包。
  [打开工具](https://tinkora.github.io/favicon_kit/)或
  [下载 v0.1.0](https://github.com/Tinkora/favicon_kit/releases/tag/v0.1.0)。
- [Tool Call Trace](https://github.com/Tinkora/tool_call_trace) 是一个在浏览器本地运行的
  AI Agent 工具调用瀑布流查看器。[打开工具](https://tinkora.github.io/tool_call_trace/)。
- [image_to_icns](https://github.com/Tinkora/image_to_icns) 是一个隐私优先的 macOS
  `.icns` 生成器，提供浏览器编辑器和 MCP server。
  [打开工具](https://tinkora.github.io/image_to_icns/)。
- [JSON YAML Swiss](https://github.com/Tinkora/json_yaml_swiss) 校验、格式化并有意地
  转换 JSON、YAML 和 TOML，同时明确报告有损边界。
  [打开 Alpha](https://tinkora.github.io/json_yaml_swiss/)。
- [MD Porter](https://github.com/Tinkora/md_porter) 在浏览器本地预览受限 GFM、
  检查 YAML frontmatter，并导出安全的自包含 HTML。
  [打开 Alpha](https://tinkora.github.io/md_porter/)。
- [MCP Doctor](https://github.com/Tinkora/mcp_doctor) 静态诊断本地 stdio MCP server 配置，并对脱敏的 MCP transcript envelope
  执行有界、离线检查，覆盖 JSON-RPC 结构、初始化顺序和 stdout 污染。[查看版本](https://github.com/Tinkora/mcp_doctor/releases/latest)。
- [MCP Timeout Guard](https://github.com/Tinkora/mcp_timeout_guard) 是一个有边界的
  stdio JSON-RPC 代理，为请求施加截止时间，不执行或改写下游 MCP server。
  [查看 Alpha](https://github.com/Tinkora/mcp_timeout_guard/releases/latest)。
- [MCP Schema Compat](https://github.com/Tinkora/mcp_schema_compat) 在本地检查 MCP 工具
  schema 与不同模型供应商的兼容性，不访问网络。[查看 Alpha](https://github.com/Tinkora/mcp_schema_compat/releases/latest)。
- [Prompt Smith](https://github.com/Tinkora/prompt_smith) 在本地检查提示词模板中缺失、未使用和格式错误的占位符，
  不调用模型，也不访问网络。[查看 Alpha](https://github.com/Tinkora/prompt_smith/releases/latest)。
- [PE Version Info](https://github.com/Tinkora/pe_version_info) 提供跨平台 `pevi` CLI，
  用于检查并安全更新 Windows PE 的 `VERSIONINFO` 资源和图标。
  [下载 Alpha](https://github.com/Tinkora/pe_version_info/releases/latest)。
- [QR Forge](https://github.com/Tinkora/qr_forge) 是一个在浏览器本地运行的 QR、
  Code 128 与 EAN-13 生成器，支持导出 SVG 和 PNG。
  [打开工具](https://tinkora.github.io/qr_forge/)。
- [Recoverable Delete](https://github.com/Tinkora/recoverable_delete) 为 Codex
  提供删除前置防护，并将支持的删除操作交给操作系统 Trash/Recycle Bin 工作流。
  [查看版本](https://github.com/Tinkora/recoverable_delete/releases/latest)。

只有实现、文档、安全边界、维护状态和公开 URL 均已验证的仓库，才会列在这里。仅有 tool schema
或规划文档，不会被视为可由 Agent 调用的产品。

## 参与

- 阅读[贡献指南](../CONTRIBUTING.zh-CN.md)。
- 查看[项目生命周期](../docs/PROJECT_LIFECYCLE.md)。
- 遵循[安全政策](../SECURITY.zh-CN.md)，并通过受影响仓库的 Security 页面私密报告漏洞。

在组织建立可持续的管理能力和私密行为举报通道前，本治理仓库继续关闭 Issues 与 Discussions。

## 支持项目

如果 Tinkora 帮你节省了时间，可以在 Ko-fi 上支持项目。你的支持主要是给 AI token
计价器续杯，用于调研、测试、文档和日常维护。

赞助完全自愿，不会影响访问权限、支持优先级或路线图决策。使用和分享工具、提交可复现的问题、
贡献经过思考的改进，也都是同样受到重视的支持方式。
