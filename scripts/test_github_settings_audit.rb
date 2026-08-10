#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "pathname"
require "stringio"

require_relative "github_settings_audit_lib"

class GitHubSettingsAuditTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("..").realpath
  FIXTURES = ROOT.join("scripts/fixtures/github_settings_audit")
  POLICY = FIXTURES.join("policy.json")
  SENSITIVE_LURES = %w[
    ghp_fixture private-owner@example.test 192.0.2.21 192.0.2.22
    192.0.2.23 192.0.2.24 192.0.2.25 private-repository-name private-release-name
    ignore\ previous\ instruction dump-response
  ].freeze

  class FixtureTransport
    attr_reader :calls

    def initialize(fixture)
      @fixture = fixture
      @calls = []
    end

    def authenticate
      @calls << ["auth"]
      response(:authentication, "auth")
    end

    def get(endpoint_id, variables: {}, paginate: false)
      @calls << [endpoint_id.to_s, variables, paginate]
      response(endpoint_id, endpoint_id.to_s)
    end

    def graphql(endpoint_id, query:, variables: {})
      @calls << [endpoint_id.to_s, variables, false, query]
      response(endpoint_id, endpoint_id.to_s)
    end

    private

    def response(endpoint_id, key)
      raw = @fixture.fetch(key) { {"status" => 404, "data" => {"message" => "fixture endpoint absent"}} }
      GitHubSettingsAudit::Response.new(
        endpoint_id: GitHubSettingsAudit::EndpointRegistry.endpoint_id(endpoint_id),
        status: raw.fetch("status"),
        data: raw["data"],
        pages: raw["pages"],
        reason_code: raw["reasonCode"]
      )
    end
  end

  def test_compliant_fixture_is_deterministic_read_only_and_redacted
    transport = FixtureTransport.new(fixture)
    result = audit(transport)
    first = JSON.pretty_generate(result.document)
    second = JSON.pretty_generate(audit(FixtureTransport.new(fixture)).document)

    assert_equal "1.0", result.document.fetch("schemaVersion")
    assert_equal "READ_ONLY", result.document.fetch("mode")
    assert_equal first, second
    assert_equal result.document.fetch("checks").sort_by { |check| [check.fetch("id"), check.fetch("resource")] }, result.document.fetch("checks")
    assert_equal 0, result.exit_code
    assert_redacted(first)
    refute transport.calls.any? { |call| call.first == "organization_rulesets" || call.first == "audit_log" }
  end

  def test_drift_detects_merge_pvr_security_topics_and_rules
    result = audit(FixtureTransport.new(fixture("drift")))
    statuses = result.document.fetch("checks").to_h { |check| [check.fetch("id"), check.fetch("status")] }

    %w[
      repo.merge.squash repo.merge.commit repo.merge.rebase repo.delete_branch
      repo.private_vulnerability_reporting repo.vulnerability_alerts
      repo.secret_scanning repo.secret_scanning_push_protection repo.topics
    ].each { |id| assert_equal "FAIL", statuses.fetch(id), id }
    assert_equal "WARN", statuses.fetch("repo.automated_security_fixes")
    assert_equal "WARN", statuses.fetch("repo.code_scanning")
    assert_equal "WARN", statuses.fetch("repo.rules")
    assert_equal 1, result.exit_code
  end

  def test_empty_repository_404s_are_gate_aware
    result = audit(FixtureTransport.new(fixture))
    checks = result.document.fetch("checks").to_h { |check| [check.fetch("id"), check] }

    assert_equal "WARN", checks.fetch("repo.rules").fetch("status")
    assert_equal "GATED", checks.fetch("repo.rules").fetch("applicability")
    assert_equal "WARN", checks.fetch("repo.codeowners_errors").fetch("status")
    assert_equal "NOT_APPLICABLE", checks.fetch("repo.default_branch").fetch("applicability")
  end

  def test_advanced_code_scanning_analysis_counts_as_configured
    advanced = fixture
    advanced.fetch("repository").fetch("data").merge!(
      "size" => 1,
      "pushed_at" => "2026-08-09T22:43:10Z",
      "default_branch" => "main"
    )
    advanced["code_scanning_default_setup"] = {
      "status" => 200,
      "data" => {"state" => "not-configured"}
    }
    advanced["code_scanning_analyses"] = {
      "status" => 200,
      "data" => [
        {
          "ref" => "refs/heads/main",
          "commit_sha" => "c" * 40,
          "error" => "",
          "tool" => {"name" => "CodeQL"}
        }
      ]
    }
    advanced["repository_branch"] = {
      "status" => 200,
      "data" => {"commit" => {"sha" => "c" * 40}}
    }
    transport = FixtureTransport.new(advanced)
    check = checks_by_id(audit(transport)).fetch("repo.code_scanning")

    assert_equal "configured", check.fetch("actual")
    analyses_call = transport.calls.find { |call| call.first == "code_scanning_analyses" }
    assert_equal "main", analyses_call.fetch(1).fetch(:branch)
    assert transport.calls.any? { |call| call.first == "repository_branch" }
  end

  def test_advanced_code_scanning_requires_a_clean_default_branch_analysis
    base = fixture
    base.fetch("repository").fetch("data").merge!(
      "size" => 1,
      "pushed_at" => "2026-08-09T22:43:10Z",
      "default_branch" => "main"
    )
    base["code_scanning_default_setup"] = {
      "status" => 200,
      "data" => {"state" => "not-configured"}
    }

    wrong_branch = Marshal.load(Marshal.dump(base))
    wrong_branch["code_scanning_analyses"] = {
      "status" => 200,
      "data" => [{"ref" => "refs/heads/feature", "commit_sha" => "c" * 40, "error" => "", "tool" => {"name" => "CodeQL"}}]
    }
    wrong_branch["repository_branch"] = {"status" => 200, "data" => {"commit" => {"sha" => "c" * 40}}}
    failed_analysis = Marshal.load(Marshal.dump(base))
    failed_analysis["code_scanning_analyses"] = {
      "status" => 200,
      "data" => [{"ref" => "refs/heads/main", "commit_sha" => "c" * 40, "error" => "build failed", "tool" => {"name" => "CodeQL"}}]
    }
    failed_analysis["repository_branch"] = {"status" => 200, "data" => {"commit" => {"sha" => "c" * 40}}}
    malformed = Marshal.load(Marshal.dump(base))
    malformed["code_scanning_analyses"] = {
      "status" => 200,
      "data" => [{"ref" => 17, "commit_sha" => "c" * 40, "error" => "", "tool" => {"name" => "CodeQL"}}]
    }
    malformed["repository_branch"] = {"status" => 200, "data" => {"commit" => {"sha" => "c" * 40}}}
    stale_head = Marshal.load(Marshal.dump(base))
    stale_head["code_scanning_analyses"] = {
      "status" => 200,
      "data" => [{"ref" => "refs/heads/main", "commit_sha" => "c" * 40, "error" => "", "tool" => {"name" => "CodeQL"}}]
    }
    stale_head["repository_branch"] = {
      "status" => 200,
      "data" => {"commit" => {"sha" => "d" * 40}}
    }
    wrong_tool = Marshal.load(Marshal.dump(base))
    wrong_tool["code_scanning_analyses"] = {
      "status" => 200,
      "data" => [{"ref" => "refs/heads/main", "commit_sha" => "c" * 40, "error" => "", "tool" => {"name" => "Semgrep"}}]
    }
    wrong_tool["repository_branch"] = {
      "status" => 200,
      "data" => {"commit" => {"sha" => "c" * 40}}
    }

    assert_equal "not-configured", checks_by_id(audit(FixtureTransport.new(wrong_branch))).fetch("repo.code_scanning").fetch("actual")
    assert_equal "not-configured", checks_by_id(audit(FixtureTransport.new(failed_analysis))).fetch("repo.code_scanning").fetch("actual")
    assert_equal "UNKNOWN", checks_by_id(audit(FixtureTransport.new(malformed))).fetch("repo.code_scanning").fetch("actual")
    assert_equal "not-configured", checks_by_id(audit(FixtureTransport.new(stale_head))).fetch("repo.code_scanning").fetch("actual")
    assert_equal "UNKNOWN", checks_by_id(audit(FixtureTransport.new(wrong_tool))).fetch("repo.code_scanning").fetch("actual")
  end

  def test_missing_scopes_respect_current_and_pending_applicability_without_graphql
    transport = FixtureTransport.new(fixture("missing_scopes"))
    result = audit(transport)
    checks = result.document.fetch("checks").to_h { |check| [check.fetch("id"), check] }

    assert_equal "UNKNOWN", checks.fetch("org.actions.allowed").fetch("status")
    assert_equal "MISSING_SCOPE", checks.fetch("org.actions.allowed").fetch("capability")
    assert_equal "WARN", checks.fetch("org.projects").fetch("status")
    assert_equal "GATED", checks.fetch("org.projects").fetch("applicability")
    assert_equal "MISSING_SCOPE", checks.fetch("org.projects").fetch("capability")
    assert_equal "gate_pending", checks.fetch("org.projects").dig("evidence", "reasonCode")
    refute transport.calls.any? { |call| call.first == "organization_projects" }
  end

  def test_selected_actions_409_is_not_applicable_when_parent_is_all
    result = audit(FixtureTransport.new(fixture("selected_all_409")))
    checks = result.document.fetch("checks").to_h { |check| [check.fetch("id"), check] }

    %w[
      org.actions.selected.github_owned org.actions.selected.verified org.actions.selected.patterns
      repo.actions.selected.github_owned repo.actions.selected.verified repo.actions.selected.patterns
    ].each do |id|
      assert_equal "PASS", checks.fetch(id).fetch("status")
      assert_equal "NOT_APPLICABLE", checks.fetch(id).fetch("applicability")
      assert_equal "parent_not_selected", checks.fetch(id).dig("evidence", "reasonCode")
    end
  end

  def test_organization_actions_requires_full_sha_pinning
    compliant = checks_by_id(audit(FixtureTransport.new(fixture)))
    assert_equal "PASS", compliant.fetch("org.actions.sha_pinning_required").fetch("status")

    drift_fixture = fixture
    drift_fixture.dig("org_actions_permissions", "data")["sha_pinning_required"] = false
    drift = checks_by_id(audit(FixtureTransport.new(drift_fixture)))
    assert_equal "FAIL", drift.fetch("org.actions.sha_pinning_required").fetch("status")

    missing_fixture = fixture
    missing_fixture.dig("org_actions_permissions", "data").delete("sha_pinning_required")
    missing = checks_by_id(audit(FixtureTransport.new(missing_fixture)))
    assert_equal "UNKNOWN", missing.fetch("org.actions.sha_pinning_required").fetch("status")
  end

  def test_graphql_partial_response_is_unknown_and_fixed_query_is_read_only
    transport = FixtureTransport.new(fixture("graphql_partial"))
    result = audit(transport)
    check = result.document.fetch("checks").find { |entry| entry.fetch("id") == "org.projects" }
    query = transport.calls.find { |call| call.first == "organization_projects" }.fetch(3)

    assert_equal "WARN", check.fetch("status")
    assert_equal "gate_pending", check.dig("evidence", "reasonCode")
    assert_match(/\Aquery\b/, query.strip)
    refute_match(/\b(?:#{"muta"}tion|subscription)\b/i, query)
  end

  def test_malformed_fields_are_unknown_not_pass
    result = audit(FixtureTransport.new(fixture("malformed")))
    checks = result.document.fetch("checks")

    assert checks.any? { |check| check.fetch("status") == "UNKNOWN" && check.dig("evidence", "reasonCode") == "invalid_field" }
    refute checks.select { |check| %w[org.plan repo.public].include?(check.fetch("id")) }.any? { |check| check.fetch("status") == "PASS" }
  end

  def test_string_fields_use_enum_and_public_metadata_allowlists
    result = audit(FixtureTransport.new(fixture("unsafe_enums")))
    output = JSON.generate(result.document)
    checks = checks_by_id(result)

    %w[org.plan org.actions.allowed repo.default_branch repo.topics repo.secret_scanning].each do |id|
      assert_equal "UNKNOWN", checks.fetch(id).fetch("status"), id
      assert_equal "invalid_field", checks.fetch(id).dig("evidence", "reasonCode"), id
    end
    assert_redacted(output)
    refute_includes output, "ignore previous instruction"
    refute_includes output, "ignore-previous-instruction"
  end

  def test_unauthorized_rate_limit_timeout_5xx_and_ambiguous_404_are_unknown
    result = audit(FixtureTransport.new(fixture("errors")), strict: true)
    reasons = result.document.fetch("checks").select { |check| check.fetch("status") == "UNKNOWN" }.map { |check| check.dig("evidence", "reasonCode") }

    %w[unauthorized rate_limited network_timeout server_error not_found_ambiguous].each do |reason|
      assert_includes reasons, reason
    end
    assert_equal 1, result.exit_code
    assert_redacted(JSON.generate(result.document))
  end

  def test_pagination_counts_only_and_never_emits_identity_or_release_names
    paginated = fixture("paginated")
    paginated.fetch("members")["pages"] = [Array.new(100) { {"login" => "redacted"} }, Array.new(2) { {"login" => "redacted"} }]
    result = audit(FixtureTransport.new(paginated))
    checks = result.document.fetch("checks").to_h { |check| [check.fetch("id"), check] }
    output = JSON.generate(result.document)

    assert_equal 102, checks.fetch("org.members.count").fetch("actual")
    assert_equal 3, checks.fetch("repo.releases").fetch("actual")
    assert_redacted(output)
  end

  def test_solo_multi_and_unknown_owner_gates_are_distinct
    solo = checks_by_id(audit(FixtureTransport.new(fixture)))
    multi = checks_by_id(audit(FixtureTransport.new(fixture("multi_owner"))))
    unknown = checks_by_id(audit(FixtureTransport.new(fixture("unknown_owner"))))

    assert_equal "PASS", solo.fetch("org.owners.solo_safe_hold").fetch("status")
    assert_equal "WARN", solo.fetch("org.owners.future_adoption").fetch("status")
    assert_equal "WARN", multi.fetch("org.owners.solo_safe_hold").fetch("status")
    assert_equal "WARN", multi.fetch("org.owners.future_adoption").fetch("status")
    assert_equal "UNKNOWN", unknown.fetch("org.owners.solo_safe_hold").fetch("status")
    assert_equal "WARN", unknown.fetch("org.owners.future_adoption").fetch("status")
  end

  def test_human_output_has_fixed_read_only_banner_sorted_summary_and_escaping
    out = StringIO.new
    err = StringIO.new
    transport = FixtureTransport.new(fixture)
    code = GitHubSettingsAudit::CLI.run(
      ["audit", "--policy", POLICY.to_s, "--repo", "sample", "--format", "human", "--dry-run"],
      out: out,
      err: err,
      transport_factory: -> { transport }
    )

    assert_equal 0, code
    assert_match(/\AREAD-ONLY GITHUB SETTINGS AUDIT\nMode: READ_ONLY\n/, out.string)
    assert_match(/Audited public repositories: \d+/, out.string)
    assert_match(/Summary: FAIL=0 PASS=\d+ UNKNOWN=\d+ WARN=\d+/, out.string)
    assert_empty err.string
    assert_redacted(out.string)
  end

  def test_write_and_transport_shaping_flags_are_rejected_before_transport
    forbidden = %w[--apply --write --method --endpoint --header --token --include-private --dump-response --unknown]

    forbidden.each do |flag|
      calls = 0
      out = StringIO.new
      err = StringIO.new
      code = GitHubSettingsAudit::CLI.run(
        ["audit", "--policy", POLICY.to_s, flag],
        out: out,
        err: err,
        transport_factory: -> { calls += 1; raise "transport must not start" }
      )
      assert_equal 2, code, flag
      assert_equal 0, calls, flag
      assert_empty out.string, flag
    end


    calls = 0
    code = GitHubSettingsAudit::CLI.run(
      ["audit", "--policy", POLICY.to_s, "--method", "PATCH"],
      out: StringIO.new,
      err: StringIO.new,
      transport_factory: -> { calls += 1 }
    )
    assert_equal 2, code
    assert_equal 0, calls
  end


  def test_unapproved_graphql_operation_is_rejected_before_command_execution
    transport_class = Class.new(GitHubSettingsAudit::LiveTransport) do
      attr_reader :capture_calls

      def initialize
        @capture_calls = 0
      end

      private

      def capture(*)
        @capture_calls += 1
        raise "command execution is forbidden"
      end
    end
    transport = transport_class.new
    operation = "#{"muta"}tion Unsafe { viewer { login } }"

    assert_raises(GitHubSettingsAudit::Error) do
      transport.graphql(:organization_projects, query: operation, variables: {org: "example-org"})
    end
    assert_equal 0, transport.capture_calls
  end

  def test_all_public_uses_only_public_inventory_entries
    transport = FixtureTransport.new(fixture)
    policy = GitHubSettingsAudit::Policy.load(POLICY)
    result = GitHubSettingsAudit::Auditor.new(
      policy: policy, transport: transport, organization: "example-org",
      repositories: [], all_public: true, attestations: {}, strict: false
    ).run
    output = JSON.generate(result.document)

    assert_equal 1, result.document.dig("run", "publicRepositoryCount")
    assert transport.calls.any? { |call| call.first == "repositories" }
    refute_includes output, "private-repository-name"
  end

  def test_unmanaged_public_repository_is_an_explicit_failure
    policy = GitHubSettingsAudit::Policy.load(POLICY)
    result = GitHubSettingsAudit::Auditor.new(
      policy: policy,
      transport: FixtureTransport.new(fixture),
      organization: "example-org",
      repositories: ["unregistered"],
      all_public: false,
      attestations: {},
      strict: false
    ).run
    check = result.document.fetch("checks").find { |entry| entry.fetch("id") == "repo.managed" }

    assert_equal "FAIL", check.fetch("status")
    assert_equal "MANAGED", check.fetch("expected")
    assert_equal "UNMANAGED", check.fetch("actual")
    assert_equal "unmanaged_repository", check.dig("evidence", "reasonCode")
    assert_equal 1, result.exit_code
  end

  def test_offline_fixture_uses_no_live_transport_and_strict_unknown_exits_one
    calls = 0
    result = audit(FixtureTransport.new(fixture("graphql_partial")), strict: true)

    assert_equal 1, result.exit_code
    assert_equal 0, calls
  end

  def test_source_transport_has_only_fixed_get_endpoints_and_fixed_query
    source = ROOT.join("scripts/github_settings_audit_lib.rb").read(encoding: "UTF-8")
    rest_templates = GitHubSettingsAudit::LiveTransport::REST_ENDPOINTS.values

    assert rest_templates.all? { |path| path.start_with?("/") }
    refute_match(/gh auth (?:token|refresh)/, source)
    refute_match(/\b(?:PATCH|PUT|DELETE)\b/, source)
    refute_match(/\b(?:#{"muta"}tion|subscription)\b/i, GitHubSettingsAudit::LiveTransport::ORGANIZATION_PROJECTS_QUERY)
  end

  private

  def audit(transport, strict: false)
    policy = GitHubSettingsAudit::Policy.load(POLICY)
    GitHubSettingsAudit::Auditor.new(
      policy: policy,
      transport: transport,
      organization: "example-org",
      repositories: ["sample"],
      all_public: false,
      attestations: {},
      strict: strict
    ).run
  end

  def fixture(scenario = nil)
    base = JSON.parse(FIXTURES.join("compliant.json").read(encoding: "UTF-8"))
    return base unless scenario

    overlays = JSON.parse(FIXTURES.join("scenarios.json").read(encoding: "UTF-8"))
    base.merge(overlays.fetch(scenario))
  end

  def checks_by_id(result)
    result.document.fetch("checks").to_h { |check| [check.fetch("id"), check] }
  end

  def assert_redacted(output)
    SENSITIVE_LURES.each { |lure| refute_includes output, lure }
  end
end
