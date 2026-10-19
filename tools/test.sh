#!/usr/bin/env bash
# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
# Runs the headless tests. It imports first, so new or renamed scripts and their class_name
# are known before the tests load them. Usage: bash tools/test.sh [text]
# With text, runs only the tests whose file path or test name contains it, and fails if none
# do. TEST_TIMEOUT (seconds, default 900) stops a run stuck in a loop.
set -uo pipefail

GODOT="${GODOT:-/c/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.."

import_log="$("$GODOT" --headless --path . --import 2>&1)"
if [ $? -ne 0 ] || grep -q "ERROR" <<<"$import_log"; then
	grep -E "ERROR|at: " <<<"$import_log"
	echo "The import reported errors (above)."
fi

timeout "${TEST_TIMEOUT:-900}" "$GODOT" --headless --fixed-fps 60 --path . -s res://tests/run_tests.gd -- "$@" 2>&1 | grep -v "^Godot Engine v"
status="${PIPESTATUS[0]}"
if [ "$status" -eq 124 ]; then
	echo "TIMED OUT after ${TEST_TIMEOUT:-900} s of real time (a test stuck in a loop?)"
fi
exit "$status"
