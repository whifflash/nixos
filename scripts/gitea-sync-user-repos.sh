#!/usr/bin/env bash
set -euo pipefail

# Env:
#   BASE_URL   (e.g. https://gitea.example.com)
#   DEST_DIR   (e.g. /home/you/gitea-sync/repos)
#   TOKEN      (via EnvironmentFile rendered from SOPS)
#   GIT_SSH_COMMAND (optional: e.g. 'ssh -o StrictHostKeyChecking=accept-new')

: "${BASE_URL:?Set BASE_URL}"
: "${DEST_DIR:?Set DEST_DIR}"
: "${TOKEN:?Set TOKEN}"

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 1; }

api() {
  local path="$1" page="${2:-1}" limit="${3:-50}"
  local url="${BASE_URL%/}${path}?page=${page}&limit=${limit}"
  curl -fsSL -H "Authorization: token ${TOKEN}" "$url"
}

ensure_repo() {
  local org="$1" name="$2" ssh_url="$3"
  local org_dir="${DEST_DIR%/}/${org}"
  local repo_dir="${org_dir}/${name}"
  mkdir -p "$org_dir"
  if [ -d "${repo_dir}/.git" ]; then
    echo "[update] ${org}/${name}"
    git -C "$repo_dir" fetch --all --prune
    current_branch="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD || echo main)"
    git -C "$repo_dir" pull --ff-only origin "$current_branch" || {
      echo "  ! fast-forward failed on ${org}/${name} (branch: ${current_branch}). Resolve manually." >&2
    }
  else
    echo "[clone ] ${org}/${name}"
    git clone "$ssh_url" "$repo_dir"
  fi
}

main() {
  mkdir -p "$DEST_DIR"
  local page=1
  while :; do
    chunk="$(api "/api/v1/user/repos" "$page" 50)"
    if [ "$(printf "%s" "$chunk" | jq "length")" -eq 0 ]; then
      break
    fi
    printf "%s\n" "$chunk" \
      | jq -r ".[] | \"\((.owner.login // .owner.username)) \(.name) \((.ssh_url // \"\"))\"" \
      | while read -r owner name ssh_url; do
          [ -z "$owner" ] && continue
          [ -z "$name" ] && continue
          [ -z "$ssh_url" ] && continue
          ensure_repo "$owner" "$name" "$ssh_url"
        done
    page=$((page + 1))
  done
}

main