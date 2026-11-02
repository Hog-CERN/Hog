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

## Install a pinned Claude Code (node image; system packages are installed by the CI job).
claude_install() {
  npm install -g --no-fund --no-audit "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION:-latest}" >/dev/null
  claude --version
}

## Run claude with a scrubbed environment.
# Only the variables Claude needs are passed through, so CI secrets (HOG_PUSH_TOKEN,
# GITHUB_TOKEN, CERN_PUSH_TOKEN, CI_JOB_TOKEN, ...) are never visible to the agent.
# Project/local settings and .mcp.json are ignored so the checked-out code (which may come
# from an untrusted MR) cannot register hooks, permissions or MCP servers.
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
    --allowedTools "Read,Grep,Glob" \
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
  for name in HOG_PUSH_TOKEN CI_JOB_TOKEN GITHUB_TOKEN CERN_PUSH_TOKEN ANTHROPIC_API_KEY \
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
  [ -n "${CI_PROJECT_URL:-}" ] && git remote set-url origin "$CI_PROJECT_URL.git"
  for key in $(git config --local --name-only --get-regexp '^(http\..*extraheader|credential\..*|include\.path)$' || true); do
    git config --local --unset-all "$key" || true
  done
}

## GitLab API call with the Hog bot token.
# $1 method, $2 path (relative to $CI_API_V4_URL), $3 optional JSON body file
gl_api() {
  local method="$1" path="$2" body="${3:-}"
  local args=(-sf -X "$method" -H "PRIVATE-TOKEN: $HOG_PUSH_TOKEN")
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
