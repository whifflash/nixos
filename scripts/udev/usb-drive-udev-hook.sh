#!/usr/bin/env sh
# usb-drive-udev-hook: tiny helper invoked by udev rules
# Expects PARTLABEL, DEVNAME, ACTION from udev environment.
# Calls the umbrella tool `usb-drive` to mount/umount.

set -eu

ACT="${1:-${ACTION:-}}"
PL="${PARTLABEL:-}"
DEV="${DEVNAME:-}"

# Only handle partitions labeled "crypt-<label>"
case "$PL" in
crypt-*) LABEL="${PL#crypt-}" ;;
*) exit 0 ;;
esac

case "$ACT" in
add)
  # Give the device a moment to settle
  sleep 1
  # rota: 0 = SSD/flash, 1 = HDD (or unknown)
  rota="$(lsblk -ndo ROTA "$DEV" 2>/dev/null || echo 1)"
  if [ "$rota" = "0" ]; then
    exec usb-drive mount-luks "$LABEL" --ssd
  else
    exec usb-drive mount-luks "$LABEL"
  fi
  ;;
remove)
  exec usb-drive umount-luks "$LABEL"
  ;;
*)
  exit 0
  ;;
esac
