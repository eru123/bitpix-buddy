#!/usr/bin/env bash
set -e
ODIN=/home/jericho/.local/bin/odin
mkdir -p /apps/bitpix-buddy/build
$ODIN build /apps/bitpix-buddy/linux -out:/apps/bitpix-buddy/build/linux-pixel-app
echo "Linux binary built. Build Windows binary on Windows with: odin build /apps/bitpix-buddy/windows -out:build/windows-pixel-app.exe"
