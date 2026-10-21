# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelHint
extends Node2D
## The tutorial hand and its steady ring (UX 5.1 and 5.2): a pointing hand that glides to the
## screw to tap and presses toward it in a slow cycle of 1.2 seconds, inside a steady ring.
## Nothing flashes or blinks. Placeholder look, drawn in code.

const CYCLE := 1.2
const FADE_IN := 0.3
const GLIDE_SECONDS := 0.4
const INK := Color("2a1708")
const SKIN := Color("f7ead4")
const RING := Color("fff1c9")

var _target := Vector2.ZERO
var _from := Vector2.ZERO
var _glide := 1.0
var _scale := 1.0
var _showing := false
var _alpha := 0.0
var _time := 0.0


func _ready() -> void:
	set_process(false)


func is_showing() -> bool:
	return _showing


func get_target() -> Vector2:
	return _target


## Shows the hand at a screw (scene units). With `glide` it moves there from where it is.
func point_at(target: Vector2, board_scale: float, glide: bool) -> void:
	_scale = board_scale
	if _showing and glide:
		_from = _target
		_glide = 0.0
	else:
		_from = target
		_glide = 1.0
	if not _showing:
		_alpha = 0.0
		_time = 0.0
	_target = target
	_showing = true
	set_process(true)
	queue_redraw()


func hide_hint() -> void:
	if not _showing:
		return
	_showing = false
	_alpha = 0.0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_time = fmod(_time + delta, CYCLE)
	_alpha = minf(1.0, _alpha + delta / FADE_IN)
	_glide = minf(1.0, _glide + delta / GLIDE_SECONDS)
	queue_redraw()


func _draw() -> void:
	if not _showing:
		return
	var at := _from.lerp(_target, LevelAnim.out_cubic(_glide))
	var s := _scale
	draw_arc(at, 20.0 * s, 0.0, TAU, 32, Color(RING, 0.9 * _alpha), 3.0 * s)
	# The hand presses toward the screw and back, once per cycle.
	var press := 0.5 - 0.5 * cos(TAU * _time / CYCLE)
	var tip := at + Vector2(7.0, 26.0 - 12.0 * press) * s
	var finger := PackedVector2Array([tip + Vector2(-5.0, 0.0) * s, tip + Vector2(5.0, 0.0) * s, tip + Vector2(5.0, 22.0) * s, tip + Vector2(-5.0, 22.0) * s])
	var palm := Rect2(tip + Vector2(-12.0, 18.0) * s, Vector2(24.0, 22.0) * s)
	draw_rect(palm, Color(SKIN, _alpha))
	draw_rect(palm, Color(INK, _alpha), false, 1.5)
	draw_colored_polygon(finger, Color(SKIN, _alpha))
	draw_polyline(PackedVector2Array([finger[3], finger[0], finger[1], finger[2]]), Color(INK, _alpha), 1.5 * s)
	draw_circle(tip + Vector2(0.0, 1.0) * s, 5.0 * s, Color(SKIN, _alpha))
	draw_arc(tip + Vector2(0.0, 1.0) * s, 5.0 * s, PI, TAU, 10, Color(INK, _alpha), 1.5 * s)
