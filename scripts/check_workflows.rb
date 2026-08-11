#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "psych"

ROOT = Pathname.new(__dir__).join("..").realpath
WORKFLOW_DIR = ROOT.join(".github/workflows")

ACTION_PINS = {
  "actions/checkout" => ["3d3c42e5aac5ba805825da76410c181273ba90b1", "v7.0.1"],
  "actions/setup-node" => ["820762786026740c76f36085b0efc47a31fe5020", "v7.0.0"],
  "actions/cache" => ["55cc8345863c7cc4c66a329aec7e433d2d1c52a9", "v6.1.0"],
  "actions/upload-artifact" => ["043fb46d1a93c77aae656e7c1c64a875d1fc6a0a", "v7.0.1"],
  "actions/download-artifact" => ["3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c", "v8.0.1"],
  "actions/configure-pages" => ["45bfe0192ca1faeb007ade9deae92b16b8254a0d", "v6.0.0"],
  "actions/upload-pages-artifact" => ["fc324d3547104276b827a68afc52ff2a11cc49c9", "v5.0.0"],
  "actions/deploy-pages" => ["cd2ce8fcbc39b97be8ca5fce6e763baed58fa128", "v5.0.0"],
  "actions/attest" => ["1e69f48acb82d1966a394da916b4c1698aa569d6", "v4.2.2"],
  "DavidAnson/markdownlint-cli2-action" => ["21c1be1b93ad9ed58fa840aacc3f279cde2a72ff", "v24.2.0"],
  "zizmorcore/zizmor-action" => ["3dc1ecc9bcb9e94e9b2c709687979e1298497054", "v0.6.2"]
}.freeze

WORKFLOWS = {
  "docs-quality.yml" => nil,
  "governance-audit.yml" => nil,
  "reusable-rust-quality.yml" => %w[working-directory toolchain features target locked msrv coverage],
  "reusable-wasm-quality.yml" => %w[working-directory toolchain features locked playwright-smoke node-version],
  "reusable-supply-chain.yml" => %w[working-directory toolchain],
  "reusable-pages.yml" => %w[source-artifact-name source-subdirectory],
  "reusable-release.yml" => %w[source-artifact-name version publish]
}.freeze

errors = []

def load_yaml(path, errors)
  text = path.binread
  unless text.force_encoding(Encoding::UTF_8).valid_encoding?
    errors << "#{path.relative_path_from(ROOT)}: 不是有效 UTF-8"
    return nil
  end

  Psych.safe_load(text, permitted_classes: [], permitted_symbols: [], aliases: false)
rescue Psych::SyntaxError => e
  errors << "#{path.relative_path_from(ROOT)}: YAML 解析失败: #{e.message.lines.first.strip}"
  nil
end

WORKFLOWS.each do |name, allowed_inputs|
  path = WORKFLOW_DIR.join(name)
  unless path.file?
    errors << "缺少工作流: .github/workflows/#{name}"
    next
  end

  document = load_yaml(path, errors)
  next unless document.is_a?(Hash)

  unless document["permissions"] == {"contents" => "read"}
    errors << "#{name}: 顶层 permissions 必须仅为 contents: read"
  end

  text = path.read(encoding: "UTF-8")
  errors << "#{name}: 禁止 secrets: inherit" if text.match?(/^\s*secrets:\s*inherit\s*$/)
  errors << "#{name}: 禁止 pull_request_target" if text.include?("pull_request_target:")
  errors << "#{name}: 禁止接受任意 shell command 输入" if text.match?(/^\s{6,}(?:test|clippy|build)-command:/)

  text.each_line.with_index(1) do |line, line_number|
    match = line.match(/^\s*uses:\s*([^\s@]+)@([0-9a-f]{40})\s+#\s+(v\d+\.\d+\.\d+)\s*$/)
    next unless line.include?("uses:") && !line.include?("./")

    unless match
      errors << "#{name}:#{line_number}: Action 必须固定完整 SHA 并保留精确 tag 注释"
      next
    end

    action, sha, tag = match.captures
    expected = ACTION_PINS[action]
    errors << "#{name}:#{line_number}: 未登记 Action #{action}" unless expected
    errors << "#{name}:#{line_number}: #{action} pin 应为 #{expected.join(" # ")}" if expected && expected != [sha, tag]
  end

  checkout_count = text.scan(%r{uses:\s*actions/checkout@}).length
  hardened_checkout_count = text.scan(/persist-credentials:\s*false/).length
  if checkout_count != hardened_checkout_count
    errors << "#{name}: 每个 checkout step 都必须设置 persist-credentials: false"
  end

  document.fetch("jobs", {}).each do |job_name, job|
    job.fetch("steps", []).each do |step|
      next unless step.fetch("uses", "").start_with?("actions/upload-artifact@")

      settings = step.fetch("with", {})
      artifact_name = settings.fetch("name", "")
      location = "#{name}:#{job_name}:#{step.fetch("name", "unnamed")}"
      errors << "#{location}: artifact 名禁止依赖 run_attempt" if artifact_name.include?("github.run_attempt")
      errors << "#{location}: 必须设置 overwrite: true 支持全量重跑" unless settings["overwrite"] == true
    end
  end

  next unless allowed_inputs

  call = document.dig("on", "workflow_call")
  unless call.is_a?(Hash)
    errors << "#{name}: 必须仅通过 workflow_call 暴露可复用入口"
    next
  end

  actual_inputs = call.fetch("inputs", {})
  unless actual_inputs.is_a?(Hash) && actual_inputs.keys.sort == allowed_inputs.sort
    errors << "#{name}: inputs 必须精确为 #{allowed_inputs.join(", ")}"
    next
  end

  actual_inputs.each do |input_name, definition|
    type = definition.is_a?(Hash) && definition["type"]
    errors << "#{name}: input #{input_name} 缺少受支持 type" unless %w[boolean number string].include?(type)
  end
end

if (path = WORKFLOW_DIR.join("reusable-rust-quality.yml")).file?
  text = path.read(encoding: "UTF-8")
  {
    "固定 fmt" => "fmt --all -- --check",
    "固定 clippy" => "clippy \"${cargo_args[@]}\" --all-targets -- -D warnings",
    "固定 test" => "test \"${cargo_args[@]}\" --all-targets",
    "MSRV job" => "inputs.msrv != ''",
    "空 features 分支" => "FEATURES",
    "固定 CI 工具链" => "CI_TOOLCHAIN: 1.95.0",
    "独立安装 cargo-llvm-cov" => 'cargo "+${CI_TOOLCHAIN}" install cargo-llvm-cov --version 0.8.7 --locked',
    "项目工具链运行 coverage" => 'cargo "+${TOOLCHAIN}" llvm-cov'
  }.each { |label, token| errors << "reusable-rust-quality.yml: 缺少#{label}" unless text.include?(token) }
  if text.scan("working-directory escapes the workspace").length < 3
    errors << "reusable-rust-quality.yml: primary、MSRV、coverage 都必须校验 realpath 工作区边界"
  end
end

if (path = WORKFLOW_DIR.join("reusable-wasm-quality.yml")).file?
  text = path.read(encoding: "UTF-8")
  {
    "固定 wasm32 target" => "wasm32-unknown-unknown",
    "固定 wasm-pack 版本" => "wasm-pack --version 0.15.0 --locked",
    "固定 CI 工具链" => "CI_TOOLCHAIN: 1.95.0",
    "独立安装 wasm-pack" => 'cargo "+${CI_TOOLCHAIN}" install wasm-pack --version 0.15.0 --locked',
    "wasm-pack 内部 Rust toolchain" => 'export RUSTUP_TOOLCHAIN="$TOOLCHAIN"',
    "固定 smoke script" => "npm run test:wasm-smoke",
    "Chromium 安装" => "playwright install --with-deps chromium",
    "输出白名单" => "unexpected WASM output"
  }.each { |label, token| errors << "reusable-wasm-quality.yml: 缺少#{label}" unless text.include?(token) }
  if text.scan("working-directory escapes the workspace").length < 2
    errors << "reusable-wasm-quality.yml: build 与 smoke 都必须校验 realpath 工作区边界"
  end
  if text.scan("special files are forbidden in WASM").length < 2
    errors << "reusable-wasm-quality.yml: build 与 smoke 输出都必须拒绝特殊节点"
  end
  artifact_name = 'wasm-package-${{ github.run_id }}'
  unless text.scan(artifact_name).length == 2
    errors << "reusable-wasm-quality.yml: 上传和下载 artifact 名必须仅使用稳定的 run_id"
  end
  errors << "reusable-wasm-quality.yml: 禁止 curl | sh" if text.match?(/curl\b.*\|\s*(?:ba)?sh/)
end

if (path = WORKFLOW_DIR.join("reusable-supply-chain.yml")).file?
  text = path.read(encoding: "UTF-8")
  {
    "Cargo.lock 前置条件" => '[[ -f "$WORKING_DIRECTORY/Cargo.lock" ]]',
    "固定 cargo-deny 安装" => "cargo-deny --version 0.20.2 --locked",
    "固定 cargo-audit 安装" => "cargo-audit --version 0.22.2 --locked"
  }.each { |label, token| errors << "reusable-supply-chain.yml: 缺少#{label}" unless text.include?(token) }
  unless text.match?(/^\s+cargo deny check advisories bans licenses sources\s*$/)
    errors << "reusable-supply-chain.yml: cargo-deny 必须以裸命令保留失败退出码"
  end
  unless text.match?(/^\s+cargo audit\s*$/)
    errors << "reusable-supply-chain.yml: cargo-audit 必须以裸命令保留失败退出码"
  end
end

if (path = WORKFLOW_DIR.join("reusable-pages.yml")).file?
  text = path.read(encoding: "UTF-8")
  {
    "独立下载" => "actions/download-artifact@",
    "标准 Pages artifact" => "actions/upload-pages-artifact@",
    "Pages 部署" => "actions/deploy-pages@",
    "拒绝 symlink" => "-type l",
    "部署 job pages 权限" => "pages: write",
    "部署 job OIDC 权限" => "id-token: write",
    "PR 部署门禁" => "github.event_name != 'pull_request'"
  }.each { |label, token| errors << "reusable-pages.yml: 缺少#{label}" unless text.include?(token) }
end

if (path = WORKFLOW_DIR.join("reusable-release.yml")).file?
  text = path.read(encoding: "UTF-8")
  release_workflow = load_yaml(path, errors)
  publish_default = release_workflow&.dig("on", "workflow_call", "inputs", "publish", "default")
  errors << "reusable-release.yml: publish 必须默认 false" unless publish_default == false
  unless release_workflow&.fetch("jobs", {})&.keys == ["prepare"]
    errors << "reusable-release.yml: Solo 版本必须只有只读 prepare job"
  end
  {
    "完整 SemVer 验证" => "SEMVER_PATTERN",
    "tag/commit/version 元数据" => "release-metadata.json",
    "publish 永久拒绝" => "publication is unavailable in this workflow version",
    "控制 metadata 排除" => "! -name release-metadata.json",
    "SHA256SUMS" => "SHA256SUMS",
    "SPDX SBOM" => "SBOM.spdx.json",
    "许可清单" => "LICENSES.json",
    "dry-run subjects" => "release-subjects"
  }.each { |label, token| errors << "reusable-release.yml: 缺少#{label}" unless text.include?(token) }
  %w[actions/attest@ RELEASE_AUTOMATION_AUTHORIZED].each do |token|
    errors << "reusable-release.yml: Solo 版本禁止 #{token}" if text.include?(token)
  end
  ["gh release create", "contents: write", "id-token: write", "attestations: write", "artifact-metadata: write", "environment: release"].each do |token|
    errors << "reusable-release.yml: Solo 版本禁止写路径 #{token}" if text.include?(token)
  end
end

if (path = WORKFLOW_DIR.join("governance-audit.yml")).file?
  text = path.read(encoding: "UTF-8")
  {
    "完整仓库合约" => "scripts/check_all.sh",
    "固定 Node.js setup" => "actions/setup-node@820762786026740c76f36085b0efc47a31fe5020 # v7.0.0",
    "锁定 npm 安装" => "npm ci --ignore-scripts --prefix scripts/spdx-validator",
    "离线 npx 验证" => "npx --no-install",
    "固定 Rust" => "rustup toolchain install 1.88.0 --profile minimal --no-self-update"
  }.each { |label, token| errors << "governance-audit.yml: 缺少#{label}" unless text.include?(token) }
  validator_dir = ROOT.join("scripts/spdx-validator")
  errors << "governance-audit.yml: 缺少固定 SPDX validator package.json" unless validator_dir.join("package.json").file?
  errors << "governance-audit.yml: 缺少固定 SPDX validator package-lock.json" unless validator_dir.join("package-lock.json").file?
end

dependabot_path = ROOT.join(".github/dependabot.yml")
if dependabot_path.file?
  dependabot = load_yaml(dependabot_path, errors)
  actions_update = dependabot&.fetch("updates", [])&.find do |update|
    update.is_a?(Hash) && update["package-ecosystem"] == "github-actions"
  end
  unless actions_update&.dig("cooldown", "default-days") == 7
    errors << "dependabot.yml: github-actions version updates 必须使用 7 天 cooldown"
  end
end

if errors.empty?
  puts "workflow contracts: OK (#{WORKFLOWS.length} workflows)"
  exit 0
end

warn errors.map { |error| "ERROR: #{error}" }.join("\n")
exit 1
