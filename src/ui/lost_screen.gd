# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LostScreen
extends UiScreen
## Out of room (docs/UX.md 3.5): a sheet that slides up over the dimmed board with Retry, the
## helpers the player owns and can use (never a purchase), and Previous level (or Title).
## Retry works from the first frame of the slide. In Relaxed the same sheet reads "Stuck for
## now" and offers a free Undo first.

signal retry_pressed
signal previous_pressed
signal title_pressed
signal helper_pressed(helper: String)

const SHEET_HEIGHT := 244.0
const SHEET_HEIGHT_HELPERS := 300.0
## The stuck sheet's longer text takes three lines.
const SHEET_HEIGHT_STUCK := 268.0
const TOP_PADDING := 16.0
const SLIDE_S := 0.25

var level_number := 2
## Offer Previous level (not on level 1 or in the daily).
var can_previous := true
## Relaxed: the stuck sheet.
var stuck := false
## [[helper, count], ...] in the fixed order, only those that can be offered.
var helpers: Array = []
var _dim := ColorRect.new()
var _sheet := Panel.new()
var _slide := 0.0


## options: number, can_previous, stuck, helpers (Array of [id, count]).
static func make(options: Variant) -> LostScreen:
	var s := new()
	if options is Dictionary:
		var d: Dictionary = options
		s.level_number = int(d.get("number", 2))
		s.can_previous = bool(d.get("can_previous", s.level_number > 1))
		s.stuck = bool(d.get("stuck", false))
		s.helpers = d.get("helpers", [])
	else:
		s.level_number = int(options)
		s.can_previous = s.level_number > 1
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
	column.add_theme_constant_override("separation", 8)
	var heading := Label.new()
	heading.text = "Stuck for now" if stuck else "The tray is full"
	heading.theme_type_variation = "HeadingLabel"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.custom_minimum_size.y = 32.0
	column.add_child(heading)
	var body := Label.new()
	body.text = "Nothing fits an open box and the tray is full. Take back a move and try another way." if stuck else "Every slot is taken, and no free screw fits an open box."
	body.theme_type_variation = "BodyLabel"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.y = 66.0 if stuck else 44.0
	column.add_child(body)
	if stuck:
		var undo := UiButton.make("Undo", UiButton.Kind.PRIMARY, "", 64.0)
		undo.pressed.connect(func() -> void: helper_pressed.emit("undo"))
		column.add_child(wide(undo))
		var retry := UiButton.make("Retry", UiButton.Kind.QUIET, "", 48.0)
		retry.pressed.connect(func() -> void: retry_pressed.emit())
		var title := UiButton.make("Title", UiButton.Kind.QUIET, "", 48.0)
		title.pressed.connect(func() -> void: title_pressed.emit())
		column.add_child(row(retry, title))
	else:
		var retry := UiButton.make("Retry", UiButton.Kind.PRIMARY, "", 64.0)
		retry.pressed.connect(func() -> void: retry_pressed.emit())
		column.add_child(wide(retry))
		if not helpers.is_empty():
			column.add_child(_helper_row())
		var title := UiButton.make("Title", UiButton.Kind.QUIET, "", 48.0)
		title.pressed.connect(func() -> void: title_pressed.emit())
		if can_previous:
			var previous := UiButton.make("Previous level", UiButton.Kind.QUIET, "", 48.0)
			previous.pressed.connect(func() -> void: previous_pressed.emit())
			column.add_child(row(previous, title))
		else:
			column.add_child(wide(title))
	play_sound("lose")
	_slide = _sheet_height()
	create_tween().tween_method(_set_slide, _slide, 0.0, SLIDE_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _helper_row() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.custom_minimum_size.y = 56.0
	for entry: Array in helpers:
		var b := HelperButton.make_helper(str(entry[0]), int(entry[1]), helpers.size() == 1)
		var id := str(entry[0])
		b.pressed.connect(func() -> void: helper_pressed.emit(id))
		h.add_child(b)
	wide(h)
	return h


func _set_slide(v: float) -> void:
	_slide = v
	_layout()


func _sheet_height() -> float:
	var base := SHEET_HEIGHT_HELPERS if (not stuck and not helpers.is_empty()) else SHEET_HEIGHT
	if stuck:
		base = SHEET_HEIGHT_STUCK
	return base + UiScreen.insets(self).w


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
