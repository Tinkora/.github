#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
output_path="$tmp_dir/github-settings-audit.json"
trap 'rm -rf -- "$tmp_dir"' EXIT

cd -- "$repo_root"

set +e
GH_HOST="invalid.example" \
GH_REPO="invalid/invalid" \
GH_CONFIG_DIR="$tmp_dir/hostile-gh-config" \
GH_TOKEN="smoke-token-must-not-be-used" \
ruby scripts/github_settings_audit.rb audit \
  --policy config/github-settings-policy.json \
  --all-public \
  --format json \
  --dry-run >"$output_path"
audit_status=$?
set -e

case "$audit_status" in
  0|1) ;;
  *)
    echo "ERROR: live read-only audit failed with exit code $audit_status" >&2
    exit "$audit_status"
    ;;
esac

npx --no-install --prefix scripts/spdx-validator \
  ajv validate --spec=draft7 \
  -s schemas/github-settings-audit.schema.json \
  -d "$output_path" >/dev/null

ruby -rjson -e '
  path = ARGV.fetch(0)
  text = File.read(path, encoding: "UTF-8")
  document = JSON.parse(text)
  expected_redaction = {
    "rawResponsesIncluded" => false,
    "identitiesIncluded" => false,
    "sensitiveFieldsIncluded" => false
  }
  abort "ERROR: mode is not READ_ONLY" unless document["mode"] == "READ_ONLY"
  abort "ERROR: redaction declaration changed" unless document["redaction"] == expected_redaction

  forbidden = [
    /gh[pousr]_[A-Za-z0-9_]{20,}/,
    /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/,
    /\b(?:\d{1,3}\.){3}\d{1,3}\b/
  ]
  abort "ERROR: sensitive value detected" if forbidden.any? { |pattern| text.match?(pattern) }
' "$output_path"

echo "GitHub settings live READ_ONLY smoke: OK (audit exit $audit_status)"
