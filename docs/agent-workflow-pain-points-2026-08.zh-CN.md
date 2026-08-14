# Agent 工作流痛点：证据与立项入口

[English](agent-workflow-pain-points-2026-08.md)

**调研日期：** 2026-08-11

本文把公开报告转换为有边界的立项入口。反复出现的失败不自动等于产品；只有在失败可复现、最小有用边界明确，并且可以在不收集用户密钥的前提下验证时，Tinkora 才开始实现。

## 证据

| 公开报告 | 重复失败 | 产品含义 |
| --- | --- | --- |
| [MCP servers #719](https://github.com/modelcontextprotocol/servers/issues/719) | 本地服务器下载依赖时 MCP 初始化超时。 | 诊断必须区分启动、依赖、PATH 和超时原因。 |
| [MCP servers #4199](https://github.com/modelcontextprotocol/servers/issues/4199) | fetch server 静默依赖 Node.js，且可能无超时阻塞。 | 运行时前置条件和子进程限制必须明确。 |
| [GitHub Copilot CLI #4323](https://github.com/github/copilot-cli/issues/4323) | 仓库级 `.mcp.json` 中的注释使严格解析器跳过全部工作区 MCP server。 | 静态诊断需要兼容客户端原生 JSONC，同时保持窄边界且不执行命令。 |
| [MCP servers #3741](https://github.com/modelcontextprotocol/servers/issues/3741) | 用户要求阻断内网、限制大小/类型、验证重定向和设置超时。 | 网络型工具需要安全策略，而不只是 URL 字段。 |
| [OpenAI Agents #4016](https://github.com/openai/openai-agents-python/issues/4016) | MCP 凭证和 query token 出现在错误、trace 和持久化元数据中。 | 脱敏必须在格式化、导出和持久化之前完成。 |
| [OpenAI Agents #4353](https://github.com/openai/openai-agents-python/issues/4353) | 严格 schema 转换静默删除约束并输出不支持的关键字。 | schema 工具需要 fixture 接收集合测试，并在不支持时显式失败。 |
| [Trae Agent #440](https://github.com/bytedance/trae-agent/issues/440) | 长会话累积消息和内存，没有有界 token 统计。 | 上下文工作需要明确预算和确定性限制。 |

这些是公开报告，不代表所有用户的统计样本。项目从 Alpha 进入 Beta 前，必须收集 Tinkora 用户自己的反馈。

## 优先入口

### P1：Trace 脱敏与契约检查

为 `tool_call_trace` 增加可选、本地运行的脱敏库和 CLI 契约检查器。先覆盖 URL 用户信息/query/fragment、授权 header、疑似 API key 的 JSON 值、配置路径，以及严格字节/行数上限。对抗 fixture 必须证明密钥不会出现在人类输出、JSON、导出物或错误路径中，同时保留非敏感 ID 的检索能力。

只有来自三个不同 Agent SDK 的真实 trace fixture 都能解析时才通过立项。不得构建托管观测平台、账号系统、厂商 exporter，或承诺识别全部密钥。

### P2：有界 MCP 探测

证据支持的静态兼容增量已经完成：`mcp_doctor` 接受 JSONC 注释和尾逗号，把 VS Code
`${input:name}` 引用视为客户端提供的值，同时仍不执行配置中的命令。

`mcp_doctor` 继续默认静态检查。只有三位外部用户复现静态检查无法解释的失败，才考虑可选 `--probe`。探测只能执行用户明确选择的命令，必须有硬超时、环境和输出清理，并禁止访问远程 URL。

### P3：上下文预算检查器

上下文预算检查器在 Tinkora 获得外部反馈前保持 Idea。如果格式高度厂商特定，优先把导入适配器放入 `tool_call_trace`，不要因为公开 tracker 中问题常见就新建仓库。

## 决定

本文不授权创建新的独立仓库。当前证据支持在 `mcp_doctor` 和 `tool_call_trace` 中做聚焦迭代。任何实现都必须同步产品规格、测试、双语 README、CHANGELOG 和发布清单。
