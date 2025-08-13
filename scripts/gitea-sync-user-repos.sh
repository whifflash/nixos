#!/usr/bin/env bash
# gitea-sync-user-repos.sh
# Sync (clone/update) all non-archived repos visible to the authenticated user.
# Expects: BASE_URL, DEST_DIR, TOKEN (via EnvironmentFile or env)
# Uses:    STATE_DIRECTORY (provided by systemd when StateDirectory= is set)

set -euo pipefail
IFS=$'\n\t'
umask 077

# ------------------------------ logging ---------------------------------------
# LOG_LEVEL can be: DEBUG, INFO, WARN, ERROR (default INFO)
lvl_num(){ case "${1:-INFO}" in DEBUG) echo 0;; INFO) echo 1;; WARN) echo 2;; ERROR) echo 3;; *) echo 1;; esac; }
should_log(){ [ "$(lvl_num "${1}")" -ge "$(lvl_num "${LOG_LEVEL:-INFO}")" ]; }
log(){
  local level="${1:-INFO}"; shift || true
  should_log "$level" || return 0
  local ts; ts="$(date -Is)"
  local msg="${*:-}"
  local prio; case "$level" in DEBUG) prio=debug;; INFO) prio=info;; WARN) prio=warning;; ERROR) prio=err;; esac
  if command -v systemd-cat >/dev/null 2>&1 && [ -n "${INVOCATION_ID:-}" ]; then
    printf '%s %s %s\n' "$ts" "$level" "$msg" | systemd-cat -t gitea-sync -p "$prio"
  fi
  printf '[%s] %-5s %s\n' "$ts" "$level" "$msg" >&2
}
die(){ log ERROR "$*"; exit 1; }
trap 'rc=$?; log ERROR "Unhandled error at ${BASH_SOURCE[0]}:${LINENO} (rc=$rc)"; exit $rc' ERR
# ------------------------------------------------------------------------------

# ------------------------------ preflights ------------------------------------
: "${BASE_URL:?BASE_URL required (e.g. https://gitea.example.com)}"
: "${DEST_DIR:?DEST_DIR required (e.g. /var/backup/gitea)}"
: "${TOKEN:?TOKEN required (Gitea personal access token)}"

require_cmd(){ command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }
require_cmd curl
require_cmd jq
require_cmd git
require_cmd ssh-keyscan
require_cmd sed
require_cmd install

# Normalize base URL (strip trailing slash for consistency)
BASE_URL="${BASE_URL%/}"

# Basic URL sanity check
if ! printf '%s' "$BASE_URL" | grep -Eq '^https?://[^/]+($|/)'; then
  die "BASE_URL seems invalid: $BASE_URL"
fi

# Derive host for ssh-keyscan from BASE_URL
GITEA_HOST="$(printf '%s\n' "$BASE_URL" | sed -E 's~^https?://([^/]+).*~\1~')"

# Prepare directories
STATE_DIR="${STATE_DIRECTORY:-/var/lib/gitea-sync}"
KNOWN_HOSTS="${STATE_DIR}/known_hosts"

install -m 700 -d "$STATE_DIR" || die "Failed to create state dir: $STATE_DIR"
install -m 755 -d "$DEST_DIR"  || die "Failed to create dest dir: $DEST_DIR"
[ -w "$DEST_DIR" ] || die "Dest dir not writable: $DEST_DIR"

# Pin host key (idempotent; warning on failure but continue)
if ! ssh-keyscan -T 5 "$GITEA_HOST" >> "$KNOWN_HOSTS" 2>/dev/null; then
  log WARN "ssh-keyscan failed for ${GITEA_HOST}; continuing (StrictHostKeyChecking will still enforce trust if key exists)"
fi
export GIT_SSH_COMMAND=${GIT_SSH_COMMAND:-"ssh -o UserKnownHostsFile=$KNOWN_HOSTS -o StrictHostKeyChecking=yes"}

# Quick connectivity probe (non-fatal but helpful)
if ! curl -fsS --connect-timeout 5 --max-time 10 "${BASE_URL}/api/v1/version" >/dev/null 2>&1; then
  log WARN "Gitea API probe failed; continuing anyway"
fi
# ------------------------------------------------------------------------------

log INFO "Starting Gitea sync (base=${BASE_URL}, dest=${DEST_DIR})"

# ------------------------------ helpers ---------------------------------------
api(){
  local path="$1" page="${2:-1}" limit="${3:-50}"
  local url="${BASE_URL}${path}?page=${page}&limit=${limit}"
  curl -fsSL --retry 3 --retry-all-errors --connect-timeout 10 --max-time 60 \
    -H "Authorization: token ${TOKEN}" "$url"
}

# Track results for summary
declare -a CLONED UPDATED SKIPPED_NO_SSH FETCH_FAILED PULL_FAILED CLONE_FAILED

clone_or_update(){
  local owner="$1" name="$2" ssh_url="$3"
  local repo_dir="${DEST_DIR}/${owner}/${name}"
  install -m 755 -d "$(dirname "$repo_dir")"

  if [ -d "$repo_dir/.git" ]; then
    log INFO "Updating ${owner}/${name}"
    if ! git -C "$repo_dir" fetch --all --prune; then
      log WARN "fetch failed for ${owner}/${name}"
      FETCH_FAILED+=("${owner}/${name}")
      return 0
    fi
    local branch
    branch="$(git -C "$repo_dir" symbolic-ref --quiet --short HEAD || echo main)"
    if ! git -C "$repo_dir" pull --ff-only origin "$branch"; then
      log WARN "pull (ff-only) failed for ${owner}/${name} on ${branch}"
      PULL_FAILED+=("${owner}/${name}")
    else
      UPDATED+=("${owner}/${name}")
    fi
  else
    log INFO "Cloning ${owner}/${name}"
    if ! git clone --depth=1 "$ssh_url" "$repo_dir"; then
      log ERROR "clone failed for ${owner}/${name}"
      CLONE_FAILED+=("${owner}/${name}")
      return 0
    fi
    CLONED+=("${owner}/${name}")
  fi
}
# ------------------------------------------------------------------------------

page=1
while :; do
  log DEBUG "Fetching page ${page}"
  chunk="$(api "/api/v1/user/repos" "$page" 50)"

  # Stop when the API returns an empty array
  if [ "$(printf '%s' "$chunk" | jq 'length')" -eq 0 ]; then
    log INFO "No more repos (page ${page}). Done."
    break
  fi

  # Use process substitution to keep variables in this shell (not a subshell)
  while IFS=$'\t' read -r owner name ssh_url; do
    if [ -z "$ssh_url" ]; then
      log WARN "Skipping ${owner}/${name} (no ssh_url)"
      SKIPPED_NO_SSH+=("${owner}/${name}")
      continue
    fi
    clone_or_update "$owner" "$name" "$ssh_url"
  done < <(
    printf '%s\n' "$chunk" \
    | jq -r '.[] | select(.archived|not) | "\((.owner.login // .owner.username))\t\(.name)\t\((.ssh_url // ""))"'
  )

  page=$((page+1))
done

# ------------------------------ summary ---------------------------------------
sum(){ printf '%s\n' "$#"; }  # count helper

log INFO "Summary: cloned=$(sum "${CLONED[@]:-}") updated=$(sum "${UPDATED[@]:-}") skipped_no_ssh=$(sum "${SKIPPED_NO_SSH[@]:-}") fetch_failed=$(sum "${FETCH_FAILED[@]:-}") pull_failed=$(sum "${PULL_FAILED[@]:-}") clone_failed=$(sum "${CLONE_FAILED[@]:-}")"

print_section(){
  local title="$1"; shift
  local -a items=( "$@" )
  [ "${#items[@]}" -eq 0 ] && return 0
  printf '\n=== %s (%d) ===\n' "$title" "${#items[@]}"
  printf '%s\n' "${items[@]}" | sort
}

print_section "CLONED"         "${CLONED[@]:-}"
print_section "UPDATED"        "${UPDATED[@]:-}"
print_section "SKIPPED (no ssh_url)" "${SKIPPED_NO_SSH[@]:-}"
print_section "FETCH FAILED"   "${FETCH_FAILED[@]:-}"
print_section "PULL FAILED"    "${PULL_FAILED[@]:-}"
print_section "CLONE FAILED"   "${CLONE_FAILED[@]:-}"

log INFO "Gitea sync complete."
