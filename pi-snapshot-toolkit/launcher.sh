#!/usr/bin/env bash
set -euo pipefail

echo "🧰 Pi Snapshot Toolkit Launcher"
echo "------------------------------"
echo "1) Setup environment"
echo "2) Backup SD card"
echo "3) Restore SD card"
echo "4) View README"
echo "5) Exit"
read -rp "Choose an option: " choice

case "$choice" in
  1) bash setup_pi_snapshot.sh ;;
  2) bash backup_pi.sh ;;
  3) bash restore_pi.sh ;;
  4) less README.md ;;
  5) echo "Goodbye!"; exit 0 ;;
  *) echo "Invalid choice"; exit 1 ;;
esac
