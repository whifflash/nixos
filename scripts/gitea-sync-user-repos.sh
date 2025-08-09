#!/usr/bin/env bash
set -euo pipefail

# Env vars (required unless noted):
#   BASE_URL   e.g. https://gitea.example.com   (used for API, hostname fallback)
#   DEST_DIR   e.g. /home/you/gitea-sync/repos
#   TOKEN      Personal Access Token with read:repository (and optionally read:organization)
#   SSH_HOST   (optional) SSH alias/host to probe first; if unset, derived from BASE_URL
#   GIT_SSH_COMMAND (optional) e.g. ssh -o StrictHostKeyChecking=accept-new

: "${BASE_URL:?Set BASE_URL}"
: "${DEST_DIR:?Set DEST_DIR}"
: "${TOKEN:?Set TOKEN}"

# ---- Dependency checks ----
for dep in jq git curl ssh getent awk; do
  command -v "$dep" >/dev/null 2>&1 || { echo "$dep is required" >&2; exit 1; }
done

# ---- Counters ----
cloned_count=0
updated_count=0
skipped_count=0

# ---- Logging helper ----
log() {
  printf '[%(%F %T)T] %s\n' -1 "$*"
}

# ---- Preflight SSH (no token/API until this passes) ----
ssh_host="${SSH_HOST:-$(echo "$BASE_URL" | awk -F/ '{print $3}' | cut -d: -f1)}"

preflight_ssh() {
  local h="$1"

  if ! getent hosts "$h" >/dev/null; then
    log "Gitea host \"$h\" not resolvable; skipping sync."
    exit 0
  fi

  if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$h" >/dev/null 2>&1; then
    log "SSH to \"$h\" failed; skipping sync."
    exit 0
  fi
}

# ---- API helper ----
api() {
  local path="$1"
  local page="${2:-1}"
  local limit="${3:-50}"
  local url="${BASE_URL%/}${path}?page=${page}&limit=${limit}"
  curl -fsSL -H "Authorization: token ${TOKEN}" "$url"
}

# ---- Clone / Pull helper ----
ensure_repo() {
  local org="$1"
  local name="$2"
  local ssh_url="$3"
  local org_dir="${DEST_DIR%/}/${org}"
  local repo_dir="${org_dir}/${name}"

  mkdir -p "$org_dir"

  if [ -d "${repo_dir}/.git" ]; then
    log "[update] ${org}/${name}"
    git -C "$repo_dir" fetch --all --prune
    current_branch="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD || echo main)"
    if git -C "$repo_dir" pull --ff-only origin "$current_branch"; then
      updated_count=$((updated_count + 1))
    else
      log "  ! fast-forward failed on ${org}/${name} (branch: ${current_branch}). Resolve manually."
    fi
  else
    log "[clone ] ${org}/${name}"
    git clone "$ssh_url" "$repo_dir"
    cloned_count=$((cloned_count + 1))
  fi
}

main() {
  preflight_ssh "$ssh_host"

  mkdir -p "$DEST_DIR"

  local page=1
  while :; do
    chunk="$(api "/api/v1/user/repos" "$page" 50)"

    if [ "$(printf "%s" "$chunk" | jq "length")" -eq 0 ]; then
      break
    fi

    printf "%s\n" "$chunk" \
      | jq -r '.[] | if .archived == true then
                    "ARCHIVED " + (.owner.login // .owner.username) + " " + .name
                  else
                    (.owner.login // .owner.username) + " " + .name + " " + (.ssh_url // "")
                  end' \
      | while read -r field1 field2 field3; do
          if [ "$field1" = "ARCHIVED" ]; then
            log "[skip  ] $field2/$field3 (archived)"
            skipped_count=$((skipped_count + 1))
            continue
          fi
          owner="$field1"
          name="$field2"
          ssh_url="$field3"
          ensure_repo "$owner" "$name" "$ssh_url"
        done

    page=$((page + 1))
  done

  log "Gitea Sync Summary: Cloned=${cloned_count} Updated=${updated_count} Skipped=${skipped_count} (archived)"
}

main