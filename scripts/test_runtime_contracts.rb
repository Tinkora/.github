#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "pathname"
require "psych"
require "socket"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").realpath
WORKFLOW_DIR = ROOT.join(".github/workflows")
errors = []

def step_definition(workflow, job, step_name, directory: WORKFLOW_DIR)
  document = Psych.safe_load(directory.join(workflow).read(encoding: "UTF-8"), aliases: false)
  step = document.fetch("jobs").fetch(job).fetch("steps").find { |candidate| candidate["name"] == step_name }
  raise "missing step #{workflow}:#{job}:#{step_name}" unless step

  step
end

def step_script(workflow, job, step_name, directory: WORKFLOW_DIR)
  step_definition(workflow, job, step_name, directory: directory).fetch("run")
end

def step_environment(workflow, job, step_name, directory: WORKFLOW_DIR)
  step_definition(workflow, job, step_name, directory: directory).fetch("env", {})
end

def run_script(script, env:, directory:)
  Open3.capture3(env, "bash", "-c", script, chdir: directory.to_s)
end

def write_stub(directory, name, body = ":")
  path = Pathname.new(directory).join(name)
  path.write("#!/usr/bin/env bash\nset -euo pipefail\n#{body}\n", encoding: "UTF-8")
  path.chmod(0o755)
end

begin
  release_dry_run = step_script("reusable-release.yml", "prepare", "Reject publication requests")
rescue RuntimeError => e
  errors << "Release workflow 缺少永久 dry-run 门禁: #{e.message}"
else
  _stdout, stderr, status = run_script(release_dry_run, env: {"PUBLISH" => "false"}, directory: ROOT)
  errors << "Release dry-run 应接受 publish=false: #{stderr.strip}" unless status.success?
  _stdout, stderr, status = run_script(release_dry_run, env: {"PUBLISH" => "true"}, directory: ROOT)
  unless !status.success? && stderr.include?("publication is unavailable in this workflow version")
    errors << "Release dry-run 应明确拒绝 publish=true"
  end
end

release_identity = step_script("reusable-release.yml", "prepare", "Validate release identity")
semver_assignment = release_identity.lines.find { |line| line.lstrip.start_with?("SEMVER_PATTERN=") }
raise "release workflow does not define SEMVER_PATTERN" unless semver_assignment
semver_check = "set -euo pipefail\n#{semver_assignment}\n[[ \"$VERSION\" =~ $SEMVER_PATTERN ]]\n"

valid_semvers = %w[
  0.0.0 1.2.3 10.20.30 1.0.0-alpha 1.0.0-alpha.1
  1.0.0-0.3.7 1.0.0-x.7.z.92 1.0.0+build.1 1.0.0-alpha+001
]
invalid_semvers = %w[
  v1.2.3 1.2 1.2.3.4 01.2.3 1.02.3 1.2.03 1.2.3- 1.2.3-01
  1.2.3+ 1.2.3+build..1
]

valid_semvers.each do |version|
  _stdout, stderr, status = run_script(semver_check, env: {"VERSION" => version}, directory: ROOT)
  errors << "SemVer 应接受 #{version}: #{stderr.strip}" unless status.success?
end
invalid_semvers.each do |version|
  _stdout, _stderr, status = run_script(semver_check, env: {"VERSION" => version}, directory: ROOT)
  errors << "SemVer 应拒绝 #{version}" if status.success?
end

pages_contract = step_script("reusable-pages.yml", "prepare-pages-artifact", "Validate artifact contract")
[["site", "."], ["site-1.2", "public/assets"]].each do |name, subdirectory|
  _stdout, stderr, status = run_script(
    pages_contract,
    env: {"SOURCE_ARTIFACT_NAME" => name, "SOURCE_SUBDIRECTORY" => subdirectory},
    directory: ROOT
  )
  errors << "Pages 合约应接受 #{name.inspect}/#{subdirectory.inspect}: #{stderr.strip}" unless status.success?
end
[["", "."], ["..", "."], ["site", ""], ["site", "/"], ["site", "../public"], ["site", "public/../private"]].each do |name, subdirectory|
  _stdout, _stderr, status = run_script(
    pages_contract,
    env: {"SOURCE_ARTIFACT_NAME" => name, "SOURCE_SUBDIRECTORY" => subdirectory},
    directory: ROOT
  )
  errors << "Pages 合约应拒绝 #{name.inspect}/#{subdirectory.inspect}" if status.success?
end

pages_tree = step_script("reusable-pages.yml", "prepare-pages-artifact", "Validate downloaded tree")
Dir.mktmpdir("pages-contract-") do |temporary|
  source = Pathname.new(temporary).join("pages-source")
  source.join("public").mkpath
  source.join("public/index.html").write("ok", encoding: "UTF-8")
  _stdout, stderr, status = run_script(
    pages_tree,
    env: {"RUNNER_TEMP" => temporary, "SOURCE_SUBDIRECTORY" => "public"},
    directory: ROOT
  )
  errors << "Pages tree 应接受普通站点目录: #{stderr.strip}" unless status.success?
end
Dir.mktmpdir("pages-contract-") do |temporary|
  source = Pathname.new(temporary).join("pages-source")
  source.join("public").mkpath
  File.symlink("public", source.join("linked"))
  _stdout, _stderr, status = run_script(
    pages_tree,
    env: {"RUNNER_TEMP" => temporary, "SOURCE_SUBDIRECTORY" => "."},
    directory: ROOT
  )
  errors << "Pages tree 应拒绝 symlink" if status.success?
end
Dir.mktmpdir("pages-contract-") do |temporary|
  Pathname.new(temporary).join("pages-source/public").mkpath
  _stdout, _stderr, status = run_script(
    pages_tree,
    env: {"RUNNER_TEMP" => temporary, "SOURCE_SUBDIRECTORY" => "public"},
    directory: ROOT
  )
  errors << "Pages tree 应拒绝空目录" if status.success?
end

coverage = step_script("reusable-rust-quality.yml", "coverage", "Generate LCOV")
unless step_environment("reusable-rust-quality.yml", "coverage", "Generate LCOV")["CI_TOOLCHAIN"] == "1.95.0"
  errors << "Coverage must define the fixed CI toolchain on the step that installs cargo-llvm-cov"
end
Dir.mktmpdir("coverage-toolchain-contract-") do |temporary|
  workspace = Pathname.new(temporary).join("workspace")
  workspace.join("crate").mkpath
  workspace = workspace.realpath
  bin = Pathname.new(temporary).join("bin")
  bin.mkpath
  cargo_capture = Pathname.new(temporary).join("cargo-commands")
  rustup_capture = Pathname.new(temporary).join("rustup-commands")
  write_stub(bin, "cargo", 'printf "%s\n" "$*" >> "$CARGO_CAPTURE"')
  write_stub(bin, "rustup", 'printf "%s\n" "$*" >> "$RUSTUP_CAPTURE"')
  env = {
    "CARGO_CAPTURE" => cargo_capture.to_s,
    "CI_TOOLCHAIN" => "1.95.0",
    "FEATURES" => "",
    "GITHUB_WORKSPACE" => workspace.to_s,
    "LOCKED" => "true",
    "PATH" => "#{bin}:#{ENV.fetch("PATH")}",
    "RUNNER_TEMP" => temporary,
    "RUSTUP_CAPTURE" => rustup_capture.to_s,
    "TARGET" => "",
    "TOOLCHAIN" => "1.85.0",
    "WORKING_DIRECTORY" => "crate"
  }
  _stdout, stderr, status = run_script(coverage, env: env, directory: workspace)
  cargo_commands = cargo_capture.file? ? cargo_capture.readlines(chomp: true) : []
  rustup_commands = rustup_capture.file? ? rustup_capture.readlines(chomp: true) : []
  unless status.success? &&
         cargo_commands.include?("+1.95.0 install cargo-llvm-cov --version 0.8.7 --locked") &&
         cargo_commands.any? { |command| command.start_with?("+1.85.0 llvm-cov ") } &&
         rustup_commands.include?("toolchain install 1.95.0 --profile minimal --no-self-update")
    errors << "Coverage tooling must compile with the fixed CI toolchain while coverage uses the project toolchain: #{stderr.strip}"
  end
end

wasm_build = step_script("reusable-wasm-quality.yml", "wasm-build", "Build WASM package")
unless step_environment("reusable-wasm-quality.yml", "wasm-build", "Build WASM package")["CI_TOOLCHAIN"] == "1.95.0"
  errors << "WASM build must define the fixed CI toolchain on the step that installs wasm-pack"
end
Dir.mktmpdir("wasm-toolchain-contract-") do |temporary|
  workspace = Pathname.new(temporary).join("workspace")
  workspace.join("crate").mkpath
  workspace = workspace.realpath
  bin = Pathname.new(temporary).join("bin")
  bin.mkpath
  capture = Pathname.new(temporary).join("toolchain")
  cargo_capture = Pathname.new(temporary).join("cargo-commands")
  rustup_capture = Pathname.new(temporary).join("rustup-commands")
  write_stub(bin, "rustup", 'printf "%s\n" "$*" >> "$RUSTUP_CAPTURE"')
  write_stub(bin, "cargo", 'printf "%s\n" "$*" >> "$CARGO_CAPTURE"')
  write_stub(bin, "wasm-pack", 'printf "%s" "${RUSTUP_TOOLCHAIN-}" > "$TOOLCHAIN_CAPTURE"')
  env = {
    "CARGO_CAPTURE" => cargo_capture.to_s,
    "CI_TOOLCHAIN" => "1.95.0",
    "FEATURES" => "",
    "GITHUB_WORKSPACE" => workspace.to_s,
    "LOCKED" => "false",
    "PATH" => "#{bin}:#{ENV.fetch("PATH")}",
    "RUNNER_TEMP" => temporary,
    "RUSTUP_CAPTURE" => rustup_capture.to_s,
    "RUSTUP_TOOLCHAIN" => nil,
    "TOOLCHAIN" => "1.85.0",
    "TOOLCHAIN_CAPTURE" => capture.to_s,
    "WORKING_DIRECTORY" => "crate"
  }
  _stdout, stderr, status = run_script(wasm_build, env: env, directory: workspace)
  cargo_commands = cargo_capture.file? ? cargo_capture.readlines(chomp: true) : []
  rustup_commands = rustup_capture.file? ? rustup_capture.readlines(chomp: true) : []
  unless status.success? &&
         capture.file? && capture.read == "1.85.0" &&
         cargo_commands.include?("+1.95.0 install wasm-pack --version 0.15.0 --locked") &&
         rustup_commands.include?("toolchain install 1.95.0 --profile minimal --no-self-update")
    errors << "wasm-pack tooling must compile with the fixed CI toolchain while builds use the project toolchain: #{stderr.strip}"
  end
end

msrv = step_script("reusable-rust-quality.yml", "msrv", "Check with the declared MSRV")
wasm_smoke_path = step_script("reusable-wasm-quality.yml", "playwright-smoke", "Validate Node.js and project path")
Dir.mktmpdir("working-directory-escape-") do |temporary|
  workspace = Pathname.new(temporary).join("workspace")
  outside = Pathname.new(temporary).join("outside")
  crate = outside.join("crate")
  workspace.mkpath
  crate.mkpath
  workspace = workspace.realpath
  outside = outside.realpath
  crate = outside.join("crate")
  crate.join("package.json").write("{}\n", encoding: "UTF-8")
  crate.join("package-lock.json").write("{}\n", encoding: "UTF-8")
  File.symlink(outside, workspace.join("bridge"))
  bin = Pathname.new(temporary).join("bin")
  bin.mkpath
  write_stub(bin, "rustup")
  write_stub(bin, "cargo")
  common = {
    "FEATURES" => "fixture",
    "GITHUB_WORKSPACE" => workspace.to_s,
    "LOCKED" => "false",
    "PATH" => "#{bin}:#{ENV.fetch("PATH")}",
    "RUNNER_TEMP" => temporary,
    "TARGET" => "",
    "WORKING_DIRECTORY" => "bridge/crate"
  }
  [
    ["MSRV", msrv, common.merge("MSRV" => "1.88.0")],
    ["coverage", coverage, common.merge("TOOLCHAIN" => "stable")],
    ["WASM smoke", wasm_smoke_path, common.merge("NODE_VERSION" => "24")]
  ].each do |label, script, env|
    _stdout, stderr, status = run_script(script, env: env, directory: workspace)
    if status.success?
      errors << "#{label} 应拒绝中间 symlink 逃逸工作区"
    elsif !stderr.include?("working-directory escapes the workspace")
      errors << "#{label} 未以 realpath 工作区边界拒绝逃逸: #{stderr.strip}"
    end
  end
end

wasm_output = step_script("reusable-wasm-quality.yml", "wasm-build", "Enforce output whitelist")
Dir.mktmpdir("wasm-output-standard-") do |temporary|
  output = Pathname.new(temporary).join("wasm-pkg")
  output.mkpath
  %w[.gitignore package.json template_web.d.ts template_web.js template_web_bg.wasm template_web_bg.wasm.d.ts].each do |name|
    output.join(name).write("fixture\n", encoding: "UTF-8")
  end
  _stdout, stderr, status = run_script(wasm_output, env: {"RUNNER_TEMP" => temporary}, directory: ROOT)
  errors << "WASM build 输出应接受标准 wasm-pack 文件: #{stderr.strip}" unless status.success?
end

Dir.mktmpdir("wasm-output-special-") do |temporary|
  output = Pathname.new(temporary).join("wasm-pkg")
  output.mkpath
  output.join("package.json").write("{}\n", encoding: "UTF-8")
  system("mkfifo", output.join("control.pipe").to_s, exception: true)
  _stdout, _stderr, status = run_script(wasm_output, env: {"RUNNER_TEMP" => temporary}, directory: ROOT)
  errors << "WASM build 输出应拒绝 FIFO" if status.success?
end

wasm_smoke = step_script("reusable-wasm-quality.yml", "playwright-smoke", "Run fixed Chromium smoke test")
Dir.mktmpdir("wasm-smoke-special-", "/tmp") do |temporary|
  workspace = Pathname.new(temporary).join("workspace")
  project = workspace.join("project")
  package = Pathname.new(temporary).join("wasm-smoke-package")
  bin = Pathname.new(temporary).join("bin")
  project.mkpath
  package.mkpath
  bin.mkpath
  write_stub(bin, "npm")
  write_stub(bin, "npx")
  socket = UNIXServer.new(package.join("control.sock").to_s)
  env = {
    "PATH" => "#{bin}:#{ENV.fetch("PATH")}",
    "WASM_SMOKE_PACKAGE" => package.to_s,
    "WORKING_DIRECTORY" => "project"
  }
  _stdout, _stderr, status = run_script(wasm_smoke, env: env, directory: workspace)
  errors << "WASM smoke 输出应拒绝 socket" if status.success?
ensure
  socket&.close
end

release_tree = step_script("reusable-release.yml", "prepare", "Validate artifact metadata and paths")
release_env = {"GITHUB_SHA" => "a" * 40, "VERSION" => "1.2.3"}

def write_release_metadata(directory, env)
  Pathname.new(directory).join("release-metadata.json").write(
    JSON.generate({"commit" => env.fetch("GITHUB_SHA"), "version" => env.fetch("VERSION")}),
    encoding: "UTF-8"
  )
end

Dir.mktmpdir("release-contract-") do |temporary|
  source = Pathname.new(temporary).join("release-source")
  source.mkpath
  write_release_metadata(source, release_env)
  source.join("tool.tar.gz").write("asset", encoding: "UTF-8")
  _stdout, stderr, status = run_script(release_tree, env: release_env.merge("RUNNER_TEMP" => temporary), directory: ROOT)
  errors << "Release tree 应接受安全的具名资产: #{stderr.strip}" unless status.success?
end
Dir.mktmpdir("release-contract-") do |temporary|
  source = Pathname.new(temporary).join("release-source")
  source.mkpath
  write_release_metadata(source, release_env)
  _stdout, _stderr, status = run_script(release_tree, env: release_env.merge("RUNNER_TEMP" => temporary), directory: ROOT)
  errors << "Release tree 应拒绝没有实际 release asset 的 artifact" if status.success?
end
Dir.mktmpdir("release-contract-") do |temporary|
  source = Pathname.new(temporary).join("release-source")
  source.join("nested").mkpath
  write_release_metadata(source, release_env)
  source.join("nested/tool").write("asset", encoding: "UTF-8")
  _stdout, _stderr, status = run_script(release_tree, env: release_env.merge("RUNNER_TEMP" => temporary), directory: ROOT)
  errors << "Release tree 应拒绝嵌套资产" if status.success?
end
Dir.mktmpdir("release-contract-") do |temporary|
  source = Pathname.new(temporary).join("release-source")
  source.mkpath
  write_release_metadata(source, release_env)
  source.join("target").write("asset", encoding: "UTF-8")
  File.symlink("target", source.join("linked"))
  _stdout, _stderr, status = run_script(release_tree, env: release_env.merge("RUNNER_TEMP" => temporary), directory: ROOT)
  errors << "Release tree 应拒绝 symlink" if status.success?
end

if errors.empty?
  puts "runtime workflow contracts: OK"
  exit 0
end

warn errors.map { |error| "ERROR: #{error}" }.join("\n")
exit 1
