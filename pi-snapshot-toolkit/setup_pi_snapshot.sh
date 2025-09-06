#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Installing required packages..."
sudo pacman -S --needed --noconfirm \
  util-linux e2fsprogs dosfstools mtools gptfdisk \
  tar zstd coreutils findutils grep sed awk

echo "✅ Setup complete."
