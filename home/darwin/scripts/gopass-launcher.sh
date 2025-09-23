#!/usr/bin/env bash
set -Euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export GOPASS_NO_SYNC=1

log="$HOME/Library/Logs/gopass-launcher.log"
logit() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$log"; }

logit "=== launcher start ==="

store="$HOME/.password-store"
if [ ! -d "$store" ]; then logit "ERR missing ~/.password-store"; exit 1; fi
if [ ! -s "$store/.gpg-id" ]; then logit "ERR missing .gpg-id"; exit 1; fi

list_file="$(mktemp)"; trap 'rm -f "$list_file"' EXIT
if ! gopass ls --flat > "$list_file" 2>>"$log"; then
  logit "ERR gopass ls failed"; exit 1
fi
[ ! -s "$list_file" ] && { logit "no entries"; exit 0; }

set +e
sel="$(choose < "$list_file")"; rc=$?
set -e
[ -z "${sel:-}" ] && { logit "cancelled"; exit 0; }
logit "selection=$sel (rc=$rc)"

pw="$(gopass show -o "$sel" 2>>"$log")"; show_rc=$?
pw_len="$(printf %s "$pw" | wc -c | tr -d ' ')"
logit "show_rc=$show_rc pw_len=$pw_len"
[ "$show_rc" -ne 0 ] && exit 1
[ "$pw_len" -eq 0 ] && exit 0

printf %s "$pw" | /usr/bin/pbcopy
clip_len="$(/usr/bin/pbpaste | wc -c | tr -d ' ')"
logit "pbcopy clip_len=$clip_len"
