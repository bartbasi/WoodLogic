# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends Control
## The main scene. It hands over to the app flow (src/ui), or, in the "Android timing" build
## (feature "timing"), runs the phone timing in place of the game (docs/ARCHITECTURE.md 10.4).

const APP_FLOW := "res://src/ui/app_flow.tscn"
const TIMING := "res://src/app/timing.gd"


func _ready() -> void:
	$Name.hide()
	if OS.has_feature("timing"):
		var timing: Control = (load(TIMING) as GDScript).new()
		add_child(timing)
		return
	add_child((load(APP_FLOW) as PackedScene).instantiate())
