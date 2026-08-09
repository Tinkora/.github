#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "psych"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").realpath
SCHEMA = ROOT.join("schemas/spdx-2.3.schema.json")
VALIDATOR_DIR = ROOT.join("scripts/spdx-validator")
VENDORED_SCHEMA_SHA256 = "3ec6cd5b8ba0c9a3e821da48536fa1b814567dc7e4376efe98d3e7b2a7a8d230"
errors = []

unless SCHEMA.file? && Digest::SHA256.file(SCHEMA).hexdigest == VENDORED_SCHEMA_SHA256
  errors << "SPDX 2.3 schema 缺失或 vendored SHA-256 不符"
end

workflow = Psych.safe_load(ROOT.join(".github/workflows/reusable-release.yml").read(encoding: "UTF-8"), aliases: false)
generator = workflow.fetch("jobs").fetch("prepare").fetch("steps")
  .find { |step| step["name"] == "Generate checksums, SBOM, and license evidence" }
  &.fetch("run")
raise "missing release evidence generator" unless generator

def validate_schema(schema, document)
  Open3.capture3(
    "npx", "--no-install", "--prefix", VALIDATOR_DIR.to_s, "ajv", "validate", "--spec=draft7",
    "--strict=false", "-s", schema.to_s, "-d", document.to_s
  )
end

Dir.mktmpdir("spdx-negative-") do |temporary|
  invalid = Pathname.new(temporary).join("missing-checksums.json")
  invalid.write(JSON.pretty_generate({
    "spdxVersion" => "SPDX-2.3",
    "dataLicense" => "CC0-1.0",
    "SPDXID" => "SPDXRef-DOCUMENT",
    "name" => "invalid",
    "creationInfo" => {"created" => "2026-08-08T00:00:00Z", "creators" => ["Tool: contract-test"]},
    "files" => [{"SPDXID" => "SPDXRef-File-1", "fileName" => "./asset"}]
  }) + "\n", encoding: "UTF-8")
  _stdout, _stderr, status = validate_schema(SCHEMA, invalid)
  errors << "官方 SPDX schema 应拒绝缺少 checksums 的 File" if status.success?
end

Dir.mktmpdir("spdx-generated-") do |temporary|
  runner_temp = Pathname.new(temporary)
  source = runner_temp.join("release-source")
  source.mkpath
  source.join("release-metadata.json").write("{\"commit\":\"#{"c" * 40}\",\"version\":\"1.2.3\"}\n", encoding: "UTF-8")
  source.join("tool.tar.gz").write("release asset\n", encoding: "UTF-8")
  env = {
    "COMMIT" => "c" * 40,
    "GITHUB_REPOSITORY" => "example-org/fixture",
    "GITHUB_RUN_ID" => "42",
    "GITHUB_SHA" => `git rev-parse HEAD`.strip,
    "GITHUB_WORKSPACE" => ROOT.to_s,
    "RUNNER_TEMP" => runner_temp.to_s,
    "VERSION" => "1.2.3"
  }
  _stdout, stderr, status = Open3.capture3(env, "bash", "-c", generator, chdir: ROOT.to_s)
  unless status.success?
    errors << "release SBOM generator 执行失败: #{stderr.strip}"
    next
  end

  sbom_path = runner_temp.join("release-candidate/SBOM.spdx.json")
  _schema_stdout, schema_stderr, schema_status = validate_schema(SCHEMA, sbom_path)
  errors << "生成 SBOM 未通过官方 SPDX 2.3 schema: #{schema_stderr.strip}" unless schema_status.success?
  next unless sbom_path.file?

  sbom = JSON.parse(sbom_path.read(encoding: "UTF-8"))
  files = Array(sbom["files"])
  unless files.map { |file| file["fileName"] } == ["./tool.tar.gz"]
    errors << "生成 SBOM 必须只描述实际 release assets"
  end
  asset = files.find { |file| file["fileName"] == "./tool.tar.gz" }
  unless asset && asset["checksums"]&.any? { |checksum| checksum["algorithm"] == "SHA256" } &&
      asset["licenseConcluded"] == "NOASSERTION" && asset["copyrightText"] == "NOASSERTION"
    errors << "生成 SBOM 缺少实际 asset 的 SHA256/licenseConcluded/copyrightText"
  end

  candidate = runner_temp.join("release-candidate")
  errors << "控制 metadata 不得复制到 release candidate" if candidate.join("release-metadata.json").exist?
  sums = candidate.join("SHA256SUMS").read(encoding: "UTF-8")
  errors << "SHA256SUMS 不得包含控制 metadata" if sums.include?("release-metadata.json")
  errors << "SHA256SUMS 必须包含实际 asset" unless sums.include?("tool.tar.gz")
  subjects = candidate.join("release-subjects")
  subject_files = subjects.directory? ? Dir.children(subjects).sort : []
  errors << "dry-run subjects 必须只包含实际 asset" unless subject_files == ["tool.tar.gz"]

  package = Array(sbom["packages"]).first
  expected_code = Digest::SHA1.hexdigest(Digest::SHA1.file(source.join("tool.tar.gz")).hexdigest)
  unless package&.dig("packageVerificationCode", "packageVerificationCodeValue") == expected_code
    errors << "packageVerificationCode 必须只基于实际 asset"
  end
end

if errors.empty?
  puts "SPDX SBOM contracts: OK"
  exit 0
end

warn errors.map { |error| "ERROR: #{error}" }.join("\n")
exit 1
