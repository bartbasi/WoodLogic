# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Icons
extends RefCounted
## Every small icon, drawn in code in one color (docs/ARCHITECTURE.md 11.1). `size` is the side
## of the square the icon fills, in the canvas' units; strokes scale with it and never go below
## 1.6 units. Icons that would need a hole in one color (the gear, the info circle, the house)
## are drawn as outlines, so they read on any plaque. Filled and outline pairs (star and
## star_empty, pip and pip_empty, stopwatch_full and stopwatch) differ in shape, not only in
## color (docs/UX.md 7.4).

const NAMES: Array[String] = [
	"star", "star_empty", "pause", "undo", "extra_slot", "screwdriver", "cup", "chevron", "arrow",
	"warning", "stopwatch", "pip", "hand", "padlock", "check", "speaker", "speaker_off", "note",
	"note_off", "home", "map", "stats", "info", "settings", "about",
	# Beyond the contract's list: the filled forms of the two top bar pips, and the arrow turned
	# for the map's "Go to level" chip.
	"stopwatch_full", "pip_empty", "arrow_up", "arrow_down", "arrow_left",
]


static func has(icon: String) -> bool:
	return NAMES.has(icon)


## Draws one icon centered on `center`. An unknown name logs an error and draws nothing.
static func draw(ci: CanvasItem, icon: String, center: Vector2, size: float, color: Color) -> void:
	var s := size
	var c := center
	var w := maxf(1.6, s * 0.095)
	match icon:
		"star":
			_fill(ci, star_points(c, s * 0.5, 0.45), color)
		"star_empty":
			_loop(ci, star_points(c, s * 0.5 - w * 0.5, 0.45), color, w * 0.8)
			_loop(ci, star_points(c + Vector2(0, s * 0.02), s * 0.19, 0.45), Color(color, color.a * 0.45), maxf(1.0, w * 0.5))
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.27, -s * 0.32), Vector2(s * 0.19, s * 0.64)), color)
			ci.draw_rect(Rect2(c + Vector2(s * 0.08, -s * 0.32), Vector2(s * 0.19, s * 0.64)), color)
		"undo":
			var o := c + Vector2(s * 0.06, s * 0.06)
			var r := s * 0.3
			ci.draw_arc(o, r, deg_to_rad(-90.0), deg_to_rad(150.0), 24, color, w, true)
			var tip := o + Vector2(0, -r)
			_fill(ci, PackedVector2Array([tip + Vector2(-s * 0.2, 0), tip + Vector2(s * 0.03, -s * 0.17), tip + Vector2(s * 0.03, s * 0.17)]), color)
		"extra_slot":
			# The tray with two slots filled and a plus where one more slot opens.
			_round_rect(ci, Rect2(c + Vector2(-s * 0.46, -s * 0.2), Vector2(s * 0.92, s * 0.44)), s * 0.14, color, false, w * 0.85)
			for i in 2:
				ci.draw_circle(c + Vector2((-0.27 + i * 0.25) * s, s * 0.02), s * 0.085, color, true, -1.0, true)
			var p := c + Vector2(s * 0.25, s * 0.02)
			ci.draw_line(p - Vector2(s * 0.12, 0), p + Vector2(s * 0.12, 0), color, w, true)
			ci.draw_line(p - Vector2(0, s * 0.12), p + Vector2(0, s * 0.12), color, w, true)
		"screwdriver":
			var d := Vector2(1, -1).normalized()
			var n := Vector2(-d.y, d.x)
			var a := c - d * s * 0.44
			var b := c - d * s * 0.06
			_capsule(ci, a, b, s * 0.13, color)
			ci.draw_line(b, c + d * s * 0.02, color, s * 0.15, true)
			var tip := c + d * s * 0.42
			ci.draw_line(c, tip, color, maxf(1.6, s * 0.08), true)
			ci.draw_line(tip + n * s * 0.06, tip - n * s * 0.06, color, maxf(1.4, s * 0.06), true)
		"cup":
			_cup(ci, c, s, color, w)
		"chevron":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.14, -s * 0.32), c + Vector2(s * 0.16, 0), c + Vector2(-s * 0.14, s * 0.32)]), color, w * 1.2, true)
		"arrow":
			_arrow(ci, c, s, Vector2.RIGHT, color, w)
		"arrow_up":
			_arrow(ci, c, s, Vector2.UP, color, w)
		"arrow_down":
			_arrow(ci, c, s, Vector2.DOWN, color, w)
		"arrow_left":
			_arrow(ci, c, s, Vector2.LEFT, color, w)
		"warning":
			var tri := PackedVector2Array([c + Vector2(0, -s * 0.42), c + Vector2(s * 0.47, s * 0.38), c + Vector2(-s * 0.47, s * 0.38)])
			_loop(ci, tri, color, w)
			ci.draw_line(c + Vector2(0, -s * 0.14), c + Vector2(0, s * 0.12), color, w * 1.1, true)
			ci.draw_circle(c + Vector2(0, s * 0.25), w * 0.65, color, true, -1.0, true)
		"stopwatch":
			var o := c + Vector2(0, s * 0.07)
			ci.draw_arc(o, s * 0.34, 0.0, TAU, 32, color, w, true)
			ci.draw_line(o, o + Vector2(s * 0.12, -s * 0.15), color, w, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.09, -s * 0.47), Vector2(s * 0.18, s * 0.1)), color)
		"stopwatch_full":
			# A filled face with the hand in a contrasting shade of the same color, so it still
			# reads as a stopwatch (not a ball) while differing in shape from the outline form.
			var o := c + Vector2(0, s * 0.07)
			ci.draw_circle(o, s * 0.37, color, true, -1.0, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.09, -s * 0.47), Vector2(s * 0.18, s * 0.1)), color)
			ci.draw_line(c + Vector2(s * 0.2, -s * 0.33), c + Vector2(s * 0.29, -s * 0.24), color, w, true)
			var hand := color.darkened(0.6) if Palette.luminance(color) > 0.3 else color.lightened(0.6)
			ci.draw_line(o, o + Vector2(s * 0.12, -s * 0.17), hand, w, true)
			ci.draw_circle(o, w * 0.6, hand, true, -1.0, true)
		"pip":
			_round_rect(ci, Rect2(c + Vector2(-s * 0.42, -s * 0.22), Vector2(s * 0.84, s * 0.44)), s * 0.12, color, true, w)
		"pip_empty":
			_round_rect(ci, Rect2(c + Vector2(-s * 0.42, -s * 0.22), Vector2(s * 0.84, s * 0.44)), s * 0.12, color, false, w * 0.9)
		"hand":
			_hand(ci, c, s, color)
		"padlock":
			ci.draw_arc(c + Vector2(0, -s * 0.1), s * 0.2, PI, TAU, 16, color, w * 1.1, true)
			ci.draw_line(c + Vector2(-s * 0.2, -s * 0.1), c + Vector2(-s * 0.2, s * 0.0), color, w * 1.1, true)
			ci.draw_line(c + Vector2(s * 0.2, -s * 0.1), c + Vector2(s * 0.2, s * 0.0), color, w * 1.1, true)
			_round_rect(ci, Rect2(c + Vector2(-s * 0.32, -s * 0.04), Vector2(s * 0.64, s * 0.46)), s * 0.08, color, true, w)
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.32, s * 0.02), c + Vector2(-s * 0.1, s * 0.25), c + Vector2(s * 0.34, -s * 0.26)]), color, w * 1.35, true)
		"speaker":
			_speaker(ci, c, s, color)
			for r: float in [0.18, 0.32]:
				ci.draw_arc(c + Vector2(s * 0.06, 0), s * r, deg_to_rad(-48.0), deg_to_rad(48.0), 12, color, w * 0.85, true)
		"speaker_off":
			_speaker(ci, c + Vector2(-s * 0.04, 0), s, color)
			_slash(ci, c, s, color, w)
		"note":
			_note(ci, c, s, color, w)
		"note_off":
			_note(ci, c, s, color, w)
			_slash(ci, c, s, color, w)
		"home":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.44, s * 0.02), c + Vector2(0, -s * 0.4), c + Vector2(s * 0.44, s * 0.02)]), color, w, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.29, -s * 0.08), c + Vector2(-s * 0.29, s * 0.4), c + Vector2(s * 0.29, s * 0.4), c + Vector2(s * 0.29, -s * 0.08)]), color, w, true)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.08, s * 0.14), Vector2(s * 0.16, s * 0.26)), color)
		"map":
			var dots: Array[Vector2] = [Vector2(-0.3, 0.36), Vector2(0.06, 0.22), Vector2(-0.18, 0.0), Vector2(0.16, -0.16)]
			for i in dots.size():
				ci.draw_circle(c + dots[i] * s, s * (0.065 + 0.012 * i), color, true, -1.0, true)
			var pole := c + Vector2(0.16, -0.16) * s
			ci.draw_line(pole, pole + Vector2(0, -s * 0.3), color, maxf(1.4, w * 0.7), true)
			_fill(ci, PackedVector2Array([pole + Vector2(0, -s * 0.3), pole + Vector2(s * 0.26, -s * 0.23), pole + Vector2(0, -s * 0.15)]), color)
		"stats":
			var base := c.y + s * 0.36
			var heights: Array[float] = [0.3, 0.54, 0.76]
			for i in 3:
				var x := c.x + (i - 1) * s * 0.27
				ci.draw_rect(Rect2(Vector2(x - s * 0.09, base - heights[i] * s), Vector2(s * 0.18, heights[i] * s)), color)
			ci.draw_line(Vector2(c.x - s * 0.44, base + w * 0.5), Vector2(c.x + s * 0.44, base + w * 0.5), color, w * 0.8, true)
		"info":
			ci.draw_arc(c, s * 0.42, 0.0, TAU, 36, color, w, true)
			ci.draw_circle(c + Vector2(0, -s * 0.19), w * 0.75, color, true, -1.0, true)
			ci.draw_line(c + Vector2(0, -s * 0.05), c + Vector2(0, s * 0.24), color, w * 1.2, true)
		"settings":
			_gear(ci, c, s, color, w)
		"about":
			# A screw head: the rim, the cap, and a cross drive standing upright.
			ci.draw_arc(c, s * 0.42, 0.0, TAU, 36, color, w, true)
			ci.draw_arc(c, s * 0.27, 0.0, TAU, 28, Color(color, color.a * 0.55), maxf(1.0, w * 0.6), true)
			ci.draw_line(c + Vector2(-s * 0.17, 0), c + Vector2(s * 0.17, 0), color, w * 1.2, true)
			ci.draw_line(c + Vector2(0, -s * 0.17), c + Vector2(0, s * 0.17), color, w * 1.2, true)
		_:
			push_error("Icons: unknown icon '%s'" % icon)


## Five point star outline points, one point up.
static func star_points(c: Vector2, r: float, inner: float = 0.45) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * inner) + Vector2(0, r * 0.06))
	return pts


static func _fill(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	ci.draw_colored_polygon(pts, color)
	_loop(ci, pts, color, 1.0)


static func _loop(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, color, width, true)


static func _capsule(ci: CanvasItem, a: Vector2, b: Vector2, r: float, color: Color) -> void:
	ci.draw_line(a, b, color, r * 2.0, true)
	ci.draw_circle(a, r, color, true, -1.0, true)
	ci.draw_circle(b, r, color, true, -1.0, true)


static func _round_rect(ci: CanvasItem, rect: Rect2, radius: float, color: Color, filled: bool, width: float) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners: Array[Vector2] = [rect.position + Vector2(r, r), Vector2(rect.end.x - r, rect.position.y + r),
		rect.end - Vector2(r, r), Vector2(rect.position.x + r, rect.end.y - r)]
	for k in 4:
		for j in 7:
			var a := PI + k * PI / 2.0 + j * (PI / 2.0) / 6.0
			pts.append(corners[k] + Vector2(cos(a), sin(a)) * r)
	if filled:
		_fill(ci, pts, color)
	else:
		_loop(ci, pts, color, width)


static func _arrow(ci: CanvasItem, c: Vector2, s: float, dir: Vector2, color: Color, w: float) -> void:
	var n := Vector2(-dir.y, dir.x)
	ci.draw_line(c - dir * s * 0.36, c + dir * s * 0.26, color, w * 1.2, true)
	ci.draw_polyline(PackedVector2Array([c + dir * s * 0.02 + n * s * 0.3, c + dir * s * 0.36, c + dir * s * 0.02 - n * s * 0.3]), color, w * 1.2, true)


static func _cup(ci: CanvasItem, c: Vector2, s: float, color: Color, w: float) -> void:
	var top := c.y - s * 0.04
	var body := PackedVector2Array([Vector2(c.x - s * 0.34, top), Vector2(c.x + s * 0.2, top),
		Vector2(c.x + s * 0.14, c.y + s * 0.36), Vector2(c.x - s * 0.28, c.y + s * 0.36)])
	_fill(ci, body, color)
	ci.draw_arc(Vector2(c.x + s * 0.22, c.y + s * 0.13), s * 0.12, -PI / 2.0, PI / 2.0, 12, color, w * 0.85, true)
	ci.draw_line(Vector2(c.x - s * 0.42, c.y + s * 0.44), Vector2(c.x + s * 0.28, c.y + s * 0.44), color, w * 0.8, true)
	for i in 2:
		var x := c.x - s * 0.17 + i * s * 0.2
		var steam := PackedVector2Array()
		for j in 7:
			var t := j / 6.0
			steam.append(Vector2(x + sin(t * TAU) * s * 0.05, top - s * 0.08 - t * s * 0.32))
		ci.draw_polyline(steam, color, w * 0.75, true)


static func _speaker(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	_fill(ci, PackedVector2Array([c + Vector2(-0.4, -0.12) * s, c + Vector2(-0.2, -0.12) * s, c + Vector2(0.02, -0.34) * s,
		c + Vector2(0.02, 0.34) * s, c + Vector2(-0.2, 0.12) * s, c + Vector2(-0.4, 0.12) * s]), color)


static func _note(ci: CanvasItem, c: Vector2, s: float, color: Color, w: float) -> void:
	var head := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		head.append(c + Vector2(-0.12, 0.26) * s + Vector2(cos(a) * 0.16, sin(a) * 0.11).rotated(-0.4) * s)
	_fill(ci, head, color)
	var stem_x := c.x + s * 0.025
	ci.draw_line(Vector2(stem_x, c.y + s * 0.24), Vector2(stem_x, c.y - s * 0.4), color, w, true)
	ci.draw_polyline(PackedVector2Array([Vector2(stem_x, c.y - s * 0.4), Vector2(stem_x + s * 0.16, c.y - s * 0.28),
		Vector2(stem_x + s * 0.26, c.y - s * 0.12), Vector2(stem_x + s * 0.2, c.y + s * 0.02)]), color, w, true)


static func _slash(ci: CanvasItem, c: Vector2, s: float, color: Color, w: float) -> void:
	ci.draw_line(c + Vector2(-0.42, -0.42) * s, c + Vector2(0.42, 0.42) * s, color, w * 1.1, true)


static func _gear(ci: CanvasItem, c: Vector2, s: float, color: Color, w: float) -> void:
	var teeth := 8
	var outer := s * 0.44
	var root := s * 0.33
	var pts := PackedVector2Array()
	for i in teeth:
		var a0 := TAU * i / teeth
		var step := TAU / teeth
		pts.append(c + Vector2(cos(a0 - step * 0.28), sin(a0 - step * 0.28)) * root)
		pts.append(c + Vector2(cos(a0 - step * 0.16), sin(a0 - step * 0.16)) * outer)
		pts.append(c + Vector2(cos(a0 + step * 0.16), sin(a0 + step * 0.16)) * outer)
		pts.append(c + Vector2(cos(a0 + step * 0.28), sin(a0 + step * 0.28)) * root)
	_loop(ci, pts, color, w * 0.9)
	ci.draw_arc(c, s * 0.14, 0.0, TAU, 20, color, w * 0.9, true)


static func _hand(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	# A hand pointing up with its index finger, for the tutorial hint.
	_capsule(ci, c + Vector2(0.02, -0.4) * s, c + Vector2(0.02, 0.02) * s, s * 0.09, color)
	for k in 3:
		var x := 0.15 + k * 0.1
		_capsule(ci, c + Vector2(x, -0.06 + k * 0.03) * s, c + Vector2(x, 0.12) * s, s * 0.06, color)
	_round_rect(ci, Rect2(c + Vector2(-0.12, -0.02) * s, Vector2(0.42, 0.42) * s), s * 0.12, color, true, 1.0)
	_capsule(ci, c + Vector2(-0.14, 0.2) * s, c + Vector2(-0.33, 0.0) * s, s * 0.075, color)
