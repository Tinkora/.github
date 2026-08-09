#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "pathname"
require "ripper"

class LanguagePolicyTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("..").realpath
  HAN = /[\u3400-\u4dbf\u4e00-\u9fff]/

  def test_english_entry_points_link_to_chinese_peers
    {
      "README.md" => "README.zh-CN.md",
      "profile/README.md" => "README.zh-CN.md"
    }.each do |english, chinese|
      head = ROOT.join(english).read(encoding: "UTF-8").lines.first(12).join
      assert_includes head, chinese, english
    end
  end

  def test_code_comments_use_english_only
    violations = source_files.flat_map do |path|
      comments(path).filter_map do |line_number, comment|
        next unless comment.match?(HAN)

        "#{path.relative_path_from(ROOT)}:#{line_number}"
      end
    end

    assert_empty violations, "Non-English code comments: #{violations.join(", ")}"
  end

  def test_contribution_policy_declares_default_language_and_comment_language
    text = ROOT.join("CONTRIBUTING.md").read(encoding: "UTF-8")

    assert_includes text, "English is the default language"
    assert_includes text, "Code comments must be written in English"
  end

  private

  def source_files
    extensions = %w[.rb .sh .yml .yaml .rs .js .ts]
    Dir.glob(ROOT.join("**/*"), File::FNM_DOTMATCH).filter_map do |entry|
      path = Pathname.new(entry)
      next unless path.file? && extensions.include?(path.extname)
      next if path.to_s.include?("/.git/") || path.to_s.include?("/node_modules/")

      path
    end
  end

  def comments(path)
    text = path.read(encoding: "UTF-8")
    return Ripper.lex(text).filter_map { |position, type, token| [position.first, token] if type == :on_comment } if path.extname == ".rb"
    return slash_comments(text) if %w[.rs .js .ts].include?(path.extname)

    hash_comments(text)
  end

  def hash_comments(text)
    text.lines.each_with_index.filter_map do |line, index|
      quote = nil
      escaped = false
      found = nil
      line.each_char.with_index do |character, column|
        if escaped
          escaped = false
        elsif character == "\\" && quote == '"'
          escaped = true
        elsif quote
          quote = nil if character == quote
        elsif character == '"' || character == "'"
          quote = character
        elsif character == "#"
          found = [index + 1, line[column..]]
          break
        end
      end
      found
    end
  end

  def slash_comments(text)
    text.lines.each_with_index.filter_map do |line, index|
      comment = line[/\/\/.*$/]
      [index + 1, comment] if comment
    end
  end
end
