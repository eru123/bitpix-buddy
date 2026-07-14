#!/usr/bin/env bash
set -e
mkdir -p /apps/bitpix-buddy/build
ODIN=/home/jericho/.local/bin/odin
$ODIN build /apps/bitpix-buddy/linux -collection:pixel_app=/apps/bitpix-buddy/common -out:/apps/bitpix-buddy/build/linux-pixel-app
$ODIN build /apps/bitpix-buddy/windows -collection:pixel_app=/apps/bitpix-buddy/common -out:/apps/bitpix-buddy/build/windows-pixel-app.exe
