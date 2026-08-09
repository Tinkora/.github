# frozen_string_literal: true

require "set"
require "uri"

module ExternalLinkPolicy
  module_function

  def extract_https_urls(markdown)
    visible_text = strip_inline_code(strip_fenced_code(markdown))

    URI.extract(visible_text, ["https"]).each_with_object(Set.new) do |candidate, urls|
      normalized = candidate.sub(/[)\]}>.,;:!?]+\z/, "")
      uri = URI.parse(normalized)
      urls << normalized if uri.is_a?(URI::HTTPS) && uri.host
    rescue URI::InvalidURIError
      next
    end.to_a
  end

  def strip_fenced_code(markdown)
    fence_character = nil
    fence_length = 0

    markdown.each_line.map do |line|
      if fence_character
        if line.match?(/\A {0,3}#{Regexp.escape(fence_character)}{#{fence_length},}[ \t]*(?:\r?\n)?\z/)
          fence_character = nil
          fence_length = 0
        end
        line.gsub(/[^\r\n]/, " ")
      elsif (opening = line.match(/\A {0,3}(`{3,}|~{3,})/))
        fence_character = opening[1][0]
        fence_length = opening[1].length
        line.gsub(/[^\r\n]/, " ")
      else
        line
      end
    end.join
  end

  def strip_inline_code(markdown)
    markdown.gsub(/(?<!`)(?<ticks>`+)(?!`).*?\k<ticks>(?!`)/m) do |span|
      span.gsub(/[^\r\n]/, " ")
    end
  end
end
