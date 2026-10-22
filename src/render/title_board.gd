# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name TitleBoard
extends Node2D
## The title screen's decorative board (docs/UX.md 3.1): a small windmill of planks and screws
## on the theme's back board, in the chosen wood and metal (Looks.current). Purely decoration:
## nothing on it looks pressable. Its one touch of life is the sails making one slow quarter
## turn when the board appears, easing in and out over about eight seconds, then resting (no
## flashing, and nothing redraws once they rest). `bake()` draws everything still (board, tower, door, ground, sun
## and their screws) into one texture, so only the sails and their screws draw live: about eight
## draw calls in all. It fades in over 150 ms once baked. The origin is the top left of the rect.

## The windmill is designed in a 340 x 340 frame centered on its hub's column, then scaled to
## fit the rect (never above 1).
const DESIGN := Vector2(340.0, 340.0)
const PANEL_INSET := 2.0
## Room around the rect in the still texture, so the board's edge and shadow aren't cut off.
const PAD := 32.0
const PANEL_CORNER := 14.0
## One turn of the sails: this far, over this long, eased in and out (DESIGN.md 9).
const TURN_DEGREES := 90.0
const TURN_SECONDS := 8.0
const FADE_SECONDS := 0.15
## Frames from asking the still group to draw until its texture is ready.
const CAPTURE_FRAMES := 2
const CACHED_SHADER := preload("res://src/render/shaders/cached.gdshader")

var _size := Vector2(312, 196)
var _scale := 1.0
var _origin := Vector2.ZERO
var _viewport: SubViewport
var _still: Node2D
var _still_planks: Array[PlankView] = []
var _rotor: Node2D
var _rotor_screws: Array[ScrewView] = []
var _rotor_planks: Array[PlankView] = []
var _texture_ready := false
## -1 idle; otherwise frames left in the bake (planks first, then the capture).
var _bake_frames := -1
var _fade := 0.0
var _angle := 0.0
var _turning := true
## How long a turn takes; tests shorten it.
var turn_seconds := TURN_SECONDS
## Where the turn in progress started, and how far into it we are (-1 when resting).
var _turn_from := 0.0
var _turn_t := -1.0


## Lays the board out to fill `size` (design units).
func setup(size: Vector2) -> void:
	_size = size
	_clear()
	_scale = clampf(minf((size.x - 24.0) / DESIGN.x, (size.y - 16.0) / DESIGN.y), 0.3, 1.0)
	_origin = Vector2(size.x * 0.5, size.y * 0.5 - 4.0 * _scale)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_still = Node2D.new()
	_viewport.add_child(_still)
	_build_still()
	_rotor = Node2D.new()
	_rotor.position = _hub()
	add_child(_rotor)
	_build_rotor()
	_texture_ready = false
	_fade = 0.0
	_turn_from = _angle
	_turn_t = 0.0 if _turning else -1.0
	_apply_fade()
	# The still texture holds premultiplied color: lay it down that way (and with the fade).
	var mat := ShaderMaterial.new()
	mat.shader = CACHED_SHADER
	material = mat
	queue_redraw()


## Draws everything still once; the board shows (fading in) when that is done.
func bake() -> void:
	if _viewport == null:
		setup(_size)
	var k := clampf(_pixels_per_unit(), 1.0, 3.0)
	_viewport.size = Vector2i(ceili((_size.x + PAD * 2.0) * k), ceili((_size.y + PAD * 2.0) * k))
	_still.scale = Vector2(k, k)
	_still.position = Vector2(PAD, PAD) * k
	for p: PlankView in _still_planks:
		p.bake()
	for p: PlankView in _rotor_planks:
		p.bake()
	# Two frames for the planks' own bakes, then the still group's capture.
	_bake_frames = 2 + CAPTURE_FRAMES
	set_process(true)


func is_baked() -> bool:
	return _texture_ready


## On (the default) gives the sails one slow turn, starting when the board has faded in, or at
## once if it already has; calling it again turns them once more. Off stops them where they are.
func set_turning(on: bool) -> void:
	_turning = on
	if on:
		_turn_from = _angle
		_turn_t = 0.0
		set_process(true)
	else:
		_turn_t = -1.0


## True while the sails are turning.
func is_turning() -> bool:
	return _turn_t >= 0.0


func _ready() -> void:
	if _viewport == null:
		setup(_size)
	if _bake_frames < 0 and not _texture_ready:
		bake()


func _process(delta: float) -> void:
	if _bake_frames >= 0:
		_bake_frames -= 1
		if _bake_frames == CAPTURE_FRAMES - 1:
			_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		elif _bake_frames < 0:
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_texture_ready = true
			queue_redraw()
	if _texture_ready and _fade < 1.0:
		_fade = minf(1.0, _fade + delta / FADE_SECONDS)
		_apply_fade()
	# The turn starts once the board is showing, eases in and out, then rests.
	if _turn_t >= 0.0 and _fade >= 1.0 and _rotor != null:
		_turn_t = minf(1.0, _turn_t + delta / maxf(turn_seconds, 0.001))
		var eased := 0.5 - 0.5 * cos(PI * _turn_t)
		_angle = fmod(_turn_from + TURN_DEGREES * eased, 360.0)
		_turn_rotor()
		if _turn_t >= 1.0:
			_turn_t = -1.0
	# At rest (baked, faded in, sails still) nothing runs or redraws.
	if _bake_frames < 0 and _fade >= 1.0 and _turn_t < 0.0:
		set_process(false)


func _apply_fade() -> void:
	modulate.a = _fade


func _draw() -> void:
	if _texture_ready and _viewport != null:
		draw_texture_rect(_viewport.get_texture(), Rect2(-Vector2(PAD, PAD), _size + Vector2(PAD, PAD) * 2.0), false)


func _clear() -> void:
	for n: Node in get_children():
		n.queue_free()
	_still_planks.clear()
	_rotor_planks.clear()
	_rotor_screws.clear()
	_viewport = null
	_rotor = null
	_bake_frames = -1


## Design units in the windmill's frame to the board's own units.
func _at(p: Vector2) -> Vector2:
	return _origin + p * _scale


func _hub() -> Vector2:
	return _at(Vector2(0, -62))


func _build_still() -> void:
	var panel := PlankView.new()
	_still.add_child(panel)
	panel.setup_panel(Rect2(Vector2(PANEL_INSET, PANEL_INSET), _size - Vector2(PANEL_INSET, PANEL_INSET) * 2.0), PANEL_CORNER, 501)
	_still_planks.append(panel)
	var ground_half := maxf(_size.x * 0.5 - 18.0, 120.0 * _scale)
	var ground_y := _at(Vector2(0, 150)).y
	var ground := _rect_outline(Vector2(_size.x * 0.5 - ground_half, ground_y - 13.0 * _scale), Vector2(ground_half * 2.0, 26.0 * _scale), 10.0 * _scale)
	_plank(ground, 4, [Vector2(_size.x * 0.5 - ground_half + 16.0 * _scale, ground_y), Vector2(_size.x * 0.5 + ground_half - 16.0 * _scale, ground_y)], [Palette.color_name(4), Palette.color_name(6)], 11)
	var tower := PackedVector2Array([_at(Vector2(-56, 146)), _at(Vector2(56, 146)), _at(Vector2(36, -44)), _at(Vector2(-36, -44))])
	_plank(tower, 3, [_at(Vector2(-34, 118)), _at(Vector2(34, 118))], ["blue", "yellow"], 12)
	var door := _rect_outline(_at(Vector2(-15, 84)), Vector2(30, 56) * _scale, 8.0 * _scale)
	# A small board leaves the door unscrewed, so its few screws don't crowd.
	_plank(door, 2, [_at(Vector2(0, 104))] if _scale > 0.6 else [], ["purple"], 13)
	if _size.x > DESIGN.x * _scale + 60.0 or _size.y > 260.0:
		var sun := _circle_outline(_at(Vector2(128, -118)), 26.0 * _scale)
		_plank(sun, 3, [_at(Vector2(128, -118))], ["sky"], 14)
	# Wide boards get a tree on the left and a short fence on the right, in the free space.
	var free := _size.x * 0.5 - 175.0 * _scale - 12.0
	if free >= 80.0 * _scale:
		_tree(_origin.x - 175.0 * _scale - free * 0.5)
	if free >= 110.0 * _scale:
		_fence(_origin.x + 175.0 * _scale + free * 0.5)


func _build_rotor() -> void:
	# Two crossed sails on the hub, in the rotor's own frame (the hub at its origin).
	var long := 118.0 * _scale
	var wide := 15.0 * _scale
	for i in 2:
		var dir := Vector2.RIGHT.rotated(deg_to_rad(35.0 + 90.0 * i))
		var n := Vector2(-dir.y, dir.x)
		var pts := PackedVector2Array()
		for j in 9:
			var a := -PI * 0.5 + PI * j / 8.0
			pts.append(dir * (long - wide) + (dir * cos(a) + n * sin(a)) * wide)
		for j in 9:
			var a := PI * 0.5 + PI * j / 8.0
			pts.append(-dir * (long - wide) + (dir * cos(a) + n * sin(a)) * wide)
		var v := PlankView.new()
		_rotor.add_child(v)
		v.setup(_to_gu(pts), PackedVector2Array(), 1 - i, PackedVector2Array(), 30 + i)
		_rotor_planks.append(v)
		for end: float in [-1.0, 1.0]:
			_rotor_screw(dir * (long - wide - 4.0 * _scale) * end, ["red", "green", "orange", "pink"][i * 2 + int(end > 0.0)])
	_rotor_screw(Vector2.ZERO, "white")
	_turn_rotor()


## A tree: a trunk standing on the ground and a round crown, one screw each.
func _tree(x: float) -> void:
	var base := _at(Vector2(0, 150)).y - 13.0 * _scale
	var trunk := _rect_outline(Vector2(x - 11.0 * _scale, base - 120.0 * _scale), Vector2(22.0, 120.0) * _scale, 8.0 * _scale)
	_plank(trunk, 3, [Vector2(x, base - 30.0 * _scale)], ["orange"], 15)
	var crown_c := Vector2(x, base - 140.0 * _scale)
	_plank(_circle_outline(crown_c, 52.0 * _scale), 2, [crown_c], ["green"], 16)


## A short fence: two posts and a rail across them, screwed where the rail crosses each post.
func _fence(x: float) -> void:
	var base := _at(Vector2(0, 150)).y - 13.0 * _scale
	for dx: float in [-40.0, 40.0]:
		var post := _rect_outline(Vector2(x + dx * _scale - 9.0 * _scale, base - 74.0 * _scale), Vector2(18.0, 74.0) * _scale, 6.0 * _scale)
		_plank(post, 3, [], [], 17 + int(dx))
	var rail := _rect_outline(Vector2(x - 64.0 * _scale, base - 54.0 * _scale), Vector2(128.0, 20.0) * _scale, 8.0 * _scale)
	_plank(rail, 2, [Vector2(x - 40.0 * _scale, base - 44.0 * _scale), Vector2(x + 40.0 * _scale, base - 44.0 * _scale)], ["red", "yellow"], 19)


func _screw_scale() -> float:
	return clampf(_scale * 1.05, 0.45, 1.0)


func _rotor_screw(at: Vector2, color_name: String) -> void:
	var s := ScrewView.new()
	s.setup(Palette.NAMES.find(color_name), ScrewView.BOARD)
	s.position = at
	s.scale = Vector2.ONE * _screw_scale()
	_rotor.add_child(s)
	_rotor_screws.append(s)


## Turns the sails; each screw keeps its light still (it turns back by the rotor's angle) while
## its drive turns with the sails.
func _turn_rotor() -> void:
	_rotor.rotation_degrees = _angle
	for s: ScrewView in _rotor_screws:
		s.rotation_degrees = -_angle
		s.set_turn(_angle)


func _plank(outline: PackedVector2Array, layer: int, screws: Array, colors: Array, seed_value: int) -> void:
	var v := PlankView.new()
	_still.add_child(v)
	v.setup(_to_gu(outline), PackedVector2Array(), layer, PackedVector2Array(), seed_value)
	_still_planks.append(v)
	for i in screws.size():
		var s := ScrewView.new()
		s.setup(Palette.NAMES.find(String(colors[i])), ScrewView.BOARD)
		s.position = screws[i]
		s.scale = Vector2.ONE * _screw_scale()
		s.set_turn(float((seed_value * 37 + i * 53) % 40 - 20))
		_still.add_child(s)


static func _to_gu(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(p / PlankView.GU)
	return out


static func _rect_outline(pos: Vector2, size: Vector2, corner: float) -> PackedVector2Array:
	return PlankView.rounded_rect(Rect2(pos, size), corner)


static func _circle_outline(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 40:
		pts.append(c + Vector2(cos(TAU * i / 40.0), sin(TAU * i / 40.0)) * r)
	return pts


func _pixels_per_unit() -> float:
	if not is_inside_tree():
		return 1.0
	var t := get_global_transform_with_canvas().get_scale()
	var f := get_viewport().get_final_transform().get_scale()
	return maxf(absf(t.x * f.x), absf(t.y * f.y))
