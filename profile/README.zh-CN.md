# Tinkora

**人能直接用，Agent 也能调用。**

[English](README.md)

Tinkora 为开发者和 AI Agent 构建聚焦、开源的实用工具。项目重视清晰的工作流、在隐私敏感场景中
进行本地处理、稳定的机器可读契约，以及可以通过 CI 验证的实际行为。

## 项目

- [Cron Maker](https://github.com/Tinkora/cron_maker) 是一个在浏览器本地运行的
  Unix cron 构建、校验与解释工具，并按所选时区预览后续执行时间。
  [打开工具](https://tinkora.github.io/cron_maker/)。
- [Cert Viewer](https://github.com/Tinkora/cert_viewer) 在本地检查 X.509 PEM
  和 DER 证书，包括扩展和指纹。
  [打开工具](https://tinkora.github.io/cert_viewer/)。
- [Curl Builder](https://github.com/Tinkora/curl_builder) 在本地构建 HTTP 请求，
  生成经过转义的 cURL、Fetch、Python、Go、Rust 和 Node.js 代码片段，但不会执行请求。
  [打开工具](https://tinkora.github.io/curl_builder/)。
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
- [Tool Call Trace](https://github.com/Tinkora/tool_call_trace) 是一个在浏览器本地运行的
  AI Agent 工具调用瀑布流查看器。[打开工具](https://tinkora.github.io/tool_call_trace/)。
- [image_to_icns](https://github.com/Tinkora/image_to_icns) 是一个隐私优先的 macOS
  `.icns` 生成器，提供浏览器编辑器和 MCP server。
  [打开工具](https://tinkora.github.io/image_to_icns/)。
- [MCP Doctor](https://github.com/Tinkora/mcp_doctor) 静态诊断本地 stdio MCP server
  的配置、路径、环境和传输契约。[查看版本](https://github.com/Tinkora/mcp_doctor/releases/latest)。
- [QR Forge](https://github.com/Tinkora/qr_forge) 是一个在浏览器本地运行的 QR、
  Code 128 与 EAN-13 生成器，支持导出 SVG 和 PNG。
  [打开工具](https://tinkora.github.io/qr_forge/)。

只有实现、文档、安全边界、维护状态和公开 URL 均已验证的仓库，才会列在这里。仅有 tool schema
或规划文档，不会被视为可由 Agent 调用的产品。

## 参与

- 阅读[贡献指南](../CONTRIBUTING.zh-CN.md)。
- 查看[项目生命周期](../docs/PROJECT_LIFECYCLE.md)。
- 遵循[安全政策](../SECURITY.zh-CN.md)，并通过受影响仓库的 Security 页面私密报告漏洞。

在组织建立可持续的管理能力和私密行为举报通道前，本治理仓库继续关闭 Issues 与 Discussions。
