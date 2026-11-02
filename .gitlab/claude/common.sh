#!/usr/bin/env bash
#   Copyright 2018-2026 The University of Birmingham
#   Copyright 2018-2026 Max-Planck-Institute for Physics
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# Helpers shared by the Claude CI jobs (review.sh, release_notes.sh).
# CI-only: not part of the Hog user-facing scripts in Other/.

CLAUDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CLAUDE_DIR

# GitLab token used to read the MR/release and post the results. Prefer CLAUDE_GITLAB_TOKEN,
# a low-privilege project access token scoped to the claude-* environments (Reporter for
# claude-review, Developer for claude-release); fall back to HOG_PUSH_TOKEN until it exists.
GL_TOKEN="${CLAUDE_GITLAB_TOKEN:-${HOG_PUSH_TOKEN:-}}"
if [ -z "$GL_TOKEN" ]; then
  echo "Neither CLAUDE_GITLAB_TOKEN nor HOG_PUSH_TOKEN is set" >&2
  exit 1
fi
if [ -n "${CLAUDE_GITLAB_TOKEN:-}" ]; then
  # Not needed by this job: keep it out of every child process.
  unset HOG_PUSH_TOKEN
else
  echo "Warning: CLAUDE_GITLAB_TOKEN is not set, using HOG_PUSH_TOKEN" >&2
fi

## Install a pinned Claude Code (node image; system packages are installed by the CI job).
claude_install() {
  npm install -g --no-fund --no-audit "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION:-latest}" >/dev/null
  claude --version
}

## Run claude with a scrubbed environment.
# Only the variables Claude needs are passed through, so CI secrets (CLAUDE_GITLAB_TOKEN,
# HOG_PUSH_TOKEN, GITHUB_TOKEN, CERN_PUSH_TOKEN, CI_JOB_TOKEN, ...) are never visible to it.
# Project/local settings and .mcp.json are ignored so the checked-out code (which may come
# from an untrusted MR) cannot register hooks, permissions or MCP servers.
# File access: Read/Grep/Glob are available but deliberately NOT pre-approved with
# --allowedTools, so in non-interactive mode they only work inside the working directory and
# the directories passed with --add-dir; anything else (runner temp dirs holding git
# credentials, other users' files, ...) is denied.
run_claude() {
  env -i \
    PATH="$PATH" HOME="$HOME" LANG=C.UTF-8 TERM=dumb \
    DISABLE_AUTOUPDATER=1 DISABLE_TELEMETRY=1 DISABLE_ERROR_REPORTING=1 \
    ${ANTHROPIC_API_KEY:+"ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"} \
    ${CLAUDE_CODE_OAUTH_TOKEN:+"CLAUDE_CODE_OAUTH_TOKEN=$CLAUDE_CODE_OAUTH_TOKEN"} \
    ${HTTPS_PROXY:+"HTTPS_PROXY=$HTTPS_PROXY"} \
    ${NO_PROXY:+"NO_PROXY=$NO_PROXY"} \
    claude \
    --model "${CLAUDE_MODEL:-claude-sonnet-5-5}" \
    --setting-sources user \
    --strict-mcp-config \
    --no-session-persistence \
    --tools "Read,Grep,Glob" \
    --output-format json \
    "$@" </dev/null
}

## Extract and validate the structured output of a claude run.
# $1 claude json output, $2 destination file. Prints usage stats.
claude_extract() {
  local out="$1" dst="$2"
  jq -r '"Claude: \(.subtype // "?"), turns: \(.num_turns // "?"), cost: $\(.total_cost_usd // 0 | . * 100 | round / 100)"' "$out" || true
  if ! jq -e '.structured_output | select(type == "object")' "$out" >"$dst"; then
    echo "No structured output in claude result:"
    jq -r '.result // .' "$out" | head -c 2000
    echo
    return 1
  fi
  assert_no_secrets "$dst"
}

## Fail if a file contains the value of a CI secret: last line of defence before anything
## written by the agent is published on GitLab.
assert_no_secrets() {
  local file="$1" name val
  [ "${#GL_TOKEN}" -ge 8 ] && grep -qF -- "$GL_TOKEN" "$file" && {
    echo "Refusing to publish: the agent output contains the GitLab token" >&2
    return 1
  }
  for name in CLAUDE_GITLAB_TOKEN HOG_PUSH_TOKEN CI_JOB_TOKEN GITHUB_TOKEN CERN_PUSH_TOKEN ANTHROPIC_API_KEY \
    CLAUDE_CODE_OAUTH_TOKEN CI_REGISTRY_PASSWORD; do
    val="${!name:-}"
    if [ "${#val}" -ge 8 ] && grep -qF -- "$val" "$file"; then
      echo "Refusing to publish: the agent output contains the value of \$$name" >&2
      return 1
    fi
  done
}

## Remove the git credentials the runner leaves in the repository config, so the agent
## cannot read them from disk (scrubbing the environment alone does not cover this).
## Call it after the last git fetch.
scrub_git_credentials() {
  local key
  if is_dry_run; then
    echo "[dry run] not touching the git configuration"
    return 0
  fi
  [ -n "${CI_PROJECT_URL:-}" ] && git remote set-url origin "$CI_PROJECT_URL.git"
  for key in $(git config --local --name-only --get-regexp '^(http\..*extraheader|credential\..*|include\.path)$' || true); do
    git config --local --unset-all "$key" || true
  done
}

## CLAUDE_DRY_RUN=1: read from GitLab but never write to it, and leave the local git
## configuration alone. Handy to try the scripts from a developer checkout.
is_dry_run() {
  [ "${CLAUDE_DRY_RUN:-0}" = "1" ]
}

## GitLab API call with $GL_TOKEN.
# $1 method, $2 path (relative to $CI_API_V4_URL), $3 optional JSON body file
gl_api() {
  local method="$1" path="$2" body="${3:-}"
  local args=(-sf -X "$method" -H "PRIVATE-TOKEN: $GL_TOKEN")
  if [ "$method" != "GET" ] && is_dry_run; then
    echo "[dry run] $method $path" >&2
    [ -n "$body" ] && jq . "$body" >&2
    echo '{}'
    return 0
  fi
  if [ -n "$body" ]; then
    args+=(-H "Content-Type: application/json" --data "@$body")
  fi
  curl "${args[@]}" "$CI_API_V4_URL$path" || {
    echo "GitLab API request failed: $method $path" >&2
    return 1
  }
}

## GET every page of a GitLab list endpoint and print one merged JSON array.
gl_get_all() {
  local path="$1" page=1 out="[]" chunk sep="?"
  [[ $path == *\?* ]] && sep="&"
  while :; do
    chunk=$(gl_api GET "${path}${sep}per_page=100&page=$page") || return 1
    out=$(printf '%s\n%s\n' "$out" "$chunk" | jq -cs 'add')
    [ "$(jq length <<<"$chunk")" -lt 100 ] && break
    page=$((page + 1))
  done
  printf '%s\n' "$out"
}
