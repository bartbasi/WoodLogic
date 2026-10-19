# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name DirPlank
extends Node2D
## One plank, or the back board, drawn as one quad with wood.gdshader. `look` holds the
## direction's common plank settings (thickness, shadow, bevel, light); `wood` holds one wood's
## colors and grain settings. Screen space light and depth are turned into the plank's local
## space here, so a rotated plank still has its edge at the bottom and its shadow down right.

const SHADER := preload("res://src/directions/shared/wood.gdshader")
const HOLE_RADIUS := 6.0

var _rect := Rect2()


func setup(plank: Dictionary, wood: Dictionary, look: Dictionary, index: int) -> void:
	position = plank.get("pos", Vector2.ZERO)
	rotation = deg_to_rad(float(plank.get("rot", 0.0)))
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var r: float = plank.get("corner", 8.0)
	var size: Vector2 = plank.get("size", Vector2.ZERO)
	# A direction may round boxes and Ls more (the toy look); never past half the thickness.
	if DirShape.shape_id(plank) == DirShape.BOX or DirShape.shape_id(plank) == DirShape.ELL:
		var thin: float = minf(size.x, size.y) if DirShape.shape_id(plank) == DirShape.BOX else float(plank["arm"])
		r = minf(r + float(look.get("corner_add", 0.0)), thin / 2.0 - 1.0)
	mat.set_shader_parameter("corner", r)
	match DirShape.shape_id(plank):
		DirShape.BOX:
			mat.set_shader_parameter("shape", 0)
			mat.set_shader_parameter("rect_a", Vector4(0, 0, size.x / 2.0, size.y / 2.0))
		DirShape.ELL:
			var e := DirShape.ell_rects(plank)
			mat.set_shader_parameter("shape", 1)
			mat.set_shader_parameter("rect_a", Vector4(e[0].x, e[0].y, e[1].x, e[1].y))
			mat.set_shader_parameter("rect_b", Vector4(e[2].x, e[2].y, e[3].x, e[3].y))
		DirShape.DISC:
			mat.set_shader_parameter("shape", 2)
			mat.set_shader_parameter("radii", Vector2(size.x, 0))
		DirShape.RING:
			mat.set_shader_parameter("shape", 3)
			mat.set_shader_parameter("radii", size)
		DirShape.TRI:
			var v: Array = plank["verts"]
			mat.set_shader_parameter("shape", 4)
			mat.set_shader_parameter("tri_ab", Vector4(v[0].x, v[0].y, v[1].x, v[1].y))
			mat.set_shader_parameter("tri_c", Vector2(v[2]))
	var holes: Array[Vector4] = []
	for h: Vector2 in plank.get("holes", []):
		holes.append(Vector4(h.x, h.y, float(look.get("hole_radius", HOLE_RADIUS)), 0))
	while holes.size() < 6:
		holes.append(Vector4(0, 0, -1000, 0))
	mat.set_shader_parameter("holes", holes)
	mat.set_shader_parameter("hole_count", (plank.get("holes", []) as Array).size())

	var layer := int(plank.get("layer", 0))
	var thick: float = plank.get("thickness", look["thickness"])
	var depth: Vector2 = (Vector2(look["edge_dir"]).normalized() * thick)
	var shadow: Vector2 = Vector2(look["shadow"]) * (1.0 + float(look.get("shadow_per_layer", 0.35)) * layer)
	if plank.has("shadow"):
		shadow = plank["shadow"]
	var blur: float = plank.get("shadow_blur", look["shadow_blur"])
	mat.set_shader_parameter("depth_vec", depth.rotated(-rotation))
	mat.set_shader_parameter("shadow_vec", shadow.rotated(-rotation))
	mat.set_shader_parameter("shadow_blur", blur)
	mat.set_shader_parameter("shadow_alpha", plank.get("shadow_alpha", look["shadow_alpha"]))
	mat.set_shader_parameter("shadow_color", look["shadow_color"])
	mat.set_shader_parameter("light_local", Vector2(look["light"]).normalized().rotated(-rotation))
	mat.set_shader_parameter("bevel", look["bevel"])
	mat.set_shader_parameter("bevel_strength", look["bevel_strength"])
	mat.set_shader_parameter("gloss", look.get("gloss", 0.0))
	mat.set_shader_parameter("face_light", look.get("face_light", 0.0))
	mat.set_shader_parameter("noise_tex", DirNoise.texture())
	var ext := DirShape.extent(plank)
	mat.set_shader_parameter("extent", ext)

	# Each plank gets its own seed, grain direction and tone, so no two look the same.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(index * 7919 + int(wood.get("seed_base", 0)))
	var along := 0.0
	if DirShape.shape_id(plank) == DirShape.BOX and size.y > size.x:
		along = PI / 2.0
	elif DirShape.shape_id(plank) == DirShape.ELL:
		along = PI / 2.0
	elif DirShape.shape_id(plank) in [DirShape.DISC, DirShape.RING, DirShape.TRI]:
		along = rng.randf_range(-0.6, 0.6)
	mat.set_shader_parameter("grain_angle", along + rng.randf_range(-0.04, 0.04))
	mat.set_shader_parameter("seed", rng.randf_range(0.0, 50.0))
	mat.set_shader_parameter("pith", rng.randf_range(-ext * 0.5, ext * 0.5))
	var tone_range: float = wood.get("tone_range", 0.08)
	mat.set_shader_parameter("tone", float(wood.get("tone", 1.0)) * (1.0 + rng.randf_range(-tone_range, tone_range)))
	for key: String in ["wood_light", "wood_dark", "edge_color", "ply_dark", "plies", "ring_freq", "ring_contrast",
			"figure", "fiber", "pores"]:
		if wood.has(key):
			mat.set_shader_parameter(key, wood[key])
	material = mat

	var margin := thick + shadow.length() + blur * 2.0 + 4.0
	_rect = Rect2(Vector2(-ext - margin, -ext - margin), Vector2(ext + margin, ext + margin) * 2.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(_rect, Color.WHITE)
