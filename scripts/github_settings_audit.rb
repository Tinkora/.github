#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "github_settings_audit_lib"

exit GitHubSettingsAudit::CLI.run(ARGV)
