#!/usr/bin/env bash
set -e
mkdir -p /apps/bitpix-buddy/build
cd /apps/bitpix-buddy/linux
/home/jericho/.local/bin/odin build . -out:/apps/bitpix-buddy/build/linux-pixel-app
cd /apps/bitpix-buddy/windows
/home/jericho/.local/bin/odin build . -out:/apps/bitpix-buddy/build/windows-pixel-app.exe
