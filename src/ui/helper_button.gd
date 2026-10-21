# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name HelperButton
extends UiButton
## A helper on the out of room sheet (docs/UX.md 3.5): with one helper it is a wide row (icon,
## name, count badge at the right); with two or three, an icon above the name and the count
## badge at the top right corner. At least 48 tall.

const NAMES := {"undo": "Undo", "extra_slot": "Extra slot", "screwdriver": "Screwdriver"}

var helper := ""
var count := 0
var wide_row := false
var _bold := UiTheme.bold_font()


## count < 0 shows no badge (Relaxed's free Undo).
static func make_helper(helper_id: String, owned: int, as_row: bool) -> HelperButton:
	var b := new()
	b.helper = helper_id
	b.count = owned
	b.wide_row = as_row
	b.label_text = NAMES.get(helper_id, helper_id)
	b.kind = UiButton.Kind.SECONDARY
	b.custom_minimum_size = Vector2(93.0, 56.0)
	b.theme_type_variation = "FlatButton"
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _draw() -> void:
	var fill := UiTheme.button_box(UiTheme.SECONDARY, UiTheme.SECONDARY_LIP, 0.25 if is_pressed() else 0.0)
	draw_style_box(fill, Rect2(Vector2.ZERO, size))
	var badge := "%d" % count if count >= 0 else ""
	if wide_row:
		UiIcons.draw(self, helper, Vector2(30.0, size.y / 2.0), 28.0, UiTheme.TEXT)
		draw_string(_bold, Vector2(56.0, size.y / 2.0 + 6.0), _name_text(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 110.0, UiTheme.SIZE_BUTTON, UiTheme.TEXT)
		_draw_badge(badge, Vector2(size.x - 28.0, size.y / 2.0))
	else:
		UiIcons.draw(self, helper, Vector2(size.x / 2.0, 20.0), 24.0, UiTheme.TEXT)
		draw_string(_bold, Vector2(0.0, size.y - 8.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.SIZE_CAPTION, UiTheme.TEXT)
		_draw_badge(badge, Vector2(size.x - 12.0, 12.0))


func _name_text() -> String:
	return label_text


func _draw_badge(text: String, center: Vector2) -> void:
	if text == "":
		return
	draw_circle(center, 11.0, UiTheme.PRIMARY)
	draw_string(_bold, center + Vector2(-12.0, 5.0), text, HORIZONTAL_ALIGNMENT_CENTER, 24.0, UiTheme.SIZE_SMALL, UiTheme.PRIMARY_TEXT)
