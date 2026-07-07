#!/usr/bin/env bash
#
# mirror-github-to-forgejo.sh
#
# Mirrors all of your GitHub repositories (public + private) to a
# self-hosted Forgejo instance as *pull mirrors*. Forgejo will then
# keep them in sync automatically on the configured interval.
#
# Requirements: bash, curl, jq
#
# Required environment variables:
#   GITHUB_TOKEN    - GitHub PAT with "repo" scope (classic) or
#                     Contents:read + Metadata:read (fine-grained, all repos)
#   FORGEJO_URL     - Base URL of your Forgejo instance, e.g. https://git.example.com
#   FORGEJO_TOKEN   - Forgejo access token with repo write permission
#
# Optional environment variables:
#   GITHUB_ORG      - Mirror the repos of this GitHub organization instead of
#                     your personal repos (you must be a member with access)
#   FORGEJO_OWNER   - User or org on Forgejo to own the mirrors
#                     (default: the user that owns FORGEJO_TOKEN; an org must
#                     already exist on Forgejo)
#   MIRROR_INTERVAL - Sync interval, e.g. "8h0m0s" (default: 8h0m0s)
#   INCLUDE_FORKS   - Set to "true" to also mirror forks (default: false)
#   DRY_RUN         - Set to "true" to only print what would happen
#
# Usage:
#   GITHUB_TOKEN=ghp_xxx FORGEJO_URL=https://git.example.com \
#   FORGEJO_TOKEN=xxx ./mirror-github-to-forgejo.sh

set -euo pipefail

# ----------------------------------------------------------------------------
# Config & sanity checks
# ----------------------------------------------------------------------------

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${FORGEJO_URL:?FORGEJO_URL is required (e.g. https://git.example.com)}"
: "${FORGEJO_TOKEN:?FORGEJO_TOKEN is required}"

FORGEJO_URL="${FORGEJO_URL%/}" # strip trailing slash
GITHUB_ORG="${GITHUB_ORG:-}"
MIRROR_INTERVAL="${MIRROR_INTERVAL:-8h0m0s}"
INCLUDE_FORKS="${INCLUDE_FORKS:-false}"
DRY_RUN="${DRY_RUN:-false}"

for cmd in curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: '$cmd' is required but not installed." >&2
    exit 1
  }
done

gh_api() {
  curl -sS --fail-with-body \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$@"
}

fj_api() {
  curl -sS \
    -H "Authorization: token ${FORGEJO_TOKEN}" \
    -H "Content-Type: application/json" \
    "$@"
}

# ----------------------------------------------------------------------------
# Resolve identities
# ----------------------------------------------------------------------------

echo "==> Verifying GitHub token..."
GITHUB_USER="$(gh_api https://api.github.com/user | jq -r .login)"
echo "    GitHub user: ${GITHUB_USER}"

echo "==> Verifying Forgejo token..."
FORGEJO_ME="$(fj_api "${FORGEJO_URL}/api/v1/user" | jq -r .login)"
if [[ -z "$FORGEJO_ME" || "$FORGEJO_ME" == "null" ]]; then
  echo "ERROR: Could not authenticate against Forgejo at ${FORGEJO_URL}" >&2
  exit 1
fi
FORGEJO_OWNER="${FORGEJO_OWNER:-$FORGEJO_ME}"
echo "    Forgejo user: ${FORGEJO_ME} (mirroring into: ${FORGEJO_OWNER})"

# If mirroring into a different owner (usually an org), make sure it exists
if [[ "$FORGEJO_OWNER" != "$FORGEJO_ME" ]]; then
  owner_code="$(fj_api -o /dev/null -w '%{http_code}' "${FORGEJO_URL}/api/v1/orgs/${FORGEJO_OWNER}")"
  if [[ "$owner_code" != "200" ]]; then
    owner_code="$(fj_api -o /dev/null -w '%{http_code}' "${FORGEJO_URL}/api/v1/users/${FORGEJO_OWNER}")"
  fi
  if [[ "$owner_code" != "200" ]]; then
    echo "ERROR: Forgejo owner '${FORGEJO_OWNER}' does not exist. Create the organization on Forgejo first." >&2
    exit 1
  fi
fi

# ----------------------------------------------------------------------------
# Fetch repos from GitHub (paginated) - personal or organization
# ----------------------------------------------------------------------------

if [[ -n "$GITHUB_ORG" ]]; then
  echo "==> Fetching repository list for GitHub org '${GITHUB_ORG}'..."
  LIST_URL="https://api.github.com/orgs/${GITHUB_ORG}/repos?type=all&per_page=100"
else
  echo "==> Fetching repository list from GitHub..."
  LIST_URL="https://api.github.com/user/repos?affiliation=owner&per_page=100"
fi

ALL_REPOS="[]"
page=1
while :; do
  batch="$(gh_api "${LIST_URL}&page=${page}")"
  count="$(jq 'length' <<<"$batch")"
  [[ "$count" -eq 0 ]] && break
  ALL_REPOS="$(jq -s 'add' <(echo "$ALL_REPOS") <(echo "$batch"))"
  page=$((page + 1))
done

if [[ "$INCLUDE_FORKS" != "true" ]]; then
  ALL_REPOS="$(jq '[.[] | select(.fork == false)]' <<<"$ALL_REPOS")"
fi

total="$(jq 'length' <<<"$ALL_REPOS")"
echo "    Found ${total} repositories."

# ----------------------------------------------------------------------------
# Create pull mirrors on Forgejo
# ----------------------------------------------------------------------------

created=0
skipped=0
failed=0

while IFS= read -r repo; do
  name="$(jq -r .name <<<"$repo")"
  clone_url="$(jq -r .clone_url <<<"$repo")"
  is_private="$(jq -r .private <<<"$repo")"
  description="$(jq -r '.description // ""' <<<"$repo")"

  # Skip if it already exists on Forgejo
  http_code="$(fj_api -o /dev/null -w '%{http_code}' \
    "${FORGEJO_URL}/api/v1/repos/${FORGEJO_OWNER}/${name}")"
  if [[ "$http_code" == "200" ]]; then
    echo "  [skip]   ${name} (already exists on Forgejo)"
    skipped=$((skipped + 1))
    continue
  fi

  echo "  [mirror] ${name} (private=${is_private})"

  if [[ "$DRY_RUN" == "true" ]]; then
    continue
  fi

  payload="$(jq -n \
    --arg clone_addr "$clone_url" \
    --arg auth_token "$GITHUB_TOKEN" \
    --arg repo_name "$name" \
    --arg repo_owner "$FORGEJO_OWNER" \
    --arg description "$description" \
    --arg mirror_interval "$MIRROR_INTERVAL" \
    --argjson private "$is_private" \
    '{
      clone_addr: $clone_addr,
      auth_token: $auth_token,
      repo_name: $repo_name,
      repo_owner: $repo_owner,
      description: $description,
      mirror: true,
      mirror_interval: $mirror_interval,
      private: $private,
      service: "github",
      wiki: true,
      issues: false,
      pull_requests: false,
      releases: true
    }')"

  response="$(fj_api -w '\n%{http_code}' -X POST \
    -d "$payload" \
    "${FORGEJO_URL}/api/v1/repos/migrate")"
  http_code="$(tail -n1 <<<"$response")"
  body="$(sed '$d' <<<"$response")"

  if [[ "$http_code" == "201" ]]; then
    created=$((created + 1))
  else
    echo "           ERROR (${http_code}): $(jq -r '.message // .' <<<"$body" 2>/dev/null || echo "$body")" >&2
    failed=$((failed + 1))
  fi
done < <(jq -c '.[]' <<<"$ALL_REPOS")

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------

echo
echo "==> Done. Created: ${created}, skipped (already exist): ${skipped}, failed: ${failed}"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "    (dry run - nothing was actually created)"
fi
[[ "$failed" -gt 0 ]] && exit 1 || exit 0
