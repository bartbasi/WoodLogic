# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name UiButton
extends Button
## A button as docs/UX.md 1.4 and 6.3 describe: at least 48 units tall, acts on release (a
## finger that slides off cancels), shrinks to 0.96 and darkens the moment it is pressed, and
## makes a quiet knock. An optional note line sits under the label.

enum Kind { PRIMARY, SECONDARY, QUIET, DANGER }

const MIN_HEIGHT := 48.0
const PRESS_SCALE := 0.96

var kind: int = Kind.SECONDARY
var label_text := ""
var note_text := ""
var _label: Label
var _note: Label


## label: the button's words. note: an optional second, smaller line. height: 0 picks the
## usual one for the kind (72 primary, 52 other).
static func make(label: String, kind_value: int = Kind.SECONDARY, note: String = "", height: float = 0.0) -> UiButton:
	var b := UiButton.new()
	b.kind = kind_value
	b.label_text = label
	b.note_text = note
	var h := height
	if h <= 0.0:
		h = 72.0 if kind_value == Kind.PRIMARY else 52.0
	b.custom_minimum_size = Vector2(0.0, maxf(MIN_HEIGHT, h))
	b.theme_type_variation = ["PrimaryButton", "SecondaryButton", "QuietButton", "DangerButton"][kind_value]
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if note == "":
		b.text = label
	else:
		b._build_two_lines()
	return b


func _ready() -> void:
	resized.connect(_update_pivot)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	_update_pivot()


func set_label(label: String) -> void:
	label_text = label
	if _label != null:
		_label.text = label
	else:
		text = label


func set_note(note: String) -> void:
	note_text = note
	if _note != null:
		_note.text = note


func _build_two_lines() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	_label = Label.new()
	_label.text = label_text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", UiTheme.bold_font())
	var big := kind == Kind.PRIMARY
	_label.add_theme_font_size_override("font_size", UiTheme.SIZE_BUTTON_PRIMARY if big else UiTheme.SIZE_BUTTON)
	var ink := UiTheme.PRIMARY_TEXT if big else UiTheme.TEXT
	_label.add_theme_color_override("font_color", ink)
	_note = Label.new()
	_note.text = note_text
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
	_note.add_theme_color_override("font_color", ink)
	box.add_child(_label)
	box.add_child(_note)
	add_child(box)


func _update_pivot() -> void:
	pivot_offset = size / 2.0


func _on_down() -> void:
	scale = Vector2(PRESS_SCALE, PRESS_SCALE)
	# A low, quiet knock (docs/ARCHITECTURE.md 10.2). Found by node, so a script run with -s
	# (which compiles before the autoload names exist) can still load this class.
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.call("play", "knock_dull", 1.3, -12.0)


func _on_up() -> void:
	scale = Vector2.ONE
