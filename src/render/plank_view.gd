# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name PlankView
extends Node2D
## One plank (docs/ARCHITECTURE.md 7, docs/DESIGN.md 7, 8 and 10). It draws in board design
## units (grid units times four) from the board's origin; the parent places and rotates it.
## `bake()` draws the still plank once into two small textures (the face, and the shape: bevel,
## rim and shadow silhouette); after that a frame costs one quad with seven texture samples a
## pixel. Until it is baked it draws a plain stand-in with the same outline, edge and shadow, so
## it is never invisible. The wiggle turns an inner body, so it adds to the parent's pose.

signal baked

const GU := 4.0
const BAKE_SHADER := preload("res://src/render/shaders/plank_bake.gdshader")
const RUN_SHADER := preload("res://src/render/shaders/plank.gdshader")

## The look (DESIGN.md 7 and 8), in design units.
const THICKNESS := 7.0
const EDGE_DIR := Vector2(0.3, 1.0)
const SHADOW := Vector2(5.0, 8.0)
## How much longer the shadow is for each layer nearer the front (layer 4 is the back).
const SHADOW_STEP := 0.25
const SHADOW_BLUR := 6.0
## Each layer further back is this much darker (layer 4, the back, by 14 percent).
const LAYER_TONE := 0.035
const SHADOW_ALPHA := 0.55
const LIGHT := Vector2(-0.55, -0.83)
const BEVEL := 4.5
const BEVEL_STRENGTH := 1.5
const HOLE_RADIUS := 6.0
## The outline is simplified to within this many design units before it goes to the shader.
const OUTLINE_TOLERANCE := 0.3
const MAX_OUTER := 128
const MAX_INNER := 64
const MAX_HOLES := 8
## Texture size limits: at most this many texels a side, and at most 3 texels a design unit.
const MAX_TEXELS := 1024
const MAX_TEXELS_PER_UNIT := 3.0
## The covered-tap wiggle (DESIGN.md 9).
const WIGGLE_DEGREES := 2.5
const WIGGLE_SECONDS := 0.24

var _body: Body
var _outer := PackedVector2Array()
var _inner := PackedVector2Array()
var _holes := PackedVector2Array()
var _layer := 0
var _seed := 0
var _center := Vector2.ZERO
var _area := Rect2()
var _wood: Dictionary = {}
var _style: Dictionary = {}
var _bake_mats: Array[ShaderMaterial] = []
var _viewports: Array[SubViewport] = []
var _run_mat: ShaderMaterial
var _is_baked := false
var _bake_wanted := false
var _generation := 0
var _tween: Tween
var _shadow_amount := 1.0
## Frames left until a bake in progress is done; -1 when none is.
var _bake_frames := -1


## What draws. Kept apart from the view so the wiggle can turn it without touching the pose.
class Body extends Node2D:
	var view: PlankView

	func _draw() -> void:
		view._draw_body(self)


func _init() -> void:
	_body = Body.new()
	_body.view = self
	add_child(_body)


func _ready() -> void:
	set_notify_local_transform(true)
	# Also when a parent turns it (a windmill's sails), so the light and edge stay screen fixed.
	set_notify_transform(true)
	_update_vectors()
	if _bake_wanted:
		bake()


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED or what == NOTIFICATION_TRANSFORM_CHANGED:
		_update_vectors()


## A plank from the logic: its outline (and a ring's hole) in grid units from the board origin,
## its layer (0 is the front), its screw holes, and a seed for its grain.
func setup(outline_gu: PackedVector2Array, inner_gu: PackedVector2Array, layer: int, holes_gu: PackedVector2Array, grain_seed: int) -> void:
	var holes := PackedVector2Array()
	for h: Vector2 in holes_gu:
		holes.append(h * GU)
	var shadow_scale := 1.0 + SHADOW_STEP * (4 - clampi(layer, 0, 4))
	_configure(_scaled(outline_gu), _scaled(inner_gu), holes, layer, grain_seed, Looks.current_wood(), {
		"thickness": THICKNESS, "shadow": SHADOW * shadow_scale, "shadow_blur": SHADOW_BLUR, "shadow_alpha": SHADOW_ALPHA,
		"bevel": BEVEL, "bevel_strength": BEVEL_STRENGTH, "layer_tone": LAYER_TONE})


## A back board panel for BoardView: a rounded rectangle in design units, in the theme's board
## wood, with a thicker edge and a long soft shadow on the wall.
func setup_panel(rect: Rect2, corner: float, grain_seed: int) -> void:
	var w := Looks.current_wood()
	var board := {"wood_light": w["board_light"], "wood_dark": w["board_dark"], "edge_color": w["board_edge"],
		"ring_freq": w.get("board_ring_freq", 0.07), "ring_contrast": w.get("board_ring_contrast", 0.55),
		"figure": w.get("board_figure", 18.0), "fiber": w.get("board_fiber", 0.45), "pores": w.get("board_pores", 0.1)}
	_configure(rounded_rect(rect, corner), PackedVector2Array(), PackedVector2Array(), 4, grain_seed, board, {
		"thickness": 10.0, "shadow": Vector2(4.0, 12.0), "shadow_blur": 16.0, "shadow_alpha": 0.7,
		"bevel": 6.0, "bevel_strength": 1.5})


func is_baked() -> bool:
	return _is_baked


## Draws the still plank into its textures. Takes effect after the next drawn frame (the
## `baked` signal); until then the stand-in shows. Call it while the board is hidden.
func bake() -> void:
	_bake_wanted = true
	if not is_inside_tree() or _outer.size() < 3:
		return
	_bake_wanted = false
	_generation += 1
	_free_bake()
	var texel := 1.0 / clampf(_pixels_per_unit(), 1.0, MAX_TEXELS_PER_UNIT)
	texel = maxf(texel, maxf(_area.size.x, _area.size.y) / MAX_TEXELS)
	var size := Vector2i(ceili(_area.size.x / texel), ceili(_area.size.y / texel))
	for pass_index in 2:
		var vp := SubViewport.new()
		vp.size = size
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var mat := _make_bake_material(pass_index, texel)
		var canvas := _BakeCanvas.new()
		canvas.size = Vector2(size)
		canvas.material = mat
		vp.add_child(canvas)
		add_child(vp)
		_viewports.append(vp)
		_bake_mats.append(mat)
	# The viewports draw in this frame's draw; two frames on they are done. Counted in _process
	# rather than awaited, so a plank freed or taken out of the tree mid-bake simply stops.
	_bake_frames = 1
	set_process(true)


func _process(_delta: float) -> void:
	if _bake_frames < 0:
		set_process(false)
		return
	_bake_frames -= 1
	if _bake_frames < 0:
		set_process(false)
		_finish_bake()


func _finish_bake() -> void:
	if _viewports.size() < 2 or not is_inside_tree():
		return
	for vp: SubViewport in _viewports:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_run_mat = ShaderMaterial.new()
	_run_mat.shader = RUN_SHADER
	_run_mat.set_shader_parameter("face_tex", _viewports[0].get_texture())
	_run_mat.set_shader_parameter("shape_tex", _viewports[1].get_texture())
	_run_mat.set_shader_parameter("area", Vector4(_area.position.x, _area.position.y, _area.size.x, _area.size.y))
	_run_mat.set_shader_parameter("shadow_alpha", float(_style["shadow_alpha"]) * _shadow_amount)
	_run_mat.set_shader_parameter("shadow_color", Tokens.SHADOW)
	_run_mat.set_shader_parameter("edge_color", _wood["edge_color"])
	# Planks further back sit a little darker, so overlapping planks of one wood still part.
	_run_mat.set_shader_parameter("tone", _tone() * (1.0 - float(_style.get("layer_tone", 0.0)) * _layer))
	_body.material = _run_mat
	_is_baked = true
	_update_vectors()
	_body.queue_redraw()
	baked.emit()


## How much of its shadow the plank casts, 0 to 1: a falling plank's shadow fades out over its
## first 200 ms as it leaves the board (DESIGN.md 8).
func set_shadow(amount: float) -> void:
	_shadow_amount = clampf(amount, 0.0, 1.0)
	if _run_mat != null:
		_run_mat.set_shader_parameter("shadow_alpha", float(_style["shadow_alpha"]) * _shadow_amount)
	else:
		_body.queue_redraw()


## The covered-tap wiggle: plus and minus 2.5 degrees about the plank's middle, three half
## swings dying away over 240 ms (DESIGN.md 9).
func wiggle() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		return
	_tween = create_tween()
	_tween.tween_method(_wiggle_step, 0.0, 1.0, WIGGLE_SECONDS)


func _wiggle_step(p: float) -> void:
	var a := deg_to_rad(WIGGLE_DEGREES) * sin(p * PI * 3.0) * (1.0 - p)
	_body.rotation = a
	_body.position = _center - _center.rotated(a)
	_update_vectors()


func _configure(outer: PackedVector2Array, inner: PackedVector2Array, holes: PackedVector2Array, layer: int, grain_seed: int, wood: Dictionary, style: Dictionary) -> void:
	_generation += 1
	_free_bake()
	_is_baked = false
	_body.material = null
	_outer = simplify(outer, OUTLINE_TOLERANCE, MAX_OUTER)
	_inner = simplify(inner, OUTLINE_TOLERANCE, MAX_INNER) if inner.size() >= 3 else PackedVector2Array()
	_holes = holes.slice(0, MAX_HOLES)
	_layer = layer
	_seed = grain_seed
	_wood = wood
	_style = style
	var box := _bounds(_outer)
	_center = box.get_center()
	var shadow: Vector2 = style["shadow"]
	var margin := float(style["thickness"]) + shadow.length() + float(style["shadow_blur"]) * 2.0 + 2.0
	_area = box.grow(margin)
	_update_vectors()
	_body.queue_redraw()


func _make_bake_material(pass_index: int, texel: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = BAKE_SHADER
	mat.set_shader_parameter("pass_index", pass_index)
	mat.set_shader_parameter("area", Vector4(_area.position.x, _area.position.y, _area.size.x, _area.size.y))
	mat.set_shader_parameter("texel", texel)
	mat.set_shader_parameter("outer", _padded(_outer, MAX_OUTER))
	mat.set_shader_parameter("outer_count", _outer.size())
	mat.set_shader_parameter("inner", _padded(_inner, MAX_INNER))
	mat.set_shader_parameter("inner_count", _inner.size())
	var holes: Array[Vector3] = []
	for h: Vector2 in _holes:
		holes.append(Vector3(h.x, h.y, HOLE_RADIUS))
	while holes.size() < MAX_HOLES:
		holes.append(Vector3(0, 0, -1000))
	mat.set_shader_parameter("holes", holes)
	mat.set_shader_parameter("hole_count", _holes.size())
	mat.set_shader_parameter("bevel", float(_style["bevel"]))
	mat.set_shader_parameter("bevel_strength", float(_style["bevel_strength"]))
	mat.set_shader_parameter("shadow_blur", float(_style["shadow_blur"]))
	mat.set_shader_parameter("noise_tex", WoodNoise.texture())
	for key: String in ["wood_light", "wood_dark", "ring_freq", "ring_contrast", "figure", "fiber", "pores"]:
		if _wood.has(key):
			mat.set_shader_parameter(key, _wood[key])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_seed)
	mat.set_shader_parameter("seed", rng.randf_range(0.0, 50.0))
	mat.set_shader_parameter("grain_angle", _grain_angle(rng))
	var reach := maxf(_area.size.x, _area.size.y) * 0.25
	mat.set_shader_parameter("pith", rng.randf_range(-reach, reach))
	mat.set_shader_parameter("tone", 1.0)
	return mat


## Each plank a little lighter or darker than the next (within 3 percent).
func _tone() -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_seed * 31 + 7)
	return 1.0 + rng.randf_range(-0.03, 0.03)


## The grain runs along the plank's longest direction (its principal axis), with a little drift.
func _grain_angle(rng: RandomNumberGenerator) -> float:
	var sxx := 0.0
	var syy := 0.0
	var sxy := 0.0
	for p: Vector2 in _outer:
		var d := p - _center
		sxx += d.x * d.x
		syy += d.y * d.y
		sxy += d.x * d.y
	var spread := sqrt(maxf((sxx - syy) * (sxx - syy) + 4.0 * sxy * sxy, 0.0))
	if spread < 0.15 * (sxx + syy):
		return rng.randf_range(-PI, PI)
	return 0.5 * atan2(2.0 * sxy, sxx - syy) + rng.randf_range(-0.04, 0.04)


## Screen space light, edge and shadow, turned into the plank's own frame.
func _update_vectors() -> void:
	if _style.is_empty():
		return
	var rot := _body.global_rotation if _body.is_inside_tree() else rotation + _body.rotation
	var depth := EDGE_DIR.normalized() * float(_style["thickness"])
	var shadow: Vector2 = _style["shadow"]
	if _run_mat != null:
		_run_mat.set_shader_parameter("depth_vec", depth.rotated(-rot))
		_run_mat.set_shader_parameter("shadow_vec", shadow.rotated(-rot))
		_run_mat.set_shader_parameter("light_local", LIGHT.normalized().rotated(-rot))
	elif _body.is_inside_tree():
		_body.queue_redraw()


func _pixels_per_unit() -> float:
	var s := _body.get_global_transform_with_canvas().get_scale()
	var f := get_viewport().get_final_transform().get_scale() if get_viewport() != null else Vector2.ONE
	return maxf(absf(s.x * f.x), absf(s.y * f.y))


func _free_bake() -> void:
	for vp: SubViewport in _viewports:
		if is_instance_valid(vp):
			vp.queue_free()
	_viewports.clear()
	_bake_mats.clear()
	_run_mat = null
	_bake_frames = -1


## The stand-in before the bake: flat face, edge and shadow, with the same outline and holes.
func _draw_body(ci: CanvasItem) -> void:
	if _outer.size() < 3:
		return
	if _is_baked:
		ci.draw_rect(_area, Color.WHITE)
		return
	var rot := rotation + _body.rotation
	var shadow: Vector2 = Vector2(_style["shadow"]).rotated(-rot)
	var depth := (EDGE_DIR.normalized() * float(_style["thickness"])).rotated(-rot)
	var face: Color = _wood["wood_light"]
	ci.draw_set_transform(shadow)
	ci.draw_colored_polygon(_outer, Color(Tokens.SHADOW, float(_style["shadow_alpha"]) * 0.8 * _shadow_amount))
	for k in range(4, 0, -1):
		ci.draw_set_transform(depth * (k / 4.0))
		ci.draw_colored_polygon(_outer, _wood["edge_color"])
	ci.draw_set_transform(Vector2.ZERO)
	ci.draw_colored_polygon(_outer, Color(face, 1.0))
	var loop := _outer.duplicate()
	loop.append(_outer[0])
	ci.draw_polyline(loop, Color(face.lightened(0.15), 1.0), 1.2, true)
	if _inner.size() >= 3:
		ci.draw_colored_polygon(_inner, Tokens.SHADOW)
	for h: Vector2 in _holes:
		ci.draw_circle(h, HOLE_RADIUS, Tokens.SHADOW, true, -1.0, true)


## Draws the bake quad, one texel per pixel of its viewport.
class _BakeCanvas extends Node2D:
	var size := Vector2.ONE

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


static func _scaled(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in points.size():
		out[i] = points[i] * GU
	return out


static func _padded(points: PackedVector2Array, n: int) -> PackedVector2Array:
	var out := points.slice(0, n)
	out.resize(n)
	return out


static func _bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var r := Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		r = r.expand(p)
	return r


## A rounded rectangle as a polygon (8 points a corner).
static func rounded_rect(rect: Rect2, corner: float) -> PackedVector2Array:
	var r := minf(corner, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var centers: Array[Vector2] = [rect.position + Vector2(r, r), Vector2(rect.end.x - r, rect.position.y + r),
		rect.end - Vector2(r, r), Vector2(rect.position.x + r, rect.end.y - r)]
	for k in 4:
		for j in 8:
			var a := PI + k * PI / 2.0 + j * (PI / 2.0) / 7.0
			pts.append(centers[k] + Vector2(cos(a), sin(a)) * r)
	return pts


## Drops points that lie within `tolerance` of the line through their neighbors, then, if the
## outline still has more than `max_points`, keeps loosening until it fits.
static func simplify(points: PackedVector2Array, tolerance: float, max_points: int) -> PackedVector2Array:
	var out := points.duplicate()
	var tol := tolerance
	while true:
		var changed := true
		while changed and out.size() > 3:
			changed = false
			var i := 0
			while i < out.size() and out.size() > 3:
				var a := out[(i - 1 + out.size()) % out.size()]
				var b := out[(i + 1) % out.size()]
				var p := out[i]
				var ab := b - a
				var off := absf(ab.cross(p - a)) / maxf(ab.length(), 1e-6)
				if off < tol:
					out.remove_at(i)
					changed = true
				else:
					i += 1
		if out.size() <= max_points:
			return out
		tol *= 1.5
	return out
