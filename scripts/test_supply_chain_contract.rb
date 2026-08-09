#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").realpath
errors = []

mutations = {
  "Cargo.lock requirement" => ['[[ -f "$WORKING_DIRECTORY/Cargo.lock" ]]', ""],
  "cargo-deny install" => ["cargo-deny --version 0.20.2 --locked", nil],
  "cargo-deny run" => ["cargo deny check advisories bans licenses sources", nil],
  "cargo-audit install" => ["cargo-audit --version 0.22.2 --locked", nil],
  "cargo-audit run" => ["cargo audit", nil],
  "ignored cargo-deny failure" => ["cargo deny check advisories bans licenses sources", "cargo deny check advisories bans licenses sources || true"],
  "ignored cargo-audit failure" => ["cargo audit", "cargo audit || true"]
}

mutations.each do |label, (token, replacement)|
  Dir.mktmpdir("supply-chain-contract-") do |temporary|
    test_root = Pathname.new(temporary)
    test_root.join("scripts").mkpath
    test_root.join(".github").mkpath
    FileUtils.cp(ROOT.join("scripts/check_workflows.rb"), test_root.join("scripts/check_workflows.rb"))
    FileUtils.cp_r(ROOT.join(".github/workflows"), test_root.join(".github/workflows"))
    workflow = test_root.join(".github/workflows/reusable-supply-chain.yml")
    lines = workflow.readlines(encoding: "UTF-8").filter_map do |line|
      next line unless line.include?(token)
      next if replacement.nil?

      line.sub(token, replacement)
    end
    workflow.write(lines.join, encoding: "UTF-8")
    _stdout, _stderr, status = Open3.capture3("ruby", test_root.join("scripts/check_workflows.rb").to_s)
    errors << "supply-chain 合约应拒绝缺少 #{label}" if status.success?
  end
end

if errors.empty?
  puts "supply-chain negative contracts: OK"
  exit 0
end

warn errors.map { |error| "ERROR: #{error}" }.join("\n")
exit 1
