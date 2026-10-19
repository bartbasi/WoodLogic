# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name DirIcons
extends RefCounted
## Small icons drawn in code: star, pause, undo, extra slot, screwdriver, cup, chevron,
## warning triangle and arrow. `c` is the center, `s` the icon size in units.


static func star_points(c: Vector2, r: float, inner: float = 0.45) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * inner))
	return pts


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var loop := pts.duplicate()
	loop.append(pts[0])
	return loop


## A filled star (earned) or an outline star with a faint inner mark (not earned).
static func star(ci: CanvasItem, c: Vector2, r: float, fill: Color, line: Color, earned: bool, width: float = 2.0) -> void:
	var pts := star_points(c, r)
	if earned:
		ci.draw_colored_polygon(pts, fill)
		ci.draw_polyline(_closed(pts), line, width, true)
	else:
		ci.draw_polyline(_closed(pts), line, width, true)
		ci.draw_polyline(_closed(star_points(c + Vector2(0, r * 0.04), r * 0.42)), Color(line, line.a * 0.45), width * 0.75, true)


static func pause(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var w := s * 0.22
	var h := s * 0.7
	ci.draw_rect(Rect2(c + Vector2(-s * 0.3, -h / 2.0), Vector2(w, h)), color)
	ci.draw_rect(Rect2(c + Vector2(s * 0.08, -h / 2.0), Vector2(w, h)), color)


static func undo(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var r := s * 0.32
	ci.draw_arc(c + Vector2(0, s * 0.06), r, PI * 1.05, PI * 2.25, 20, color, s * 0.11, true)
	var tip := c + Vector2(-r, s * 0.06) + Vector2(-s * 0.02, s * 0.0)
	ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.17, -s * 0.06), tip + Vector2(s * 0.17, -s * 0.06),
		tip + Vector2(0, s * 0.2)]), color)


static func extra_slot(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var w := s * 0.11
	ci.draw_arc(c + Vector2(-s * 0.1, s * 0.04), s * 0.26, 0, TAU, 28, color, w, true)
	var p := c + Vector2(s * 0.27, -s * 0.24)
	ci.draw_rect(Rect2(p - Vector2(s * 0.16, w / 2.0), Vector2(s * 0.32, w)), color)
	ci.draw_rect(Rect2(p - Vector2(w / 2.0, s * 0.16), Vector2(w, s * 0.32)), color)


static func screwdriver(ci: CanvasItem, c: Vector2, s: float, color: Color, accent: Color) -> void:
	var dir := Vector2(1, -1).normalized()
	var n := Vector2(dir.y, -dir.x)
	var a := c - dir * s * 0.42
	var handle_end := c - dir * s * 0.02
	var tip := c + dir * s * 0.42
	var hw := s * 0.13
	ci.draw_colored_polygon(PackedVector2Array([a + n * hw, handle_end + n * hw, handle_end - n * hw, a - n * hw]), accent)
	ci.draw_polyline(_closed(PackedVector2Array([a + n * hw, handle_end + n * hw, handle_end - n * hw, a - n * hw])), color, 1.5, true)
	ci.draw_line(handle_end, tip, color, s * 0.08, true)
	ci.draw_line(tip - dir * s * 0.03 + n * s * 0.06, tip - dir * s * 0.03 - n * s * 0.06, color, s * 0.05, true)


## The cup for Buy me a coffee: a cup with a handle and two curls of steam.
static func cup(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var w := s * 0.07
	var top := c.y - s * 0.08
	var body := PackedVector2Array([Vector2(c.x - s * 0.32, top), Vector2(c.x + s * 0.22, top),
		Vector2(c.x + s * 0.16, c.y + s * 0.34), Vector2(c.x - s * 0.26, c.y + s * 0.34)])
	ci.draw_colored_polygon(body, color)
	ci.draw_arc(Vector2(c.x + s * 0.24, c.y + s * 0.1), s * 0.12, -PI / 2.0, PI / 2.0, 12, color, w, true)
	for i in 2:
		var x := c.x - s * 0.15 + i * s * 0.2
		var steam := PackedVector2Array()
		for j in 7:
			var t := j / 6.0
			steam.append(Vector2(x + sin(t * TAU) * s * 0.05, top - s * 0.06 - t * s * 0.3))
		ci.draw_polyline(steam, color, w * 0.9, true)


static func chevron(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.25, -s * 0.5), c + Vector2(s * 0.25, 0), c + Vector2(-s * 0.25, s * 0.5)]),
		color, maxf(s * 0.22, 1.5), true)


static func arrow_right(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var w := s * 0.16
	ci.draw_line(c + Vector2(-s * 0.4, 0), c + Vector2(s * 0.2, 0), color, w, true)
	ci.draw_polyline(PackedVector2Array([c + Vector2(0, -s * 0.32), c + Vector2(s * 0.36, 0), c + Vector2(0, s * 0.32)]), color, w, true)


static func warning(ci: CanvasItem, c: Vector2, s: float, fill: Color, mark: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -s * 0.46), c + Vector2(s * 0.5, s * 0.4), c + Vector2(-s * 0.5, s * 0.4)])
	ci.draw_colored_polygon(pts, fill)
	ci.draw_polyline(_closed(pts), fill, 1.5, true)
	ci.draw_line(c + Vector2(0, -s * 0.18), c + Vector2(0, s * 0.12), mark, s * 0.1, true)
	ci.draw_circle(c + Vector2(0, s * 0.26), s * 0.06, mark, true, -1.0, true)


## A round "button" check used by star captions and the like.
static func stopwatch(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_arc(c + Vector2(0, s * 0.06), s * 0.36, 0, TAU, 24, color, s * 0.1, true)
	ci.draw_line(c + Vector2(0, s * 0.06), c + Vector2(s * 0.14, -s * 0.12), color, s * 0.09, true)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.46), Vector2(s * 0.2, s * 0.1)), color)
