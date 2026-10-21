# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends Node2D
## The app icon, drawn with the game's own views on a 432 unit square (Android's adaptive icon
## canvas): a walnut back board, one honey oak plank across it and a big red screw with its
## triangle drive. `part` picks what to draw: "full" (everything), "background" (the walnut),
## "foreground" (plank and screw, inside the adaptive icon's safe circle), or "monochrome" (the
## same shapes as one flat silhouette, for themed icons). tools/art/app_icon.gd renders it.

const CANVAS := 432.0
const CLEAR := preload("res://tools/art/sheets/clear_pixels.gdshader")

var part := "full"
var _planks: Array[PlankView] = []


func _ready() -> void:
	var k := get_viewport_rect().size.x / CANVAS
	scale = Vector2(k, k)
	if part == "full" or part == "background":
		var board := PlankView.new()
		add_child(board)
		board.setup_panel(Rect2(-40, -40, CANVAS + 80, CANVAS + 80), 0.0, 77)
		_planks.append(board)
	if part == "full" or part == "foreground":
		var plank := PlankView.new()
		add_child(plank)
		plank.setup(_gu(_plank_outline()), PackedVector2Array(), 0, _gu(PackedVector2Array([_plank_end()])), 12)
		_planks.append(plank)
		var screw := ScrewView.new()
		screw.setup(0, ScrewView.BOARD)
		screw.position = _screw_center()
		screw.scale = Vector2(4.6, 4.6)
		screw.set_turn(-8.0)
		add_child(screw)
	if part == "monochrome":
		add_child(Mono.new())
	for p: PlankView in _planks:
		p.bake()


static func _gu(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(p / 4.0)
	return out


## The plank: a rounded bar rising to the right through the middle.
static func _plank_outline() -> PackedVector2Array:
	var pts := PlankView.rounded_rect(Rect2(-190, -58, 380, 116), 40.0)
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(Vector2(CANVAS * 0.5, CANVAS * 0.5) + p.rotated(deg_to_rad(-32.0)))
	return out


static func _screw_center() -> Vector2:
	return Vector2(CANVAS * 0.5, CANVAS * 0.5) + Vector2(42, 0).rotated(deg_to_rad(-32.0))


static func _plank_end() -> Vector2:
	return Vector2(CANVAS * 0.5, CANVAS * 0.5) + Vector2(-118, 0).rotated(deg_to_rad(-32.0))


## The silhouette: the plank, a gap around the screw, the head, and its drive cut out.
class Mono extends Node2D:
	func _ready() -> void:
		var layers: Array = [
			[_plank_poly(), false],
			[_circle(_screw(), 64.0 + 10.0), true],
			[_circle(_screw(), 64.0), false],
			[_triangle(_screw(), 34.0), true],
			[_circle(_hole(), 9.0), true],
		]
		for entry: Array in layers:
			var node := Shape.new()
			node.points = entry[0]
			if entry[1]:
				var mat := ShaderMaterial.new()
				mat.shader = CLEAR
				node.material = mat
			add_child(node)

	func _plank_poly() -> PackedVector2Array:
		return get_parent()._plank_outline()

	func _screw() -> Vector2:
		return get_parent()._screw_center()

	func _hole() -> Vector2:
		return get_parent()._plank_end()

	static func _circle(c: Vector2, r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 64:
			pts.append(c + Vector2(cos(TAU * i / 64.0), sin(TAU * i / 64.0)) * r)
		return pts

	static func _triangle(c: Vector2, r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 3:
			var a := -PI / 2.0 + TAU * i / 3.0 + deg_to_rad(-8.0)
			pts.append(c + Vector2(cos(a), sin(a)) * r + Vector2(0, r * 0.12))
		return pts


class Shape extends Node2D:
	var points := PackedVector2Array()

	func _draw() -> void:
		draw_colored_polygon(points, Color.WHITE)
		var loop := points.duplicate()
		loop.append(points[0])
		draw_polyline(loop, Color.WHITE, 1.5, true)
