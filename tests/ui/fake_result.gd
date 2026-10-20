# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name FakeLevelResult
extends RefCounted
## Stands in for LevelResult (ARCHITECTURE section 6) in the app flow tests.

var level: LevelData
var replay := false
var elapsed_ms := 12000
var tray_uses := 0
var helpers_used := PackedStringArray()
var stars := Vector3i(1, 1, 1)
