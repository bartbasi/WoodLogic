#!/usr/bin/env bash
# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
# Captures the Phase 1 look directions into docs/design/<direction>-<view>.png at phone size.
# Needs a desktop session (a windowed run; headless draws nothing).
# Usage: bash tools/art/capture_directions.sh [directions] [views]   (RES=720x1280 for another size)
set -uo pipefail

GODOT="${GODOT:-/c/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe}"
RES="${RES:-1080x2400}"
cd "$(dirname "$0")/../.."

directions="${1:-workshop nordic toybox}"
views="${2:-board boxes clear title}"
status=0
for d in $directions; do
	for v in $views; do
		out="res://docs/design/$d-$v.png"
		if ! "$GODOT" --path . --resolution "$RES" -s res://tools/art/capture.gd -- "res://src/directions/$d/$v.tscn" "$out" "$RES" 2>&1 | grep -E "saved|ERROR|WARNING|error"; then
			status=1
		fi
	done
done
exit "$status"
