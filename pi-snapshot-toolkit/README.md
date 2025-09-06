# 🧰 Pi Snapshot Toolkit

A fast, bootable, and space-efficient backup/restore system for Raspberry Pi OS SD cards.

---

## 📦 Features

- Single compressed archive per backup
- Bootable restore with partition table, boot flag, labels, UUIDs
- Filesystem-level archiving (skips free space)
- SHA256 checksum verification
- Rootfs expansion to fill larger targets
- UUID validation in fstab and cmdline.txt
- Interactive menus and automation flags
- Automatic mount detection and cleanup

---

## 🛠 Setup

### `setup_pi_snapshot.sh`

Installs required packages.

```bash
chmod +x setup_pi_snapshot.sh
