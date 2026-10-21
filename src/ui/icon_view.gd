# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name IconView
extends Control
## A square control that draws one icon (docs/ARCHITECTURE.md 11.1) and takes no touches.

var icon := ""
var icon_size := 24.0
var color := UiTheme.TEXT


static func make(icon_name: String, size_units: float = 24.0, tint: Color = UiTheme.TEXT) -> IconView:
	var v := new()
	v.icon = icon_name
	v.icon_size = size_units
	v.color = tint
	v.custom_minimum_size = Vector2(size_units, size_units)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func set_icon(icon_name: String) -> void:
	icon = icon_name
	queue_redraw()


func _draw() -> void:
	UiIcons.draw(self, icon, size / 2.0, icon_size, color)
