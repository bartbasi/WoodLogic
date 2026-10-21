# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Palette
extends RefCounted
## The nine screw colors and their symbols (docs/DESIGN.md 3.2), in the index order the logic,
## the generator and the data use. The logic only knows the index; everything about how a color
## looks lives here. Symbols are filled outlines at unit radius, so the same data draws a box
## band, a preview lid, a ghost and the screw head's recess (screw.gdshader draws the recess
## from the same shapes as distance functions).

## Symbol ids, one per color, in COLORS order.
enum Sym { TRIANGLE, STAR, DIAMOND, CROSS, SQUARE, MOON, CIRCLE, RING, BAR }

const COLORS: Array[Color] = [
	Color("e5331e"),  # 0 red
	Color("f9d63a"),  # 1 yellow
	Color("4bc4ed"),  # 2 sky
	Color("1e45b8"),  # 3 blue
	Color("f5922a"),  # 4 orange
	Color("f7f2ea"),  # 5 white
	Color("2f875a"),  # 6 green
	Color("8454d9"),  # 7 purple
	Color("e062a6"),  # 8 pink
]
const NAMES: Array[String] = ["red", "yellow", "sky", "blue", "orange", "white", "green", "purple", "pink"]
const SYMBOL_NAMES: Array[String] = ["triangle", "star", "diamond", "cross", "square", "moon", "circle", "ring", "bar"]

## Ink for symbols printed on a color (box bands, preview lids).
const INK_DARK := Color("1d1a17")
const INK_LIGHT := Color("fbf7f0")

## Below this relative luminance a cap counts as dark: its recess shows bright bare metal and
## printed symbols use light ink.
const DARK_CAP := 0.17

static var _outlines: Array[PackedVector2Array] = []


static func count() -> int:
	return COLORS.size()


static func color(index: int) -> Color:
	return COLORS[posmod(index, COLORS.size())]


static func color_name(index: int) -> String:
	return NAMES[posmod(index, NAMES.size())]


static func symbol_name(index: int) -> String:
	return SYMBOL_NAMES[posmod(index, SYMBOL_NAMES.size())]


## Drawing data for a color's symbol: {"id": Sym, "name": String, "outline": filled polygon at
## unit radius, y down, upright}. Scale it by the radius the symbol should fill.
static func symbol(index: int) -> Dictionary:
	var i := posmod(index, COLORS.size())
	return {"id": i, "name": SYMBOL_NAMES[i], "outline": outline(i)}


## The symbol's outline at unit radius (the symbol fits a circle of radius 1).
static func outline(index: int) -> PackedVector2Array:
	if _outlines.is_empty():
		for i in COLORS.size():
			_outlines.append(_make(i))
	return _outlines[posmod(index, COLORS.size())]


## WCAG relative luminance, from linear light.
static func luminance(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func is_dark(index: int) -> bool:
	return luminance(color(index)) < DARK_CAP


## Black or white ink, whichever contrasts more with the color.
static func ink(index: int) -> Color:
	var c := color(index)
	return INK_DARK if contrast(INK_DARK, c) >= contrast(INK_LIGHT, c) else INK_LIGHT


## Draws a color's symbol filled, fitting a circle of `radius` around `center`, turned by
## `turn_deg` (degrees, clockwise). Smooth edges come from an antialiased outline in the same
## ink, so no MSAA is needed.
static func draw_symbol(ci: CanvasItem, index: int, center: Vector2, radius: float, ink_color: Color, turn_deg: float = 0.0) -> void:
	var src := outline(index)
	var pts := PackedVector2Array()
	pts.resize(src.size())
	var rot := deg_to_rad(turn_deg)
	for i in src.size():
		pts[i] = center + (src[i] * radius).rotated(rot)
	ci.draw_colored_polygon(pts, ink_color)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, ink_color, maxf(0.8, radius * 0.06), true)


static func _circle(r: float, n: int, c: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## Points along a circle from angle a0 to a1, taking the way round that passes `via`.
static func _arc(c: Vector2, r: float, a0: float, a1: float, via: float, n: int) -> PackedVector2Array:
	var sweep := wrapf(a1 - a0, 0.0, TAU)
	if absf(wrapf(via - a0, 0.0, TAU)) > sweep:
		sweep -= TAU
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := a0 + sweep * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func _make(sym: int) -> PackedVector2Array:
	match sym:
		Sym.TRIANGLE:
			var pts := PackedVector2Array()
			for i in 3:
				var a := -PI / 2.0 + TAU * i / 3.0
				pts.append(Vector2(cos(a), sin(a)) * 0.98 + Vector2(0.0, 0.14))
			return pts
		Sym.STAR:
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + TAU * i / 10.0
				pts.append(Vector2(cos(a), sin(a)) * (1.0 if i % 2 == 0 else 0.45) + Vector2(0.0, 0.06))
			return pts
		Sym.DIAMOND:
			return PackedVector2Array([Vector2(0, -1), Vector2(0.68, 0), Vector2(0, 1), Vector2(-0.68, 0)])
		Sym.CROSS:
			var a := 0.96
			var b := 0.26
			return PackedVector2Array([
				Vector2(-b, -a), Vector2(b, -a), Vector2(b, -b), Vector2(a, -b), Vector2(a, b), Vector2(b, b),
				Vector2(b, a), Vector2(-b, a), Vector2(-b, b), Vector2(-a, b), Vector2(-a, -b), Vector2(-b, -b)])
		Sym.SQUARE:
			var s := 0.64
			return PackedVector2Array([Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)])
		Sym.MOON:
			# A crescent: the outer circle minus a smaller circle offset up and right.
			var r0 := 0.86
			var c := Vector2(0.38, -0.22)
			var r1 := 0.7
			var d := c.length()
			var along := (r0 * r0 - r1 * r1 + d * d) / (2.0 * d)
			var h := sqrt(maxf(r0 * r0 - along * along, 0.0))
			var u := c / d
			var n := Vector2(-u.y, u.x)
			var p1 := u * along + n * h
			var p2 := u * along - n * h
			var away := (-c).angle()
			var outer := _arc(Vector2.ZERO, r0, p1.angle(), p2.angle(), away, 28)
			var inner := _arc(c, r1, (p2 - c).angle(), (p1 - c).angle(), away, 20)
			inner.remove_at(0)
			inner.remove_at(inner.size() - 1)
			outer.append_array(inner)
			return outer
		Sym.CIRCLE:
			return _circle(0.62, 32)
		Sym.RING:
			# One simple polygon: the outer circle, then the inner circle backwards, joined by a
			# hairline seam that the antialiased outline closes.
			var ro := 0.78
			var ri := 0.44
			var pts := PackedVector2Array()
			var n := 36
			for i in n + 1:
				var a := 0.02 + (TAU - 0.04) * i / n
				pts.append(Vector2(cos(a), sin(a)) * ro)
			for i in n + 1:
				var a := TAU - 0.02 - (TAU - 0.04) * i / n
				pts.append(Vector2(cos(a), sin(a)) * ri)
			return pts
		Sym.BAR:
			return PackedVector2Array([Vector2(-1, -0.26), Vector2(1, -0.26), Vector2(1, 0.26), Vector2(-1, 0.26)])
	return _circle(0.62, 24)
