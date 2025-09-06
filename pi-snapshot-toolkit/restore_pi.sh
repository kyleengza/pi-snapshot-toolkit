#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${HOME}/pi_backups"
DEVICE=""
ARCHIVE=""
assume_yes=false
grow=true

while (( "$#" )); do
  case "$1" in
    -d) DEVICE="$2"; shift 2 ;;
    -a) ARCHIVE="$2"; shift 2 ;;
    -y) assume_yes=true; shift ;;
    --no-grow) grow=false; shift ;;
    *) echo "Usage: $0 [-d /dev/sdX] [-a archive] [-y] [--no-grow]"; exit 1 ;;
  esac
done

if [[ -z "$DEVICE" ]]; then
  echo "🔍 Available removable devices:"
  lsblk -dpno NAME,SIZE,MODEL | grep -E '/dev/sd'
  read -rp "Enter device (e.g. /dev/sdb): " DEVICE
fi

if [[ -z "$ARCHIVE" ]]; then
  echo "📦 Available archives:"
  ls -1t "$BACKUP_DIR"/*.tar.zst
  read -rp "Enter archive path: " ARCHIVE
fi

BOOT="${DEVICE}1"
ROOT="${DEVICE}2"

echo "⚠️ About to wipe and restore $DEVICE"
if ! $assume_yes; then
  read -rp "Type RESTORE to continue: " CONFIRM
  [[ "$CONFIRM" == "RESTORE" ]] || exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

echo "📥 Extracting archive..."
tar -C "$WORKDIR" -xf "$ARCHIVE"

echo "🔍 Verifying checksums..."
(
  cd "$WORKDIR"
  sha256sum -c manifest.sha256
)

source <(sed 's/^/export /' "$WORKDIR/manifest.txt")

echo "🧹 Wiping $DEVICE..."
sudo wipefs -a "$DEVICE"

echo "📐 Restoring partition table..."
sudo sfdisk "$DEVICE" < "$WORKDIR/partition_table.sfdisk"
sleep 2
sudo partprobe "$DEVICE"

echo "🔧 Setting boot flag..."
sudo sfdisk --activate "$DEVICE" 1

echo "🧱 Creating vfat on $BOOT..."
sudo mkfs.vfat -F32 -n "$boot_label" "$BOOT"

echo "🧱 Creating ext4 on $ROOT..."
sudo mkfs.ext4 -F -L "$root_label" "$ROOT"
sudo tune2fs -U "$root_uuid" "$ROOT"

BOOT_MNT="$(mktemp -d)"
ROOT_MNT="$(mktemp -d)"

echo "📥 Mounting boot..."
sudo mount "$BOOT" "$BOOT_MNT"

echo "📥 Mounting root..."
sudo mount "$ROOT" "$ROOT_MNT"

echo "📦 Extracting boot files..."
sudo tar --numeric-owner -C "$BOOT_MNT" -xaf "$WORKDIR/boot.tar.zst"

echo "📦 Extracting root files..."
sudo tar --xattrs --acls --numeric-owner -C "$ROOT_MNT" -xaf "$WORKDIR/root.tar.zst"

if $grow; then
  echo "📏 Expanding root partition..."
  sudo umount "$ROOT_MNT"
  echo ",+" | sudo sfdisk -N2 "$DEVICE"
  sudo partprobe "$DEVICE"
  sudo resize2fs "$ROOT"
  sudo mount "$ROOT" "$ROOT_MNT"
fi

echo "🔍 Validating UUIDs..."
ACT_BOOT_UUID=$(lsblk -no UUID "$BOOT")
ACT_ROOT_UUID=$(lsblk -no UUID "$ROOT")

if grep -q "UUID=" "$ROOT_MNT/etc/fstab"; then
  grep "UUID=" "$ROOT_MNT/etc/fstab" | grep -q "$ACT_ROOT_UUID" || echo "⚠️ fstab root UUID mismatch"
  grep "UUID=" "$ROOT_MNT/etc/fstab" | grep -q "$ACT_BOOT_UUID" || echo "⚠️ fstab boot UUID mismatch"
fi

if grep -q "root=UUID=" "$BOOT_MNT/cmdline.txt"; then
  grep "root=UUID=$ACT_ROOT_UUID" "$BOOT_MNT/cmdline.txt" || echo "⚠️ cmdline.txt root UUID mismatch"
fi

sudo umount "$BOOT_MNT" "$ROOT_MNT"
rmdir "$BOOT_MNT" "$ROOT_MNT"

echo "✅ Restore complete."
