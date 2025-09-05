#!/usr/bin/env sh
# usb-drive: umbrella utility for USB wiping + LUKS (POSIX sh)
# Subcommands:
#   usb-drive wipe /dev/sdX [--full]
#   usb-drive encrypt-luks /dev/sdX LABEL [ext4|btrfs] [--ssd]
#   usb-drive mount-luks LABEL [--ssd]
#   usb-drive umount-luks LABEL
#   usb-drive info [/dev/sdX]
# Notes:
#   - Operates ONLY on removable devices (lsblk RM=1).
#   - --ssd enables --allow-discards and discard mount opts.

set -eu

error() { printf >&2 "%s\n" "$*"; }
die() {
  error "$@"
  exit 1
}

is_removable() { [ "$(lsblk -ndo RM "$1" 2>/dev/null | tr -d ' ')" = "1" ]; }
is_rotational() { [ "$(lsblk -ndo ROTA "$1" 2>/dev/null | tr -d ' ')" = "1" ]; } # 1=HDD, 0=SSD/flash

confirm_destroy() {
  d="$1"
  printf "!!! DANGEROUS OPERATION !!!\nThis will ERASE ALL DATA on %s\n" "$d"
  printf "Type EXACTLY: YES, destroy %s : " "$d"
  IFS= read -r ans || true
  [ "x$ans" = "xYES, destroy $d" ] || die "Aborted."
}

part_path() {
  disk="$1"
  case "$disk" in
  *[0-9]) printf "%sp1" "$disk" ;;
  *) printf "%s1" "$disk" ;;
  esac
}

udev_settle() {
  if command -v udevadm >/dev/null 2>&1; then udevadm settle || true; fi
}

wait_for_block() {
  p="$1"
  i=0
  while [ $i -lt 40 ]; do
    [ -b "$p" ] && return 0
    i=$((i + 1))
    sleep 0.1
  done
  return 1
}

cmd_wipe() {
  [ $# -ge 1 ] && [ $# -le 2 ] || die "Usage: usb-drive wipe /dev/sdX [--full]"
  DISK="$1"
  FULL="${2:-}"
  [ -b "$DISK" ] || die "Not a block device: $DISK"
  is_removable "$DISK" || die "$DISK is not removable (USB)."
  lsblk -o NAME,MODEL,TRAN,RM,ROTA,SIZE,TYPE "$DISK"
  confirm_destroy "$DISK"

  # Unmount children if any
  lsblk -nrpo NAME "$DISK" | tail -n +2 | while IFS= read -r n; do umount "$n" 2>/dev/null || true; done
  swapoff -a || true

  wipefs -a "$DISK" || true

  if ! is_rotational "$DISK"; then
    if command -v blkdiscard >/dev/null 2>&1; then
      if blkdiscard -v "$DISK"; then
        sgdisk --zap-all "$DISK" >/dev/null 2>&1 || true
        sync
        printf "Wipe complete via discard.\n"
        return 0
      fi
    fi
  fi

  if [ "$FULL" = "--full" ]; then
    printf "Zeroing full device (slow)...\n"
    dd if=/dev/zero of="$DISK" bs=4M status=none conv=fsync || true
  else
    printf "Zeroing first/last 64MiB...\n"
    dd if=/dev/zero of="$DISK" bs=1M count=64 status=none conv=fsync || true
    size_b=$(lsblk -ndo SIZE -b "$DISK")
    seek_mb=$((size_b / 1024 / 1024 - 64))
    dd if=/dev/zero of="$DISK" bs=1M seek="$seek_mb" count=64 status=none conv=fsync || true
  fi
  sgdisk --zap-all "$DISK" >/dev/null 2>&1 || true
  sync
  printf "Wipe complete.\n"
}

cmd_encrypt_luks() {
  [ $# -ge 2 ] || die "Usage: usb-drive encrypt-luks /dev/sdX LABEL [ext4|btrfs] [--ssd]"
  DISK="$1"
  LABEL="$2"
  FSTYPE="${3:-ext4}"
  SSD="no"
  [ "${4:-}" = "--ssd" ] && SSD="yes"
  [ -b "$DISK" ] || die "Not a block device: $DISK"
  is_removable "$DISK" || die "$DISK is not removable (USB)."
  lsblk -o NAME,MODEL,TRAN,RM,ROTA,SIZE,TYPE,MOUNTPOINT "$DISK"
  confirm_destroy "$DISK"

  # Fresh GPT single partition
  wipefs -a "$DISK" || true
  parted -s "$DISK" mklabel gpt
  parted -s "$DISK" mkpart primary 1MiB 100%
  sgdisk --typecode=1:8309 --change-name=1:"crypt-$LABEL" "$DISK" >/dev/null 2>&1 || true

  PART=$(part_path "$DISK")
  udev_settle
  wait_for_block "$PART" || die "Partition not found: $PART"

  # LUKS2
  cryptsetup luksFormat \
    --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha256 \
    --pbkdf argon2id \
    "$PART"

  if [ "$SSD" = "yes" ]; then
    cryptsetup open --allow-discards "$PART" "crypt-$LABEL"
  else
    cryptsetup open "$PART" "crypt-$LABEL"
  fi

  case "$FSTYPE" in
  ext4) mkfs.ext4 -L "${LABEL}_data" "/dev/mapper/crypt-$LABEL" ;;
  btrfs) mkfs.btrfs -L "${LABEL}_data" "/dev/mapper/crypt-$LABEL" ;;
  *) die "Unsupported fs: $FSTYPE (use ext4|btrfs)" ;;
  esac

  LUKS_UUID=$(blkid -s UUID -o value "$PART" || true)
  FS_UUID=$(blkid -s UUID -o value "/dev/mapper/crypt-$LABEL" || true)

  printf "Done.\n  LUKS UUID: %s\n  FS UUID: %s\n" "${LUKS_UUID:-?}" "${FS_UUID:-?}"
  printf "Mount with: usb-drive mount-luks %s%s\n" "$LABEL" "$([ "$SSD" = "yes" ] && printf " --ssd" || printf "")"
  # Leave it closed by default:
  cryptsetup close "crypt-$LABEL" || true
}

cmd_mount_luks() {
  [ $# -ge 1 ] && [ $# -le 2 ] || die "Usage: usb-drive mount-luks LABEL [--ssd]"
  LABEL="$1"
  SSD="${2:-}"
  DEV=$(lsblk -rno PATH,PARTLABEL,RM | awk -v L="crypt-$LABEL" '$2==L && $3==1{print $1;exit}')
  [ -n "$DEV" ] || die "Could not find removable partition with PARTLABEL=crypt-$LABEL"
  LUKS_UUID=$(blkid -s UUID -o value "$DEV" || true)
  [ -n "$LUKS_UUID" ] || die "No UUID for $DEV"
  MNT="/media/$LABEL"
  mkdir -p "$MNT"

  if [ "$SSD" = "--ssd" ]; then
    cryptsetup open --allow-discards "/dev/disk/by-uuid/$LUKS_UUID" "crypt-$LABEL"
    FSTYPE=$(blkid -s TYPE -o value "/dev/mapper/crypt-$LABEL" || true)
    if [ "$FSTYPE" = "btrfs" ]; then
      mount -o discard=async "/dev/mapper/crypt-$LABEL" "$MNT"
    else
      mount -o discard "/dev/mapper/crypt-$LABEL" "$MNT"
    fi
  else
    cryptsetup open "/dev/disk/by-uuid/$LUKS_UUID" "crypt-$LABEL"
    mount "/dev/mapper/crypt-$LABEL" "$MNT"
  fi
  printf "Mounted at %s\n" "$MNT"
}

cmd_umount_luks() {
  [ $# -eq 1 ] || die "Usage: usb-drive umount-luks LABEL"
  LABEL="$1"
  MNT="/media/$LABEL"
  if mountpoint -q "$MNT"; then umount "$MNT" || die "Failed to umount $MNT"; fi
  if [ -e "/dev/mapper/crypt-$LABEL" ]; then cryptsetup close "crypt-$LABEL" || die "Failed to close crypt-$LABEL"; fi
  printf "Closed crypt-%s\n" "$LABEL"
}

cmd_info() {
  if [ $# -eq 0 ]; then
    lsblk -o NAME,MODEL,TRAN,RM,ROTA,SIZE,TYPE,MOUNTPOINT
  else
    DISK="$1"
    [ -b "$DISK" ] || die "Not a block device: $DISK"
    lsblk -o NAME,MODEL,SERIAL,TRAN,RM,ROTA,SIZE,TYPE,MOUNTPOINT "$DISK"
  fi
}

usage() {
  cat <<EOF
Usage: usb-drive <command> [args...]

Commands:
  wipe /dev/sdX [--full]           Erase a removable disk (TRIM or zeroing)
  encrypt-luks /dev/sdX LABEL [ext4|btrfs] [--ssd]
                                   Create plain LUKS2 + filesystem
  mount-luks LABEL [--ssd]         Open and mount at /media/LABEL
  umount-luks LABEL                Unmount and close
  info [/dev/sdX]                  Show removable device info

Notes:
  - Only operates on removable devices (lsblk RM=1).
  - --ssd passes TRIM through LUKS and mounts with discard.
EOF
}

main() {
  [ $# -ge 1 ] || {
    usage
    exit 1
  }
  sub="$1"
  shift
  case "$sub" in
  wipe) cmd_wipe "$@" ;;
  encrypt-luks) cmd_encrypt_luks "$@" ;;
  mount-luks) cmd_mount_luks "$@" ;;
  umount-luks) cmd_umount_luks "$@" ;;
  info) cmd_info "$@" ;;
  -h | --help | help) usage ;;
  *)
    error "Unknown command: $sub"
    usage
    exit 1
    ;;
  esac
}

main "$@"
