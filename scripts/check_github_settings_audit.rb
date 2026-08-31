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
  expected_repositories = [".github", "agent_worktree_doctor", "cert_viewer", "color_atlas", "cron_maker", "csv_sculptor", "curl_builder", "data_toolbox", "developer_primitives", "diff_viz", "dmg_background", "encoding_toolbox", "eval_split_guard", "favicon_kit", "image_to_icns", "json_yaml_swiss", "pe_version_info", "jwt_inspector", "mcp_doctor", "mcp_schema_compat", "mcp_timeout_guard", "md_porter", "prompt_smith", "qr_forge", "recoverable_delete", "repo-template-rust-wasm", "tool_call_trace"]
  errors << "production policy must manage the planned public repositories" unless production_policy.repositories == expected_repositories
  errors << "production policy stage must be solo-public" unless production_policy.stage == "solo-public"
  gates = production_policy.data.fetch("gates")
  errors << "source publication gate must be satisfied" unless gates["sourcePublication"] == "satisfied"
  errors << "public interaction gate must remain pending" unless gates["publicInteraction"] == "pending"
  errors << "member Team creation must remain owner-only" unless production_policy.organization_target("memberTeamCreation").dig("value") == false
  errors << "all five new-repository security defaults must remain enabled" unless production_policy.organization_target("securityDefaultsMinimum").dig("value") == 5
  repository_targets = production_policy.repository_targets(".github")
  errors << ".github source must be published" unless repository_targets.dig("sourcePublished", "value") == true
  errors << ".github Issues must remain disabled" unless repository_targets.dig("issues", "value") == false
  errors << ".github Discussions must remain disabled" unless repository_targets.dig("discussions", "value") == false
  worktree_targets = production_policy.repository_targets("agent_worktree_doctor")
  errors << "agent_worktree_doctor source must be published" unless worktree_targets.dig("sourcePublished", "value") == true
  errors << "agent_worktree_doctor Issues must be enabled" unless worktree_targets.dig("issues", "value") == true
  errors << "agent_worktree_doctor Discussions must be enabled" unless worktree_targets.dig("discussions", "value") == true
  errors << "agent_worktree_doctor Projects must remain disabled" unless worktree_targets.dig("projects", "value") == false
  errors << "agent_worktree_doctor must have two published releases" unless worktree_targets.dig("releases", "value") == 2
  errors << "agent_worktree_doctor topics must include worktree" unless worktree_targets.dig("topics", "value").include?("worktree")
  errors << "agent_worktree_doctor code scanning must be configured" unless worktree_targets.dig("codeScanning", "value") == "configured"
  errors << "agent_worktree_doctor currently uses branch protection instead of repository rulesets" unless worktree_targets.dig("rulesMinimum", "value") == 0
  cron_targets = production_policy.repository_targets("cron_maker")
  errors << "cron_maker source must be published" unless cron_targets.dig("sourcePublished", "value") == true
  errors << "cron_maker Issues must remain disabled" unless cron_targets.dig("issues", "value") == false
  errors << "cron_maker Discussions must remain disabled" unless cron_targets.dig("discussions", "value") == false
  errors << "cron_maker Projects must remain disabled" unless cron_targets.dig("projects", "value") == false
  errors << "cron_maker must have its first release" unless cron_targets.dig("releases", "value") == 1
  errors << "cron_maker topics must include cron-expression" unless cron_targets.dig("topics", "value").include?("cron-expression")
  errors << "cron_maker code scanning must be configured" unless cron_targets.dig("codeScanning", "value") == "configured"
  errors << "cron_maker must protect release tags" unless cron_targets.dig("rulesMinimum", "value") == 1
  csv_targets = production_policy.repository_targets("csv_sculptor")
  errors << "csv_sculptor source must be published" unless csv_targets.dig("sourcePublished", "value") == true
  errors << "csv_sculptor Issues must be enabled" unless csv_targets.dig("issues", "value") == true
  errors << "csv_sculptor Discussions must be enabled" unless csv_targets.dig("discussions", "value") == true
  errors << "csv_sculptor Projects must remain disabled" unless csv_targets.dig("projects", "value") == false
  errors << "csv_sculptor must have five published releases" unless csv_targets.dig("releases", "value") == 5
  errors << "csv_sculptor topics must include csv" unless csv_targets.dig("topics", "value").include?("csv")
  errors << "csv_sculptor code scanning must be configured" unless csv_targets.dig("codeScanning", "value") == "configured"
  errors << "csv_sculptor must protect main and release tags" unless csv_targets.dig("rulesMinimum", "value") == 2
  curl_targets = production_policy.repository_targets("curl_builder")
  errors << "curl_builder source must be published" unless curl_targets.dig("sourcePublished", "value") == true
  errors << "curl_builder Issues must be enabled" unless curl_targets.dig("issues", "value") == true
  errors << "curl_builder Discussions must be enabled" unless curl_targets.dig("discussions", "value") == true
  errors << "curl_builder Projects must be enabled" unless curl_targets.dig("projects", "value") == true
  errors << "curl_builder must have its first release" unless curl_targets.dig("releases", "value") == 1
  errors << "curl_builder topics must include code-generation" unless curl_targets.dig("topics", "value").include?("code-generation")
  errors << "curl_builder code scanning must be configured" unless curl_targets.dig("codeScanning", "value") == "configured"
  errors << "curl_builder must protect its main branch" unless curl_targets.dig("rulesMinimum", "value") == 1
  data_targets = production_policy.repository_targets("data_toolbox")
  errors << "data_toolbox source must be published" unless data_targets.dig("sourcePublished", "value") == true
  errors << "data_toolbox Issues must be enabled" unless data_targets.dig("issues", "value") == true
  errors << "data_toolbox Discussions must be enabled" unless data_targets.dig("discussions", "value") == true
  errors << "data_toolbox Projects must be enabled" unless data_targets.dig("projects", "value") == true
  errors << "data_toolbox must have its alpha release" unless data_targets.dig("releases", "value") == 1
  errors << "data_toolbox topics must include ai-agents" unless data_targets.dig("topics", "value").include?("ai-agents")
  errors << "data_toolbox topics must include tinkora" unless data_targets.dig("topics", "value").include?("tinkora")
  errors << "data_toolbox code scanning must be configured" unless data_targets.dig("codeScanning", "value") == "configured"
  errors << "data_toolbox must protect its main branch and release tags" unless data_targets.dig("rulesMinimum", "value") == 2
  primitives_targets = production_policy.repository_targets("developer_primitives")
  errors << "developer_primitives source must be published" unless primitives_targets.dig("sourcePublished", "value") == true
  errors << "developer_primitives Issues must be enabled" unless primitives_targets.dig("issues", "value") == true
  errors << "developer_primitives Discussions must be enabled" unless primitives_targets.dig("discussions", "value") == true
  errors << "developer_primitives Projects must be enabled" unless primitives_targets.dig("projects", "value") == true
  errors << "developer_primitives must have two published releases" unless primitives_targets.dig("releases", "value") == 2
  errors << "developer_primitives topics must include uuidv7" unless primitives_targets.dig("topics", "value").include?("uuidv7")
  errors << "developer_primitives topics must include timezone" unless primitives_targets.dig("topics", "value").include?("timezone")
  errors << "developer_primitives code scanning must be configured" unless primitives_targets.dig("codeScanning", "value") == "configured"
  errors << "developer_primitives must have repository rules" unless primitives_targets.dig("rulesMinimum", "value") == 1
  diff_targets = production_policy.repository_targets("diff_viz")
  errors << "diff_viz source must be published" unless diff_targets.dig("sourcePublished", "value") == true
  errors << "diff_viz Issues must be enabled" unless diff_targets.dig("issues", "value") == true
  errors << "diff_viz Discussions must be enabled" unless diff_targets.dig("discussions", "value") == true
  errors << "diff_viz Projects must be disabled" unless diff_targets.dig("projects", "value") == false
  errors << "diff_viz must have its first release" unless diff_targets.dig("releases", "value") == 1
  errors << "diff_viz topics must include diff-viewer" unless diff_targets.dig("topics", "value").include?("diff-viewer")
  errors << "diff_viz code scanning must be configured" unless diff_targets.dig("codeScanning", "value") == "configured"
  errors << "diff_viz must protect its main branch and release tags" unless diff_targets.dig("rulesMinimum", "value") == 1
  cert_targets = production_policy.repository_targets("cert_viewer")
  errors << "cert_viewer source must be published" unless cert_targets.dig("sourcePublished", "value") == true
  errors << "cert_viewer Issues must be enabled" unless cert_targets.dig("issues", "value") == true
  errors << "cert_viewer Discussions must be enabled" unless cert_targets.dig("discussions", "value") == true
  errors << "cert_viewer must have two published releases" unless cert_targets.dig("releases", "value") == 2
  errors << "cert_viewer topics must include x509" unless cert_targets.dig("topics", "value").include?("x509")
  errors << "cert_viewer code scanning must be configured" unless cert_targets.dig("codeScanning", "value") == "configured"
  errors << "cert_viewer must protect its main branch and release tags" unless cert_targets.dig("rulesMinimum", "value") == 1
  dmg_targets = production_policy.repository_targets("dmg_background")
  errors << "dmg_background source must be published" unless dmg_targets.dig("sourcePublished", "value") == true
  errors << "dmg_background Issues must remain disabled" unless dmg_targets.dig("issues", "value") == false
  errors << "dmg_background Discussions must remain disabled" unless dmg_targets.dig("discussions", "value") == false
  errors << "dmg_background must have its first release" unless dmg_targets.dig("releases", "value") == 1
  errors << "dmg_background topics must include dmg" unless dmg_targets.dig("topics", "value").include?("dmg")
  errors << "dmg_background code scanning must be configured" unless dmg_targets.dig("codeScanning", "value") == "configured"
  errors << "dmg_background must protect release tags" unless dmg_targets.dig("rulesMinimum", "value") == 1
  encoding_targets = production_policy.repository_targets("encoding_toolbox")
  errors << "encoding_toolbox source must be published" unless encoding_targets.dig("sourcePublished", "value") == true
  errors << "encoding_toolbox Issues must be enabled" unless encoding_targets.dig("issues", "value") == true
  errors << "encoding_toolbox Discussions must be enabled" unless encoding_targets.dig("discussions", "value") == true
  errors << "encoding_toolbox Projects must remain disabled" unless encoding_targets.dig("projects", "value") == false
  errors << "encoding_toolbox must have its first release" unless encoding_targets.dig("releases", "value") == 1
  errors << "encoding_toolbox topics must include encoding" unless encoding_targets.dig("topics", "value").include?("encoding")
  errors << "encoding_toolbox code scanning must be configured" unless encoding_targets.dig("codeScanning", "value") == "configured"
  errors << "encoding_toolbox must protect its main branch" unless encoding_targets.dig("rulesMinimum", "value") == 1
  split_targets = production_policy.repository_targets("eval_split_guard")
  errors << "eval_split_guard source must be published" unless split_targets.dig("sourcePublished", "value") == true
  errors << "eval_split_guard Issues must be enabled" unless split_targets.dig("issues", "value") == true
  errors << "eval_split_guard Discussions must be enabled" unless split_targets.dig("discussions", "value") == true
  errors << "eval_split_guard Projects must remain disabled" unless split_targets.dig("projects", "value") == false
  errors << "eval_split_guard must have two published releases" unless split_targets.dig("releases", "value") == 2
  errors << "eval_split_guard topics must include evaluation" unless split_targets.dig("topics", "value").include?("evaluation")
  errors << "eval_split_guard code scanning must be configured" unless split_targets.dig("codeScanning", "value") == "configured"
  errors << "eval_split_guard currently uses branch protection instead of repository rulesets" unless split_targets.dig("rulesMinimum", "value") == 0
  favicon_targets = production_policy.repository_targets("favicon_kit")
  errors << "favicon_kit source must be published" unless favicon_targets.dig("sourcePublished", "value") == true
  errors << "favicon_kit Issues must be enabled" unless favicon_targets.dig("issues", "value") == true
  errors << "favicon_kit Discussions must be enabled" unless favicon_targets.dig("discussions", "value") == true
  errors << "favicon_kit Projects must be enabled" unless favicon_targets.dig("projects", "value") == true
  errors << "favicon_kit must allow rebase merge" unless favicon_targets.dig("allowRebaseMerge", "value") == true
  errors << "favicon_kit must have its first release" unless favicon_targets.dig("releases", "value") == 1
  errors << "favicon_kit topics must include favicon-generator" unless favicon_targets.dig("topics", "value").include?("favicon-generator")
  errors << "favicon_kit code scanning must be configured" unless favicon_targets.dig("codeScanning", "value") == "configured"
  errors << "favicon_kit must protect main and release tags" unless favicon_targets.dig("rulesMinimum", "value") == 2
  image_targets = production_policy.repository_targets("image_to_icns")
  errors << "image_to_icns source must be published" unless image_targets.dig("sourcePublished", "value") == true
  errors << "image_to_icns Issues must be enabled" unless image_targets.dig("issues", "value") == true
  errors << "image_to_icns Discussions must be enabled" unless image_targets.dig("discussions", "value") == true
  errors << "image_to_icns must require its first immutable release" unless image_targets.dig("releases", "value") == 1
  errors << "image_to_icns topics must include icns" unless image_targets.dig("topics", "value").include?("icns")
  json_yaml_targets = production_policy.repository_targets("json_yaml_swiss")
  errors << "json_yaml_swiss source must be published" unless json_yaml_targets.dig("sourcePublished", "value") == true
  errors << "json_yaml_swiss Issues must be enabled" unless json_yaml_targets.dig("issues", "value") == true
  errors << "json_yaml_swiss Discussions must be enabled" unless json_yaml_targets.dig("discussions", "value") == true
  errors << "json_yaml_swiss Projects must remain disabled" unless json_yaml_targets.dig("projects", "value") == false
  errors << "json_yaml_swiss must have its first release" unless json_yaml_targets.dig("releases", "value") == 1
  errors << "json_yaml_swiss topics must include tinkora" unless json_yaml_targets.dig("topics", "value").include?("tinkora")
  errors << "json_yaml_swiss code scanning must be configured" unless json_yaml_targets.dig("codeScanning", "value") == "configured"
  errors << "json_yaml_swiss must protect its main branch" unless json_yaml_targets.dig("rulesMinimum", "value") == 1
  pe_targets = production_policy.repository_targets("pe_version_info")
  errors << "pe_version_info source must be published" unless pe_targets.dig("sourcePublished", "value") == true
  errors << "pe_version_info Issues must be enabled" unless pe_targets.dig("issues", "value") == true
  errors << "pe_version_info Discussions must be enabled" unless pe_targets.dig("discussions", "value") == true
  errors << "pe_version_info must have four published releases" unless pe_targets.dig("releases", "value") == 4
  errors << "pe_version_info topics must include PE" unless pe_targets.dig("topics", "value").include?("pe")
  errors << "pe_version_info code scanning status must be explicit" unless pe_targets.dig("codeScanning", "value") == "not-configured"
  jwt_targets = production_policy.repository_targets("jwt_inspector")
  errors << "jwt_inspector source must be published" unless jwt_targets.dig("sourcePublished", "value") == true
  errors << "jwt_inspector Issues must be enabled" unless jwt_targets.dig("issues", "value") == true
  errors << "jwt_inspector Discussions must be enabled" unless jwt_targets.dig("discussions", "value") == true
  errors << "jwt_inspector must have two published releases" unless jwt_targets.dig("releases", "value") == 2
  errors << "jwt_inspector topics must include jwt" unless jwt_targets.dig("topics", "value").include?("jwt")
  errors << "jwt_inspector code scanning must be configured" unless jwt_targets.dig("codeScanning", "value") == "configured"
  errors << "jwt_inspector must protect its main branch and release tags" unless jwt_targets.dig("rulesMinimum", "value") == 1
  mcp_targets = production_policy.repository_targets("mcp_doctor")
  errors << "mcp_doctor source must be published" unless mcp_targets.dig("sourcePublished", "value") == true
  errors << "mcp_doctor Issues must be enabled" unless mcp_targets.dig("issues", "value") == true
  errors << "mcp_doctor Discussions must be enabled" unless mcp_targets.dig("discussions", "value") == true
  errors << "mcp_doctor must have seventeen published releases" unless mcp_targets.dig("releases", "value") == 17
  errors << "mcp_doctor topics must include mcp" unless mcp_targets.dig("topics", "value").include?("mcp")
  errors << "mcp_doctor code scanning must be configured" unless mcp_targets.dig("codeScanning", "value") == "configured"
  errors << "mcp_doctor must protect its main branch and release tags" unless mcp_targets.dig("rulesMinimum", "value") == 1
  timeout_targets = production_policy.repository_targets("mcp_timeout_guard")
  errors << "mcp_timeout_guard source must be published" unless timeout_targets.dig("sourcePublished", "value") == true
  errors << "mcp_timeout_guard Issues must be enabled" unless timeout_targets.dig("issues", "value") == true
  errors << "mcp_timeout_guard Discussions must be enabled" unless timeout_targets.dig("discussions", "value") == true
  errors << "mcp_timeout_guard Projects must be enabled" unless timeout_targets.dig("projects", "value") == true
  errors << "mcp_timeout_guard must have its first release" unless timeout_targets.dig("releases", "value") == 1
  errors << "mcp_timeout_guard topics must include mcp" unless timeout_targets.dig("topics", "value").include?("mcp")
  errors << "mcp_timeout_guard code scanning must be configured" unless timeout_targets.dig("codeScanning", "value") == "configured"
  errors << "mcp_timeout_guard must protect main and release tags" unless timeout_targets.dig("rulesMinimum", "value") == 2
  qr_targets = production_policy.repository_targets("qr_forge")
  errors << "qr_forge source must be published" unless qr_targets.dig("sourcePublished", "value") == true
  errors << "qr_forge Issues must be enabled" unless qr_targets.dig("issues", "value") == true
  errors << "qr_forge Discussions must be enabled" unless qr_targets.dig("discussions", "value") == true
  errors << "qr_forge Projects must be enabled" unless qr_targets.dig("projects", "value") == true
  errors << "qr_forge must have its first release" unless qr_targets.dig("releases", "value") == 1
  errors << "qr_forge topics must include qr-code-generator" unless qr_targets.dig("topics", "value").include?("qr-code-generator")
  errors << "qr_forge code scanning must be configured" unless qr_targets.dig("codeScanning", "value") == "configured"
  errors << "qr_forge must protect its main branch and release tags" unless qr_targets.dig("rulesMinimum", "value") == 1
  recoverable_targets = production_policy.repository_targets("recoverable_delete")
  errors << "recoverable_delete source must be published" unless recoverable_targets.dig("sourcePublished", "value") == true
  errors << "recoverable_delete Issues must be enabled" unless recoverable_targets.dig("issues", "value") == true
  errors << "recoverable_delete Discussions must remain disabled" unless recoverable_targets.dig("discussions", "value") == false
  errors << "recoverable_delete Projects must be enabled" unless recoverable_targets.dig("projects", "value") == true
  errors << "recoverable_delete must have its first release" unless recoverable_targets.dig("releases", "value") == 1
  errors << "recoverable_delete topics must include trash" unless recoverable_targets.dig("topics", "value").include?("trash")
  errors << "recoverable_delete code scanning status must be explicit" unless recoverable_targets.dig("codeScanning", "value") == "not-configured"
  errors << "recoverable_delete must protect main and release tags" unless recoverable_targets.dig("rulesMinimum", "value") == 2
  template_targets = production_policy.repository_targets("repo-template-rust-wasm")
  errors << "repo-template-rust-wasm source must be published" unless template_targets.dig("sourcePublished", "value") == true
  errors << "repo-template-rust-wasm Issues must remain disabled" unless template_targets.dig("issues", "value") == false
  errors << "repo-template-rust-wasm Discussions must remain disabled" unless template_targets.dig("discussions", "value") == false
  errors << "repo-template-rust-wasm must remain release-free" unless template_targets.dig("releases", "value") == 0
  errors << "repo-template-rust-wasm topics must include template" unless template_targets.dig("topics", "value").include?("template")
  errors << "repo-template-rust-wasm code scanning status must be explicit" unless template_targets.dig("codeScanning", "value") == "not-configured"
  trace_targets = production_policy.repository_targets("tool_call_trace")
  errors << "tool_call_trace source must be published" unless trace_targets.dig("sourcePublished", "value") == true
  errors << "tool_call_trace Issues must remain disabled" unless trace_targets.dig("issues", "value") == false
  errors << "tool_call_trace Discussions must remain disabled" unless trace_targets.dig("discussions", "value") == false
  errors << "tool_call_trace must have three published releases" unless trace_targets.dig("releases", "value") == 3
  errors << "tool_call_trace topics must include ai-agents" unless trace_targets.dig("topics", "value").include?("ai-agents")
  errors << "tool_call_trace code scanning must be configured" unless trace_targets.dig("codeScanning", "value") == "configured"
  errors << "tool_call_trace must protect release tags" unless trace_targets.dig("rulesMinimum", "value") == 1
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
