#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"
require "time"
require "uri"

module GitHubSettingsAudit
  class Error < StandardError; end
  class PolicyError < Error; end
  class ControlProbeError < Error; end
  class ProcessTimeout < Error; end
  class OutputLimitExceeded < Error; end
  class TrustedExecutableUnavailable < Error; end

  module EndpointRegistry
    Entry = Struct.new(:endpoint_id, :rest_path, :graphql_query, keyword_init: true)

    ORGANIZATION_PROJECTS_QUERY = <<~GRAPHQL.freeze
      query OrganizationProjects($organization: String!) {
        organization(login: $organization) {
          projectsV2(first: 1) {
            totalCount
          }
        }
      }
    GRAPHQL

    ENTRIES = {
      authentication: Entry.new(endpoint_id: "authentication"),
      viewer: Entry.new(endpoint_id: "viewer", rest_path: "/user"),
      organization: Entry.new(endpoint_id: "organization", rest_path: "/orgs/%{org}"),
      owners: Entry.new(endpoint_id: "owners", rest_path: "/orgs/%{org}/members?filter=all&role=admin&per_page=100"),
      members: Entry.new(endpoint_id: "members", rest_path: "/orgs/%{org}/members?filter=all&role=all&per_page=100"),
      public_members: Entry.new(endpoint_id: "public_members", rest_path: "/orgs/%{org}/public_members?per_page=100"),
      outside_collaborators: Entry.new(endpoint_id: "outside_collaborators", rest_path: "/orgs/%{org}/outside_collaborators?filter=all&per_page=100"),
      teams: Entry.new(endpoint_id: "teams", rest_path: "/orgs/%{org}/teams?per_page=100"),
      operator_membership: Entry.new(endpoint_id: "operator_membership", rest_path: "/orgs/%{org}/memberships/%{login}"),
      org_actions_permissions: Entry.new(endpoint_id: "org_actions_permissions", rest_path: "/orgs/%{org}/actions/permissions"),
      org_actions_workflow: Entry.new(endpoint_id: "org_actions_workflow", rest_path: "/orgs/%{org}/actions/permissions/workflow"),
      org_actions_selected: Entry.new(endpoint_id: "org_actions_selected", rest_path: "/orgs/%{org}/actions/permissions/selected-actions"),
      org_security_defaults: Entry.new(endpoint_id: "org_security_defaults", rest_path: "/orgs/%{org}/code-security/configurations/defaults?per_page=100"),
      repositories: Entry.new(endpoint_id: "repositories", rest_path: "/orgs/%{org}/repos?type=public&per_page=100"),
      repository: Entry.new(endpoint_id: "repository", rest_path: "/repos/%{org}/%{repo}"),
      repo_rulesets: Entry.new(endpoint_id: "repo_rulesets", rest_path: "/repos/%{org}/%{repo}/rulesets?per_page=100"),
      branch_protection: Entry.new(endpoint_id: "branch_protection", rest_path: "/repos/%{org}/%{repo}/branches/%{branch}/protection"),
      repo_actions_permissions: Entry.new(endpoint_id: "repo_actions_permissions", rest_path: "/repos/%{org}/%{repo}/actions/permissions"),
      repo_actions_workflow: Entry.new(endpoint_id: "repo_actions_workflow", rest_path: "/repos/%{org}/%{repo}/actions/permissions/workflow"),
      repo_actions_selected: Entry.new(endpoint_id: "repo_actions_selected", rest_path: "/repos/%{org}/%{repo}/actions/permissions/selected-actions"),
      community_profile: Entry.new(endpoint_id: "community_profile", rest_path: "/repos/%{org}/%{repo}/community/profile"),
      codeowners_errors: Entry.new(endpoint_id: "codeowners_errors", rest_path: "/repos/%{org}/%{repo}/codeowners/errors"),
      releases: Entry.new(endpoint_id: "releases", rest_path: "/repos/%{org}/%{repo}/releases?per_page=100"),
      private_vulnerability_reporting: Entry.new(endpoint_id: "private_vulnerability_reporting", rest_path: "/repos/%{org}/%{repo}/private-vulnerability-reporting"),
      vulnerability_alerts: Entry.new(endpoint_id: "vulnerability_alerts", rest_path: "/repos/%{org}/%{repo}/vulnerability-alerts"),
      automated_security_fixes: Entry.new(endpoint_id: "automated_security_fixes", rest_path: "/repos/%{org}/%{repo}/automated-security-fixes"),
      code_scanning_default_setup: Entry.new(endpoint_id: "code_scanning_default_setup", rest_path: "/repos/%{org}/%{repo}/code-scanning/default-setup"),
      organization_projects: Entry.new(endpoint_id: "organization_projects", graphql_query: ORGANIZATION_PROJECTS_QUERY),
      organization_rulesets: Entry.new(endpoint_id: "organization_rulesets"),
      manual_attestation: Entry.new(endpoint_id: "manual_attestation")
    }.transform_values(&:freeze).freeze

    def self.fetch(endpoint_id)
      ENTRIES.fetch(endpoint_id.to_sym) { raise Error, "endpoint is not allowlisted" }
    end

    def self.endpoint_id(endpoint_id)
      fetch(endpoint_id).endpoint_id
    end

    def self.rest_endpoints
      ENTRIES.filter_map do |key, entry|
        [key, entry.rest_path] if entry.rest_path
      end.to_h.freeze
    end
  end

  Response = Struct.new(:status, :data, :pages, :reason_code, :endpoint_id, keyword_init: true) do
    def success?
      status.is_a?(Integer) && status.between?(200, 299) && reason_code.nil?
    end

    def count
      return unless pages.nil? || (pages.is_a?(Array) && pages.all? { |page| page.is_a?(Array) })
      return pages.sum(&:length) if pages
      return data.length if data.is_a?(Array)

      nil
    end
  end

  Result = Struct.new(:document, :exit_code, keyword_init: true)

  class TrustedExecutable
    GH_CANDIDATES = %w[
      /usr/bin/gh
      /usr/local/bin/gh
      /opt/homebrew/bin/gh
      /home/linuxbrew/.linuxbrew/bin/gh
    ].freeze

    def self.resolve(candidates = GH_CANDIDATES)
      candidates.each do |candidate|
        path = File.realpath(candidate)
        stat = File.stat(path)
        next unless stat.file? && File.executable?(path) && (stat.mode & 0o022).zero?

        return path
      rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
        next
      end
      raise TrustedExecutableUnavailable, "trusted gh executable unavailable"
    end
  end

  class ProcessRunner
    OUTPUT_LIMIT_BYTES = 4 * 1024 * 1024
    TERMINATION_GRACE_SECONDS = 0.2
    READ_CHUNK_BYTES = 16 * 1024

    def initialize(timeout_seconds: 30, output_limit_bytes: OUTPUT_LIMIT_BYTES)
      @timeout_seconds = timeout_seconds
      @output_limit_bytes = output_limit_bytes
    end

    def capture3(environment, *arguments)
      stdin = stdout = stderr = wait_thread = nil
      process_group_id = nil
      stdout_buffer = +"".b
      stderr_buffer = +"".b
      deadline = monotonic_time + @timeout_seconds
      stdin, stdout, stderr, wait_thread = Open3.popen3(environment, *arguments, pgroup: true)
      process_group_id = wait_thread.pid
      stdin.close
      readers = [stdout, stderr]
      buffers = {stdout => stdout_buffer, stderr => stderr_buffer}

      until readers.empty?
        remaining = deadline - monotonic_time
        raise ProcessTimeout, "process timed out" unless remaining.positive?

        ready = IO.select(readers, nil, nil, remaining)
        raise ProcessTimeout, "process timed out" unless ready

        ready.first.each do |reader|
          begin
            loop do
              chunk = reader.read_nonblock(READ_CHUNK_BYTES)
              buffers.fetch(reader) << chunk
              if stdout_buffer.bytesize + stderr_buffer.bytesize > @output_limit_bytes
                raise OutputLimitExceeded, "process output limit exceeded"
              end
            end
          rescue IO::WaitReadable
            nil
          rescue EOFError
            readers.delete(reader)
          end
        end
      end

      remaining = deadline - monotonic_time
      raise ProcessTimeout, "process timed out" unless remaining.positive? && wait_thread.join(remaining)

      [utf8(stdout_buffer), utf8(stderr_buffer), wait_thread.value]
    rescue StandardError
      terminate_process_group(wait_thread, process_group_id)
      raise
    ensure
      [stdin, stdout, stderr].compact.each do |stream|
        stream.close unless stream.closed?
      rescue IOError
        nil
      end
    end

    private

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def terminate_process_group(wait_thread, process_group_id)
      return unless wait_thread && process_group_id

      signal_process_group("TERM", process_group_id)
      unless wait_for_process_group_exit(process_group_id, TERMINATION_GRACE_SECONDS)
        signal_process_group("KILL", process_group_id)
        wait_for_process_group_exit(process_group_id, TERMINATION_GRACE_SECONDS)
      end
      wait_thread.join
    end

    def wait_for_process_group_exit(process_group_id, timeout)
      deadline = monotonic_time + timeout
      while process_group_alive?(process_group_id)
        remaining = deadline - monotonic_time
        return false unless remaining.positive?

        sleep [remaining, 0.01].min
      end
      true
    end

    def process_group_alive?(process_group_id)
      Process.kill(0, -process_group_id)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end

    def signal_process_group(signal, pid)
      Process.kill(signal, -pid)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end

    def utf8(buffer)
      buffer.force_encoding(Encoding::UTF_8)
    end
  end

  class Policy
    ORGANIZATION_TARGETS = {
      "plan" => String,
      "basePermission" => String,
      "memberRepositoryCreation" => [TrueClass, FalseClass],
      "memberRepositoryDeletion" => [TrueClass, FalseClass],
      "memberVisibilityChanges" => [TrueClass, FalseClass],
      "outsideCollaboratorInvitation" => [TrueClass, FalseClass],
      "twoFactorRequired" => [TrueClass, FalseClass],
      "projectsMinimum" => Integer,
      "securityDefaultsMinimum" => Integer,
      "actionsEnabledRepositories" => String,
      "actionsAllowed" => String,
      "actionsShaPinningRequired" => [TrueClass, FalseClass],
      "actionsGithubOwnedAllowed" => [TrueClass, FalseClass],
      "actionsVerifiedAllowed" => [TrueClass, FalseClass],
      "actionsPatternsAllowed" => Array,
      "defaultWorkflowPermission" => String,
      "canApprovePullRequestReviews" => [TrueClass, FalseClass]
    }.freeze
    REPOSITORY_TARGETS = {
      "sourcePublished" => [TrueClass, FalseClass],
      "defaultBranch" => String,
      "topics" => Array,
      "issues" => [TrueClass, FalseClass],
      "discussions" => [TrueClass, FalseClass],
      "wiki" => [TrueClass, FalseClass],
      "projects" => [TrueClass, FalseClass],
      "allowSquashMerge" => [TrueClass, FalseClass],
      "allowMergeCommit" => [TrueClass, FalseClass],
      "allowRebaseMerge" => [TrueClass, FalseClass],
      "deleteBranchOnMerge" => [TrueClass, FalseClass],
      "privateVulnerabilityReporting" => [TrueClass, FalseClass],
      "vulnerabilityAlerts" => [TrueClass, FalseClass],
      "automatedSecurityFixes" => [TrueClass, FalseClass],
      "secretScanning" => String,
      "secretScanningPushProtection" => String,
      "codeScanning" => String,
      "rulesMinimum" => Integer,
      "actionsEnabled" => [TrueClass, FalseClass],
      "actionsAllowed" => String,
      "actionsGithubOwnedAllowed" => [TrueClass, FalseClass],
      "actionsVerifiedAllowed" => [TrueClass, FalseClass],
      "actionsPatternsAllowed" => Array,
      "defaultWorkflowPermission" => String,
      "canApprovePullRequestReviews" => [TrueClass, FalseClass],
      "communityHealthMinimum" => Integer,
      "codeownersErrors" => Integer,
      "releases" => Integer
    }.freeze
    APPLICABILITIES = %w[CURRENT FUTURE_GATE].freeze
    GATE_STATES = %w[pending satisfied not_applicable].freeze
    REPOSITORY_OVERRIDE_TARGETS = %w[sourcePublished topics issues releases].freeze
    GATE_NAMES = %w[independentSecondOwner publicInteraction sourcePublication releaseAutomation].freeze
    TOP_LEVEL_KEYS = %w[$schema expectedLogin gates manualAttestations organization organizationTargets repositoryScope schemaVersion stage].freeze
    LOGIN_PATTERN = /\A[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?\z/
    REPOSITORY_PATTERN = /\A(?!\.{1,2}\z)[A-Za-z0-9_.-]+\z/
    BRANCH_PATTERN = /\A[A-Za-z0-9._\/-]+\z/
    TOPIC_PATTERN = /\A[a-z0-9][a-z0-9-]{0,49}\z/
    ACTION_PATTERN = /\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+@[0-9a-f]{40}\z/

    attr_reader :data

    def self.load(path)
      bytes = Pathname.new(path).binread
      raise PolicyError, "BOM is forbidden" if bytes.start_with?("\xEF\xBB\xBF".b)

      text = bytes.force_encoding(Encoding::UTF_8)
      raise PolicyError, "policy must be UTF-8" unless text.valid_encoding?

      new(JSON.parse(text))
    rescue Errno::ENOENT, Errno::EACCES, JSON::ParserError => e
      raise PolicyError, e.class.name
    end

    def initialize(data)
      @data = data
      validate!
    end

    def organization
      data.fetch("organization")
    end

    def expected_login
      data.fetch("expectedLogin")
    end

    def stage
      data.fetch("stage")
    end

    def repositories
      data.dig("repositoryScope", "repositories").keys
    end

    def organization_target(name)
      data.fetch("organizationTargets").fetch(name)
    end

    def managed_repository?(repository)
      data.dig("repositoryScope", "repositories").key?(repository)
    end

    def repository_targets(repository)
      data.dig("repositoryScope", "defaults").merge(
        data.dig("repositoryScope", "repositories").fetch(repository)
      )
    end

    def manual_attestations
      data.fetch("manualAttestations").sort.map do |id, definition|
        definition.merge("id" => id)
      end
    end

    def effective_applicability(target)
      return "APPLICABLE" if target.fetch("applicability") == "CURRENT"

      case data.fetch("gates").fetch(target.fetch("gate"))
      when "pending" then "GATED"
      when "satisfied" then "APPLICABLE"
      when "not_applicable" then "NOT_APPLICABLE"
      end
    end

    private

    def validate!
      unless data.is_a?(Hash) && data.keys.sort == TOP_LEVEL_KEYS.sort &&
             data["$schema"] == "../schemas/github-settings-policy.schema.json" && data["schemaVersion"] == "1.0"
        raise PolicyError, "unsupported schema"
      end
      raise PolicyError, "invalid stage" unless %w[solo-local solo-public multi-maintainer].include?(data["stage"])
      validate_identifier!(data["organization"], LOGIN_PATTERN)
      validate_identifier!(data["expectedLogin"], LOGIN_PATTERN)
      validate_gates!
      validate_targets!(data["organizationTargets"], ORGANIZATION_TARGETS)

      scope = data["repositoryScope"]
      unless scope.is_a?(Hash) && scope.keys.sort == %w[defaults repositories visibility] && scope["visibility"] == "public"
        raise PolicyError, "repository scope must be public"
      end
      repositories = scope["repositories"]
      raise PolicyError, "invalid repository map" unless repositories.is_a?(Hash)

      validate_targets!(scope["defaults"], REPOSITORY_TARGETS)
      repositories.each do |name, overrides|
        validate_identifier!(name, REPOSITORY_PATTERN)
        validate_targets!(overrides, REPOSITORY_TARGETS, partial: true)
        unless REPOSITORY_OVERRIDE_TARGETS.all? { |target| overrides.key?(target) }
          raise PolicyError, "repository override target missing"
        end
        validate_repository_target_values!(scope["defaults"].merge(overrides))
      end
      validate_organization_target_values!
      validate_repository_target_values!(scope["defaults"])
      validate_public_interaction_hold!(scope)
      validate_manual_attestations!
      if stage == "multi-maintainer" && data.dig("gates", "independentSecondOwner") != "satisfied"
        raise PolicyError, "multi-maintainer requires an independent second owner"
      end
    end

    def validate_identifier!(value, pattern)
      raise PolicyError, "invalid identifier" unless value.is_a?(String) && value.match?(pattern)
    end

    def validate_gates!
      gates = data["gates"]
      raise PolicyError, "invalid gates" unless gates.is_a?(Hash) && gates.keys.sort == GATE_NAMES.sort
      raise PolicyError, "invalid gate" unless gates.values.all? { |value| GATE_STATES.include?(value) }
    end

    def validate_targets!(targets, specification, partial: false)
      valid_keys = targets.is_a?(Hash) && targets.keys.all? { |name| specification.key?(name) }
      valid_keys &&= targets.keys.sort == specification.keys.sort unless partial
      unless valid_keys
        raise PolicyError, "target set mismatch"
      end

      targets.each do |name, target|
        type = specification.fetch(name)
        applicability = target.is_a?(Hash) ? target["applicability"] : nil
        valid_type = Array(type).any? { |klass| target.is_a?(Hash) && target["value"].is_a?(klass) }
        valid_applicability = APPLICABILITIES.include?(applicability)
        expected_keys = applicability == "FUTURE_GATE" ? %w[applicability gate value] : %w[applicability value]
        valid_keys = target.is_a?(Hash) && target.keys.sort == expected_keys
        valid_gate = applicability != "FUTURE_GATE" || GATE_NAMES.include?(target["gate"])
        valid_value = type != Integer || (target.is_a?(Hash) && target["value"].is_a?(Integer) && target["value"] >= 0)
        raise PolicyError, "invalid target" unless valid_type && valid_applicability && valid_keys && valid_gate && valid_value
      end
    end

    def validate_manual_attestations!
      attestations = data["manualAttestations"]
      raise PolicyError, "invalid manual attestations" unless attestations.is_a?(Hash)

      valid = attestations.all? do |id, entry|
        next false unless id.is_a?(String) && id.match?(/\Amanual\.[a-z0-9_]+\z/)
        next false unless entry.is_a?(Hash)
        expected_keys = entry["applicability"] == "FUTURE_GATE" ? %w[applicability gate severity] : %w[applicability severity]
        next false unless entry.keys.sort == expected_keys
        next false unless APPLICABILITIES.include?(entry["applicability"])
        next false unless entry["applicability"] != "FUTURE_GATE" || GATE_NAMES.include?(entry["gate"])

        %w[LOW MEDIUM HIGH].include?(entry["severity"])
      end
      raise PolicyError, "invalid manual attestations" unless valid
    end

    def validate_organization_target_values!
      organization_values = data.fetch("organizationTargets")
      allowed = [
        [organization_values.fetch("plan").fetch("value"), %w[free team enterprise business business_plus]],
        [organization_values.fetch("basePermission").fetch("value"), %w[none read write admin]],
        [organization_values.fetch("actionsEnabledRepositories").fetch("value"), %w[all selected none]],
        [organization_values.fetch("actionsAllowed").fetch("value"), %w[all local_only selected]],
        [organization_values.fetch("defaultWorkflowPermission").fetch("value"), %w[read write]]
      ]
      raise PolicyError, "invalid target enum" unless allowed.all? { |value, values| values.include?(value) }

      validate_action_patterns!(organization_values.fetch("actionsPatternsAllowed").fetch("value"))
    end

    def validate_repository_target_values!(repository_values)
      allowed = [
        [repository_values.fetch("actionsAllowed").fetch("value"), %w[all local_only selected]],
        [repository_values.fetch("defaultWorkflowPermission").fetch("value"), %w[read write]],
        [repository_values.fetch("secretScanning").fetch("value"), %w[enabled disabled]],
        [repository_values.fetch("secretScanningPushProtection").fetch("value"), %w[enabled disabled]],
        [repository_values.fetch("codeScanning").fetch("value"), %w[configured not-configured]]
      ]
      raise PolicyError, "invalid target enum" unless allowed.all? { |value, values| values.include?(value) }

      default_branch = repository_values.fetch("defaultBranch").fetch("value")
      raise PolicyError, "invalid default branch" unless default_branch.match?(BRANCH_PATTERN)

      topics = repository_values.fetch("topics").fetch("value")
      unless topics.all? { |topic| topic.is_a?(String) && topic.match?(TOPIC_PATTERN) } && topics.uniq.length == topics.length
        raise PolicyError, "invalid topics"
      end
      validate_action_patterns!(repository_values.fetch("actionsPatternsAllowed").fetch("value"))
    end

    def validate_action_patterns!(values)
      valid = values.uniq.length == values.length && values.all? do |value|
        value.is_a?(String) && value.match?(ACTION_PATTERN)
      end
      raise PolicyError, "invalid action patterns" unless valid
    end

    def validate_public_interaction_hold!(scope)
      return if data.dig("gates", "publicInteraction") == "satisfied"

      targets = [scope.fetch("defaults")] + scope.fetch("repositories").values.map do |overrides|
        scope.fetch("defaults").merge(overrides)
      end
      disabled = {"applicability" => "CURRENT", "value" => false}
      unless targets.all? { |values| values.fetch("issues") == disabled && values.fetch("discussions") == disabled }
        raise PolicyError, "public interaction must remain disabled"
      end
    end
  end

  class LiveTransport
    REST_ENDPOINTS = EndpointRegistry.rest_endpoints
    ORGANIZATION_PROJECTS_QUERY = EndpointRegistry::ORGANIZATION_PROJECTS_QUERY
    TIMEOUT_SECONDS = 30
    PAGE_SIZE = 100
    MAX_PAGES = 100
    CLEARED_ENVIRONMENT = %w[
      GH_HOST GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN GH_CONFIG_DIR GH_REPO
      GH_DEBUG GH_TOKEN GITHUB_TOKEN
    ].freeze

    def initialize(command_runner: nil, gh_path: nil)
      @command_runner = command_runner || ProcessRunner.new(timeout_seconds: TIMEOUT_SECONDS)
      @gh_path = TrustedExecutable.resolve(gh_path ? [gh_path] : TrustedExecutable::GH_CANDIDATES)
    rescue TrustedExecutableUnavailable
      raise ControlProbeError
    end

    def authenticate
      endpoint_id = EndpointRegistry.endpoint_id(:authentication)
      stdout, stderr, status = capture(@gh_path, "auth", "status", "--hostname", "github.com")
      return response(endpoint_id, status: "auth_failed", reason_code: "authentication_failed") unless status.success?

      combined = "#{stdout}\n#{stderr}"
      scopes = %w[admin:org read:org read:project].select { |scope| combined.include?(scope) }
      response(endpoint_id, status: 0, data: {"scopes" => scopes})
    rescue ProcessTimeout, OutputLimitExceeded, Errno::ENOENT
      response(:authentication, status: "auth_failed", reason_code: "authentication_failed")
    end

    def get(endpoint_id, variables: {}, paginate: false)
      entry = EndpointRegistry.fetch(endpoint_id)
      raise Error, "endpoint is not a REST endpoint" unless entry.rest_path

      endpoint = format_endpoint(entry.rest_path, variables)
      return get_paginated(entry.endpoint_id, endpoint) if paginate

      stdout, stderr, status = capture(*rest_arguments(endpoint))
      return error_response(entry.endpoint_id, stderr) unless status.success?

      return response(entry.endpoint_id, status: 204) if stdout.strip.empty?

      response(entry.endpoint_id, status: 200, data: parse_json(stdout))
    rescue JSON::ParserError
      response(endpoint_id, status: "invalid_json", reason_code: "invalid_response")
    rescue ProcessTimeout
      response(endpoint_id, status: "timeout", reason_code: "network_timeout")
    rescue OutputLimitExceeded
      response(endpoint_id, status: "output_limit", reason_code: "output_limit")
    rescue Errno::ENOENT
      response(endpoint_id, status: "transport_failed", reason_code: "transport_unavailable")
    end

    def graphql(endpoint_id, query:, variables: {})
      entry = EndpointRegistry.fetch(endpoint_id)
      unless entry.graphql_query && query.equal?(entry.graphql_query)
        raise Error, "GraphQL operation is not allowlisted"
      end
      organization = validated_value(variables, :org, Policy::LOGIN_PATTERN)
      stdout, stderr, status = capture(
        @gh_path, "api", "--hostname", "github.com", "graphql", "--method", "POST",
        "-f", "query=#{ORGANIZATION_PROJECTS_QUERY}", "-F", "organization=#{organization}"
      )
      return error_response(entry.endpoint_id, stderr) unless status.success?

      parsed = parse_json(stdout)
      reason = parsed["errors"].is_a?(Array) && !parsed["errors"].empty? ? "graphql_partial" : nil
      response(entry.endpoint_id, status: 200, data: parsed["data"], reason_code: reason)
    rescue JSON::ParserError
      response(endpoint_id, status: "invalid_json", reason_code: "invalid_response")
    rescue ProcessTimeout
      response(endpoint_id, status: "timeout", reason_code: "network_timeout")
    rescue OutputLimitExceeded
      response(endpoint_id, status: "output_limit", reason_code: "output_limit")
    rescue Errno::ENOENT
      response(endpoint_id, status: "transport_failed", reason_code: "transport_unavailable")
    end

    private

    def capture(*arguments)
      environment = CLEARED_ENVIRONMENT.to_h { |name| [name, nil] }
      @command_runner.capture3(environment, *arguments)
    end

    def get_paginated(endpoint_id, endpoint)
      pages = []
      response_bytes = 0
      MAX_PAGES.times do |index|
        page_endpoint = with_page(endpoint, index + 1)
        stdout, stderr, status = capture(*rest_arguments(page_endpoint))
        return error_response(endpoint_id, stderr) unless status.success?

        response_bytes += stdout.bytesize + stderr.bytesize
        if response_bytes > ProcessRunner::OUTPUT_LIMIT_BYTES
          return response(endpoint_id, status: "output_limit", reason_code: "output_limit")
        end
        page = stdout.strip.empty? ? [] : parse_json(stdout)
        return response(endpoint_id, status: "invalid_json", reason_code: "invalid_response") unless page.is_a?(Array)

        pages << page
        return response(endpoint_id, status: 200, pages: pages) if page.length < PAGE_SIZE
      end
      response(endpoint_id, status: "pagination_limit", reason_code: "pagination_limit")
    end

    def rest_arguments(endpoint)
      [@gh_path, "api", "--hostname", "github.com", "--method", "GET", endpoint]
    end

    def with_page(endpoint, page)
      uri = URI.parse(endpoint)
      query = URI.decode_www_form(uri.query.to_s)
      query.reject! { |name, _value| name == "page" }
      query << ["page", page.to_s]
      uri.query = URI.encode_www_form(query)
      uri.to_s
    end

    def parse_json(text)
      JSON.parse(text)
    end

    def format_endpoint(template, variables)
      values = {}
      values[:org] = validated_value(variables, :org, Policy::LOGIN_PATTERN) if template.include?("%{org}")
      values[:repo] = validated_value(variables, :repo, Policy::REPOSITORY_PATTERN) if template.include?("%{repo}")
      values[:login] = validated_value(variables, :login, Policy::LOGIN_PATTERN) if template.include?("%{login}")
      if template.include?("%{branch}")
        branch = validated_value(variables, :branch, Policy::BRANCH_PATTERN)
        values[:branch] = URI.encode_www_form_component(branch)
      end
      format(template, values)
    end

    def validated_value(variables, key, pattern)
      value = variables.fetch(key)
      raise Error, "invalid endpoint variable" unless value.is_a?(String) && value.match?(pattern)

      value
    end

    def error_response(endpoint_id, error_text)
      status = error_text[/HTTP\s+(\d{3})/i, 1]&.to_i
      reason = if error_text.match?(/rate.?limit/i)
                 "rate_limited"
               elsif status == 401
                 "unauthorized"
               elsif status == 403
                 "forbidden"
               elsif status == 404
                 "not_found_ambiguous"
               elsif status && status >= 500
                 "server_error"
               else
                 "network_error"
               end
      response(endpoint_id, status: status || "transport_failed", reason_code: reason)
    end

    def response(endpoint_id, **attributes)
      Response.new(endpoint_id: EndpointRegistry.endpoint_id(endpoint_id), **attributes)
    end
  end

  class Auditor
    STATUS_ORDER = %w[FAIL PASS UNKNOWN WARN].freeze
    REASON_CODES = %w[
      authentication_failed count_only count_unavailable empty_repository
      empty_repository_gate forbidden free_plan_capability graphql_partial
      independent_owner_pending invalid_field invalid_response manual_attestation
      manual_attestation_required minimum_not_met minimum_satisfied missing_scope
      network_error network_timeout not_found_ambiguous parent_all
      output_limit pagination_limit parent_not_selected rate_limited
      repository_rule_present resource_absent selected_policy_visible
      server_error solo_safe_hold stage_reassessment_required target_mismatch
      target_satisfied transport_unavailable unauthorized gate_pending
      gate_not_applicable unmanaged_repository
      independence_requires_attestation
    ].freeze
    SEVERITY = {
      info: "INFO", low: "LOW", medium: "MEDIUM", high: "HIGH"
    }.freeze

    def initialize(policy:, transport:, organization:, repositories:, all_public:, attestations:, strict: false)
      @policy = policy
      @transport = transport
      @organization = organization
      @repositories = repositories
      @all_public = all_public
      @attestations = attestations
      @strict = strict
      @checks = []
      @plan = "UNKNOWN"
      @login = "UNKNOWN"
      @public_repository_count = 0
    end

    def run
      authenticate!
      audit_organization
      audit_repositories
      audit_manual_attestations
      checks = @checks.sort_by { |check| [check.fetch("id"), check.fetch("resource")] }
      summary = STATUS_ORDER.to_h { |status| [status, checks.count { |check| check.fetch("status") == status }] }
      document = {
        "schemaVersion" => "1.0",
        "mode" => "READ_ONLY",
        "run" => {
          "org" => @organization,
          "login" => @login,
          "plan" => @plan,
          "publicRepositoryCount" => @public_repository_count
        },
        "summary" => summary,
        "checks" => checks,
        "redaction" => {
          "rawResponsesIncluded" => false,
          "identitiesIncluded" => false,
          "sensitiveFieldsIncluded" => false
        }
      }
      exit_code = summary["FAIL"].positive? || (@strict && summary["UNKNOWN"].positive?) ? 1 : 0
      Result.new(document: document, exit_code: exit_code)
    end

    private

    def authenticate!
      auth = @transport.authenticate
      raise ControlProbeError unless auth.status == 0 && auth.data.is_a?(Hash) && auth.data["scopes"].is_a?(Array)

      @scopes = auth.data["scopes"].select { |scope| scope.is_a?(String) }
      viewer = get(:viewer)
      login = viewer.data["login"] if viewer.success? && viewer.data.is_a?(Hash)
      raise ControlProbeError unless login.is_a?(String) && login.match?(Policy::LOGIN_PATTERN)

      @login = login
      add_comparison(
        id: "operator.login", resource: @organization, target: {"applicability" => "CURRENT", "value" => @policy.expected_login},
        actual: login, response: viewer, severity: :high
      )
    end

    def audit_organization
      organization = get(:organization, org: @organization)
      data = organization.data.is_a?(Hash) ? organization.data : {}
      plan = enum(data["plan"].is_a?(Hash) ? data.dig("plan", "name") : nil, %w[free team enterprise business business_plus])
      @plan = plan || "UNKNOWN"
      add_response_or_comparison("org.plan", @organization, @policy.organization_target("plan"), plan, organization, :medium)
      add_response_or_comparison("org.base_permission", @organization, @policy.organization_target("basePermission"), enum(data["default_repository_permission"], %w[none read write admin]), organization, :high)
      creation = repository_creation_value(data)
      add_response_or_comparison("org.member_repository_creation", @organization, @policy.organization_target("memberRepositoryCreation"), creation, organization, :high)
      add_response_or_comparison("org.member_repository_deletion", @organization, @policy.organization_target("memberRepositoryDeletion"), typed(data["members_can_delete_repositories"], boolean_types), organization, :high)
      add_response_or_comparison("org.member_visibility_changes", @organization, @policy.organization_target("memberVisibilityChanges"), typed(data["members_can_change_repo_visibility"], boolean_types), organization, :high)
      add_response_or_comparison("org.outside_collaborator_invitation", @organization, @policy.organization_target("outsideCollaboratorInvitation"), typed(data["members_can_invite_outside_collaborators"], boolean_types), organization, :high)

      owners = add_count("org.owners.count", :owners, :high)
      add_owner_gates(owners)
      add_count("org.members.count", :members, :info)
      add_count("org.public_members.count", :public_members, :info)
      add_count("org.outside_collaborators.count", :outside_collaborators, :medium)
      add_count("org.teams.count", :teams, :info)
      audit_operator_membership
      audit_two_factor(data, organization, owners)
      audit_org_actions
      audit_org_projects
      audit_org_security_defaults
      audit_free_capabilities
    end

    def repository_creation_value(data)
      values = %w[
        members_can_create_repositories
        members_can_create_public_repositories
        members_can_create_private_repositories
        members_can_create_internal_repositories
      ].map do |key|
        typed(data[key], boolean_types)
      end
      return true if values.include?(true)
      return nil if values.any?(&:nil?)

      false
    end

    def add_count(id, endpoint_id, severity)
      response = get(endpoint_id, {org: @organization}, paginate: true)
      count = response.success? ? response.count : nil
      if count.is_a?(Integer)
        add_check(id, @organization, "PASS", severity, "CURRENT", "COUNT_ONLY", count, "AVAILABLE", response.endpoint_id, response.status, "count_only")
      else
        add_unknown(id, @organization, severity, "CURRENT", "COUNT_ONLY", response)
      end
      count
    end

    def add_owner_gates(count)
      if @policy.stage == "multi-maintainer"
        add_check("org.owners.solo_safe_hold", @organization, "WARN", :medium, "NOT_APPLICABLE", 1, count || "UNKNOWN", "AVAILABLE", :owners, count.nil? ? "UNAVAILABLE" : 200, "stage_reassessment_required")
      elsif count.nil?
        synthetic = synthetic_response(:owners, status: "unknown", reason_code: "count_unavailable")
        add_unknown("org.owners.solo_safe_hold", @organization, :high, "CURRENT", 1, synthetic)
      elsif count == 1
        add_check("org.owners.solo_safe_hold", @organization, "PASS", :high, "CURRENT", 1, count, "AVAILABLE", :owners, 200, "solo_safe_hold")
      else
        add_check("org.owners.solo_safe_hold", @organization, "WARN", :medium, "CURRENT", 1, count, "AVAILABLE", :owners, 200, "stage_reassessment_required")
      end

      target = {"applicability" => "FUTURE_GATE", "gate" => "independentSecondOwner", "value" => 2}
      response = if count.nil?
                   synthetic_response(:owners, status: "unknown", reason_code: "count_unavailable")
                 else
                   synthetic_response(:owners, status: 200)
                 end
      add_minimum("org.owners.future_adoption", @organization, target, count, response, :high)
    end

    def audit_operator_membership
      response = get(:operator_membership, org: @organization, login: @login)
      actual = if response.success? && response.data.is_a?(Hash)
                 state = enum(response.data["state"], %w[active pending])
                 role = enum(response.data["role"], %w[admin member])
                 "#{state}_#{role}" if state && role
               end
      target = {"applicability" => "CURRENT", "value" => "active_admin"}
      add_response_or_comparison("operator.membership", @organization, target, actual, response, :high)
    end

    def audit_two_factor(data, response, owner_count)
      actual = typed(data["two_factor_requirement_enabled"], boolean_types)
      if @policy.stage == "multi-maintainer"
        add_check("org.two_factor.solo_safe_hold", @organization, "WARN", :high, "NOT_APPLICABLE", false, actual.nil? ? "UNKNOWN" : actual, "AVAILABLE", :organization, response.status, "stage_reassessment_required")
      elsif actual.nil? || !response.success? || owner_count.nil?
        add_unknown("org.two_factor.solo_safe_hold", @organization, :high, "CURRENT", false, response)
      elsif owner_count == 1 && actual == false
        add_check("org.two_factor.solo_safe_hold", @organization, "PASS", :high, "CURRENT", false, actual, "AVAILABLE", :organization, response.status, "solo_safe_hold")
      else
        add_check("org.two_factor.solo_safe_hold", @organization, "WARN", :high, "CURRENT", false, actual, "AVAILABLE", :organization, response.status, "stage_reassessment_required")
      end
      add_response_or_comparison("org.two_factor.future_adoption", @organization, @policy.organization_target("twoFactorRequired"), actual, response, :high)
    end

    def audit_org_actions
      permissions = get(:org_actions_permissions, org: @organization)
      capability = @scopes.include?("admin:org") ? "AVAILABLE" : "MISSING_SCOPE"
      permissions_data = permissions.data.is_a?(Hash) ? permissions.data : {}
      allowed = enum(permissions_data["allowed_actions"], %w[all local_only selected]) if permissions.success?
      enabled = enum(permissions_data["enabled_repositories"], %w[all selected none]) if permissions.success?
      sha_pinning_required = typed(permissions_data["sha_pinning_required"], boolean_types) if permissions.success?
      add_response_or_comparison("org.actions.enabled_repositories", @organization, @policy.organization_target("actionsEnabledRepositories"), enabled, permissions, :high, capability: capability)
      add_response_or_comparison("org.actions.allowed", @organization, @policy.organization_target("actionsAllowed"), allowed, permissions, :high, capability: capability)
      add_response_or_comparison("org.actions.sha_pinning_required", @organization, @policy.organization_target("actionsShaPinningRequired"), sha_pinning_required, permissions, :high, capability: capability)

      workflow = get(:org_actions_workflow, org: @organization)
      workflow_data = workflow.data.is_a?(Hash) ? workflow.data : {}
      add_response_or_comparison("org.actions.default_workflow_permission", @organization, @policy.organization_target("defaultWorkflowPermission"), enum(workflow_data["default_workflow_permissions"], %w[read write]), workflow, :high, capability: capability)
      add_response_or_comparison("org.actions.approve_pull_requests", @organization, @policy.organization_target("canApprovePullRequestReviews"), typed(workflow_data["can_approve_pull_request_reviews"], boolean_types), workflow, :high, capability: capability)
      audit_selected_actions(
        "org.actions.selected", :org_actions_selected, @organization, allowed, permissions,
        {
          "github_owned" => @policy.organization_target("actionsGithubOwnedAllowed"),
          "verified" => @policy.organization_target("actionsVerifiedAllowed"),
          "patterns" => @policy.organization_target("actionsPatternsAllowed")
        },
        {org: @organization}, capability
      )
    end

    def audit_org_projects
      target = @policy.organization_target("projectsMinimum")
      unless @scopes.include?("read:project")
        response = synthetic_response(:organization_projects, status: "not_called", reason_code: "missing_scope")
        add_target_unknown("org.projects", @organization, :medium, target, response, "MISSING_SCOPE")
        return
      end

      response = @transport.graphql(
        :organization_projects,
        query: LiveTransport::ORGANIZATION_PROJECTS_QUERY,
        variables: {org: @organization}
      )
      count = response.data.dig("organization", "projectsV2", "totalCount") if response.data.is_a?(Hash)
      add_minimum("org.projects", @organization, target, typed(count, Integer), response, :medium)
    end

    def audit_org_security_defaults
      response = get(:org_security_defaults, {org: @organization}, paginate: true)
      count = response.success? ? response.count : nil
      add_minimum("org.security_defaults", @organization, @policy.organization_target("securityDefaultsMinimum"), count, response, :high)
    end

    def audit_free_capabilities
      return unless @plan == "free"

      target = {"applicability" => "FUTURE_GATE", "gate" => "sourcePublication", "value" => "AVAILABLE"}
      add_check("org.rulesets", @organization, "WARN", :medium, @policy.effective_applicability(target), "AVAILABLE", "NOT_AVAILABLE_ON_FREE", "NOT_AVAILABLE_ON_FREE", :organization_rulesets, "NOT_CALLED", "free_plan_capability")
    end

    def audit_repositories
      names = @repositories
      if @all_public
        response = get(:repositories, {org: @organization}, paginate: true)
        unless response.success?
          add_unknown("org.public_repositories", @organization, :high, "CURRENT", "COUNT_ONLY", response)
          return
        end
        pages = response.pages || []
        names = pages.flatten.filter_map do |repo|
          next unless repo.is_a?(Hash) && repo["private"] == false
          name = repo["name"]
          name if name.is_a?(String) && name.match?(Policy::REPOSITORY_PATTERN)
        end.uniq.sort
      end

      names.sort.each { |name| audit_repository(name) }
    end

    def audit_repository(name)
      core = get(:repository, org: @organization, repo: name)
      data = core.data.is_a?(Hash) ? core.data : {}
      public = if data["private"] == false && data["visibility"] == "public"
                 true
               elsif data["private"] == true || data["visibility"] == "private"
                 false
               end
      resource = public == true ? "#{@organization}/#{name}" : "repository"
      unless core.success? && !public.nil?
        add_unknown("repo.public", resource, :high, "CURRENT", true, core)
        return
      end

      @public_repository_count += 1 if public
      add_comparison(id: "repo.public", resource: resource, target: {"applicability" => "CURRENT", "value" => true}, actual: public, response: core, severity: :high)
      return unless public

      unless @policy.managed_repository?(name)
        add_check(
          "repo.managed", resource, "FAIL", :high, "CURRENT", "MANAGED", "UNMANAGED",
          "AVAILABLE", :repository, core.status, "unmanaged_repository"
        )
        return
      end

      add_check(
        "repo.managed", resource, "PASS", :high, "CURRENT", "MANAGED", "MANAGED",
        "AVAILABLE", :repository, core.status, "target_satisfied"
      )
      targets = @policy.repository_targets(name)

      published = repository_published(data)
      empty = !published unless published.nil?
      add_response_or_comparison("repo.source_published", resource, targets.fetch("sourcePublished"), published, core, :high)
      audit_default_branch(resource, data, core, empty, targets)
      topics = valid_topics(data["topics"])
      add_response_or_comparison("repo.topics", resource, targets.fetch("topics"), topics&.sort, core, :medium, expected: targets.dig("topics", "value").sort)
      audit_repo_boolean_settings(resource, data, core, targets)
      audit_repo_security_analysis(resource, data, core, targets)
      audit_repo_rules(resource, name, data, empty, targets)
      audit_repo_actions(resource, name, targets)
      audit_repo_community(resource, name, targets)
      audit_repo_security_endpoints(resource, name, targets)
      releases = get(:releases, {org: @organization, repo: name}, paginate: true)
      add_response_or_comparison("repo.releases", resource, targets.fetch("releases"), releases.success? ? releases.count : nil, releases, :medium)
    end

    def audit_default_branch(resource, data, response, empty, targets)
      target = targets.fetch("defaultBranch")
      if empty == true && data["default_branch"].nil?
        add_not_applicable(
          id: "repo.default_branch", resource: resource, target: target, response: response,
          severity: :medium, actual: "EMPTY_REPOSITORY", evidence_status: response.status,
          reason_code: "empty_repository"
        )
      else
        add_response_or_comparison("repo.default_branch", resource, target, valid_branch(data["default_branch"]), response, :medium)
      end
    end

    def audit_repo_boolean_settings(resource, data, response, targets)
      {
        "repo.issues" => ["issues", "has_issues", :medium],
        "repo.discussions" => ["discussions", "has_discussions", :medium],
        "repo.wiki" => ["wiki", "has_wiki", :low],
        "repo.projects" => ["projects", "has_projects", :low],
        "repo.merge.squash" => ["allowSquashMerge", "allow_squash_merge", :high],
        "repo.merge.commit" => ["allowMergeCommit", "allow_merge_commit", :high],
        "repo.merge.rebase" => ["allowRebaseMerge", "allow_rebase_merge", :high],
        "repo.delete_branch" => ["deleteBranchOnMerge", "delete_branch_on_merge", :high]
      }.each do |id, (target, field, severity)|
        add_response_or_comparison(id, resource, targets.fetch(target), typed(data[field], boolean_types), response, severity)
      end
    end

    def audit_repo_security_analysis(resource, data, response, targets)
      analysis = data["security_and_analysis"].is_a?(Hash) ? data["security_and_analysis"] : {}
      {
        "repo.secret_scanning" => ["secretScanning", "secret_scanning"],
        "repo.secret_scanning_push_protection" => ["secretScanningPushProtection", "secret_scanning_push_protection"]
      }.each do |id, (target, field)|
        value = analysis[field].is_a?(Hash) ? enum(analysis.dig(field, "status"), %w[enabled disabled]) : nil
        add_response_or_comparison(id, resource, targets.fetch(target), value, response, :high)
      end
    end

    def audit_repo_rules(resource, name, data, empty, targets)
      rulesets = get(:repo_rulesets, {org: @organization, repo: name}, paginate: true)
      branch = valid_branch(data["default_branch"])
      protection = if branch
                     get(:branch_protection, org: @organization, repo: name, branch: branch)
                   else
                     reason_code = empty == true ? "empty_repository" : "invalid_field"
                     synthetic_response(:branch_protection, status: "not_called", reason_code: reason_code)
                   end
      rules_count = rulesets.success? ? rulesets.count : nil
      protected = protection.success?
      target = targets.fetch("rulesMinimum")
      if rules_count && rules_count >= target["value"]
        add_minimum("repo.rules", resource, target, rules_count, rulesets, :high)
      elsif protected
        add_minimum("repo.rules", resource, target, [target["value"], 1].max, protection, :high)
      elsif rulesets.success? && (empty == true || (branch && protection.status == 404))
        add_minimum("repo.rules", resource, target, rules_count, rulesets, :high)
      else
        evidence = rulesets.success? ? protection : rulesets
        add_target_unknown("repo.rules", resource, :high, target, evidence)
      end
    end

    def audit_repo_actions(resource, name, targets)
      permissions = get(:repo_actions_permissions, org: @organization, repo: name)
      permissions_data = permissions.data.is_a?(Hash) ? permissions.data : {}
      allowed = enum(permissions_data["allowed_actions"], %w[all local_only selected]) if permissions.success?
      enabled = typed(permissions_data["enabled"], boolean_types) if permissions.success?
      add_response_or_comparison("repo.actions.enabled", resource, targets.fetch("actionsEnabled"), enabled, permissions, :high)
      add_response_or_comparison("repo.actions.allowed", resource, targets.fetch("actionsAllowed"), allowed, permissions, :high)

      workflow = get(:repo_actions_workflow, org: @organization, repo: name)
      workflow_data = workflow.data.is_a?(Hash) ? workflow.data : {}
      add_response_or_comparison("repo.actions.default_workflow_permission", resource, targets.fetch("defaultWorkflowPermission"), enum(workflow_data["default_workflow_permissions"], %w[read write]), workflow, :high)
      add_response_or_comparison("repo.actions.approve_pull_requests", resource, targets.fetch("canApprovePullRequestReviews"), typed(workflow_data["can_approve_pull_request_reviews"], boolean_types), workflow, :high)
      audit_selected_actions(
        "repo.actions.selected", :repo_actions_selected, resource, allowed, permissions,
        {
          "github_owned" => targets.fetch("actionsGithubOwnedAllowed"),
          "verified" => targets.fetch("actionsVerifiedAllowed"),
          "patterns" => targets.fetch("actionsPatternsAllowed")
        },
        {org: @organization, repo: name}
      )
    end

    def audit_selected_actions(id, endpoint_id, resource, parent, parent_response, targets, variables, capability = "AVAILABLE")
      unless parent_response.success? && capability == "AVAILABLE"
        response = synthetic_response(
          endpoint_id,
          status: parent_response.status,
          reason_code: parent_response.reason_code
        )
        targets.each do |field, target|
          add_target_unknown("#{id}.#{field}", resource, :medium, target, response, capability)
        end
        return
      end

      response = get(endpoint_id, variables)
      if %w[all local_only].include?(parent) && response.status == 409
        targets.each do |field, target|
          add_not_applicable(
            id: "#{id}.#{field}", resource: resource, target: target, response: response,
            severity: :low, actual: "PARENT_NOT_SELECTED", evidence_status: 409,
            reason_code: "parent_not_selected"
          )
        end
        return
      end

      data = response.data.is_a?(Hash) ? response.data : {}
      actuals = {
        "github_owned" => typed(data["github_owned_allowed"], boolean_types),
        "verified" => typed(data["verified_allowed"], boolean_types),
        "patterns" => valid_action_patterns(data["patterns_allowed"])&.sort
      }
      targets.each do |field, target|
        expected_target = field == "patterns" ? target.merge("value" => target["value"].sort) : target
        add_response_or_comparison("#{id}.#{field}", resource, expected_target, actuals[field], response, :high)
      end
    end

    def audit_repo_community(resource, name, targets)
      profile = get(:community_profile, org: @organization, repo: name)
      percentage = profile.data["health_percentage"] if profile.success? && profile.data.is_a?(Hash)
      add_minimum("repo.community_profile", resource, targets.fetch("communityHealthMinimum"), typed(percentage, Integer), profile, :medium)

      errors = get(:codeowners_errors, org: @organization, repo: name)
      if errors.success? && errors.data.is_a?(Hash) && errors.data["errors"].is_a?(Array)
        add_response_or_comparison("repo.codeowners_errors", resource, targets.fetch("codeownersErrors"), errors.data["errors"].length, errors, :medium)
      else
        add_target_unknown("repo.codeowners_errors", resource, :medium, targets.fetch("codeownersErrors"), errors)
      end
    end

    def audit_repo_security_endpoints(resource, name, targets)
      pvr = get(:private_vulnerability_reporting, org: @organization, repo: name)
      pvr_value = pvr.data["enabled"] if pvr.success? && pvr.data.is_a?(Hash)
      add_response_or_comparison("repo.private_vulnerability_reporting", resource, targets.fetch("privateVulnerabilityReporting"), typed(pvr_value, boolean_types), pvr, :high)

      alerts = get(:vulnerability_alerts, org: @organization, repo: name)
      audit_presence_endpoint("repo.vulnerability_alerts", resource, targets.fetch("vulnerabilityAlerts"), alerts, :high)
      fixes = get(:automated_security_fixes, org: @organization, repo: name)
      audit_presence_endpoint("repo.automated_security_fixes", resource, targets.fetch("automatedSecurityFixes"), fixes, :medium)

      scanning = get(:code_scanning_default_setup, org: @organization, repo: name)
      state = scanning.data["state"] if scanning.success? && scanning.data.is_a?(Hash)
      if scanning.status == 404
        evidence = synthetic_response(:code_scanning_default_setup, status: 200)
        add_response_or_comparison("repo.code_scanning", resource, targets.fetch("codeScanning"), "not-configured", evidence, :high, evidence_status: 404, reason_code: "resource_absent")
      else
        add_response_or_comparison("repo.code_scanning", resource, targets.fetch("codeScanning"), enum(state, %w[configured not-configured]), scanning, :high)
      end
    end

    def audit_presence_endpoint(id, resource, target, response, severity)
      if response.success?
        add_response_or_comparison(id, resource, target, true, response, severity)
      elsif response.status == 404
        evidence = synthetic_response(response.endpoint_id, status: 200)
        add_response_or_comparison(id, resource, target, false, evidence, severity, evidence_status: 404, reason_code: "resource_absent")
      else
        add_target_unknown(id, resource, severity, target, response)
      end
    end

    def audit_manual_attestations
      @policy.manual_attestations.each do |definition|
        id = definition.fetch("id")
        applicability = @policy.effective_applicability(definition)
        severity = definition.fetch("severity").downcase.to_sym
        value = @attestations[id]
        if applicability == "GATED"
          add_check(id, @organization, "WARN", severity, applicability, true, value.nil? ? "UNATTESTED" : (value ? "ATTESTED" : "NOT_ATTESTED"), "MANUAL", :manual_attestation, value.nil? ? "NOT_PROVIDED" : "ATTESTED", "gate_pending")
        elsif applicability == "NOT_APPLICABLE"
          add_check(id, @organization, "WARN", severity, applicability, true, "NOT_APPLICABLE", "MANUAL", :manual_attestation, "NOT_CALLED", "gate_not_applicable")
        elsif value == true
          add_check(id, @organization, "PASS", severity, applicability, true, "ATTESTED", "MANUAL", :manual_attestation, "ATTESTED", "manual_attestation")
        elsif value == false
          add_check(id, @organization, "FAIL", severity, applicability, true, "NOT_ATTESTED", "MANUAL", :manual_attestation, "NOT_ATTESTED", "manual_attestation")
        else
          add_check(id, @organization, "UNKNOWN", severity, applicability, true, "UNATTESTED", "MANUAL", :manual_attestation, "NOT_PROVIDED", "manual_attestation_required")
        end
      end
    end

    def add_response_or_comparison(id, resource, target, actual, response, severity, capability: "AVAILABLE", expected: nil, evidence_status: nil, reason_code: nil)
      applicability = @policy.effective_applicability(target)
      if applicability != "APPLICABLE"
        reason = applicability == "GATED" ? "gate_pending" : "gate_not_applicable"
        add_check(
          id, resource, "WARN", severity, applicability, expected || target["value"], actual.nil? ? "UNKNOWN" : actual,
          capability, response.endpoint_id, evidence_status || normalized_status(response.status), reason
        )
        return
      end
      if !response.success? || actual.nil? || capability == "MISSING_SCOPE"
        add_unknown(id, resource, severity, applicability, expected || target["value"], response, capability)
        return
      end
      add_comparison(
        id: id, resource: resource, target: target.merge("value" => expected || target["value"]),
        actual: actual, response: response, severity: severity, capability: capability,
        evidence_status: evidence_status, reason_code: reason_code
      )
    end

    def add_not_applicable(id:, resource:, target:, response:, severity:, actual:, evidence_status:, reason_code:)
      applicability = @policy.effective_applicability(target)
      if applicability == "APPLICABLE"
        add_check(
          id, resource, "PASS", severity, "NOT_APPLICABLE", target["value"], actual,
          "AVAILABLE", response.endpoint_id, evidence_status, reason_code
        )
      else
        gate_reason = applicability == "GATED" ? "gate_pending" : "gate_not_applicable"
        add_check(
          id, resource, "WARN", severity, applicability, target["value"], actual,
          "AVAILABLE", response.endpoint_id, evidence_status, gate_reason
        )
      end
    end

    def add_comparison(id:, resource:, target:, actual:, response:, severity:, capability: "AVAILABLE", evidence_status: nil, reason_code: nil)
      applicability = @policy.effective_applicability(target)
      if applicability != "APPLICABLE"
        reason = applicability == "GATED" ? "gate_pending" : "gate_not_applicable"
        add_check(id, resource, "WARN", severity, applicability, target["value"], actual.nil? ? "UNKNOWN" : actual, capability, response.endpoint_id, evidence_status || normalized_status(response.status), reason)
        return
      end

      matches = actual == target["value"]
      status = matches ? "PASS" : "FAIL"
      add_check(
        id, resource, status, severity, applicability, target["value"], actual,
        capability, response.endpoint_id, evidence_status || response.status,
        reason_code || (matches ? "target_satisfied" : "target_mismatch")
      )
    end

    def add_minimum(id, resource, target, actual, response, severity)
      applicability = @policy.effective_applicability(target)
      if applicability != "APPLICABLE"
        reason = applicability == "GATED" ? "gate_pending" : "gate_not_applicable"
        add_check(id, resource, "WARN", severity, applicability, target["value"], actual.nil? ? "UNKNOWN" : actual, "AVAILABLE", response.endpoint_id, normalized_status(response.status), reason)
        return
      end
      unless response.success? && actual.is_a?(Integer)
        add_unknown(id, resource, severity, applicability, target["value"], response)
        return
      end

      meets = actual >= target["value"]
      status = meets ? "PASS" : "FAIL"
      add_check(id, resource, status, severity, applicability, target["value"], actual, "AVAILABLE", response.endpoint_id, response.status, meets ? "minimum_satisfied" : "minimum_not_met")
    end

    def add_unknown(id, resource, severity, applicability, expected, response, capability = "API_UNAVAILABLE")
      capability = "MISSING_SCOPE" if response.reason_code == "missing_scope"
      reason = normalized_reason(response)
      add_check(id, resource, "UNKNOWN", severity, applicability, expected, "UNKNOWN", capability, response.endpoint_id, normalized_status(response.status), reason)
    end

    def add_target_unknown(id, resource, severity, target, response, capability = "API_UNAVAILABLE")
      applicability = @policy.effective_applicability(target)
      if applicability == "APPLICABLE"
        add_unknown(id, resource, severity, applicability, target["value"], response, capability)
      else
        reason = applicability == "GATED" ? "gate_pending" : "gate_not_applicable"
        add_check(id, resource, "WARN", severity, applicability, target["value"], "UNKNOWN", capability, response.endpoint_id, normalized_status(response.status), reason)
      end
    end

    def add_check(id, resource, status, severity, applicability, expected, actual, capability, endpoint_id, evidence_status, reason_code)
      applicability = {"CURRENT" => "APPLICABLE", "FUTURE_GATE" => "GATED", "MANUAL" => "APPLICABLE"}.fetch(applicability, applicability)
      @checks << {
        "id" => id,
        "resource" => resource,
        "status" => status,
        "severity" => SEVERITY.fetch(severity),
        "applicability" => applicability,
        "expected" => expected,
        "actual" => actual,
        "capability" => capability,
        "evidence" => {
          "endpointId" => EndpointRegistry.endpoint_id(endpoint_id),
          "status" => evidence_status,
          "reasonCode" => reason_code
        }
      }
    end

    def get(endpoint_id, variables = {}, paginate: false, **keywords)
      merged = variables.merge(keywords)
      @transport.get(endpoint_id, variables: merged, paginate: paginate)
    end

    def synthetic_response(endpoint_id, **attributes)
      Response.new(endpoint_id: EndpointRegistry.endpoint_id(endpoint_id), **attributes)
    end

    def valid_topics(value)
      return unless value.is_a?(Array)
      return unless value.all? { |topic| topic.is_a?(String) && topic.match?(Policy::TOPIC_PATTERN) }

      value
    end

    def valid_branch(value)
      value if value.is_a?(String) && value.match?(Policy::BRANCH_PATTERN)
    end

    def repository_published(data)
      return unless data.key?("pushed_at")

      pushed_at = data["pushed_at"]
      return false if pushed_at.nil?
      return unless pushed_at.is_a?(String)

      Time.iso8601(pushed_at)
      true
    rescue ArgumentError
      nil
    end

    def valid_action_patterns(value)
      return unless value.is_a?(Array) && value.uniq.length == value.length
      return unless value.all? { |pattern| pattern.is_a?(String) && pattern.match?(Policy::ACTION_PATTERN) }

      value
    end

    def enum(value, allowed)
      value if value.is_a?(String) && allowed.include?(value)
    end

    def typed(value, types)
      Array(types).any? { |type| value.is_a?(type) } ? value : nil
    end

    def boolean_types
      [TrueClass, FalseClass]
    end

    def normalized_status(status)
      status.is_a?(Integer) ? status : "UNAVAILABLE"
    end

    def normalized_reason(response)
      return response.reason_code if REASON_CODES.include?(response.reason_code)
      return "unauthorized" if response.status == 401
      return "forbidden" if response.status == 403
      return "not_found_ambiguous" if response.status == 404
      return "server_error" if response.status.is_a?(Integer) && response.status >= 500
      return "invalid_response" if response.status == "invalid_json"

      response.success? ? "invalid_field" : "network_error"
    end
  end

  class CLI
    FORMATS = %w[human json].freeze
    FORBIDDEN_OPTIONS = %w[
      --apply --write --method --endpoint --header --token --include-private --dump-response
    ].freeze

    def self.run(argv, out: $stdout, err: $stderr, transport_factory: -> { LiveTransport.new })
      options = parse(argv)
      policy = Policy.load(options.fetch(:policy))
      organization = options[:organization] || policy.organization
      validate_identifier!(organization, Policy::LOGIN_PATTERN)
      repositories = options[:repositories].empty? ? policy.repositories : options[:repositories]
      repositories.each { |repository| validate_identifier!(repository, Policy::REPOSITORY_PATTERN) }
      raise PolicyError, "scope conflict" if options[:all_public] && !options[:repositories].empty?

      attestations = load_attestations(options[:attestations], policy)
      result = Auditor.new(
        policy: policy,
        transport: transport_factory.call,
        organization: organization,
        repositories: repositories,
        all_public: options[:all_public],
        attestations: attestations,
        strict: options[:strict]
      ).run
      if options[:format] == "json"
        out.write(JSON.pretty_generate(result.document), "\n")
      else
        out.write(human(result.document))
      end
      result.exit_code
    rescue PolicyError, ArgumentError
      err.write("ERROR: invalid CLI or policy input\n")
      2
    rescue ControlProbeError
      err.write("ERROR: authentication or control probe unavailable\n")
      3
    end

    def self.parse(argv)
      arguments = argv.dup
      raise ArgumentError unless arguments.shift == "audit"

      options = {repositories: [], all_public: false, format: "human", strict: false, dry_run: false}
      until arguments.empty?
        option = arguments.shift
        raise ArgumentError if FORBIDDEN_OPTIONS.include?(option)

        case option
        when "--policy"
          options[:policy] = required_value(arguments)
        when "--org"
          options[:organization] = required_value(arguments)
        when "--repo"
          options[:repositories] << required_value(arguments)
        when "--all-public"
          options[:all_public] = true
        when "--attestations"
          options[:attestations] = required_value(arguments)
        when "--format"
          options[:format] = required_value(arguments)
          raise ArgumentError unless FORMATS.include?(options[:format])
        when "--strict"
          options[:strict] = true
        when "--dry-run"
          options[:dry_run] = true
        else
          raise ArgumentError
        end
      end
      raise ArgumentError unless options[:policy]

      options
    end

    def self.required_value(arguments)
      value = arguments.shift
      raise ArgumentError unless value && !value.start_with?("--")

      value
    end

    def self.validate_identifier!(value, pattern)
      raise PolicyError unless value.is_a?(String) && value.match?(pattern)
    end

    def self.load_attestations(path, policy)
      return {} unless path

      bytes = Pathname.new(path).binread
      raise PolicyError if bytes.start_with?("\xEF\xBB\xBF".b)
      text = bytes.force_encoding(Encoding::UTF_8)
      raise PolicyError unless text.valid_encoding?
      document = JSON.parse(text)
      raise PolicyError unless document.is_a?(Hash) && document.keys.sort == %w[attestations schemaVersion]
      raise PolicyError unless document["schemaVersion"] == "1.0" && document["attestations"].is_a?(Hash)

      allowed = policy.manual_attestations.map { |entry| entry.fetch("id") }
      values = document["attestations"]
      raise PolicyError unless values.keys.all? { |key| allowed.include?(key) }
      raise PolicyError unless values.values.all? { |value| value == true || value == false }

      values
    rescue Errno::ENOENT, Errno::EACCES, JSON::ParserError
      raise PolicyError
    end

    def self.human(document)
      summary = document.fetch("summary")
      lines = [
        "READ-ONLY GITHUB SETTINGS AUDIT",
        "Mode: READ_ONLY",
        "Organization: #{document.dig("run", "org")}",
        "Plan: #{document.dig("run", "plan")}",
        "Audited public repositories: #{document.dig("run", "publicRepositoryCount")}",
        "Summary: #{Auditor::STATUS_ORDER.map { |status| "#{status}=#{summary.fetch(status)}" }.join(" ")}",
        ""
      ]
      document.fetch("checks").each do |check|
        lines << format(
          "%-7s %-48s %-18s %s",
          check.fetch("status"), check.fetch("id"), check.fetch("applicability"), check.fetch("resource")
        )
      end
      lines.join("\n") + "\n"
    end
  end
end
