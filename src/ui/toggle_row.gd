# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name ToggleRow
extends UiButton
## A toggle row (docs/UX.md 1.4): the whole row is the target. It shows a label, a note, a
## switch 56 x 32 and the word On or Off beside it, so the state is never only color or
## position. The knob slides across in 120 ms.

signal switched(on: bool)

var on := true
var note := ""
## A tick when the switch turns off too. The Sound row sets this false: turning sound off
## makes no sound (UX 6.3).
var tick_when_off := true
var _knob := 1.0
var _bold := UiTheme.bold_font()


static func make_row(label: String, note_text: String, is_on: bool, height: float = 56.0) -> ToggleRow:
	var r := new()
	r.label_text = label
	r.note = note_text
	r.on = is_on
	r._knob = 1.0 if is_on else 0.0
	r.kind = UiButton.Kind.SECONDARY
	r.custom_minimum_size = Vector2(0.0, height)
	r.theme_type_variation = "FlatButton"
	r.focus_mode = Control.FOCUS_ALL
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


func _ready() -> void:
	super._ready()
	pressed.connect(_toggle)


func _toggle() -> void:
	on = not on
	create_tween().tween_method(_set_knob, _knob, 1.0 if on else 0.0, 0.12)
	switched.emit(on)
	if on or tick_when_off:
		var audio := get_node_or_null("/root/Audio")
		if audio != null:
			audio.call("play", "tick")


func set_on(value: bool) -> void:
	on = value
	_knob = 1.0 if on else 0.0
	queue_redraw()


func _set_knob(v: float) -> void:
	_knob = v
	queue_redraw()


func _draw() -> void:
	draw_style_box(UiTheme.plaque_box(10), Rect2(Vector2.ZERO, size))
	var mid := size.y / 2.0
	var text_y := mid + 6.0 if note == "" else mid - 3.0
	draw_string(_bold, Vector2(12.0, text_y), label_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 128.0, UiTheme.SIZE_BUTTON, UiTheme.TEXT)
	if note != "":
		draw_string(ThemeDB.fallback_font, Vector2(12.0, mid + 14.0), note, HORIZONTAL_ALIGNMENT_LEFT, size.x - 128.0, UiTheme.SIZE_SMALL, UiTheme.TEXT_DIM)
	var track := Rect2(size.x - 12.0 - 56.0, mid - 16.0, 56.0, 32.0)
	var track_box := StyleBoxFlat.new()
	track_box.bg_color = UiTheme.PRIMARY if on else UiTheme.SECONDARY_LIP
	track_box.set_corner_radius_all(16)
	track_box.set_border_width_all(2)
	track_box.border_color = UiTheme.PLAQUE_BORDER
	draw_style_box(track_box, track)
	var knob_x := track.position.x + 16.0 + _knob * 24.0
	draw_circle(Vector2(knob_x, mid), 11.0, UiTheme.TEXT)
	draw_string(_bold, Vector2(track.position.x - 44.0, mid + 6.0), "On" if on else "Off", HORIZONTAL_ALIGNMENT_RIGHT, 38.0, UiTheme.SIZE_BUTTON, UiTheme.TEXT)
