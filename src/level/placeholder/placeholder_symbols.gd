# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name PlaceholderSymbols
extends RefCounted
## The placeholder look's nine screw colors (DESIGN.md 3.2, in the logic's index order) and one
## simple line symbol for each, so color is never the only signal (UX 7.4). Phase 4 replaces this
## with src/render's Palette; nothing outside src/level/placeholder/ uses it.

const COLORS: Array[Color] = [
	Color("e5331e"), Color("f9d63a"), Color("4bc4ed"), Color("1e45b8"), Color("f5922a"),
	Color("f7f2ea"), Color("2f875a"), Color("8454d9"), Color("e062a6"),
]
const INK_DARK := Color("2a1708")
const INK_LIGHT := Color("fff8ec")
const RIM_LIGHT := Color("f4f1ea")
const RIM_DARK := Color("4c463e")

## Symbol numbers, in the same order as COLORS: triangle, star, diamond, cross, square, moon,
## circle, ring, bar.
const TRIANGLE := 0
const STAR := 1
const DIAMOND := 2
const CROSS := 3
const SQUARE := 4
const MOON := 5
const CIRCLE := 6
const RING := 7
const BAR := 8

static var _star := _make_star()
static var _moon := _make_moon()
static var _triangle := PackedVector2Array([Vector2(0, -1), Vector2(0.9, 0.75), Vector2(-0.9, 0.75), Vector2(0, -1)])
static var _diamond := PackedVector2Array([Vector2(0, -1), Vector2(0.8, 0), Vector2(0, 1), Vector2(-0.8, 0), Vector2(0, -1)])
static var _square := PackedVector2Array([Vector2(-0.7, -0.7), Vector2(0.7, -0.7), Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(-0.7, -0.7)])


static func color_of(index: int) -> Color:
	return COLORS[posmod(index, COLORS.size())]


## Dark or light ink, whichever reads better on this screw color.
static func ink_for(index: int) -> Color:
	var c := color_of(index)
	var lum := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	return INK_DARK if lum > 0.45 else INK_LIGHT


## Draws a color's symbol on `canvas`, filling a circle of `radius` around `center`, turned by
## `turn_deg`. Strokes are `width` wide in the canvas' own units.
static func draw(canvas: CanvasItem, index: int, center: Vector2, radius: float, turn_deg: float, ink: Color, width: float) -> void:
	var w := width / radius
	canvas.draw_set_transform(center, deg_to_rad(turn_deg), Vector2(radius, radius))
	match posmod(index, COLORS.size()):
		TRIANGLE:
			canvas.draw_polyline(_triangle, ink, w)
		STAR:
			canvas.draw_polyline(_star, ink, w)
		DIAMOND:
			canvas.draw_polyline(_diamond, ink, w)
		CROSS:
			canvas.draw_line(Vector2(-0.85, 0), Vector2(0.85, 0), ink, w)
			canvas.draw_line(Vector2(0, -0.85), Vector2(0, 0.85), ink, w)
		SQUARE:
			canvas.draw_polyline(_square, ink, w)
		MOON:
			canvas.draw_polyline(_moon, ink, w)
		CIRCLE:
			canvas.draw_circle(Vector2.ZERO, 0.6, ink)
		RING:
			canvas.draw_arc(Vector2.ZERO, 0.7, 0.0, TAU, 20, ink, w)
		_:
			canvas.draw_line(Vector2(-0.9, 0), Vector2(0.9, 0), ink, w * 1.3)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _make_star() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in 11:
		var r := 1.0 if i % 2 == 0 else 0.45
		var a := -PI * 0.5 + i * PI / 5.0
		out.append(Vector2(cos(a), sin(a)) * r)
	return out


## A crescent: the left part of a circle with a smaller circle cut out of its right.
static func _make_moon() -> PackedVector2Array:
	var out := PackedVector2Array()
	var a0 := deg_to_rad(52.4)
	var a1 := deg_to_rad(307.6)
	for i: int in 13:
		var a := lerpf(a0, a1, i / 12.0)
		out.append(Vector2(cos(a), sin(a)))
	var b0 := deg_to_rad(277.9)
	var b1 := deg_to_rad(82.1)
	for i: int in 11:
		var a := lerpf(b0, b1, i / 10.0)
		out.append(Vector2(0.5, 0.0) + Vector2(cos(a), sin(a)) * 0.8)
	out.append(out[0])
	return out
