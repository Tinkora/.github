#!/usr/bin/env ruby
# frozen_string_literal: true

require "net/http"
require "pathname"
require "set"
require "uri"
require_relative "external_link_policy"

ROOT = Pathname.new(__dir__).join("..").realpath
MAX_REDIRECTS = 5
errors = []

urls = Dir.glob(ROOT.join("**/*.md")).each_with_object(Set.new) do |entry, result|
  next if entry.include?("/.git/")

  text = File.binread(entry).force_encoding(Encoding::UTF_8)
  unless text.valid_encoding?
    errors << "#{Pathname.new(entry).relative_path_from(ROOT)}: 不是有效 UTF-8"
    next
  end
  ExternalLinkPolicy.extract_https_urls(text).each { |url| result << url }
end

def fetch(uri, redirects = 0)
  raise "重定向次数超过 #{MAX_REDIRECTS}" if redirects > MAX_REDIRECTS
  raise "仅允许 HTTPS" unless uri.is_a?(URI::HTTPS)

  request = Net::HTTP::Head.new(uri.request_uri, {"User-Agent" => "Tinkora-doc-link-check/1"})
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 20) do |http|
    http.request(request)
  end
  if response.is_a?(Net::HTTPRedirection)
    location = response["location"] or raise "重定向缺少 Location"
    return fetch(URI.join(uri, location), redirects + 1)
  end
  return response if response.code.to_i < 400
  return response unless [403, 405, 429].include?(response.code.to_i)

  get = Net::HTTP::Get.new(uri.request_uri, {"User-Agent" => "Tinkora-doc-link-check/1", "Range" => "bytes=0-0"})
  Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 20) { |http| http.request(get) }
end

urls.sort.each do |url|
  response = fetch(URI.parse(url))
  errors << "#{url}: HTTP #{response.code}" if response.code.to_i >= 400
rescue StandardError => e
  errors << "#{url}: #{e.message}"
end

if errors.empty?
  puts "external links: OK (#{urls.length} HTTPS URLs)"
  exit 0
end

warn errors.map { |error| "ERROR: #{error}" }.join("\n")
exit 1
