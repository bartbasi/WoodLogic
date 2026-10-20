#!/usr/bin/env bash
# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
# Builds the "Android debug" APK into build/woodlogic-debug.apk.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
build_android "Android debug" "build/woodlogic-debug.apk"
