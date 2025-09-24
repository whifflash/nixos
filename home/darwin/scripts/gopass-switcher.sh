#!/usr/bin/env bash
set -Eeuo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin"

stores_dir="$HOME/pass-stores" # you moved it there
map_file="$(mktemp)"
list_file="$(mktemp)"
trap 'rm -f "$map_file" "$list_file"' EXIT

if [ -d "$stores_dir" ]; then
  while IFS= read -r d; do
    name="$(basename "$d")"
    printf "%s\t%s\n" "$name" "$d" >>"$map_file"
    printf "%s\n" "$name" >>"$list_file"
  done < <(find "$stores_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
fi

# Fallback if none found
if [ ! -s "$list_file" ]; then
  printf "default\n" >"$list_file"
  printf "default\t$HOME/.password-store\n" >"$map_file"
fi

sel_name="$(cat "$list_file" | choose || true)"
[ -z "${sel_name:-}" ] && exit 0

sel_path="$(awk -F'\t' -v n="$sel_name" '$1==n{print $2; exit}' "$map_file")"
: "${sel_path:=$HOME/.password-store}"

# Persist selection for scripts that still read it
printf "%s\n" "$sel_path" >/tmp/pass.store

# Keep gopass happy: point ~/.password-store to the selected dir
ln -sfn "$sel_path" "$HOME/.password-store"

# Nice to have: sanity-check the store is initialized (.gpg-id exists)
if [ ! -s "$sel_path/.gpg-id" ]; then
  /usr/bin/osascript -e 'display notification "Selected store has no .gpg-id" with title "gopass"'
  exit 0
fi

/usr/bin/osascript -e "display notification \"Store set to: $sel_name\" with title \"gopass\""
