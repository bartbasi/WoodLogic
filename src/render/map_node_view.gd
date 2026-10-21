# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MapNodeView
extends CachedDrawing
## One level on the progress map (docs/ARCHITECTURE.md 11.1, docs/UX.md 3.6), centered on its
## origin. Cleared: an oak disc 64 across with the number and three stars. A hard level (`big`):
## 72 across with a notched edge. Next: an 80 brass disc with a thick walnut border, the number
## and a play triangle. Locked: a dim walnut disc with the number and a padlock. The states differ
## in shape and icons, never only in color, and the number always reads at 4.5:1 or more. Plain
## _draw calls, no shader, so a pool of twenty costs next to nothing. The map screen places,
## recycles and hit tests them.

enum { CLEARED, NEXT, LOCKED }

const SIZE_CLEARED := 64.0
const SIZE_HARD := 72.0
const SIZE_NEXT := 80.0
const SIZE_LOCKED := 64.0
const NUMBER_SIZE := 18
const OAK := Color("dcae6c")
const OAK_EDGE := Color("8a5a2c")
const INK := Color("2a1708")
const MISSED := Color("6b4413")

var _number := 1
var _state := CLEARED
var _stars := 0
var _big := false
var _pressed := false
## The pressed look as a property too (the same as set_pressed).
var pressed: bool:
	get:
		return _pressed
	set(value):
		set_pressed(value)
## Held here: the canvas draws with the font after _draw returns.
var _font: Font = RenderFonts.bold()


func setup(number: int, state: int, stars: int, big: bool) -> void:
	_number = number
	_state = clampi(state, CLEARED, LOCKED)
	_stars = clampi(stars, 0, 3)
	_big = big
	repaint()


## The pressed look (UX 3.6: shown on touch down, dropped if the touch becomes a scroll).
func set_pressed(on: bool) -> void:
	_pressed = on
	scale = Vector2.ONE * (Tokens.PRESSED_SCALE if on else 1.0)
	repaint()


func _paint_rect() -> Rect2:
	var r := diameter() * 0.5 + 8.0
	return Rect2(-r, -r, r * 2.0, r * 2.0 + 4.0)


## The node's size across, for hit testing and spacing.
func diameter() -> float:
	match _state:
		NEXT:
			return SIZE_NEXT
		LOCKED:
			return SIZE_LOCKED
	return SIZE_HARD if _big else SIZE_CLEARED


func _paint(ci: CanvasItem) -> void:
	var r := diameter() * 0.5
	var dark := Tokens.PRESSED_DARKEN if _pressed else 0.0
	ci.draw_circle(Vector2(1.5, 4.0), r, Color(0, 0, 0, 0.4), true, -1.0, true)
	match _state:
		NEXT:
			ci.draw_circle(Vector2(0, 3), r, Tokens.PRIMARY_LIP, true, -1.0, true)
			ci.draw_circle(Vector2.ZERO, r, Tokens.SECONDARY_LIP, true, -1.0, true)
			ci.draw_circle(Vector2.ZERO, r - 5.0, Tokens.PRIMARY.darkened(dark), true, -1.0, true)
			ci.draw_arc(Vector2.ZERO, r - 7.0, PI * 1.1, PI * 1.75, 16, Color(1, 1, 1, 0.35), 2.0, true)
			_number_text(ci, Vector2(0, -8), Tokens.PRIMARY_TEXT)
			var tri := PackedVector2Array([Vector2(-6, 9), Vector2(8, 16), Vector2(-6, 23)])
			ci.draw_colored_polygon(tri, Tokens.PRIMARY_TEXT)
		LOCKED:
			ci.draw_circle(Vector2(0, 3), r, Tokens.SECONDARY_LIP, true, -1.0, true)
			ci.draw_circle(Vector2.ZERO, r, Tokens.SECONDARY.darkened(dark), true, -1.0, true)
			ci.draw_arc(Vector2.ZERO, r - 1.0, 0.0, TAU, 40, Color(Tokens.TEXT_DIM, 0.25), 1.5, true)
			_number_text(ci, Vector2(0, -7), Tokens.TEXT_DIM)
			Icons.draw(ci, "padlock", Vector2(0, 15), 16.0, Tokens.TEXT_DIM)
		_:
			var face := OAK.darkened(dark)
			if _big:
				_notched(ci, Vector2(0, 3), r, OAK_EDGE)
				_notched(ci, Vector2.ZERO, r, face)
			else:
				ci.draw_circle(Vector2(0, 3), r, OAK_EDGE, true, -1.0, true)
				ci.draw_circle(Vector2.ZERO, r, face, true, -1.0, true)
			ci.draw_arc(Vector2.ZERO, r - 3.0, PI * 1.1, PI * 1.75, 16, Color(1, 1, 1, 0.3), 2.0, true)
			_number_text(ci, Vector2(0, -8), INK)
			for i in 3:
				var c := Vector2((i - 1) * 14.0, 14.0)
				if i < _stars:
					Icons.draw(ci, "star", c, 12.0, Tokens.STAR_RIM)
					Icons.draw(ci, "star", c, 9.0, Tokens.STAR_FACE)
				else:
					Icons.draw(ci, "star_empty", c, 12.0, MISSED)


func _number_text(ci: CanvasItem, center: Vector2, color: Color) -> void:
	var font := _font
	var text := str(_number)
	var size := NUMBER_SIZE if text.length() < 4 else NUMBER_SIZE - 3
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := center.y + (font.get_ascent(size) - font.get_descent(size)) * 0.5
	ci.draw_string(font, Vector2(center.x - w * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## A disc with twelve notches cut in its edge (the hard levels' badge).
func _notched(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var n := 48
	for i in n:
		var a := TAU * i / n
		var notch := 1.0 - 0.07 * maxf(0.0, cos(a * 12.0)) * 1.0
		pts.append(c + Vector2(cos(a), sin(a)) * r * notch)
	ci.draw_colored_polygon(pts, color)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, color, 1.0, true)
