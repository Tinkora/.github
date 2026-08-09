#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "pathname"
require "tempfile"

require_relative "github_settings_audit_lib"

class GitHubSettingsAuditSpecIssuesTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("..").realpath
  FIXTURES = ROOT.join("scripts/fixtures/github_settings_audit")
  SCHEMA = ROOT.join("schemas/github-settings-policy.schema.json")
  VALIDATOR = ROOT.join("scripts/spdx-validator")

  class FixtureTransport
    attr_reader :calls

    def initialize(document)
      @document = document
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
      raw = @document.fetch(key) { {"status" => 404, "data" => {"message" => "fixture endpoint absent"}} }
      GitHubSettingsAudit::Response.new(
        endpoint_id: GitHubSettingsAudit::EndpointRegistry.endpoint_id(endpoint_id),
        status: raw.fetch("status"), data: raw["data"], pages: raw["pages"], reason_code: raw["reasonCode"]
      )
    end
  end

  class FakeCommandRunner
    Status = Struct.new(:successful) do
      def success?
        successful
      end
    end

    attr_reader :calls

    def initialize
      @calls = []
    end

    def capture3(environment, *arguments)
      @calls << [environment, arguments]
      if arguments.drop(1) == ["auth", "status", "--hostname", "github.com"]
        return ["Token scopes: admin:org, read:org, read:project", "", Status.new(true)]
      end
      if arguments.include?("graphql")
        return [JSON.generate({"data" => {"organization" => {"projectsV2" => {"totalCount" => 1}}}}), "", Status.new(true)]
      end

      output = arguments.last.include?("page=") ? "[]" : "{}"
      [output, "", Status.new(true)]
    end
  end

  def test_gate_state_changes_same_fixture_from_solo_hold_to_multi_failures
    fixture = fixture_document
    solo = checks_by_id(audit(policy: policy(stage: "solo-local"), fixture: fixture))
    multi = checks_by_id(audit(
      policy: policy(stage: "multi-maintainer", gates: {
        "independentSecondOwner" => "satisfied",
        "sourcePublication" => "satisfied"
      }),
      fixture: fixture
    ))

    assert_equal "PASS", solo.fetch("org.owners.solo_safe_hold").fetch("status")
    assert_equal "WARN", solo.fetch("org.owners.future_adoption").fetch("status")
    assert_equal "GATED", solo.fetch("org.owners.future_adoption").fetch("applicability")
    assert_equal "WARN", solo.fetch("org.two_factor.future_adoption").fetch("status")
    assert_equal "GATED", solo.fetch("org.two_factor.future_adoption").fetch("applicability")
    assert_equal "WARN", solo.fetch("manual.second_owner_recovery").fetch("status")
    assert_equal "GATED", solo.fetch("manual.second_owner_recovery").fetch("applicability")

    assert_equal "WARN", multi.fetch("org.owners.solo_safe_hold").fetch("status")
    assert_equal "NOT_APPLICABLE", multi.fetch("org.owners.solo_safe_hold").fetch("applicability")
    assert_equal "FAIL", multi.fetch("org.owners.future_adoption").fetch("status")
    assert_equal "APPLICABLE", multi.fetch("org.owners.future_adoption").fetch("applicability")
    assert_equal "FAIL", multi.fetch("org.two_factor.future_adoption").fetch("status")
    assert_equal "APPLICABLE", multi.fetch("org.two_factor.future_adoption").fetch("applicability")
    assert_equal "UNKNOWN", multi.fetch("manual.second_owner_recovery").fetch("status")
    refute_equal solo, multi
  end

  def test_not_applicable_gate_is_not_reported_as_pass
    result = audit(
      policy: policy(gates: {"sourcePublication" => "not_applicable"}),
      fixture: fixture_document
    )
    check = checks_by_id(result).fetch("repo.rules")

    assert_equal "NOT_APPLICABLE", check.fetch("applicability")
    refute_equal "PASS", check.fetch("status")
  end

  def test_multi_maintainer_policy_requires_satisfied_independent_owner_gate
    assert_raises(GitHubSettingsAudit::PolicyError) do
      policy(stage: "multi-maintainer")
    end
  end

  def test_repository_targets_merge_defaults_with_only_the_named_repository_override
    document = policy_document
    document.dig("repositoryScope", "repositories")["docs"] = {
      "sourcePublished" => {"applicability" => "CURRENT", "value" => true},
      "topics" => {"applicability" => "CURRENT", "value" => ["documentation"]},
      "issues" => {"applicability" => "CURRENT", "value" => false},
      "releases" => {"applicability" => "CURRENT", "value" => 2}
    }

    parsed = GitHubSettingsAudit::Policy.new(document)

    assert_equal ["sample", "docs"].sort, parsed.repositories.sort
    assert_equal ["automation", "ruby"], parsed.repository_targets("sample").dig("topics", "value")
    assert_equal ["documentation"], parsed.repository_targets("docs").dig("topics", "value")
    assert_equal 2, parsed.repository_targets("docs").dig("releases", "value")
    assert_equal false, parsed.repository_targets("docs").dig("discussions", "value")
  end

  def test_repository_override_requires_independent_publication_interaction_and_release_targets
    document = policy_document
    document.dig("repositoryScope", "repositories", "sample").delete("issues")

    assert_raises(GitHubSettingsAudit::PolicyError) { GitHubSettingsAudit::Policy.new(document) }
    refute ajv_valid?(document)
  end

  def test_source_publication_can_pass_while_public_interaction_remains_disabled
    document = policy_document
    document["gates"]["sourcePublication"] = "satisfied"
    document.dig("repositoryScope", "repositories", "sample", "sourcePublished")["value"] = true
    document.dig("repositoryScope", "repositories", "sample", "issues")["value"] = false
    fixture = fixture_document
    fixture.dig("repository", "data")["pushed_at"] = "2026-08-09T09:46:53Z"
    fixture.dig("repository", "data")["has_issues"] = false

    checks = checks_by_id(audit(policy: GitHubSettingsAudit::Policy.new(document), fixture: fixture))

    assert_equal "PASS", checks.fetch("repo.source_published").fetch("status")
    assert_equal "PASS", checks.fetch("repo.issues").fetch("status")
    assert_equal "PASS", checks.fetch("repo.discussions").fetch("status")
    assert_equal "pending", document.dig("gates", "publicInteraction")
  end

  def test_recent_push_is_published_before_repository_size_metadata_updates
    document = policy_document
    document["gates"]["sourcePublication"] = "satisfied"
    document.dig("repositoryScope", "repositories", "sample", "sourcePublished")["value"] = true
    fixture = fixture_document
    repository = fixture.dig("repository", "data")
    repository["size"] = 0
    repository["pushed_at"] = "2026-08-09T09:46:53Z"

    check = checks_by_id(
      audit(policy: GitHubSettingsAudit::Policy.new(document), fixture: fixture)
    ).fetch("repo.source_published")

    assert_equal "PASS", check.fetch("status")
    assert_equal true, check.fetch("actual")
  end

  def test_source_publication_is_unknown_for_missing_or_malformed_push_evidence
    document = policy_document
    document["gates"]["sourcePublication"] = "satisfied"
    document.dig("repositoryScope", "repositories", "sample", "sourcePublished")["value"] = true
    policy = GitHubSettingsAudit::Policy.new(document)

    [[:missing, nil], [:wrong_type, 42], [:malformed, "not-a-timestamp"]].each do |label, value|
      fixture = fixture_document
      repository = fixture.dig("repository", "data")
      label == :missing ? repository.delete("pushed_at") : repository["pushed_at"] = value

      check = checks_by_id(audit(policy: policy, fixture: fixture)).fetch("repo.source_published")

      assert_equal "UNKNOWN", check.fetch("status"), label
    end
  end

  def test_pending_public_interaction_rejects_enabled_issues_or_discussions_targets
    issues_enabled = policy_document
    issues_enabled.dig("repositoryScope", "repositories", "sample", "issues")["value"] = true
    discussions_enabled = policy_document
    discussions_enabled.dig("repositoryScope", "defaults", "discussions")["value"] = true

    [issues_enabled, discussions_enabled].each do |document|
      assert_raises(GitHubSettingsAudit::PolicyError) { GitHubSettingsAudit::Policy.new(document) }
      refute ajv_valid?(document)
    end
  end

  def test_actions_parent_and_selected_fields_are_independent_complete_checks
    checks = checks_by_id(audit(policy: policy, fixture: fixture_document))

    %w[
      org.actions.enabled_repositories org.actions.allowed org.actions.sha_pinning_required
      org.actions.selected.github_owned org.actions.selected.verified
      org.actions.selected.patterns repo.actions.enabled repo.actions.allowed
      repo.actions.selected.github_owned repo.actions.selected.verified
      repo.actions.selected.patterns
    ].each { |id| assert_equal "PASS", checks.fetch(id).fetch("status"), id }
  end

  def test_selected_actions_empty_object_is_unknown_not_pass
    fixture = fixture_document
    fixture["org_actions_selected"] = {"status" => 200, "data" => {}}
    fixture["repo_actions_selected"] = {"status" => 200, "data" => {}}
    checks = checks_by_id(audit(policy: policy, fixture: fixture))

    %w[
      org.actions.selected.github_owned org.actions.selected.verified org.actions.selected.patterns
      repo.actions.selected.github_owned repo.actions.selected.verified repo.actions.selected.patterns
    ].each { |id| assert_equal "UNKNOWN", checks.fetch(id).fetch("status"), id }
  end

  def test_selected_actions_compares_every_policy_field
    fixture = fixture_document
    fixture["org_actions_selected"] = {
      "status" => 200,
      "data" => {"github_owned_allowed" => false, "verified_allowed" => true, "patterns_allowed" => ["other/action@1111111111111111111111111111111111111111"]}
    }
    checks = checks_by_id(audit(policy: policy, fixture: fixture))

    assert_equal "FAIL", checks.fetch("org.actions.selected.github_owned").fetch("status")
    assert_equal "FAIL", checks.fetch("org.actions.selected.verified").fetch("status")
    assert_equal "FAIL", checks.fetch("org.actions.selected.patterns").fetch("status")
  end

  def test_actions_403_keeps_parent_and_selected_checks_unknown
    fixture = fixture_document
    fixture["auth"] = {"status" => 0, "data" => {"scopes" => ["read:org", "read:project"]}}
    fixture["org_actions_permissions"] = {"status" => 403, "data" => {"message" => "scope missing"}}
    checks = checks_by_id(audit(policy: policy, fixture: fixture))

    %w[
      org.actions.enabled_repositories org.actions.allowed
      org.actions.selected.github_owned org.actions.selected.verified org.actions.selected.patterns
    ].each { |id| assert_equal "UNKNOWN", checks.fetch(id).fetch("status"), id }
  end

  def test_selected_actions_409_is_unknown_when_parent_remains_selected
    fixture = fixture_document
    fixture["org_actions_selected"] = {"status" => 409, "data" => {"message" => "conflict"}}
    checks = checks_by_id(audit(policy: policy, fixture: fixture))

    %w[
      org.actions.selected.github_owned org.actions.selected.verified org.actions.selected.patterns
    ].each { |id| assert_equal "UNKNOWN", checks.fetch(id).fetch("status"), id }
  end

  def test_member_repository_creation_ors_all_effective_permissions
    fixture = fixture_document
    fixture.fetch("organization").fetch("data")["members_can_create_internal_repositories"] = true
    document = policy_document
    target = document.dig("organizationTargets", "memberRepositoryCreation")
    target.delete("gate")
    target["applicability"] = "CURRENT"
    checks = checks_by_id(audit(policy: GitHubSettingsAudit::Policy.new(document), fixture: fixture))

    assert_equal true, checks.fetch("org.member_repository_creation").fetch("actual")
    assert_equal "FAIL", checks.fetch("org.member_repository_creation").fetch("status")
  end

  def test_empty_repository_with_confirmed_empty_rulesets_stays_gated
    fixture = fixture_document
    fixture["repo_rulesets"] = {"status" => 200, "data" => []}
    check = checks_by_id(audit(policy: policy, fixture: fixture)).fetch("repo.rules")

    assert_equal "WARN", check.fetch("status")
    assert_equal "GATED", check.fetch("applicability")
  end

  def test_nonempty_repository_with_two_ambiguous_404s_is_unknown
    fixture = fixture_document
    fixture["repository"] = nonempty_repository
    fixture["repo_rulesets"] = {"status" => 404, "data" => {"message" => "ambiguous"}}
    fixture["branch_protection"] = {"status" => 404, "data" => {"message" => "ambiguous"}}
    check = checks_by_id(audit(
      policy: policy(gates: {"sourcePublication" => "satisfied"}), fixture: fixture
    )).fetch("repo.rules")

    assert_equal "UNKNOWN", check.fetch("status")
    assert_equal "not_found_ambiguous", check.dig("evidence", "reasonCode")
  end

  def test_nonempty_repository_with_confirmed_empty_rulesets_fails
    fixture = fixture_document
    fixture["repository"] = nonempty_repository
    fixture["repo_rulesets"] = {"status" => 200, "data" => []}
    fixture["branch_protection"] = {"status" => 404, "data" => {"message" => "not protected"}}
    check = checks_by_id(audit(
      policy: policy(gates: {"sourcePublication" => "satisfied"}), fixture: fixture
    )).fetch("repo.rules")

    assert_equal "FAIL", check.fetch("status")
    assert_equal "APPLICABLE", check.fetch("applicability")
  end

  def test_rules_are_unknown_without_valid_publication_or_default_branch_evidence
    fixture = fixture_document
    repository = fixture.dig("repository", "data")
    repository["pushed_at"] = "not-a-timestamp"
    repository["default_branch"] = "main\ninvalid"
    fixture["repo_rulesets"] = {"status" => 200, "data" => []}

    check = checks_by_id(audit(
      policy: policy(gates: {"sourcePublication" => "satisfied"}), fixture: fixture
    )).fetch("repo.rules")

    assert_equal "UNKNOWN", check.fetch("status")
    assert_equal "branch_protection", check.dig("evidence", "endpointId")
    assert_equal "invalid_field", check.dig("evidence", "reasonCode")
  end

  def test_not_configured_enum_can_satisfy_target
    fixture = fixture_document
    fixture["code_scanning_default_setup"] = {"status" => 404, "data" => {"message" => "absent"}}
    document = policy_document
    document["gates"]["sourcePublication"] = "satisfied"
    document.dig("repositoryScope", "defaults", "codeScanning")["value"] = "not-configured"
    check = checks_by_id(audit(
      policy: GitHubSettingsAudit::Policy.new(document), fixture: fixture
    )).fetch("repo.code_scanning")

    assert_equal "PASS", check.fetch("status")
    assert_equal "not-configured", check.fetch("actual")
  end

  def test_ruby_and_fixed_schema_accept_same_positive_policy
    document = policy_document

    assert GitHubSettingsAudit::Policy.new(document)
    assert ajv_valid?(document)
  end

  def test_ruby_and_fixed_schema_reject_same_invalid_policies
    invalid_documents = []
    invalid_documents << policy_document.tap { |document| document.delete("$schema") }
    invalid_documents << policy_document.merge("unexpected" => true)
    invalid_documents << policy_document.tap { |document| document["organizationTargets"]["plan"]["unexpected"] = true }
    invalid_documents << policy_document.tap { |document| document["organizationTargets"]["plan"]["value"] = "banana" }
    invalid_documents << policy_document.tap { |document| document["organizationTargets"]["basePermission"]["value"] = "banana" }
    invalid_documents << policy_document.tap { |document| document["repositoryScope"]["defaults"]["actionsAllowed"]["value"] = "banana" }
    invalid_documents << policy_document.tap { |document| document["repositoryScope"]["defaults"]["defaultWorkflowPermission"]["value"] = "banana" }
    invalid_documents << policy_document.tap { |document| document["repositoryScope"]["defaults"]["codeScanning"]["value"] = "banana" }
    invalid_documents << policy_document.tap { |document| document.dig("repositoryScope", "repositories").replace("." => {}) }
    invalid_documents << policy_document.tap { |document| document.dig("repositoryScope", "repositories").replace(".." => {}) }
    %w[v1 main * abc123].each do |ref|
      invalid_documents << policy_document.tap do |document|
        document.dig("organizationTargets", "actionsPatternsAllowed", "value").replace(["owner/action@#{ref}"])
      end
    end
    invalid_documents << policy_document.tap do |document|
      document.dig("repositoryScope", "defaults", "actionsPatternsAllowed", "value")
        .replace(["owner/action@ABCDEF0123456789ABCDEF0123456789ABCDEF01"])
    end

    invalid_documents.each do |document|
      assert_raises(GitHubSettingsAudit::PolicyError) { GitHubSettingsAudit::Policy.new(document) }
      refute ajv_valid?(document)
    end
  end

  def test_current_targets_reject_gate_and_future_targets_require_valid_gate
    current_with_gate = policy_document
    current_with_gate["organizationTargets"]["plan"]["gate"] = "sourcePublication"
    future_without_gate = policy_document
    future_without_gate["organizationTargets"]["basePermission"].delete("gate")
    future_bad_gate = policy_document
    future_bad_gate["organizationTargets"]["basePermission"]["gate"] = "unknownGate"

    [current_with_gate, future_without_gate, future_bad_gate].each do |document|
      assert_raises(GitHubSettingsAudit::PolicyError) { GitHubSettingsAudit::Policy.new(document) }
      refute ajv_valid?(document)
    end
  end

  def test_manual_attestations_use_a_strict_object_map_and_stable_key_order
    document = policy_document
    document["manualAttestations"] = manual_attestation_map(document).sort.reverse.to_h

    policy = GitHubSettingsAudit::Policy.new(document)

    assert ajv_valid?(document)
    assert_equal document["manualAttestations"].keys.sort,
                 policy.manual_attestations.map { |entry| entry.fetch("id") }
  end

  def test_ruby_and_schema_reject_manual_attestation_arrays_invalid_keys_and_extra_fields
    array_document = policy_document
    array_document["manualAttestations"] = manual_attestation_map(array_document).map do |id, definition|
      definition.merge("id" => id)
    end
    invalid_key_document = policy_document
    invalid_key_document["manualAttestations"] = manual_attestation_map(invalid_key_document)
    invalid_key_document["manualAttestations"]["invalid-id"] = {
      "applicability" => "CURRENT", "severity" => "LOW"
    }
    extra_field_document = policy_document
    extra_field_document["manualAttestations"] = manual_attestation_map(extra_field_document)
    extra_field_document["manualAttestations"].fetch("manual.audit_log_review")["id"] = "manual.audit_log_review"

    [array_document, invalid_key_document, extra_field_document].each do |document|
      assert_raises(GitHubSettingsAudit::PolicyError) { GitHubSettingsAudit::Policy.new(document) }
      refute ajv_valid?(document)
    end
  end

  def test_duplicate_manual_attestation_text_keys_follow_json_last_wins_semantics
    definitions = JSON.parse(<<~JSON)
      {
        "manual.duplicate": {"applicability": "CURRENT", "severity": "LOW"},
        "manual.duplicate": {"applicability": "CURRENT", "severity": "HIGH"}
      }
    JSON
    document = policy_document
    document["manualAttestations"] = definitions

    policy = GitHubSettingsAudit::Policy.new(document)

    assert_equal 1, definitions.length
    assert_equal "HIGH", definitions.fetch("manual.duplicate").fetch("severity")
    assert ajv_valid?(document)
    assert_equal ["manual.duplicate"], policy.manual_attestations.map { |entry| entry.fetch("id") }
  end

  def test_fixture_transport_proves_offline_audit_never_calls_open3
    transport = FixtureTransport.new(fixture_document)
    Open3.stub(:capture3, ->(*) { flunk "offline audit invoked Open3" }) do
      audit(policy: policy, fixture: fixture_document, transport: transport)
    end

    assert_operator transport.calls.length, :>, 10
  end

  def test_live_transport_runner_captures_only_fixed_rest_gets_and_fixed_query
    runner = FakeCommandRunner.new
    transport = GitHubSettingsAudit::LiveTransport.new(command_runner: runner, gh_path: "/bin/echo")
    variables = {org: "example-org", repo: "sample", login: "fixture-operator", branch: "main"}

    transport.authenticate
    GitHubSettingsAudit::LiveTransport::REST_ENDPOINTS.each_key do |endpoint_id|
      transport.get(endpoint_id, variables: variables, paginate: endpoint_id == :members)
    end
    transport.graphql(
      :organization_projects,
      query: GitHubSettingsAudit::LiveTransport::ORGANIZATION_PROJECTS_QUERY,
      variables: {org: "example-org"}
    )

    rest_calls = runner.calls.map(&:last).select { |arguments| arguments[1] == "api" && !arguments.include?("graphql") }
    assert_equal GitHubSettingsAudit::LiveTransport::REST_ENDPOINTS.length, rest_calls.length
    rest_calls.each do |arguments|
      method_index = arguments.index("--method")
      assert_equal "GET", arguments.fetch(method_index + 1)
      refute_includes %w[POST PATCH PUT DELETE], arguments.fetch(method_index + 1)
    end
    graph_arguments = runner.calls.map(&:last).find { |arguments| arguments.include?("graphql") }
    assert_includes graph_arguments, "query=#{GitHubSettingsAudit::LiveTransport::ORGANIZATION_PROJECTS_QUERY}"
    assert_match(/\Aquery\b/, GitHubSettingsAudit::LiveTransport::ORGANIZATION_PROJECTS_QUERY.strip)
  end

  def test_live_transport_rejects_unfixed_graphql_without_runner_call
    runner = FakeCommandRunner.new
    transport = GitHubSettingsAudit::LiveTransport.new(command_runner: runner, gh_path: "/bin/echo")
    operation = "#{"muta"}tion Unsafe { viewer { login } }"

    assert_raises(GitHubSettingsAudit::Error) do
      transport.graphql(:organization_projects, query: operation, variables: {org: "example-org"})
    end
    assert_empty runner.calls
  end

  def test_manual_smoke_script_is_static_only_and_never_runs_in_governance_ci
    path = ROOT.join("scripts/smoke_github_settings_audit.sh")
    assert path.file?
    text = path.read(encoding: "UTF-8")
    workflow = ROOT.join(".github/workflows/governance-audit.yml").read(encoding: "UTF-8")

    assert_includes text, "mktemp -d"
    assert_includes text, "schemas/github-settings-audit.schema.json"
    assert_includes text, "READ_ONLY"
    assert_match(/0\|1/, text)
    refute_includes workflow, "smoke_github_settings_audit.sh"
  end

  private

  def fixture_document
    JSON.parse(FIXTURES.join("compliant.json").read(encoding: "UTF-8"))
  end

  def policy(stage: "solo-local", gates: {})
    document = policy_document
    document["stage"] = stage
    document["gates"].merge!(gates)
    GitHubSettingsAudit::Policy.new(document)
  end

  def policy_document
    document = JSON.parse(FIXTURES.join("policy.json").read(encoding: "UTF-8"))
    document["$schema"] = "../schemas/github-settings-policy.schema.json"
    document
  end

  def manual_attestation_map(document)
    document.fetch("manualAttestations").transform_values(&:dup)
  end

  def nonempty_repository
    data = fixture_document.fetch("repository").fetch("data").merge(
      "size" => 12,
      "pushed_at" => "2026-08-09T09:46:53Z",
      "default_branch" => "main"
    )
    {"status" => 200, "data" => data}
  end

  def audit(policy:, fixture:, transport: nil)
    GitHubSettingsAudit::Auditor.new(
      policy: policy,
      transport: transport || FixtureTransport.new(fixture),
      organization: "example-org",
      repositories: ["sample"],
      all_public: false,
      attestations: {},
      strict: false
    ).run
  end

  def checks_by_id(result)
    result.document.fetch("checks").to_h { |check| [check.fetch("id"), check] }
  end

  def ajv_valid?(document)
    Tempfile.create(["github-settings-policy", ".json"]) do |file|
      file.write(JSON.generate(document))
      file.flush
      _stdout, _stderr, status = Open3.capture3(
        "npx", "--no-install", "--prefix", VALIDATOR.to_s,
        "ajv", "validate", "--spec=draft7", "-s", SCHEMA.to_s, "-d", file.path
      )
      status.success?
    end
  end
end
