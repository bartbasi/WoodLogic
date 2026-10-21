# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Toast
extends Control
## A toast (docs/UX.md 1.4): a one line plaque 24 units above the bottom edge, shown for 2
## seconds, never blocking a tap. Only one at a time; a new one replaces the old.

const SHOWN_S := 2.0

var text := ""
var _plaque: PanelContainer
var _timer := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_process(false)


## Shows `message`, replacing any toast that is up.
func show_text(message: String) -> void:
	text = message
	if _plaque != null:
		_plaque.queue_free()
	_plaque = PanelContainer.new()
	_plaque.theme_type_variation = "Plaque"
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = message
	l.theme_type_variation = "BodyLabel"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = minf(300.0, maxf(120.0, size.x - 48.0))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.add_child(l)
	add_child(_plaque)
	_plaque.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_plaque.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_plaque.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_plaque.offset_top = 0.0
	_plaque.offset_bottom = -(24.0 + UiScreen.insets(self).w)
	_timer = SHOWN_S
	set_process(true)


func is_showing() -> bool:
	return _plaque != null and is_instance_valid(_plaque)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		if _plaque != null:
			_plaque.queue_free()
			_plaque = null
		set_process(false)
