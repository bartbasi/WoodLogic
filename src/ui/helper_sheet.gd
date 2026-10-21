# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name HelperSheet
extends UiScreen
## The first-time explanation of a helper (docs/UX.md 3.13.1): a sheet 264 tall that sits
## directly above the helper bar, shown before the level that introduces the helper. "Got it"
## closes it. The clock is held while it is open (the app flow does that). The helper bar stays
## visible below it, so this screen only covers the sheet's own area and takes touches there.

signal got_it

const SHEET_HEIGHT := 264.0
## The helper bar and its gap under the board (UX 3.2.1).
const BAR_SPACE := 64.0
const SLIDE_S := 0.25
const BODIES := {
	"undo": ["Undo", "Takes back your last move."],
	"extra_slot": ["Extra slot", "Adds one more tray slot, once per try."],
	"screwdriver": ["Screwdriver", "Removes any one screw, even a covered one, to where a tap would send it."],
}

var helper := "undo"
var _sheet := Panel.new()
var _slide := 0.0


static func make(helper_id: String) -> HelperSheet:
	var s := new()
	s.helper = helper_id
	s.opaque = false
	s.fade_in = false
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _build() -> void:
	_sheet.add_theme_stylebox_override("panel", UiTheme.sheet_box())
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	move_child(column, -1)
	var texts := texts_for(helper)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var art := IconView.make(helper, 64.0, UiTheme.TEXT_GOLD)
	art.custom_minimum_size = Vector2(72.0, 72.0)
	top.add_child(art)
	var h := Label.new()
	h.text = texts[0]
	h.theme_type_variation = "HeadingLabel"
	h.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(h)
	column.add_child(top)
	var b := Label.new()
	b.text = texts[1]
	b.theme_type_variation = "BodyLabel"
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.y = 50.0
	column.add_child(b)
	var cost := Label.new()
	cost.text = "Using a helper means no Clean star on that try."
	cost.theme_type_variation = "SmallLabel"
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(cost)
	column.add_child(spacer())
	var ok := UiButton.make("Got it", UiButton.Kind.PRIMARY, "", 56.0)
	ok.pressed.connect(func() -> void: got_it.emit())
	column.add_child(wide(ok))
	_slide = SHEET_HEIGHT
	create_tween().tween_method(_set_slide, _slide, 0.0, SLIDE_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_slide(v: float) -> void:
	_slide = v
	_layout()


func _bottom() -> float:
	return size.y - UiScreen.insets(self).w - BAR_SPACE


func _content_rect() -> Rect2:
	var r := super._content_rect()
	var top := _bottom() - SHEET_HEIGHT + _slide + 12.0
	return Rect2(r.position.x, top, r.size.x, SHEET_HEIGHT - 20.0)


func _layout() -> void:
	super._layout()
	_sheet.position = Vector2(0.0, _bottom() - SHEET_HEIGHT + _slide)
	_sheet.size = Vector2(size.x, SHEET_HEIGHT)


## [heading, body] for a helper. The count of free ones comes from Tuning.
static func texts_for(helper_id: String) -> Array:
	var pair: Array = BODIES[helper_id]
	var free := int(Tuning.helpers[helper_id]["free"])
	var given := "Here is 1 to get you started." if free == 1 else "Here are %d to get you started." % free
	return [pair[0], "%s %s" % [pair[1], given]]
