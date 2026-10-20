#!/usr/bin/env bash
# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
# Builds the "Android timing" APK into build/woodlogic-timing.apk.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
build_android "Android timing" "build/woodlogic-timing.apk"
check_only_golden_tests "build/woodlogic-timing.apk"
