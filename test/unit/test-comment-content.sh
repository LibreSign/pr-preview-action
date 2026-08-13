#!/usr/bin/env bash

set -e

source "$(dirname "$0")/../lib/assert.sh"

# Test configuration - values that generate-comment.sh needs
action_repository="rossjrw/pr-preview-action"
action_version="v1.0.0-test"
preview_url="https://test-owner.github.io/test-repo/pr-preview/pr-12345/"
preview_branch="gh-pages"
server_url="https://github.com"
deployment_repository="test-owner/test-repo"
action_start_time="2025-01-01 12:00 UTC"
qr_code_provider=""

echo >&2 "test comment: deployment"
echo >&2 "==============================="
comment_file="comment-generated.md"
bash lib/generate-comment.sh \
    "$action_repository" \
    "$action_version" \
    "$preview_url" \
    "$preview_branch" \
    "$server_url" \
    "$deployment_repository" \
    "$action_start_time" \
    "deploy" \
    "$qr_code_provider" \
    > "$comment_file"
cat >&2 "$comment_file"
echo >&2 "==============================="

assert_file_contains "$comment_file" "PR Preview Action"
assert_file_contains "$comment_file" "$action_version"
assert_file_contains "$comment_file" "$preview_url"
assert_file_contains "$comment_file" "Built to branch"
assert_file_contains "$comment_file" "pr-12345"
assert_file_contains "$comment_file" "/?url=" && exit 1 || true

echo >&2 "test comment: removal"
echo >&2 "==============================="
bash lib/generate-comment.sh \
    "$action_repository" \
    "$action_version" \
    "$preview_url" \
    "$preview_branch" \
    "$server_url" \
    "$deployment_repository" \
    "$action_start_time" \
    "remove" \
    "$qr_code_provider" \
    > "$comment_file"
cat >&2 "$comment_file"
echo >&2 "==============================="

assert_file_contains "$comment_file" "PR Preview Action"
assert_file_contains "$comment_file" "$action_version"
assert_file_contains "$comment_file" "Preview removed"
assert_file_contains "$comment_file" "/?url=" && exit 1 || true

echo >&2 "test comment: deployment with QR code"
echo >&2 "==============================="
qr_code_provider="https://qr.example.com/?url="
bash lib/generate-comment.sh \
    "$action_repository" \
    "$action_version" \
    "$preview_url" \
    "$preview_branch" \
    "$server_url" \
    "$deployment_repository" \
    "$action_start_time" \
    "deploy" \
    "$qr_code_provider" \
    > "$comment_file"
qr_code_provider=""
cat >&2 "$comment_file"
echo >&2 "==============================="

assert_file_contains "$comment_file" "qr.example.com/?url=$preview_url"

echo >&2 "test comment: deployment with QR code, backwards compatibility with qr-code:true"
echo >&2 "==============================="
qr_code_provider="true"
bash lib/generate-comment.sh \
    "$action_repository" \
    "$action_version" \
    "$preview_url" \
    "$preview_branch" \
    "$server_url" \
    "$deployment_repository" \
    "$action_start_time" \
    "deploy" \
    "$qr_code_provider" \
    > "$comment_file"
qr_code_provider=""
cat >&2 "$comment_file"
echo >&2 "==============================="

assert_file_contains "$comment_file" "qr.rossjrw.com"

echo >&2 "test sticky comments: PR number forwarding"
echo >&2 "==============================="
action_file="$(dirname "$0")/../../action.yml"
sticky_number='number: ${{ inputs.pr-number || github.event.number }}'

assert_file_contains "$action_file" "$sticky_number" "Sticky comment action should receive PR number with fallback expression"

count=$(grep -Ec '^[[:space:]]+number: \$\{\{ inputs\.pr-number \|\| github\.event\.number \}\}$' "$action_file")
assert_equals "2" "$count"

deploy_count=$(awk '
    /^[[:space:]]*- name: Leave a comment after deployment$/ { in_step=1; next }
    in_step && /^[[:space:]]*- name: / { in_step=0 }
    in_step && /number: \$\{\{ inputs\.pr-number \|\| github.event.number \}\}/ { count++ }
    END { print count + 0 }
' "$action_file")
assert_equals "1" "$deploy_count"

remove_count=$(awk '
    /^[[:space:]]*- name: Leave a comment after removal$/ { in_step=1; next }
    in_step && /^[[:space:]]*- name: / { in_step=0 }
    in_step && /number: \$\{\{ inputs\.pr-number \|\| github.event.number \}\}/ { count++ }
    END { print count + 0 }
' "$action_file")
assert_equals "1" "$remove_count"
