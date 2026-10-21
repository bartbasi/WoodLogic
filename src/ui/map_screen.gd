# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MapScreen
extends MenuScreen
## The progress map (docs/UX.md 3.6): the menu frame with the trail as its body.

signal level_chosen(level: int)
signal locked_tapped(next: int)

var highest := 0
var levels: Dictionary = {}
var view: MapView


## progress: Save.progress_copy().
static func make(progress: Dictionary) -> MapScreen:
	var s := new()
	s.highest = int(progress.get("highest_cleared", 0))
	s.levels = progress.get("levels", {})
	s.use_scroll = false
	return s


func _build_body() -> void:
	view = MapView.make(highest, levels)
	view.level_chosen.connect(func(n: int) -> void: level_chosen.emit(n))
	view.locked_tapped.connect(func(n: int) -> void: locked_tapped.emit(n))
	body.add_child(view)


func scroll_to_top() -> void:
	if view != null:
		view.scroll_to_next()
