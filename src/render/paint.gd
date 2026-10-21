# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Paint
extends RefCounted
## Small drawing helpers the box, tray, map and effect views share: rounded panels (StyleBoxFlat,
## antialiased, with an optional border and soft shadow) and the neutral hollow of an empty well.


static func panel(ci: CanvasItem, rect: Rect2, fill: Color, radius: float = 8.0, border: Color = Color(0, 0, 0, 0),
		border_w: int = 0, shadow: Color = Color(0, 0, 0, 0), shadow_size: int = 0, shadow_off: Vector2 = Vector2.ZERO) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(round(radius)))
	sb.corner_detail = 8
	sb.anti_aliasing = true
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	if shadow_size > 0:
		sb.shadow_color = shadow
		sb.shadow_size = shadow_size
		sb.shadow_offset = shadow_off
	ci.draw_style_box(sb, rect)


## An empty well or slot: a hollow lit from above, so its upper inside wall is in shadow and its
## lower lip catches the light. Always a neutral color, never the box's, so it can't be read as
## a screw (DESIGN.md 7).
static func well(ci: CanvasItem, c: Vector2, r: float, base: Color) -> void:
	ci.draw_circle(c, r, base, true, -1.0, true)
	ci.draw_arc(c, r - 1.6, PI * 1.02, PI * 1.98, 16, Color(0, 0, 0, 0.32), 3.2, true)
	ci.draw_arc(c, r - 0.7, PI * 0.12, PI * 0.88, 16, Color(1, 1, 1, 0.3), 1.4, true)


## A few faint grain strokes across a wooden rect, so flat panels still read as wood.
static func grain_lines(ci: CanvasItem, rect: Rect2, color: Color, seed_value: int, count: int = 5) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var y := rect.position.y + rect.size.y * (i + 0.5) / count + rng.randf_range(-2.0, 2.0)
		var pts := PackedVector2Array()
		var steps := 6
		for j in steps + 1:
			var x := rect.position.x + 3.0 + (rect.size.x - 6.0) * j / steps
			pts.append(Vector2(x, y + sin(j * 1.3 + i + seed_value) * 1.2))
		ci.draw_polyline(pts, color, 1.0, true)
