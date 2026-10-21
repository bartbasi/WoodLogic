# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name UiDialog
extends UiScreen
## A dialog (docs/UX.md 1.4): a centered panel 304 wide holding a short question, with the
## buttons stacked below the text. The background dims by 55 percent. Used for resetting
## progress and for buying a helper.

## The index of the button tapped (or of `cancel_index` for the Back button).
signal chosen(index: int)

var heading_text := ""
var body_text := ""
## [[label, UiButton.Kind], ...] in order, first one on top.
var choices: Array = []
## The button Back stands for ("Not now", "Keep my progress").
var cancel_index := 0
var _buttons: Array[UiButton] = []


static func make(heading: String, body_line: String, options: Array, cancel: int = -1) -> UiDialog:
	var d := new()
	d.heading_text = heading
	d.body_text = body_line
	d.choices = options
	d.cancel_index = options.size() - 1 if cancel < 0 else cancel
	d.opaque = false
	return d


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	column.visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Plaque"
	panel.custom_minimum_size.x = 304.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var h := Label.new()
	h.text = heading_text
	h.theme_type_variation = "HeadingLabel"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(h)
	var b := Label.new()
	b.text = body_text
	b.theme_type_variation = "BodyLabel"
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)
	for i: int in choices.size():
		var entry: Array = choices[i]
		var kind: int = entry[1]
		var button := UiButton.make(str(entry[0]), kind, "", 56.0 if kind == UiButton.Kind.PRIMARY else 52.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: chosen.emit(i))
		_buttons.append(button)
		v.add_child(button)
		if i == 0 and choices.size() > 1:
			v.add_child(gap(4.0))
	panel.add_child(v)
	center.add_child(panel)
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


## The Back button: the same as the cancel choice.
func cancel() -> void:
	chosen.emit(cancel_index)
