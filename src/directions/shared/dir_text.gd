# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name DirText
extends RefCounted
## Text drawing with Godot's default font only. Bold is the same font with embolden applied
## (a FontVariation made in code, no font file).

static var _bold: FontVariation
static var _wide: FontVariation


static func regular() -> Font:
	return ThemeDB.fallback_font


static func bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.9
	return _bold


## Bold with extra letter spacing, for display lettering.
static func wide() -> Font:
	if _wide == null:
		_wide = FontVariation.new()
		_wide.base_font = ThemeDB.fallback_font
		_wide.variation_embolden = 1.1
		_wide.spacing_glyph = 2
	return _wide


## Draws text centered in rect (or left or right aligned), vertically centered on the cap height.
static func draw(ci: CanvasItem, text: String, rect: Rect2, size: int, color: Color, font: Font = null,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, outline: int = 0, outline_color: Color = Color.BLACK) -> void:
	var f := font if font != null else regular()
	var ascent := f.get_ascent(size)
	var descent := f.get_descent(size)
	var baseline := rect.position.y + (rect.size.y + ascent - descent) / 2.0 - size * 0.04
	var pos := Vector2(rect.position.x, baseline)
	if outline > 0:
		ci.draw_string_outline(f, pos, text, align, rect.size.x, size, outline, outline_color)
	ci.draw_string(f, pos, text, align, rect.size.x, size, color)


static func width(text: String, size: int, font: Font = null) -> float:
	var f := font if font != null else regular()
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
