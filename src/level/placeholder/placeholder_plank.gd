# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name PlaceholderPlank
extends Node2D
## The placeholder plank: a flat polygon in a wood color picked by its layer, with a darker rim
## and a dark disc at each hole. Same setup and methods as docs/ARCHITECTURE.md 7's PlankView.
## It draws in board design units (grid units times four) from the board's origin; the parent
## places and rotates it (the level scene turns it about the hanging screw). The wiggle turns an
## inner body, so it adds to whatever pose the parent has set.

const LAYER_COLORS: Array[Color] = [
	Color("f2cd8f"), Color("dfb072"), Color("c68f50"), Color("a97537"), Color("8a5a2a"),
]
const RIM := Color("6e4421")
const HOLE := Color("2a190d")
const GU := 4.0

var _body: Body
var _center := Vector2.ZERO
var _tween: Tween
var _layer := 0


## What actually draws: kept apart so the wiggle can turn it without touching the parent's pose.
class Body extends Node2D:
	var faces: Array[PackedVector2Array] = []
	var rims: Array[PackedVector2Array] = []
	var holes := PackedVector2Array()
	var fill := Color.WHITE
	## Where the shadow falls from this plank, in its own frame: down and right on the screen
	## whatever the plank's turn (DESIGN.md 8).
	var shadow_offset := Vector2(3.0, 4.0)

	func _draw() -> void:
		draw_set_transform(shadow_offset, 0.0, Vector2.ONE)
		for face: PackedVector2Array in faces:
			draw_colored_polygon(face, Color(0.1, 0.05, 0.02, 0.5))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for face: PackedVector2Array in faces:
			draw_colored_polygon(face, fill)
		for rim: PackedVector2Array in rims:
			draw_polyline(rim, PlaceholderPlank.RIM, 2.4, true)
		for h: Vector2 in holes:
			draw_circle(h, 5.0, PlaceholderPlank.HOLE)
			draw_arc(h, 5.0, 0.0, TAU, 16, Color(0.0, 0.0, 0.0, 0.5), 1.0)


func _ready() -> void:
	set_notify_local_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and _body != null:
		_update_shadow()


func _update_shadow() -> void:
	var reach := 1.0 + 0.25 * (4 - _layer)
	var off := transform.basis_xform_inv(Vector2(3.0, 4.2) * reach)
	if not off.is_equal_approx(_body.shadow_offset):
		_body.shadow_offset = off
		_body.queue_redraw()


func setup(outline_gu: PackedVector2Array, inner_gu: PackedVector2Array, layer: int, holes_gu: PackedVector2Array, grain_seed: int) -> void:
	if _body == null:
		_body = Body.new()
		add_child(_body)
	_layer = clampi(layer, 0, 4)
	var outer := _scaled(outline_gu)
	var inner := _scaled(inner_gu)
	_body.faces.clear()
	_body.rims.clear()
	if inner.size() >= 3:
		_body.faces.append(_annulus(outer, inner))
		_body.rims.append(_closed(inner))
	else:
		_body.faces.append(outer)
	_body.rims.append(_closed(outer))
	_body.holes = _scaled(holes_gu)
	var tone := 1.0 + (posmod(grain_seed, 7) - 3) * 0.008
	_body.fill = Color(LAYER_COLORS[clampi(layer, 0, 4)] * tone, 1.0)
	_center = _average(outer)
	_update_shadow()
	_body.queue_redraw()


## The covered-tap wiggle: plus and minus 3 degrees, two cycles, 220 ms (UX 6.1).
func wiggle() -> void:
	if _body == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_wiggle_step, 0.0, 1.0, 0.22)


func _wiggle_step(p: float) -> void:
	var a := deg_to_rad(3.0) * sin(p * TAU * 2.0) * (1.0 - p)
	_body.rotation = a
	_body.position = _center - _center.rotated(a)


static func _scaled(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i: int in points.size():
		out[i] = points[i] * GU
	return out


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out


static func _average(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p: Vector2 in points:
		sum += p
	return sum / maxf(1.0, points.size())


## A ring as one polygon: the outer outline with a hairline slit cut to the hole, so one fill
## draws it and the hole stays open.
static func _annulus(outer: PackedVector2Array, inner: PackedVector2Array) -> PackedVector2Array:
	var c := _average(inner)
	var reach := 0.0
	for p: Vector2 in outer:
		reach = maxf(reach, p.distance_to(c))
	var slit := PackedVector2Array([c + Vector2(0.0, -0.4), c + Vector2(reach + 8.0, -0.4), c + Vector2(reach + 8.0, 0.4), c + Vector2(0.0, 0.4)])
	var merged := Geometry2D.merge_polygons(inner, slit)
	if merged.size() == 1:
		var cut := Geometry2D.clip_polygons(outer, merged[0])
		if cut.size() == 1:
			return cut[0]
	return outer
