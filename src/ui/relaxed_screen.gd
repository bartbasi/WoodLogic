# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name RelaxedScreen
extends MenuScreen
## Relaxed setup (docs/UX.md 3.12): pick a difficulty and be playing in one tap. The last
## difficulty played carries a small "Last" tag.

signal band_pressed(band: String)

const NOTES := {"easy": "Fewer screws, plenty of room", "medium": "A good puzzle", "hard": "Tight spots and long plans"}

var last_band := ""
var buttons: Dictionary = {}


static func make(last: String) -> RelaxedScreen:
	var s := new()
	s.last_band = last
	return s


func _build_body() -> void:
	body.add_child(text_plaque("No clock, no stars, and you can't lose. Undo is free."))
	body.add_child(spacer())
	for band: String in ["easy", "medium", "hard"]:
		var b := UiButton.make(band.capitalize(), UiButton.Kind.SECONDARY, NOTES[band], 60.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: band_pressed.emit(band))
		if band == last_band:
			var tag := Label.new()
			tag.text = "Last"
			tag.theme_type_variation = "CaptionLabel"
			tag.position = Vector2(8.0, 2.0)
			tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			tag.offset_left = -48.0
			tag.offset_top = 4.0
			tag.offset_right = -8.0
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tag)
		buttons[band] = b
		body.add_child(wide(b))
	body.add_child(gap(8.0))
