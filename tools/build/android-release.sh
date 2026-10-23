#!/usr/bin/env bash
# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
# Builds the signed release: build/woodlogic.aab for Google Play and build/woodlogic.apk for
# GitHub Releases, then checks them. Stops with a message if there is no release key yet.
#   bash tools/build/android-release.sh
# The key lives outside the repo (see docs/release.md). By default:
#   $USERPROFILE/.woodlogic-keys/woodlogic-release.keystore
#   $USERPROFILE/.woodlogic-keys/woodlogic-release-password.txt   (a line: password: <text>)
# These environment variables override the defaults:
#   WOODLOGIC_KEYSTORE, WOODLOGIC_KEY_ALIAS (default woodlogic), WOODLOGIC_PASSWORD_FILE,
#   WOODLOGIC_KEYSTORE_PASSWORD (the password itself, instead of the file).
# The password is handed to Godot through its own environment variables for this one build.
# Nothing secret is written into the project.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

KEYS="${USERPROFILE:-$HOME}/.woodlogic-keys"
KEYSTORE="${WOODLOGIC_KEYSTORE:-$KEYS/woodlogic-release.keystore}"
ALIAS="${WOODLOGIC_KEY_ALIAS:-woodlogic}"
PASSWORD_FILE="${WOODLOGIC_PASSWORD_FILE:-$KEYS/woodlogic-release-password.txt}"
APK="build/woodlogic.apk"
AAB="build/woodlogic.aab"

fail() { echo "FAILED: $*" >&2; exit 1; }

if [ ! -f "$KEYSTORE" ]; then
	echo "There is no release key yet: $KEYSTORE does not exist." >&2
	echo "Nothing was built. See docs/release.md, section \"Make the release key\"." >&2
	exit 1
fi
PASSWORD="${WOODLOGIC_KEYSTORE_PASSWORD:-}"
if [ -z "$PASSWORD" ] && [ -f "$PASSWORD_FILE" ]; then
	PASSWORD="$(sed -n 's/^password: //p' "$PASSWORD_FILE" | tr -d '\r' | head -n 1)"
fi
if [ -z "$PASSWORD" ]; then
	echo "The release key has no password: set WOODLOGIC_KEYSTORE_PASSWORD, or put a line" >&2
	echo "\"password: ...\" in $PASSWORD_FILE. See docs/release.md." >&2
	exit 1
fi
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ALIAS"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$PASSWORD"

# The Gradle build template (needed for the AAB) is not kept in git: unpack it from the
# export templates when it is missing.
VERSION_TAG="4.7.2.stable"
if [ ! -f android/build/build.gradle ] || [ "$(cat android/.build_version 2>/dev/null || true)" != "$VERSION_TAG" ]; then
	SOURCE_ZIP="${APPDATA:-$HOME}/Godot/export_templates/$VERSION_TAG/android_source.zip"
	[ -f "$SOURCE_ZIP" ] || fail "the Android build template is missing: $SOURCE_ZIP"
	echo "Unpacking the Android build template into android/build ..."
	rm -rf android/build
	mkdir -p android/build
	unzip -q "$SOURCE_ZIP" -d android/build
	printf '%s' "$VERSION_TAG" > android/.build_version
	touch android/build/.gdignore
fi

# Godot waits for Gradle to close its output. A Gradle background daemon keeps it open, so the
# export would never end: run Gradle without the daemon (this file is the unpacked, untracked
# template, not the repo's).
grep -q "^org.gradle.daemon=false" android/build/gradle.properties || echo "org.gradle.daemon=false" >> android/build/gradle.properties

mkdir -p build
rm -f "$APK" "$AAB"
echo "Importing the project..."
implog="$(mktemp)"
if ! "$GODOT" --headless --path . --import >"$implog" 2>&1 || grep -qE '^(SCRIPT )?ERROR' "$implog"; then
	cat "$implog" >&2; rm -f "$implog"; fail "the import reported errors"
fi
rm -f "$implog"

echo "Exporting the signed APK ..."
"$GODOT" --headless --path . --export-release "Android release APK" "$APK" || fail "the APK export failed"
echo "Exporting the signed AAB (Gradle, this takes a few minutes) ..."
"$GODOT" --headless --path . --export-release "Android release AAB" "$AAB" || fail "the AAB export failed"
[ -s "$APK" ] || fail "$APK was not made"
[ -s "$AAB" ] || fail "$AAB was not made"

BT="$(ls -d "$SDK"/build-tools/* | sort -V | tail -n 1)"
AAPT2="$BT/aapt2.exe"; [ -e "$AAPT2" ] || AAPT2="$BT/aapt2"
APKSIGNER="$BT/apksigner.bat"; [ -e "$APKSIGNER" ] || APKSIGNER="$BT/apksigner"

echo
echo "Files:"
for out in "$APK" "$AAB"; do echo "  $(stat -c %s "$out") bytes  $out"; done

echo
badging="$("$AAPT2" dump badging "$APK" 2>/dev/null)"
echo "$badging" | grep -E "^package:|^sdkVersion|^minSdkVersion|^targetSdkVersion|^application-label:|^native-code"
if echo "$badging" | grep -q "application-debuggable"; then fail "the APK is debuggable"; fi
echo "Debuggable: no"

perms="$("$AAPT2" dump permissions "$APK" 2>/dev/null | tail -n +2 | grep -v '^$' || true)"
[ -z "$perms" ] || fail "the APK asks for permissions: $perms"
echo "Permissions: none"

forbidden='(^|/)assets/(tests|tools|docs|build|src/directions)/|PROMPT[.]md|[.]md$|[.]keystore$|[.]jks$|password'
for f in "$APK" "$AAB"; do
	names="$(unzip -Z1 "$f")"
	bad="$(echo "$names" | grep -E "$forbidden" || true)"
	[ -z "$bad" ] || fail "$f holds files that must not ship: $bad"
	echo "$f: no tests, tools, docs, build, Markdown, PROMPT.md or key files ($(echo "$names" | grep -cE "(^|/)assets/data/") data files)"
	echo "$names" | grep -qE '(^|/)assets/LICENSE$' || fail "$f has no LICENSE"
	echo "$names" | grep -qE '(^|/)assets/NOTICE$' || fail "$f has no NOTICE"
done

# The AAB's manifest: no permission entries.
if unzip -p "$AAB" base/manifest/AndroidManifest.xml | grep -a -q "uses-permission"; then
	fail "the AAB manifest asks for permissions"
fi
echo "AAB permissions: none"

echo
"$APKSIGNER" verify --print-certs "$APK" | grep -E "Verifies|certificate SHA-256 digest|DN:" || fail "the APK signature does not verify"
if command -v jarsigner >/dev/null 2>&1; then
	jarsigner -verify "$AAB" | grep -q "jar verified" || fail "the AAB signature does not verify"
	echo "AAB signature: verified"
fi
echo
echo "Release built: $AAB (upload to Google Play) and $APK (GitHub Releases)."
