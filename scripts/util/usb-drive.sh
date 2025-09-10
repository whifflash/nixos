#!/usr/bin/env sh
# usb-drive: umbrella utility for USB wiping + LUKS (POSIX sh)
# Subcommands:
#   usb-drive wipe /dev/sdX [--full]
#   usb-drive encrypt-luks /dev/sdX LABEL [ext4|btrfs] [--ssd] [--force]
#   usb-drive mount-luks LABEL [--ssd]
#   usb-drive umount-luks LABEL
#   usb-drive info [/dev/sdX]

set -eu

error() { printf >&2 "%s\n" "$*"; }
die() {
  error "$@"
  exit 1
}

is_root() { [ "$(id -u)" -eq 0 ]; }

needs_root_subcmd() {
  case "$1" in
  wipe | encrypt-luks | mount-luks | umount-luks) return 0 ;;
  *) return 1 ;;
  esac
}

auto_escalate_or_die() {
  sub="$1"
  shift
  if needs_root_subcmd "$sub" && ! is_root; then
    if command -v sudo >/dev/null 2>&1; then
      exec sudo -- "$0" "$sub" "$@"
    elif command -v doas >/dev/null 2>&1; then
      exec doas -- "$0" "$sub" "$@"
    else
      die "This command requires root. Please run with sudo/doas."
    fi
  fi
}

# --- detection helpers --------------------------------------------------------
is_rotational() {
  val="$(lsblk -ndo ROTA "$1" 2>/dev/null | tr -d ' ')"
  [ "$val" = "1" ]
}

# Best-effort USB detection. Returns 0 if *likely* USB, 1 otherwise.
is_usb() {
  d="$1"
  tran="$(lsblk -ndo TRAN "$d" 2>/dev/null | tr -d ' ')"
  if [ -n "$tran" ] && [ "$tran" = "usb" ]; then
    return 0
  fi
  if command -v udevadm >/dev/null 2>&1; then
    if udevadm info -q property -n "$d" 2>/dev/null | grep -q '^ID_BUS=usb$'; then
      return 0
    fi
  fi
  sys="/sys/class/block/$(basename "$d")/device"
  if [ -e "$sys" ]; then
    target="$(readlink -f "$sys" 2>/dev/null || echo "$sys")"
    if printf %s "$target" | grep -q '/usb'; then
      return 0
    fi
  fi
  return 1
}

part_path() {
  case "$1" in *[0-9]) printf "%sp1" "$1" ;; *) printf "%s1" "$1" ;; esac
}

udev_settle() {
  if command -v udevadm >/dev/null 2>&1; then
    udevadm settle || true
  fi
}

wait_for_block() {
  p="$1"
  i=0
  while [ $i -lt 40 ]; do
    if [ -b "$p" ]; then
      return 0
    fi
    i=$((i + 1))
    sleep 0.1
  done
  return 1
}

# --- wipe ---------------------------------------------------------------------
cmd_wipe() {
  if [ $# -lt 1 ] || [ $# -gt 2 ]; then die "Usage: usb-drive wipe /dev/sdX [--full]"; fi
  DISK="$1"
  FULL="${2:-}"
  [ -b "$DISK" ] || die "Not a block device: $DISK"

  if ! is_usb "$DISK"; then
    error "Warning: could not confirm $DISK is a USB device (bridge quirks are common). Proceeding."
  fi

  lsblk -o NAME,MODEL,TRAN,RM,ROTA,SIZE,TYPE "$DISK"
  printf "!!! DANGEROUS OPERATION !!!\nThis will ERASE ALL DATA on %s\n" "$DISK"
  printf "Type EXACTLY: YES, destroy %s : " "$DISK"
  IFS= read -r ans || true
  [ "$ans" = "YES, destroy $DISK" ] || die "Aborted."

  # Unmount children if any
  lsblk -nrpo NAME "$DISK" | tail -n +2 | while IFS= read -r n; do umount "$n" 2>/dev/null || true; done
  swapoff -a || true

  wipefs -a "$DISK" || true

  if ! is_rotational "$DISK" && command -v blkdiscard >/dev/null 2>&1; then
    if blkdiscard -v "$DISK"; then
      sgdisk --zap-all "$DISK" >/dev/null 2>&1 || true
      sync
      printf "Wipe complete via discard.\n"
      return 0
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

# --- encrypt-luks -------------------------------------------------------------
cmd_encrypt_luks() {
  if [ $# -lt 2 ]; then die "Usage: usb-drive encrypt-luks /dev/sdX LABEL [ext4|btrfs] [--ssd] [--force]"; fi
  DISK="$1"
  LABEL="$2"
  FSTYPE="${3:-ext4}"
  SSD="no"
  FORCE="no"

  # parse optional args (order-insensitive)
  shift 2
  for arg in "$@"; do
    case "$arg" in
    ext4 | btrfs) FSTYPE="$arg" ;;
    --ssd) SSD="yes" ;;
    --force | --no-usb-check) FORCE="yes" ;;
    esac
  done

  [ -b "$DISK" ] || die "Not a block device: $DISK"
  if ! is_usb "$DISK" && [ "$FORCE" != "yes" ]; then
    error "Warning: could not confirm $DISK is USB. Proceeding anyway (use --force to silence)."
  fi

  lsblk -o NAME,MODEL,TRAN,RM,ROTA,SIZE,TYPE,MOUNTPOINT "$DISK"
  printf "!!! DANGEROUS OPERATION !!!\nThis will DESTROY ALL DATA on %s\n" "$DISK"
  printf "Type EXACTLY: YES, destroy %s : " "$DISK"
  IFS= read -r ans || true
  [ "$ans" = "YES, destroy $DISK" ] || die "Aborted."

  wipefs -a "$DISK" || true
  parted -s "$DISK" mklabel gpt
  parted -s "$DISK" mkpart primary 1MiB 100%
  sgdisk --typecode=1:8309 --change-name=1:"crypt-$LABEL" "$DISK" >/dev/null 2>&1 || true

  PART=$(part_path "$DISK")
  udev_settle
  wait_for_block "$PART" || die "Partition not found: $PART"

  cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 --hash sha256 --pbkdf argon2id "$PART"
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
  cryptsetup close "crypt-$LABEL" || true
}

# --- mount-luks ---------------------------------------------------------------
cmd_mount_luks() {
  if [ $# -lt 1 ] || [ $# -gt 2 ]; then die "Usage: usb-drive mount-luks LABEL [--ssd]"; fi
  LABEL="$1"
  SSD="${2:-}"

  # Prefer a device with TRAN=usb when multiple exist; otherwise pick first match.
  best=""
  usb=""
  while IFS= read -r line; do
    p=$(printf %s "$line" | awk '{print $1}')
    l=$(printf %s "$line" | awk '{print $2}')
    t=$(printf %s "$line" | awk '{print $3}')
    if [ "$l" = "crypt-$LABEL" ]; then
      if [ -z "$best" ]; then best="$p"; fi
      if [ "$t" = "usb" ]; then
        usb="$p"
        break
      fi
    fi
  done <<EOF
$(lsblk -rno PATH,PARTLABEL,TRAN)
EOF
  DEV="${usb:-$best}"
  [ -n "$DEV" ] || die "Could not find partition with PARTLABEL=crypt-$LABEL"

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

# --- umount-luks --------------------------------------------------------------
cmd_umount_luks() {
  if [ $# -ne 1 ]; then die "Usage: usb-drive umount-luks LABEL"; fi
  LABEL="$1"
  MNT="/media/$LABEL"
  if mountpoint -q "$MNT"; then
    umount "$MNT" || true
  fi
  if [ -e "/dev/mapper/crypt-$LABEL" ]; then
    cryptsetup close "crypt-$LABEL" || true
  fi
  printf "Closed crypt-%s\n" "$LABEL"
}

# --- info ---------------------------------------------------------------------
cmd_info() {
  if [ $# -eq 0 ]; then
    lsblk -o NAME,MODEL,TRAN,RM,ROTA,SIZE,TYPE,MOUNTPOINT
  else
    DISK="$1"
    [ -b "$DISK" ] || die "Not a block device: $DISK"
    lsblk -o NAME,MODEL,SERIAL,TRAN,RM,ROTA,SIZE,TYPE,MOUNTPOINT "$DISK"
    if is_usb "$DISK"; then
      echo "bus: USB (detected)"
    else
      echo "bus: not confirmed as USB"
    fi
  fi
}

usage() {
  cat <<EOF
Usage: usb-drive <command> [args...]
  wipe /dev/sdX [--full]
  encrypt-luks /dev/sdX LABEL [ext4|btrfs] [--ssd] [--force]
  mount-luks LABEL [--ssd]
  umount-luks LABEL
  info [/dev/sdX]
EOF
}

main() {
  if [ $# -lt 1 ]; then
    usage
    exit 1
  fi
  sub="$1"
  shift
  auto_escalate_or_die "$sub" "$@"
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
