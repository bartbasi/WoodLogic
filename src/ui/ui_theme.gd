# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name UiTheme
extends RefCounted
## The Theme every screen shares, built in code from DESIGN.md's Workshop tokens with flat
## colors (docs/UX.md 1.3 and 1.4). Godot's default font only; bold is the same font made
## heavier. Type variations: PrimaryButton, SecondaryButton, QuietButton, DangerButton,
## DisplayLabel, HeadingLabel, BodyLabel, SmallLabel, CaptionLabel, and the panels Plaque
## and Sheet.

const PEGBOARD := Color("7a5a3d")
const PLAQUE := Color(0.172, 0.114, 0.075, 0.94)
const PLAQUE_BORDER := Color(0.847, 0.643, 0.271, 0.55)
const TEXT := Color("f7ead4")
const TEXT_DIM := Color("e8d6b8")
const TEXT_GOLD := Color("f3c766")
const PRIMARY := Color("d8a445")
const PRIMARY_LIP := Color("8a6420")
const PRIMARY_TEXT := Color("2a1708")
const SECONDARY := Color("4b3121")
const SECONDARY_LIP := Color("24160d")
const QUIET_LINE := Color(0.847, 0.643, 0.271, 0.6)
const DANGER := Color("8e2a1c")
const DANGER_LIP := Color("4f160e")
const FOCUS := Color("f7ead4")
const VEIL := Color(0.078, 0.051, 0.031, 0.62)

const SIZE_DISPLAY := 32
const SIZE_HEADING := 24
const SIZE_BUTTON_PRIMARY := 22
const SIZE_BUTTON := 18
const SIZE_BODY := 16
const SIZE_SMALL := 14
const SIZE_CAPTION := 13

## The default font made heavier. (A new one each time: nothing static holds a resource, so
## nothing is still in use when the game quits.)
static func bold_font() -> Font:
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.6
	return fv


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = ThemeDB.fallback_font
	t.default_font_size = SIZE_BODY
	# Labels.
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", SIZE_BODY)
	_label_variation(t, "DisplayLabel", SIZE_DISPLAY, TEXT, true)
	_label_variation(t, "HeadingLabel", SIZE_HEADING, TEXT, true)
	_label_variation(t, "BodyLabel", SIZE_BODY, TEXT, false)
	_label_variation(t, "SmallLabel", SIZE_SMALL, TEXT_DIM, false)
	_label_variation(t, "CaptionLabel", SIZE_CAPTION, TEXT_DIM, false)
	# Panels.
	t.set_stylebox("panel", "PanelContainer", plaque_box(10))
	t.set_type_variation("Plaque", "PanelContainer")
	t.set_stylebox("panel", "Plaque", plaque_box(10))
	t.set_type_variation("Sheet", "PanelContainer")
	t.set_stylebox("panel", "Sheet", sheet_box())
	# Buttons.
	t.set_font("font", "Button", bold_font())
	t.set_font_size("font_size", "Button", SIZE_BUTTON)
	_button_variation(t, "Button", SECONDARY, SECONDARY_LIP, TEXT, SIZE_BUTTON)
	_button_variation(t, "SecondaryButton", SECONDARY, SECONDARY_LIP, TEXT, SIZE_BUTTON)
	_button_variation(t, "PrimaryButton", PRIMARY, PRIMARY_LIP, PRIMARY_TEXT, SIZE_BUTTON_PRIMARY)
	_button_variation(t, "DangerButton", DANGER, DANGER_LIP, TEXT, SIZE_BUTTON)
	_button_variation(t, "QuietButton", Color(0, 0, 0, 0), Color(0, 0, 0, 0), TEXT, SIZE_BUTTON)
	var quiet := quiet_boxes()
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, "QuietButton", quiet[state])
	return t


static func plaque_box(radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PLAQUE
	s.set_corner_radius_all(radius)
	s.set_border_width_all(1)
	s.border_color = PLAQUE_BORDER
	s.set_content_margin_all(12)
	return s


## The out of room sheet: a plaque with rounded top corners only.
static func sheet_box() -> StyleBoxFlat:
	var s := plaque_box(14)
	s.corner_radius_bottom_left = 0
	s.corner_radius_bottom_right = 0
	s.bg_color = Color(0.172, 0.114, 0.075, 1.0)
	return s


static func quiet_boxes() -> Dictionary:
	var out := {}
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.172, 0.114, 0.075, 0.94) if state == "pressed" else Color(0.172, 0.114, 0.075, 0.6)
		s.set_corner_radius_all(10)
		s.set_border_width_all(2)
		s.border_color = QUIET_LINE
		s.set_content_margin_all(8)
		out[state] = s
	return out


static func focus_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_corner_radius_all(12)
	s.set_border_width_all(3)
	s.border_color = FOCUS
	return s


static func button_box(fill: Color, lip: Color, darken: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill.darkened(darken)
	s.set_corner_radius_all(10)
	s.border_width_bottom = 4
	s.border_color = lip.darkened(darken)
	s.set_content_margin_all(8)
	return s


static func _button_variation(t: Theme, type_name: String, fill: Color, lip: Color, text: Color, size: int) -> void:
	if type_name != "Button":
		t.set_type_variation(type_name, "Button")
	t.set_stylebox("normal", type_name, button_box(fill, lip, 0.0))
	t.set_stylebox("hover", type_name, button_box(fill, lip, 0.0))
	t.set_stylebox("pressed", type_name, button_box(fill, lip, 0.25))
	t.set_stylebox("disabled", type_name, button_box(fill, lip, 0.35))
	t.set_stylebox("focus", type_name, focus_box())
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(color_name, type_name, text)
	t.set_color("font_disabled_color", type_name, text.darkened(0.3))
	t.set_font_size("font_size", type_name, size)
	t.set_font("font", type_name, bold_font())


static func _label_variation(t: Theme, type_name: String, size: int, color: Color, bold: bool) -> void:
	t.set_type_variation(type_name, "Label")
	t.set_font_size("font_size", type_name, size)
	t.set_color("font_color", type_name, color)
	if bold:
		t.set_font("font", type_name, bold_font())
