#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"
require "tempfile"

require_relative "github_settings_audit_lib"

ROOT = Pathname.new(__dir__).join("..").realpath
FIXTURES = ROOT.join("scripts/fixtures/github_settings_audit")
VALIDATOR = ROOT.join("scripts/spdx-validator")
errors = []

class ContractFixtureTransport
  def initialize(document)
    @document = document
  end

  def authenticate
    response(:authentication, "auth")
  end

  def get(endpoint_id, variables: {}, paginate: false)
    variables
    paginate
    response(endpoint_id, endpoint_id.to_s)
  end

  def graphql(endpoint_id, query:, variables: {})
    endpoint_id
    query
    variables
    response(:organization_projects, "organization_projects")
  end

  private

  def response(endpoint_id, key)
    raw = @document.fetch(key) { {"status" => 404} }
    GitHubSettingsAudit::Response.new(
      endpoint_id: GitHubSettingsAudit::EndpointRegistry.endpoint_id(endpoint_id),
      status: raw.fetch("status"),
      data: raw["data"],
      pages: raw["pages"],
      reason_code: raw["reasonCode"]
    )
  end
end

def validate_json(schema, document, errors)
  Tempfile.create(["github-settings-audit", ".json"]) do |file|
    file.write(JSON.generate(document))
    file.flush
    _stdout, stderr, status = Open3.capture3(
      "npx", "--no-install", "--prefix", VALIDATOR.to_s,
      "ajv", "validate", "--spec=draft7", "-s", schema.to_s, "-d", file.path
    )
    errors << "#{schema.basename}: schema validation failed: #{stderr.lines.first&.strip}" unless status.success?
  end
rescue Errno::ENOENT
  errors << "#{schema.basename}: fixed schema validator unavailable"
end

begin
  production_policy = GitHubSettingsAudit::Policy.load(ROOT.join("config/github-settings-policy.json"))
  errors << "production policy organization must be tinkora" unless production_policy.organization == "tinkora"
  errors << "production policy login must be tinkeragora" unless production_policy.expected_login == "tinkeragora"
  expected_repositories = [".github", "image_to_icns", "repo-template-rust-wasm"]
  errors << "production policy must manage the planned public repositories" unless production_policy.repositories == expected_repositories
  errors << "production policy stage must be solo-public" unless production_policy.stage == "solo-public"
  gates = production_policy.data.fetch("gates")
  errors << "source publication gate must be satisfied" unless gates["sourcePublication"] == "satisfied"
  errors << "public interaction gate must remain pending" unless gates["publicInteraction"] == "pending"
  repository_targets = production_policy.repository_targets(".github")
  errors << ".github source must be published" unless repository_targets.dig("sourcePublished", "value") == true
  errors << ".github Issues must remain disabled" unless repository_targets.dig("issues", "value") == false
  errors << ".github Discussions must remain disabled" unless repository_targets.dig("discussions", "value") == false
  image_targets = production_policy.repository_targets("image_to_icns")
  errors << "image_to_icns source must be published" unless image_targets.dig("sourcePublished", "value") == true
  errors << "image_to_icns Issues must remain disabled" unless image_targets.dig("issues", "value") == false
  errors << "image_to_icns Discussions must remain disabled" unless image_targets.dig("discussions", "value") == false
  errors << "image_to_icns must require its first immutable release" unless image_targets.dig("releases", "value") == 1
  errors << "image_to_icns topics must include icns" unless image_targets.dig("topics", "value").include?("icns")
  template_targets = production_policy.repository_targets("repo-template-rust-wasm")
  errors << "repo-template-rust-wasm source must be published" unless template_targets.dig("sourcePublished", "value") == true
  errors << "repo-template-rust-wasm Issues must remain disabled" unless template_targets.dig("issues", "value") == false
  errors << "repo-template-rust-wasm Discussions must remain disabled" unless template_targets.dig("discussions", "value") == false
  errors << "repo-template-rust-wasm must remain release-free" unless template_targets.dig("releases", "value") == 0
  errors << "repo-template-rust-wasm topics must include template" unless template_targets.dig("topics", "value").include?("template")
  errors << "repo-template-rust-wasm code scanning status must be explicit" unless template_targets.dig("codeScanning", "value") == "not-configured"
  manual_ids = production_policy.manual_attestations.map { |entry| entry.fetch("id") }
  errors << "manual attestations must be generated in stable key order" unless manual_ids == manual_ids.sort
rescue GitHubSettingsAudit::PolicyError
  errors << "production policy rejected by Ruby contract"
end

policy_document = JSON.parse(ROOT.join("config/github-settings-policy.json").read(encoding: "UTF-8"))
errors << "production manual attestations must be an object map" unless policy_document["manualAttestations"].is_a?(Hash)
validate_json(ROOT.join("schemas/github-settings-policy.schema.json"), policy_document, errors)

fixture_policy = GitHubSettingsAudit::Policy.load(FIXTURES.join("policy.json"))
fixture = JSON.parse(FIXTURES.join("compliant.json").read(encoding: "UTF-8"))
result = GitHubSettingsAudit::Auditor.new(
  policy: fixture_policy,
  transport: ContractFixtureTransport.new(fixture),
  organization: fixture_policy.organization,
  repositories: fixture_policy.repositories,
  all_public: false,
  attestations: {},
  strict: false
).run
validate_json(ROOT.join("schemas/github-settings-audit.schema.json"), result.document, errors)

unless result.document.keys.sort == %w[checks mode redaction run schemaVersion summary]
  errors << "audit output top-level fields drifted"
end
unless result.document.fetch("redaction") == {
  "rawResponsesIncluded" => false,
  "identitiesIncluded" => false,
  "sensitiveFieldsIncluded" => false
}
  errors << "audit output redaction declaration drifted"
end

source = ROOT.join("scripts/github_settings_audit_lib.rb").read(encoding: "UTF-8")
forbidden_source = {
  "auth token command" => /gh auth token/,
  "auth refresh command" => /gh auth refresh/,
  "repository mutation command" => /gh repo (?:create|delete|edit)/,
  "issue or pull request mutation" => /gh (?:issue|pr) (?:create|edit|close|merge)/,
  "Git command" => /Open3\.capture3\([^\n]*["']git["']/,
  "raw response write" => /File\.(?:write|binwrite)/
}
forbidden_source.each do |label, pattern|
  errors << "auditor contains forbidden #{label}" if source.match?(pattern)
end

endpoints = GitHubSettingsAudit::LiveTransport::REST_ENDPOINTS
errors << "REST endpoints must be a unique fixed allowlist" unless endpoints.values.uniq.length == endpoints.length
errors << "REST endpoint must use an absolute API path" unless endpoints.values.all? { |path| path.start_with?("/") }
errors << "Audit Log API must never be requested" if endpoints.key?(:audit_log)
registry = GitHubSettingsAudit::EndpointRegistry::ENTRIES
endpoint_ids = registry.values.map(&:endpoint_id)
errors << "endpoint registry IDs must be unique" unless endpoint_ids.uniq.length == endpoint_ids.length
errors << "REST allowlist must come from the endpoint registry" unless endpoints == GitHubSettingsAudit::EndpointRegistry.rest_endpoints
errors << "live transport must not use unbounded pagination" if source.include?("--paginate")
errors << "live transport must fix the GitHub hostname" unless source.include?('"--hostname", "github.com"')
errors << "auditor must not duplicate endpoint evidence mappings" if source.include?("def endpoint_for")
query = GitHubSettingsAudit::LiveTransport::ORGANIZATION_PROJECTS_QUERY
errors << "GraphQL query must be a fixed read query" unless query.strip.start_with?("query ")
forbidden_graphql = /\b(?:#{"muta"}tion|subscription)\b/i
errors << "GraphQL write operation is forbidden" if query.match?(forbidden_graphql)

required_references = {
  "README.md" => "docs/SETTINGS_AUDIT.md",
  "README.zh-CN.md" => "docs/SETTINGS_AUDIT.md",
  "CHANGELOG.md" => "read-only GitHub settings audit",
  "docs/ACCESS_MODEL.md" => "SETTINGS_AUDIT.md",
  "docs/SECURITY_OPERATIONS.md" => "SETTINGS_AUDIT.md",
  "schemas/README.md" => "github-settings-audit.schema.json"
}
required_references.each do |relative, marker|
  text = ROOT.join(relative).read(encoding: "UTF-8")
  errors << "#{relative}: missing settings audit reference" unless text.include?(marker)
end

check_all = ROOT.join("scripts/check_all.sh").read(encoding: "UTF-8")
%w[
  scripts/test_github_settings_audit.rb
  scripts/test_github_settings_audit_spec_issues.rb
  scripts/test_github_settings_audit_quality_issues.rb
  scripts/check_github_settings_audit.rb
].each do |command|
  errors << "scripts/check_all.sh: missing #{command}" unless check_all.include?(command)
end

smoke_path = ROOT.join("scripts/smoke_github_settings_audit.sh")
unless smoke_path.file?
  errors << "manual live smoke script is missing"
else
  smoke = smoke_path.read(encoding: "UTF-8")
  %w[mktemp READ_ONLY schemas/github-settings-audit.schema.json].each do |marker|
    errors << "manual live smoke is missing #{marker}" unless smoke.include?(marker)
  end
end
errors << "manual live smoke must not run in governance CI" if check_all.include?("smoke_github_settings_audit.sh")

if errors.empty?
  puts "GitHub settings audit contracts: OK"
  exit 0
end

warn errors.map { |error| "ERROR: #{error}" }.join("\n")
exit 1
