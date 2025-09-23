#!/usr/bin/env bash
set -Euo pipefail

# Strong PATH for launchd/skhd
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export GOPASS_NO_SYNC=1

# Optional debug log (never logs secrets)
log="$HOME/Library/Logs/gopass-launcher.log"
logit() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$log"; }

# Use the symlinked store (set by your switcher)
store="$HOME/.password-store"
if [ ! -d "$store" ]; then
  logit "ERR: ~/.password-store missing"
  /usr/bin/osascript -e 'display notification "~/.password-store missing" with title "gopass"'
  exit 1
fi
if [ ! -s "$store/.gpg-id" ]; then
  logit "ERR: .gpg-id missing in store"
  /usr/bin/osascript -e 'display notification "Selected store not initialized (.gpg-id)" with title "gopass"'
  exit 1
fi

# Build entry list
list_file="$(mktemp)"; trap 'rm -f "$list_file"' EXIT
if ! gopass ls --flat > "$list_file" 2>>"$log"; then
  logit "ERR: gopass ls failed"
  /usr/bin/osascript -e 'display notification "Failed to list entries" with title "gopass"'
  exit 1
fi
[ ! -s "$list_file" ] && exit 0

# Fuzzy pick
set +e
selection="$(choose < "$list_file")"; rc=$?
set -e
[ -z "${selection:-}" ] && exit 0
logit "selection=$selection (rc=$rc)"

# Fetch first line only; if empty, bail quietly
pw="$(gopass show -o "$selection" 2>>"$log" || true)"
if [ -z "$pw" ]; then
  logit "WARN: empty password for $selection"
  /usr/bin/osascript -e "display notification \"Empty password (first line)\" with title \"gopass\""
  exit 0
fi

# Copy and confirm; then clear after 45s
printf %s "$pw" | /usr/bin/pbcopy
/usr/bin/osascript -e "display notification \"Copied: $selection\" with title \"gopass\""
( sleep 45; /usr/bin/pbcopy < /dev/null ) >/dev/null 2>&1 &

# (Optional) sanity log of clipboard length (not the secret)
clip_len="$(/usr/bin/pbpaste | wc -c | tr -d ' ')"
logit "pbcopy ok, clip_len=${clip_len}"
