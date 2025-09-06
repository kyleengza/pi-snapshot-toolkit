#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${HOME}/pi_backups"
DEFAULT_PREFIX="pi_backup"

DEVICE=""
PREFIX="${DEFAULT_PREFIX}"
assume_yes=false

while getopts ":d:p:y" opt; do
  case "$opt" in
    d) DEVICE="$OPTARG" ;;
    p) PREFIX="$OPTARG" ;;
    y) assume_yes=true ;;
    *) echo "Usage: $0 [-d /dev/sdX] [-p prefix] [-y]"; exit 1 ;;
  esac
done

mkdir -p "$BACKUP_DIR"
TS="$(date +%Y%m%d_%H%M%S)"
WORKDIR="$(mktemp -d "${BACKUP_DIR}/work_${TS}_XXXX")"
ARCHIVE="${BACKUP_DIR}/${PREFIX}_${TS}.tar.zst"

cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

if [[ -z "$DEVICE" ]]; then
  echo "🔍 Available removable devices:"
  lsblk -dpno NAME,SIZE,MODEL | grep -E '/dev/sd'
  read -rp "Enter device (e.g. /dev/sdb): " DEVICE
fi

BOOT="${DEVICE}1"
ROOT="${DEVICE}2"

# Unmount if mounted
for part in "$BOOT" "$ROOT"; do
  if mountpoint -q "/mnt/$(basename "$part")"; then
    echo "⚠️ Unmounting $part..."
    sudo umount "/mnt/$(basename "$part")"
  fi
done

# Create clean mount points
BOOT_MNT="$(mktemp -d)"
ROOT_MNT="$(mktemp -d)"

echo "📦 Dumping partition table..."
sudo sfdisk -d "$DEVICE" > "$WORKDIR/partition_table.sfdisk"

echo "📥 Mounting boot partition..."
sudo mount -o ro "$BOOT" "$BOOT_MNT"

echo "📥 Mounting root partition..."
sudo mount -o ro "$ROOT" "$ROOT_MNT"

echo "📦 Archiving boot..."
sudo tar --numeric-owner -C "$BOOT_MNT" -caf "$WORKDIR/boot.tar.zst" .

echo "📦 Archiving root..."
sudo tar --xattrs --acls --numeric-owner -C "$ROOT_MNT" -caf "$WORKDIR/root.tar.zst" .

sudo umount "$BOOT_MNT" "$ROOT_MNT"
rmdir "$BOOT_MNT" "$ROOT_MNT"

BOOT_LABEL=$(lsblk -no LABEL "$BOOT")
ROOT_LABEL=$(lsblk -no LABEL "$ROOT")
BOOT_UUID=$(lsblk -no UUID "$BOOT")
ROOT_UUID=$(lsblk -no UUID "$ROOT")

cat > "$WORKDIR/manifest.txt" <<EOF
prefix=$PREFIX
device=$DEVICE
timestamp=$TS
boot_label=$BOOT_LABEL
root_label=$ROOT_LABEL
boot_uuid=$BOOT_UUID
root_uuid=$ROOT_UUID
EOF

(
  cd "$WORKDIR"
  sha256sum partition_table.sfdisk boot.tar.zst root.tar.zst manifest.txt > manifest.sha256
)

echo "📦 Packing archive..."
tar -C "$WORKDIR" -caf "$ARCHIVE" .

ln -sf "$(basename "$ARCHIVE")" "$BACKUP_DIR/${PREFIX}_latest.tar.zst"

echo "✅ Backup complete: $ARCHIVE"
