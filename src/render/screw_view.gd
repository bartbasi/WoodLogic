# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name ScrewView
extends Node2D
## One screw head (docs/ARCHITECTURE.md 7, docs/DESIGN.md 3 and 4), centered on its origin and
## drawn in design units at its size's diameter. One small quad with screw.gdshader. The metal
## finish and the symbols setting come from Looks.current when `setup` runs.

const SHADER := preload("res://src/render/shaders/screw.gdshader")

const BOARD := 0
const WELL := 1
const TRAY := 2
## Head diameters in design units (docs/UX.md 3.2.1 and 3.2.2).
const DIAMETERS: Array[float] = [28.0, 24.0, 32.0]
## The free and covered looks cross-fade over this long (DESIGN.md 4).
const FADE_SECONDS := 0.15
## The quad reaches this many radii from the center, room for a lifted head's shadow.
const REACH := 2.0

var _mat: ShaderMaterial
var _color := 0
var _size := BOARD
var _covered := false
var _bright := false
var _cover_mix := 0.0
var _turn := 0.0
var _lift := 0.0


func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	set_process(false)


func setup(color: int, size: int) -> void:
	_color = posmod(color, Palette.count())
	_size = clampi(size, BOARD, TRAY)
	var c := Palette.color(_color)
	var m := Looks.current_metal()
	_mat.set_shader_parameter("radius", radius())
	_mat.set_shader_parameter("head_color", c)
	_mat.set_shader_parameter("symbol", _color if Looks.symbols_on() else -1)
	_mat.set_shader_parameter("recess_light", 1.0 if Palette.is_dark(_color) else 0.0)
	for key: String in ["metal_light", "metal_dark", "recess_metal", "gloss", "spec_power"]:
		_mat.set_shader_parameter(key, m[key])
	_mat.set_shader_parameter("shadow_color", Tokens.SHADOW)
	# The ghost's symbol and dashed ring are dark on light woods and light on dark ones (ebony),
	# so they always show through.
	var wood := Looks.current_wood()
	var dark_wood := Palette.luminance(wood["wood_light"]) < 0.12
	var ink := c.lightened(0.6) if Palette.is_dark(_color) or dark_wood else c.darkened(0.55)
	_mat.set_shader_parameter("ghost_ink", ink)
	_mat.set_shader_parameter("ghost_ring", Tokens.TEXT if dark_wood else Color("2a1708"))
	_apply()
	queue_redraw()


func radius() -> float:
	return DIAMETERS[_size] * 0.5


## Free or covered. The change fades over 150 ms when the view is on screen.
func set_covered(covered: bool) -> void:
	if covered == _covered:
		return
	_covered = covered
	_fade_to_target()


## Screwdriver mode (docs/ARCHITECTURE.md 7): a covered screw shows at full strength, its color
## and symbol clear, so the player can pick any screw. Off again, it goes back to the ghost.
func set_bright(on: bool) -> void:
	if on == _bright:
		return
	_bright = on
	_fade_to_target()


func is_bright() -> bool:
	return _bright


func _target() -> float:
	return 1.0 if _covered and not _bright else 0.0


func _fade_to_target() -> void:
	if not is_inside_tree():
		_cover_mix = _target()
		_apply()
		return
	set_process(true)


func is_covered() -> bool:
	return _covered


## The screw's turn in degrees (clockwise); the recess and the rim marks turn with it.
func set_turn(degrees: float) -> void:
	_turn = degrees
	_apply()


## 0 in its hole, 1 fully out: the head grows a little and its shadow moves out and softens.
func set_lift(amount: float) -> void:
	_lift = clampf(amount, 0.0, 1.0)
	_apply()


func _process(delta: float) -> void:
	var target := _target()
	_cover_mix = move_toward(_cover_mix, target, delta / FADE_SECONDS)
	_apply()
	if _cover_mix == target:
		set_process(false)


func _apply() -> void:
	_mat.set_shader_parameter("angle", deg_to_rad(_turn))
	_mat.set_shader_parameter("lift", _lift)
	_mat.set_shader_parameter("cover", _cover_mix)


func _draw() -> void:
	var r := radius() * REACH
	draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color.WHITE)
