# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name DirSymbols
extends RefCounted
## Draws the colorblind symbols as filled shapes with _draw calls, for boxes, previews and
## labels. Screw heads draw the same shapes in screw.gdshader as a recess. `r` is the radius
## of the circle the symbol fits in. Each polygon gets an antialiased outline in its own color
## so the edges stay smooth without MSAA.


static func draw(ci: CanvasItem, sym: int, center: Vector2, r: float, color: Color, angle: float = 0.0) -> void:
	match sym:
		DirColors.Sym.CIRCLE:
			ci.draw_circle(center, r * 0.62, color, true, -1.0, true)
		DirColors.Sym.RING:
			ci.draw_arc(center, r * 0.6, 0.0, TAU, 40, color, r * 0.28, true)
		DirColors.Sym.MOON:
			_poly(ci, _moon(r), center, angle, color)
		_:
			_poly(ci, points(sym, r), center, angle, color)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, center: Vector2, angle: float, color: Color) -> void:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(center + p.rotated(angle))
	ci.draw_colored_polygon(out, color)
	var loop := out.duplicate()
	loop.append(out[0])
	ci.draw_polyline(loop, color, 1.0, true)


## Outline points for the polygon symbols, centered on the origin, y down.
static func points(sym: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match sym:
		DirColors.Sym.TRIANGLE:
			for i in 3:
				var a := -PI / 2.0 + TAU * i / 3.0
				pts.append(Vector2(cos(a), sin(a)) * r * 0.95 + Vector2(0, r * 0.12))
		DirColors.Sym.SQUARE:
			var s := r * 0.62
			pts = PackedVector2Array([Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)])
		DirColors.Sym.STAR:
			for i in 10:
				var a := -PI / 2.0 + TAU * i / 10.0
				var rr := r * (1.0 if i % 2 == 0 else 0.44)
				pts.append(Vector2(cos(a), sin(a)) * rr + Vector2(0, r * 0.06))
		DirColors.Sym.DIAMOND:
			pts = PackedVector2Array([Vector2(0, -r), Vector2(r * 0.66, 0), Vector2(0, r), Vector2(-r * 0.66, 0)])
		DirColors.Sym.CROSS:
			var a := r * 0.95
			var b := r * 0.26
			pts = PackedVector2Array([
				Vector2(-b, -a), Vector2(b, -a), Vector2(b, -b), Vector2(a, -b), Vector2(a, b), Vector2(b, b),
				Vector2(b, a), Vector2(-b, a), Vector2(-b, b), Vector2(-a, b), Vector2(-a, -b), Vector2(-b, -b)])
		DirColors.Sym.BAR:
			var w := r * 0.98
			var h := r * 0.26
			pts = PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)])
		_:
			for i in 24:
				var a := TAU * i / 24.0
				pts.append(Vector2(cos(a), sin(a)) * r * 0.62)
	return pts


## A crescent: the outer arc of one circle and the inner arc of a smaller offset circle.
static func _moon(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var outer := r * 0.8
	var inner := r * 0.66
	var off := Vector2(r * 0.36, -r * 0.2)
	# Where the two circles cross, found numerically along the outer circle.
	var steps := 48
	var inside_from := -1.0
	var inside_to := -1.0
	var angles: Array[float] = []
	for i in steps + 1:
		var a := TAU * i / steps
		var p := Vector2(cos(a), sin(a)) * outer
		if p.distance_to(off) > inner:
			angles.append(a)
	if angles.is_empty():
		return pts
	# The visible outer arc is the part outside the cutting circle; walk it in order.
	var mid := off.angle() + PI
	var half := 0.0
	for a: float in angles:
		half = maxf(half, absf(wrapf(a - mid, -PI, PI)))
	inside_from = mid - half
	inside_to = mid + half
	for i in 25:
		var a := lerpf(inside_from, inside_to, i / 24.0)
		pts.append(Vector2(cos(a), sin(a)) * outer)
	# Back along the cutting circle, from the end point to the start point.
	var e := pts[pts.size() - 1] - off
	var s := pts[0] - off
	var ea := e.angle()
	var sa := s.angle()
	var sweep := wrapf(sa - ea, -TAU, 0.0)
	if sweep > -0.01:
		sweep -= TAU
	for i in range(1, 24):
		var a := ea + sweep * i / 24.0
		pts.append(off + Vector2(cos(a), sin(a)) * inner)
	return pts
