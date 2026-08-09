# 为 Tinkora 贡献

[English](CONTRIBUTING.md)

感谢你帮助 Tinkora 的工具变得更可靠、更实用。

当前尚未开放公开互动。Issues 和 Discussions 保持关闭；在私密行为举报与管理前置条件通过验证前，
不会主动招揽外部贡献。本文件记录仓库未来明确开放这些通道后所适用的流程。

## 创建 Issue 前

1. 搜索已有 Issue，并用最新代码确认行为。
2. 从示例中移除凭据、个人数据、专有内容及其他敏感材料。
3. 选择与请求相符的结构化表单。项目提案必须包含真实用户工作流、替代方案、差异化、成功指标、
   停止条件和拟任维护者。
4. 不要用公开 Issue 报告疑似漏洞，请遵循 [SECURITY.zh-CN.md](SECURITY.zh-CN.md)。

Organization Discussions 和公开 Project 尚未配置；确认可用前不要链接或依赖这些通道。

## 语言

GitHub 可识别的默认入口和公开技术文档默认使用英文；持续维护的中文版本使用 `.zh-CN.md` 后缀，并在
文件顶部附近链接回英文默认版本。用户可见的要求、限制、命令或安全说明变化时，必须同步更新两种语言。

代码注释只使用英文。标识符、API 名称、文件名、命令、协议和引用的错误消息保留原始拼写。

Commit 的 subject 和 body 使用英文，并遵循
[Conventional Commits](https://www.conventionalcommits.org/)；仓库如定义了更严格格式，以仓库规则为准。

## Pull Request

每个 Pull Request 应只聚焦一个完整结果。关联相应 Issue，说明范围和非目标，并记录准确的验证命令。
用户可见语义变化时同步更新中英文文档；重要变更还需更新 [CHANGELOG.md](CHANGELOG.md)。

外部变更使用 Pull Request，并且必须通过仓库检查。Solo 维护阶段由 Owner 直接在 `main` 开发，
不配置唯一 Owner 无法满足的 required approval；这不降低本地评审和验证要求。只有满足
[docs/ACCESS_MODEL.md](docs/ACCESS_MODEL.md) 中的访问前置条件后，才能启用多人批准和 CODEOWNERS 要求。

## 质量要求

- 为行为变更添加面向结果的测试。
- 保持向后兼容，或记录迁移与弃用方式。
- 说明安全、隐私、无障碍和数据保留影响。
- 沿用项目约定，避免无关重构。
- 没有可复现证据时，不得声称已发布、稳定、部署或可由 Agent 调用。
- HTML 或其他用户可见前端必须遵循
  [docs/PROJECT_LIFECYCLE.md](docs/PROJECT_LIFECYCLE.md) 中可审核的 `ui-ux-pro-max` 门禁。

参与即表示你同意遵守 [CODE_OF_CONDUCT.zh-CN.md](CODE_OF_CONDUCT.zh-CN.md)。
