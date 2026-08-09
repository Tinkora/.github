#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd -- "$repo_root"

ruby scripts/check_docs.rb
ruby scripts/test_language_policy.rb
ruby scripts/test_public_brand_policy.rb
ruby scripts/test_external_link_policy.rb
ruby scripts/check_workflows.rb
ruby scripts/test_github_settings_audit.rb
ruby scripts/test_github_settings_audit_spec_issues.rb
ruby scripts/test_github_settings_audit_quality_issues.rb
ruby scripts/check_github_settings_audit.rb
ruby scripts/test_runtime_contracts.rb
ruby scripts/test_spdx_sbom.rb
ruby scripts/test_supply_chain_contract.rb

find scripts -type d -name node_modules -prune -o -type f -name '*.sh' -exec bash -n {} +
if command -v shellcheck >/dev/null 2>&1; then
  find scripts -type d -name node_modules -prune -o -type f -name '*.sh' -exec shellcheck {} +
fi
