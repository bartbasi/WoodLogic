# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MapTrail
extends RefCounted
## The path between two levels on the progress map (docs/ARCHITECTURE.md 11.1, docs/UX.md 3.6):
## a solid brass inlay along a gentle curve between cleared levels and up to the next one, and a
## dashed line of cream dots beyond it (a shape difference, not only color). Also the fade over
## the top of the trail. Static drawing calls for the map screen's own _draw.

const SOLID_WIDTH := 6.0
const STEPS := 14


## Draws one segment from `from` to `to` (node centers; the ends are hidden under the nodes).
static func draw_segment(ci: CanvasItem, from: Vector2, to: Vector2, cleared: bool) -> void:
	var pts := curve(from, to)
	if cleared:
		var shadow := PackedVector2Array()
		for p: Vector2 in pts:
			shadow.append(p + Vector2(1.0, 2.5))
		ci.draw_polyline(shadow, Color(0, 0, 0, 0.35), SOLID_WIDTH + 1.0, true)
		ci.draw_polyline(pts, Tokens.PRIMARY_LIP, SOLID_WIDTH + 2.0, true)
		ci.draw_polyline(pts, Tokens.PRIMARY, SOLID_WIDTH, true)
		var hi := PackedVector2Array()
		for p: Vector2 in pts:
			hi.append(p + Vector2(-0.8, -1.2))
		ci.draw_polyline(hi, Color(1, 1, 1, 0.3), 1.4, true)
	else:
		var length := 0.0
		for i in range(1, pts.size()):
			length += pts[i].distance_to(pts[i - 1])
		var count := maxi(2, int(length / 14.0))
		for i in count + 1:
			var p := _along(pts, length * i / count)
			ci.draw_circle(p + Vector2(0.6, 1.2), 3.2, Color(0, 0, 0, 0.3), true, -1.0, true)
			ci.draw_circle(p, 3.0, Color(Tokens.TEXT, 0.55), true, -1.0, true)


## The fade over the top of the trail (UX 3.6): `color` at the top edge of `rect`, clear at its
## bottom edge. One gradient quad.
static func draw_fade(ci: CanvasItem, rect: Rect2, color: Color) -> void:
	var pts := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var cols := PackedColorArray([color, color, Color(color, 0.0), Color(color, 0.0)])
	ci.draw_polygon(pts, cols)


## A gentle S between two nodes, so the zigzag reads as a path.
static func curve(from: Vector2, to: Vector2) -> PackedVector2Array:
	var mid := (from + to) * 0.5
	var d := to - from
	var n := Vector2(-d.y, d.x).normalized() * d.length() * 0.12
	var pts := PackedVector2Array()
	for i in STEPS + 1:
		var t := i / float(STEPS)
		var a := from.lerp(mid + n, t)
		var b := (mid + n).lerp(to, t)
		var p := a.lerp(b, t)
		pts.append(p.lerp(from.lerp(to, t), 0.5))
	return pts


static func _along(pts: PackedVector2Array, distance: float) -> Vector2:
	var left := distance
	for i in range(1, pts.size()):
		var step := pts[i].distance_to(pts[i - 1])
		if left <= step and step > 0.0:
			return pts[i - 1].lerp(pts[i], left / step)
		left -= step
	return pts[pts.size() - 1]
