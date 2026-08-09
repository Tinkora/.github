#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "uri"

ROOT = Pathname.new(__dir__).join("..").realpath
errors = []

required_files = %w[
  README.md README.zh-CN.md LICENSE CHANGELOG.md CODE_OF_CONDUCT.md
  CODE_OF_CONDUCT.zh-CN.md CONTRIBUTING.md CONTRIBUTING.zh-CN.md GOVERNANCE.md
  SECURITY.md SECURITY.zh-CN.md SUPPORT.md SUPPORT.zh-CN.md MAINTAINERS.md
  docs/ACCESS_MODEL.md docs/RELEASE_POLICY.md docs/SECURITY_OPERATIONS.md
  docs/TRANSLATION_POLICY.md docs/WORKFLOWS.md docs/PROJECT_LIFECYCLE.md
  docs/decisions/0001-source-publication-boundary.md
]

bilingual_pairs = %w[
  README profile/README CODE_OF_CONDUCT CONTRIBUTING SECURITY SUPPORT
].map { |stem| ["#{stem}.md", "#{stem}.zh-CN.md"] }

governance_tables = %w[
  GOVERNANCE.md docs/ACCESS_MODEL.md docs/RELEASE_POLICY.md
  docs/SECURITY_OPERATIONS.md
]

required_files.each do |relative|
  errors << "缺少必需文件: #{relative}" unless ROOT.join(relative).file?
end

bilingual_pairs.each do |english, chinese|
  errors << "缺少双语文件对: #{english} / #{chinese}" unless ROOT.join(english).file? && ROOT.join(chinese).file?
end

frontend_policy = ROOT.join("docs/PROJECT_LIFECYCLE.md").read(encoding: "UTF-8")
%w[ui-ux-pro-max --design-system stack UX 375 768 1024 1440 console keyboard accessibility overflow AGENTS.md].each do |marker|
  errors << "docs/PROJECT_LIFECYCLE.md: 缺少前端门禁 #{marker}" unless frontend_policy.include?(marker)
end

governance_tables.each do |relative|
  path = ROOT.join(relative)
  next unless path.file?

  text = path.binread.force_encoding(Encoding::UTF_8)
  header = "| Setting | Current | Target | Apply when |"
  errors << "#{relative}: 治理表缺少 Current/Target/Apply when 三字段" unless text.include?(header)
end

text_files = Dir.glob(ROOT.join("**/*"), File::FNM_DOTMATCH).filter_map do |entry|
  path = Pathname.new(entry)
  next unless path.file?
  next if path.to_s.include?("/.git/")
  next if path.to_s.include?("/node_modules/")
  next unless %w[.md .yml .yaml .json .jsonc .rb .sh].include?(path.extname) || path.basename.to_s == "LICENSE"

  path
end


text_files.each do |path|
  relative = path.relative_path_from(ROOT)
  bytes = path.binread
  errors << "#{relative}: 禁止 UTF-8 BOM" if bytes.start_with?("\xEF\xBB\xBF".b)
  text = bytes.force_encoding(Encoding::UTF_8)
  unless text.valid_encoding?
    errors << "#{relative}: 不是有效 UTF-8"
    next
  end
  next unless path.extname == ".md"

  text.scan(/!?\[[^\]]*\]\((<[^>]+>|[^\s)]+)(?:\s+["'][^"']*["'])?\)/).each do |capture|
    raw_target = capture.first
    raw_target = raw_target[1..-2] if raw_target.start_with?("<") && raw_target.end_with?(">")
    next if raw_target.empty? || raw_target.start_with?("#")
    next if raw_target.match?(%r{\A(?:https?|mailto):}i)

    begin
      decoded = URI::DEFAULT_PARSER.unescape(raw_target.split("#", 2).first)
    rescue ArgumentError
      errors << "#{relative}: 无法解析本地链接 #{raw_target.inspect}"
      next
    end
    next if decoded.empty?

    resolved = path.dirname.join(decoded).cleanpath.expand_path
    unless resolved.to_s == ROOT.to_s || resolved.to_s.start_with?("#{ROOT}/")
      errors << "#{relative}: 本地链接越界 #{raw_target.inspect}"
      next
    end
    errors << "#{relative}: 本地链接不存在 #{raw_target.inspect}" unless resolved.exist?
  end
end

bilingual_pairs.each do |english, chinese|
  next unless ROOT.join(english).file? && ROOT.join(chinese).file?

  english_head = ROOT.join(english).read(encoding: "UTF-8").lines.first(12).join
  chinese_head = ROOT.join(chinese).read(encoding: "UTF-8").lines.first(12).join
  errors << "#{english}: 文件开头缺少中文入口" unless english_head.include?(File.basename(chinese))
  errors << "#{chinese}: 文件开头缺少英文入口" unless chinese_head.include?(File.basename(english))
end

if errors.empty?
  puts "documentation contracts: OK (#{text_files.length} UTF-8 text files)"
  exit 0
end

warn errors.map { |error| "ERROR: #{error}" }.join("\n")
exit 1
