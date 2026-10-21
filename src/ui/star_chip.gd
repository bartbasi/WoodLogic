# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name StarChip
extends Control
## The star bank on the title: a star icon and the total (UX 3.1). Quiet, not a button.

var stars := 0


static func make(count: int) -> StarChip:
	var c := new()
	c.stars = count
	c.custom_minimum_size = Vector2(96.0, 48.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _draw() -> void:
	var box := Rect2(0.0, (size.y - 32.0) / 2.0, minf(size.x, 96.0), 32.0)
	draw_style_box(UiTheme.chip_box(), box)
	UiIcons.draw(self, "star", Vector2(box.position.x + 20.0, size.y / 2.0), 20.0, UiTheme.TEXT_GOLD)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(box.position.x + 36.0, size.y / 2.0 + 6.0), UiText.number(stars), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 40.0, UiTheme.SIZE_BUTTON, UiTheme.TEXT)
