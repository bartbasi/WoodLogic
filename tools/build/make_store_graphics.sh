#!/usr/bin/env bash
# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
# Makes the Google Play graphics into build/store/ (ignored by git): icon-512.png,
# feature-1024x500.png, and phone-1.png to phone-6.png (1080x1920 screens of the real game).
#   bash tools/build/make_store_graphics.sh
# Needs a desktop session: the pictures are drawn in a real window. It uses a scratch save in
# user://store_shots/ and never opens a link.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
GODOT="${GODOT_WINDOW:-C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe}"
mkdir -p build/store
rm -f build/store/*.png
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --path . --resolution 1024x500 -s res://tools/build/store_graphics.gd -- feature
"$GODOT" --path . --resolution 1080x1920 -s res://tools/build/store_graphics.gd -- screenshots
ls -l build/store
