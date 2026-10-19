# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LogicEvent
extends RefCounted
## One thing that happened in an action, for the view to animate (docs/ARCHITECTURE.md 4.3).
## Fields a kind does not use stay -1 (or 0.0 and empty).

const SCREW_TO_BOX := 0
const SCREW_TO_TRAY := 1
const PLANK_SWUNG := 2
const PLANK_FELL := 3
const COVER_CHANGED := 4
const BOX_CLOSED := 5
const BOX_ARRIVED := 6
const TRAY_TO_BOX := 7
const TRAY_EXTENDED := 8
const UNDONE := 9
const WON := 10
const LOST := 11
const RESUMED := 12
const KIND_NAMES: Array[String] = ["SCREW_TO_BOX", "SCREW_TO_TRAY", "PLANK_SWUNG", "PLANK_FELL", "COVER_CHANGED", "BOX_CLOSED", "BOX_ARRIVED", "TRAY_TO_BOX", "TRAY_EXTENDED", "UNDONE", "WON", "LOST", "RESUMED"]

var kind: int = -1
var screw: int = -1
var plank: int = -1
var position: int = -1
var slot: int = -1
var well: int = -1
var color: int = -1
var angle: float = 0.0
var screws := PackedInt32Array()


static func make(event_kind: int) -> LogicEvent:
	var e := LogicEvent.new()
	e.kind = event_kind
	return e


func kind_name() -> String:
	return KIND_NAMES[kind] if kind >= 0 and kind < KIND_NAMES.size() else "?"


## A short readable form, for tests and logs.
func describe() -> String:
	var parts := PackedStringArray([kind_name()])
	if screw >= 0:
		parts.append("screw %d" % screw)
	if plank >= 0:
		parts.append("plank %d" % plank)
	if position >= 0:
		parts.append("position %d" % position)
	if slot >= 0:
		parts.append("slot %d" % slot)
	if well >= 0:
		parts.append("well %d" % well)
	if kind == BOX_CLOSED or kind == BOX_ARRIVED:
		parts.append("color %d" % color)
	if kind == PLANK_SWUNG:
		parts.append("angle %.1f" % angle)
	if not screws.is_empty():
		parts.append("screws %s" % str(Array(screws)))
	return " ".join(parts)
