#!/usr/bin/env bash
set -euo pipefail

# Install a lightweight pre-commit "delegator" that runs pre-commit via your flake's devShell.
# This avoids hardcoded /nix/store paths that break after GC or upgrades.

# Only if we're in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# Respect repo-local hooksPath if set; otherwise use .git/hooks
HOOKS_PATH="$(git config --local core.hooksPath || true)"
if [ -z "${HOOKS_PATH}" ]; then
  HOOKS_PATH="$(git rev-parse --git-dir)/hooks"
fi

mkdir -p "$HOOKS_PATH"
HOOK="$HOOKS_PATH/pre-commit"
MARK="# managed-by-nix-delegator"

# Create/refresh only if:
#  - no hook exists, or
#  - the existing hook is our managed one
if [ ! -f "$HOOK" ] || grep -q "$MARK" "$HOOK"; then
  cat >"$HOOK" <<'EOF'
#!/usr/bin/env bash
# managed-by-nix-delegator
set -euo pipefail
# Run repo's pre-commit via the devShell to avoid brittle /nix/store paths
exec nix develop -c pre-commit run --hook-stage pre-commit
EOF
  chmod +x "$HOOK"
  echo "[git-hooks] installed delegator at $HOOK"
fi
