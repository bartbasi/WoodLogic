# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Swatch
extends UiButton
## One wood or metal sample in Settings (docs/UX.md 3.8): a 48 x 48 target. The chosen one has
## a thick outline and a check mark; a locked one is dimmed and shows a padlock. The sample
## is the theme's light and dark colors from `Looks`, light at the top.

var id := ""
var selected := false
var locked := false


static func make_swatch(swatch_id: String, is_selected: bool, is_locked: bool) -> Swatch:
	var s := new()
	s.id = swatch_id
	s.label_text = swatch_id.capitalize()
	s.selected = is_selected
	s.locked = is_locked
	s.kind = UiButton.Kind.QUIET
	s.custom_minimum_size = Vector2(48.0, 48.0)
	s.theme_type_variation = "FlatButton"
	s.focus_mode = Control.FOCUS_ALL
	s.tooltip_text = s.label_text
	return s


func _draw() -> void:
	var colors := _colors()
	var light := colors[0].darkened(0.4) if locked else colors[0]
	var dark := colors[1].darkened(0.4) if locked else colors[1]
	var shape := PackedVector2Array([Vector2(2, 2), Vector2(size.x - 2.0, 2), Vector2(size.x - 2.0, size.y - 2.0), Vector2(2, size.y - 2.0)])
	draw_polygon(shape, PackedColorArray([light, light, dark, dark]))
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.set_corner_radius_all(8)
	box.set_border_width_all(4 if selected else 2)
	box.border_color = UiTheme.PRIMARY if selected else UiTheme.PLAQUE_BORDER
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var center := size / 2.0
	if locked:
		UiIcons.draw(self, "padlock", center, 22.0, UiTheme.TEXT)
	elif selected:
		UiIcons.draw(self, "check", center, 22.0, UiTheme.PRIMARY_TEXT)


## The light and dark colors of this swatch's wood or metal.
func _colors() -> Array[Color]:
	if Looks.WOODS.has(id):
		var w := Looks.wood(id)
		return [w["wood_light"], w["wood_dark"]]
	var m := Looks.metal(id)
	return [m["metal_light"], m["metal_dark"]]
