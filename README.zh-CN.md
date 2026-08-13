# Tinkora 社区健康文件仓库

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

这个特殊仓库维护 Tinkora 的公开组织简介、默认社区健康文件、可复用 GitHub Actions workflow
以及治理政策。

## 本仓库提供什么

- [`profile/`](profile/README.zh-CN.md) 中的组织简介。
- 供未自行定义文件的公开仓库继承的贡献、行为、安全和支持指南。
- 供未自行定义赞助选项的仓库继承的默认 Ko-fi 入口。
- 可被项目仓库继承的 Issue Forms 与 Pull Request 模板。
- 维护者、访问控制、发布、安全、生命周期和翻译政策。
- 架构决策，包括[源码发布边界](docs/decisions/0001-source-publication-boundary.md)。
- 以证据为门禁的产品立项记录，包括当前的
  [Agent 工作流痛点审查](docs/agent-workflow-pain-points-2026-08.zh-CN.md)。
- 经过评审的 Rust、WebAssembly、供应链、GitHub Pages 和候选发布验证 workflow。
- 永久只读的 [GitHub 设置审计](docs/SETTINGS_AUDIT.md)，用于核验已记录的组织与仓库控制。

## 仓库继承

GitHub 可以从公开的特殊 `.github` 仓库继承受支持的社区健康文件；项目仓库内的同名文件优先。
License 不会继承，每个项目都必须自行包含并核验 `LICENSE`。

## 项目

只有完成源码、文档、CI、安全和维护责任审查的仓库，才会列入组织简介。规划文档和本地原型不构成
公开产品承诺。

## 贡献与安全

提议变更前请阅读 [CONTRIBUTING.zh-CN.md](CONTRIBUTING.zh-CN.md)。请按照
[SECURITY.zh-CN.md](SECURITY.zh-CN.md) 私密报告漏洞，不要在公开 Issue、Pull Request 或
Discussions 中披露疑似漏洞。

## 许可证

本仓库原创内容采用 [MIT License](LICENSE)。第三方文档保留各自文件中声明的归属。
