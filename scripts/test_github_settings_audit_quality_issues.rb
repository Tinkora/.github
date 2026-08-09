#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "pathname"
require "stringio"
require "tmpdir"

require_relative "github_settings_audit_lib"

class GitHubSettingsAuditQualityIssuesTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("..").realpath
  FIXTURES = ROOT.join("scripts/fixtures/github_settings_audit")
  POLICY = FIXTURES.join("policy.json")

  class Status
    def initialize(success)
      @success = success
    end

    def success?
      @success
    end
  end

  class RecordingRunner
    attr_reader :calls

    def initialize(&response)
      @response = response
      @calls = []
    end

    def capture3(environment, *arguments)
      @calls << [environment, arguments]
      return @response.call(environment, arguments, @calls.length) if @response

      ["{}", "", Status.new(true)]
    end
  end

  class FixtureTransport
    attr_reader :calls

    def initialize(document)
      @document = document
      @calls = []
    end

    def authenticate
      @calls << ["authentication"]
      response("authentication", "auth")
    end

    def get(endpoint_id, variables: {}, paginate: false)
      @calls << [endpoint_id.to_s, variables, paginate]
      response(endpoint_id.to_s, endpoint_id.to_s)
    end

    def graphql(endpoint_id, query:, variables: {})
      @calls << [endpoint_id.to_s, variables, false, query]
      response(endpoint_id.to_s, endpoint_id.to_s)
    end

    private

    def response(endpoint_id, key)
      raw = @document.fetch(key) { {"status" => 404, "data" => {"message" => "fixture endpoint absent"}} }
      GitHubSettingsAudit::Response.new(
        endpoint_id: GitHubSettingsAudit::EndpointRegistry.endpoint_id(endpoint_id),
        status: raw.fetch("status"),
        data: raw["data"],
        pages: raw["pages"],
        reason_code: raw["reasonCode"]
      )
    end
  end

  def test_live_transport_uses_trusted_absolute_gh_fixed_host_and_clean_environment
    runner = RecordingRunner.new do |_environment, arguments, _call_number|
      output = arguments.include?("auth") ? "Token scopes: admin:org, read:org, read:project" : "{}"
      [output, "", Status.new(true)]
    end
    gh_path = File.realpath("/bin/echo")
    transport = GitHubSettingsAudit::LiveTransport.new(command_runner: runner, gh_path: "/bin/echo")

    with_environment(
      "GH_HOST" => "attacker.example",
      "GH_ENTERPRISE_TOKEN" => "enterprise-secret",
      "GITHUB_ENTERPRISE_TOKEN" => "github-enterprise-secret",
      "GH_CONFIG_DIR" => "/tmp/attacker-config",
      "GH_REPO" => "attacker/repository",
      "GH_DEBUG" => "api",
      "GH_TOKEN" => "secret",
      "GITHUB_TOKEN" => "github-secret"
    ) do
      transport.authenticate
      transport.get(:viewer)
      transport.graphql(
        :organization_projects,
        query: GitHubSettingsAudit::LiveTransport::ORGANIZATION_PROJECTS_QUERY,
        variables: {org: "example-org"}
      )
    end

    runner.calls.each do |environment, arguments|
      assert_equal gh_path, arguments.first
      GitHubSettingsAudit::LiveTransport::CLEARED_ENVIRONMENT.each do |name|
        assert environment.key?(name), name
        assert_nil environment[name], name
      end
    end
    api_calls = runner.calls.map(&:last).select { |arguments| arguments[1] == "api" }
    api_calls.each do |arguments|
      host_index = arguments.index("--hostname")
      assert_equal "github.com", arguments.fetch(host_index + 1)
    end
    auth_arguments = runner.calls.first.last
    assert_equal [gh_path, "auth", "status", "--hostname", "github.com"], auth_arguments
  end

  def test_absolute_gh_ignores_a_path_substitute
    Dir.mktmpdir("hostile-gh") do |directory|
      marker = File.join(directory, "executed")
      fake_gh = File.join(directory, "gh")
      File.write(fake_gh, "#!/bin/sh\ntouch #{marker}\n")
      File.chmod(0o755, fake_gh)

      with_environment("PATH" => directory, "GH_CONFIG_DIR" => directory) do
        transport = GitHubSettingsAudit::LiveTransport.new(gh_path: "/bin/echo")
        transport.authenticate
      end

      refute_path_exists marker
    end
  end

  def test_trusted_executable_rejects_unsafe_candidates
    Dir.mktmpdir("trusted-gh") do |directory|
      non_executable = File.join(directory, "non-executable")
      writable = File.join(directory, "writable")
      File.write(non_executable, "plain")
      File.write(writable, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, writable)
      File.chmod(0o775, writable)

      [directory, non_executable, writable].each do |candidate|
        assert_raises(GitHubSettingsAudit::Error) do
          GitHubSettingsAudit::TrustedExecutable.resolve([candidate])
        end
      end
    end
  end

  def test_cli_maps_missing_trusted_gh_to_fixed_control_probe_error
    output = StringIO.new
    error_output = StringIO.new
    missing_path = "/definitely/missing/gh"

    exit_code = GitHubSettingsAudit::CLI.run(
      ["audit", "--policy", POLICY.to_s],
      out: output,
      err: error_output,
      transport_factory: -> { GitHubSettingsAudit::LiveTransport.new(gh_path: missing_path) }
    )

    assert_equal 3, exit_code
    assert_empty output.string
    assert_equal "ERROR: authentication or control probe unavailable\n", error_output.string
    refute_includes error_output.string, missing_path
    refute_match(/github_settings_audit_lib\.rb:\d+/, error_output.string)
  end

  def test_process_runner_terminates_and_reaps_timed_out_process_group
    Dir.mktmpdir("runner-timeout") do |directory|
      pid_path = File.join(directory, "pid")
      runner = GitHubSettingsAudit::ProcessRunner.new(timeout_seconds: 0.2, output_limit_bytes: 1024)
      threads_before = Thread.list.select(&:alive?).map(&:object_id)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      assert_raises(GitHubSettingsAudit::ProcessTimeout) do
        runner.capture3({}, "/bin/sh", "-c", "echo $$ > '#{pid_path}'; sleep 30")
      end

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      assert_operator elapsed, :<, 2
      pid = Integer(File.read(pid_path, encoding: "UTF-8"))
      assert_raises(Errno::ESRCH) { Process.kill(0, pid) }
      assert_empty Thread.list.select(&:alive?).reject { |thread| threads_before.include?(thread.object_id) }
    end
  end

  def test_process_runner_terminates_background_group_after_direct_child_exits
    child_pid = nil
    Dir.mktmpdir("runner-orphan") do |directory|
      pid_path = File.join(directory, "child-pid")
      runner = GitHubSettingsAudit::ProcessRunner.new(timeout_seconds: 0.2, output_limit_bytes: 1024)

      assert_raises(GitHubSettingsAudit::ProcessTimeout) do
        runner.capture3(
          {},
          "/bin/sh",
          "-c",
          "(trap '' HUP; exec sleep 30) & child=$!; echo $child > '#{pid_path}'; exit 0"
        )
      end

      child_pid = Integer(File.read(pid_path, encoding: "UTF-8"))
      assert_process_exited(child_pid)
    end
  ensure
    terminate_test_process(child_pid)
  end

  def test_process_runner_fails_closed_when_combined_output_exceeds_four_mib
    runner = GitHubSettingsAudit::ProcessRunner.new(
      timeout_seconds: 5,
      output_limit_bytes: GitHubSettingsAudit::ProcessRunner::OUTPUT_LIMIT_BYTES
    )

    assert_raises(GitHubSettingsAudit::OutputLimitExceeded) do
      runner.capture3({}, "/bin/sh", "-c", "dd if=/dev/zero bs=1048576 count=5 2>/dev/null")
    end
  end

  def test_process_runner_cleans_background_group_after_output_limit
    child_pid = nil
    Dir.mktmpdir("runner-output-group") do |directory|
      pid_path = File.join(directory, "child-pid")
      runner = GitHubSettingsAudit::ProcessRunner.new(timeout_seconds: 2, output_limit_bytes: 1024)

      assert_raises(GitHubSettingsAudit::OutputLimitExceeded) do
        runner.capture3(
          {},
          "/bin/sh",
          "-c",
          "(trap '' HUP PIPE; sleep 0.05; while :; do printf '0123456789'; done) & child=$!; echo $child > '#{pid_path}'; exit 0"
        )
      end

      child_pid = Integer(File.read(pid_path, encoding: "UTF-8"))
      assert_process_exited(child_pid)
    end
  ensure
    terminate_test_process(child_pid)
  end

  def test_process_runner_cleans_background_group_after_unexpected_reader_error
    child_pid = nil
    Dir.mktmpdir("runner-reader-error") do |directory|
      pid_path = File.join(directory, "child-pid")
      runner = GitHubSettingsAudit::ProcessRunner.new(timeout_seconds: 2, output_limit_bytes: 1024)
      original_select = IO.method(:select)
      forced_error = lambda do |*arguments|
        ready = original_select.call(*arguments)
        sleep 0.05
        raise "forced reader error"
      end

      error = assert_raises(RuntimeError) do
        IO.stub(:select, forced_error) do
          runner.capture3(
            {},
            "/bin/sh",
            "-c",
            "(trap '' HUP; exec sleep 30) & child=$!; echo $child > '#{pid_path}'; echo ready; exit 0"
          )
        end
      end
      assert_equal "forced reader error", error.message

      child_pid = Integer(File.read(pid_path, encoding: "UTF-8"))
      assert_process_exited(child_pid)
    end
  ensure
    terminate_test_process(child_pid)
  end

  def test_process_runner_kills_a_process_group_that_ignores_term
    Dir.mktmpdir("runner-kill") do |directory|
      pid_path = File.join(directory, "pid")
      runner = GitHubSettingsAudit::ProcessRunner.new(timeout_seconds: 0.1, output_limit_bytes: 1024)

      assert_raises(GitHubSettingsAudit::ProcessTimeout) do
        runner.capture3(
          {},
          "/bin/sh",
          "-c",
          "trap '' TERM; echo $$ > '#{pid_path}'; while :; do sleep 1; done"
        )
      end

      pid = Integer(File.read(pid_path, encoding: "UTF-8"))
      assert_raises(Errno::ESRCH) { Process.kill(0, pid) }
    end
  end

  def test_manual_pagination_has_no_paginate_flag_and_fails_after_one_hundred_full_pages
    full_page = JSON.generate(Array.new(100) { {} })
    runner = RecordingRunner.new { |_environment, _arguments, _call_number| [full_page, "", Status.new(true)] }
    transport = GitHubSettingsAudit::LiveTransport.new(command_runner: runner, gh_path: "/bin/echo")

    response = transport.get(:members, variables: {org: "example-org"}, paginate: true)

    assert_equal "pagination_limit", response.reason_code
    assert_equal "members", response.endpoint_id
    assert_equal GitHubSettingsAudit::LiveTransport::MAX_PAGES, runner.calls.length
    runner.calls.each_with_index do |(_environment, arguments), index|
      refute_includes arguments, "--paginate"
      refute_includes arguments, "--slurp"
      assert_includes arguments.last, "per_page=100"
      assert_includes arguments.last, "page=#{index + 1}"
    end
  end

  def test_manual_pagination_applies_four_mib_limit_to_the_aggregate_response
    large_page = JSON.generate(Array.new(100) { "x" * 25_000 })
    runner = RecordingRunner.new { |_environment, _arguments, _call_number| [large_page, "", Status.new(true)] }
    transport = GitHubSettingsAudit::LiveTransport.new(command_runner: runner, gh_path: "/bin/echo")

    response = transport.get(:members, variables: {org: "example-org"}, paginate: true)

    assert_equal "output_limit", response.reason_code
    assert_equal "members", response.endpoint_id
    assert_equal 2, runner.calls.length
  end

  def test_dot_segment_repository_names_fail_before_transport
    %w[. ..].each do |repository|
      document = policy_document
      document.dig("repositoryScope", "repositories").replace(repository => {})
      assert_raises(GitHubSettingsAudit::PolicyError) { GitHubSettingsAudit::Policy.new(document) }

      calls = 0
      code = GitHubSettingsAudit::CLI.run(
        ["audit", "--policy", POLICY.to_s, "--repo", repository],
        out: StringIO.new,
        err: StringIO.new,
        transport_factory: -> { calls += 1; raise "transport must not start" }
      )
      assert_equal 2, code
      assert_equal 0, calls

      runner = RecordingRunner.new
      transport = GitHubSettingsAudit::LiveTransport.new(command_runner: runner, gh_path: "/bin/echo")
      assert_raises(GitHubSettingsAudit::Error) do
        transport.get(:repository, variables: {org: "example-org", repo: repository})
      end
      assert_empty runner.calls
    end
  end

  def test_projects_missing_scope_uses_effective_gate_applicability
    expected = {
      "pending" => ["WARN", "GATED", "gate_pending"],
      "not_applicable" => ["WARN", "NOT_APPLICABLE", "gate_not_applicable"],
      "satisfied" => ["UNKNOWN", "APPLICABLE", "missing_scope"]
    }

    expected.each do |gate, values|
      fixture = fixture_document
      fixture.dig("auth", "data", "scopes").delete("read:project")
      check = checks_by_id(audit(fixture, gates: {"publicInteraction" => gate})).fetch("org.projects")

      assert_equal values[0], check.fetch("status"), gate
      assert_equal values[1], check.fetch("applicability"), gate
      assert_equal values[2], check.dig("evidence", "reasonCode"), gate
      assert_equal "organization_projects", check.dig("evidence", "endpointId"), gate
    end
  end

  def test_automated_security_fixes_error_uses_effective_gate_applicability
    expected = {
      "pending" => ["WARN", "GATED", "gate_pending"],
      "not_applicable" => ["WARN", "NOT_APPLICABLE", "gate_not_applicable"],
      "satisfied" => ["UNKNOWN", "APPLICABLE", "server_error"]
    }

    expected.each do |gate, values|
      fixture = fixture_document
      fixture["automated_security_fixes"] = {"status" => 500, "reasonCode" => "server_error"}
      check = checks_by_id(audit(fixture, gates: {"sourcePublication" => gate})).fetch("repo.automated_security_fixes")

      assert_equal values[0], check.fetch("status"), gate
      assert_equal values[1], check.fetch("applicability"), gate
      assert_equal values[2], check.dig("evidence", "reasonCode"), gate
      assert_equal "automated_security_fixes", check.dig("evidence", "endpointId"), gate
    end
  end

  def test_strict_mode_does_not_upgrade_pending_gate_warnings
    fixture = fixture_document
    fixture.dig("auth", "data", "scopes").delete("read:project")
    policy = GitHubSettingsAudit::Policy.load(POLICY)
    attestations = policy.manual_attestations.filter_map do |definition|
      [definition.fetch("id"), true] if definition.fetch("applicability") == "CURRENT"
    end.to_h
    result = audit(fixture, strict: true, attestations: attestations)

    assert_equal 0, result.document.dig("summary", "UNKNOWN")
    assert_operator result.document.dig("summary", "WARN"), :>, 0
    assert_equal 0, result.exit_code
  end

  def test_security_presence_evidence_uses_registry_endpoint_for_every_result_path
    {
      204 => ["PASS", "target_satisfied"],
      404 => ["FAIL", "resource_absent"],
      500 => ["UNKNOWN", "server_error"]
    }.each do |status, expected|
      fixture = fixture_document
      fixture["vulnerability_alerts"] = response_fixture(status)
      fixture["automated_security_fixes"] = response_fixture(status)
      checks = checks_by_id(audit(fixture, gates: {"sourcePublication" => "satisfied"}))

      {
        "repo.vulnerability_alerts" => "vulnerability_alerts",
        "repo.automated_security_fixes" => "automated_security_fixes"
      }.each do |check_id, endpoint_id|
        check = checks.fetch(check_id)
        assert_equal expected[0], check.fetch("status"), "#{check_id} #{status}"
        assert_equal expected[1], check.dig("evidence", "reasonCode"), "#{check_id} #{status}"
        assert_equal endpoint_id, check.dig("evidence", "endpointId"), "#{check_id} #{status}"
      end
    end
  end

  def test_empty_repository_default_branch_uses_effective_gate_applicability
    cases = [
      ["current", nil, "PASS", "NOT_APPLICABLE", "empty_repository"],
      ["pending", "pending", "WARN", "GATED", "gate_pending"],
      ["not_applicable", "not_applicable", "WARN", "NOT_APPLICABLE", "gate_not_applicable"],
      ["satisfied", "satisfied", "PASS", "NOT_APPLICABLE", "empty_repository"]
    ]

    cases.each do |label, gate, status, applicability, reason_code|
      document = policy_document
      if gate
        target = document.dig("repositoryScope", "defaults", "defaultBranch")
        target["applicability"] = "FUTURE_GATE"
        target["gate"] = "sourcePublication"
        document.fetch("gates")["sourcePublication"] = gate
      end
      check = checks_by_id(
        audit(fixture_document, policy: GitHubSettingsAudit::Policy.new(document))
      ).fetch("repo.default_branch")

      assert_equal status, check.fetch("status"), label
      assert_equal applicability, check.fetch("applicability"), label
      assert_equal reason_code, check.dig("evidence", "reasonCode"), label
    end
  end

  private

  def assert_process_exited(pid)
    100.times do
      Process.kill(0, pid)
      sleep 0.01
    rescue Errno::ESRCH
      return
    end
    flunk "process #{pid} is still alive"
  end

  def terminate_test_process(pid)
    return unless pid

    Process.kill("TERM", pid)
    100.times do
      Process.kill(0, pid)
      sleep 0.01
    rescue Errno::ESRCH
      return
    end
    Process.kill("KILL", pid)
  rescue Errno::ESRCH, Errno::EPERM
    nil
  end

  def with_environment(values)
    previous = values.to_h { |name, _value| [name, ENV[name]] }
    values.each { |name, value| ENV[name] = value }
    yield
  ensure
    previous.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
  end

  def fixture_document
    JSON.parse(FIXTURES.join("compliant.json").read(encoding: "UTF-8"))
  end

  def policy_document
    JSON.parse(POLICY.read(encoding: "UTF-8"))
  end

  def audit(fixture, gates: {}, strict: false, attestations: {}, policy: nil)
    unless policy
      document = policy_document
      document.fetch("gates").merge!(gates)
      policy = GitHubSettingsAudit::Policy.new(document)
    end
    GitHubSettingsAudit::Auditor.new(
      policy: policy,
      transport: FixtureTransport.new(fixture),
      organization: "example-org",
      repositories: ["sample"],
      all_public: false,
      attestations: attestations,
      strict: strict
    ).run
  end

  def checks_by_id(result)
    result.document.fetch("checks").to_h { |check| [check.fetch("id"), check] }
  end

  def response_fixture(status)
    case status
    when 204 then {"status" => 204}
    when 404 then {"status" => 404, "reasonCode" => "not_found_ambiguous"}
    else {"status" => status, "reasonCode" => "server_error"}
    end
  end
end
