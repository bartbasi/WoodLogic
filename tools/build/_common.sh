#!/usr/bin/env bash
# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
# Shared by the Android build scripts. Source it; do not run it.
#   build_android <preset name> <output apk>

GODOT="${GODOT:-C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe}"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-C:/Android/Sdk}}"

build_android() {
	local preset="$1" out="$2"
	local root
	root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
	cd "$root" || return 1
	mkdir -p build
	rm -f "$out"

	echo "Importing the project..."
	local implog
	implog="$(mktemp)"
	if ! "$GODOT" --headless --path . --import >"$implog" 2>&1 || grep -qE '^(SCRIPT )?ERROR' "$implog"; then
		echo "FAILED: the import reported errors:" >&2
		cat "$implog" >&2
		rm -f "$implog"
		return 1
	fi
	rm -f "$implog"

	echo "Exporting \"$preset\" to $out ..."
	if ! "$GODOT" --headless --path . --export-debug "$preset" "$out"; then
		echo "FAILED: Godot could not export \"$preset\"." >&2
		return 1
	fi
	if [ ! -s "$out" ]; then
		echo "FAILED: $out was not made." >&2
		return 1
	fi

	echo
	echo "APK: $out ($(du -h "$out" | cut -f1), $(stat -c %s "$out") bytes)"

	local bt aapt
	bt="$(ls -d "$SDK"/build-tools/* | sort -V | tail -n 1)"
	aapt="$bt/aapt2.exe"
	[ -e "$aapt" ] || aapt="$bt/aapt2"
	[ -e "$aapt" ] || { echo "FAILED: aapt2 not found in $bt" >&2; return 1; }

	echo
	"$aapt" dump badging "$out" | grep -E "^package:|^sdkVersion|^targetSdkVersion|^application-label:|^native-code"
	echo
	local perms
	perms="$("$aapt" dump permissions "$out" | tail -n +2 | grep -v '^$' || true)"
	if [ -n "$perms" ]; then
		echo "FAILED: the APK asks for permissions:" >&2
		echo "$perms" >&2
		return 1
	fi
	echo "Permissions: none"

	echo
	local listing
	listing="$(unzip -l "$out")"
	echo "Files in the APK under assets/ :"
	echo "$listing" | grep " assets/" | awk '{print "  " $4}' | head -n 20
	echo "res://data files inside the APK: $(echo "$listing" | grep -c ' assets/data/.*.json') json files (assets/data/...)"
	echo "Excluded folders found inside (should be 0): $(echo "$listing" | grep -v golden_levels | grep -cE ' assets/(src/directions|tests|tools|docs|build)/' || true)"
	return 0
}

# Fails if the APK holds anything under assets/tests/ except the golden levels file.
check_only_golden_tests() {
	local out="$1" extra
	extra="$(unzip -l "$out" | awk '{print $4}' | grep '^assets/tests/' | grep -v '^assets/tests/logic/golden_levels.json$' || true)"
	if [ -n "$extra" ]; then
		echo "FAILED: test files in the timing APK:" >&2
		echo "$extra" >&2
		return 1
	fi
	echo "Test files in the APK: only tests/logic/golden_levels.json"
}
