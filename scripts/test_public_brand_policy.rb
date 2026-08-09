#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "pathname"

class PublicBrandPolicyTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("..").realpath
  FORBIDDEN_BRAND = Regexp.new(["agent", "commons"].join("\\s*"), Regexp::IGNORECASE)
  RETIRED_DOCUMENTS = %w[
    ORGANIZATION_SETUP_PLAN.md
    REPOSITORY_STANDARD.md
    ROADMAP.md
    TOOL_MATRIX.md
    docs/DOMAIN_AND_SCHEMA_MIGRATION.md
    docs/GITHUB_NAMESPACE_MIGRATION.md
    docs/ORGANIZATION_SETTINGS.md
    docs/decisions/0001-tinkora-brand-migration.md
  ].freeze

  def test_retired_migration_documents_are_not_published
    existing = RETIRED_DOCUMENTS.select { |relative| ROOT.join(relative).exist? }

    assert_empty existing, "Retired public documents: #{existing.join(", ")}"
  end

  def test_public_tree_contains_no_retired_brand_references
    violations = text_files.filter_map do |path|
      path.relative_path_from(ROOT).to_s if path.read(encoding: "UTF-8").match?(FORBIDDEN_BRAND)
    end

    assert_empty violations, "Retired brand references: #{violations.join(", ")}"
  end

  private

  def text_files
    Dir.glob(ROOT.join("**/*"), File::FNM_DOTMATCH).filter_map do |entry|
      path = Pathname.new(entry)
      next unless path.file?
      next if path.to_s.include?("/.git/") || path.to_s.include?("/node_modules/")
      next unless %w[.md .rb .json .jsonc .yml .yaml .sh].include?(path.extname)

      path
    end
  end
end
