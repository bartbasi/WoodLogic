# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelResult
extends RefCounted
## What the level scene hands the screens when a level is won (docs/ARCHITECTURE.md 6).

var level: LevelData
var replay: bool = false
## Taken at the winning tap (GDD S6), not after the animation.
var elapsed_ms: int = 0
var tray_uses: int = 0
var helpers_used := PackedStringArray()
## From Stars.award: (cleared, fast, clean), each 0 or 1.
var stars := Vector3i.ZERO
