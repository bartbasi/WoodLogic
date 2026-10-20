# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LostScreen
extends UiScreen
## Out of room (docs/UX.md 3.5), Phase 3: a sheet that slides up over the dimmed board with
## Retry, then Previous level and Title side by side (just Title on level 1). No helpers yet.
## Retry works from the first frame of the slide.

signal retry_pressed
signal previous_pressed
signal title_pressed

const SHEET_HEIGHT := 244.0
const TOP_PADDING := 16.0
const SLIDE_S := 0.25

var level_number := 2
var _dim := ColorRect.new()
var _sheet := Panel.new()
var _slide := 0.0


static func make(level: int) -> LostScreen:
	var s := LostScreen.new()
	s.level_number = level
	s.opaque = false
	s.fade_in = false
	return s


func _build() -> void:
	_dim.color = Color(0.0, 0.0, 0.0, 0.3)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_sheet.add_theme_stylebox_override("panel", UiTheme.sheet_box())
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	move_child(column, -1)
	var heading := Label.new()
	heading.text = "The tray is full"
	heading.theme_type_variation = "HeadingLabel"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.custom_minimum_size.y = 32.0
	column.add_child(heading)
	var body := Label.new()
	body.text = "Every slot is taken, and no free screw fits an open box."
	body.theme_type_variation = "BodyLabel"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.y = 44.0
	column.add_child(body)
	var retry := UiButton.make("Retry", UiButton.Kind.PRIMARY, "", 64.0)
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	column.add_child(wide(retry))
	var title := UiButton.make("Title", UiButton.Kind.QUIET, "", 48.0)
	title.pressed.connect(func() -> void: title_pressed.emit())
	if level_number > 1:
		var previous := UiButton.make("Previous level", UiButton.Kind.QUIET, "", 48.0)
		previous.pressed.connect(func() -> void: previous_pressed.emit())
		column.add_child(row(previous, title))
	else:
		column.add_child(wide(title))
	_slide = _sheet_height()
	create_tween().tween_method(_set_slide, _slide, 0.0, SLIDE_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_slide(v: float) -> void:
	_slide = v
	_layout()


func _sheet_height() -> float:
	return SHEET_HEIGHT + UiScreen.insets(self).w


func _content_rect() -> Rect2:
	var r := super._content_rect()
	var h := _sheet_height()
	var top := size.y - h + _slide + TOP_PADDING
	return Rect2(r.position.x, top, r.size.x, h - TOP_PADDING)


func _layout() -> void:
	super._layout()
	var h := _sheet_height()
	_sheet.position = Vector2(0.0, size.y - h + _slide)
	_sheet.size = Vector2(size.x, h)
