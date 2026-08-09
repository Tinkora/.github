#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require_relative "external_link_policy"

class ExternalLinkPolicyTest < Minitest::Test
  def test_extracts_bare_markdown_and_autolink_urls
    markdown = <<~MARKDOWN
      [Tinkora](https://github.com/tinkora)
      <https://example.com/docs>
      A bare GFM link: https://example.org/status.
    MARKDOWN

    assert_equal %w[
      https://example.com/docs
      https://example.org/status
      https://github.com/tinkora
    ], ExternalLinkPolicy.extract_https_urls(markdown).sort
  end

  def test_ignores_urls_inside_inline_and_fenced_code
    markdown = <<~MARKDOWN
      `https://example.invalid/schema-reference.json`

      ```text
      https://example.invalid/not-a-link
      ```

      [Live](https://example.com/live)
    MARKDOWN

    assert_equal ["https://example.com/live"], ExternalLinkPolicy.extract_https_urls(markdown)
  end

  def test_trims_markdown_delimiters_and_sentence_punctuation
    markdown = "See [repository](https://github.com/Tinkora/.github), then https://example.com/help;\n"

    assert_equal %w[
      https://example.com/help
      https://github.com/Tinkora/.github
    ], ExternalLinkPolicy.extract_https_urls(markdown).sort
  end
end
