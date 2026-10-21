# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name CoffeeChip
extends UiButton
## The "Buy me a coffee" chip (UX 1.7): a cup icon and the words in a quiet outline, 140 x 32
## inside a 140 x 48 target. It never animates and has no badge. Build it only when
## `Links.coffee_visible()` is true.

const TARGET := Vector2(140.0, 48.0)


static func make_chip() -> CoffeeChip:
	var c := new()
	c.kind = UiButton.Kind.QUIET
	c.label_text = "Buy me a coffee"
	c.custom_minimum_size = TARGET
	c.theme_type_variation = "FlatButton"
	c.focus_mode = Control.FOCUS_ALL
	c.size_flags_horizontal = Control.SIZE_SHRINK_END
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.tooltip_text = "Buy me a coffee"
	return c


func _draw() -> void:
	var box := Rect2((size.x - 140.0) / 2.0, (size.y - 32.0) / 2.0, 140.0, 32.0)
	draw_style_box(UiTheme.chip_box(is_pressed()), box)
	UiIcons.draw(self, "cup", Vector2(box.position.x + 18.0, size.y / 2.0), 20.0, UiTheme.TEXT)
	draw_string(ThemeDB.fallback_font, Vector2(box.position.x + 32.0, size.y / 2.0 + 4.5), "Buy me a coffee", HORIZONTAL_ALIGNMENT_LEFT, 104.0, UiTheme.SIZE_CAPTION, UiTheme.TEXT)
