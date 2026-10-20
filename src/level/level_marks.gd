# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelMarks
extends Node2D
## Short lived marks drawn over the board: the ripple where a tap lands on bare board, steady
## rings (a covered screw's ghost, the screws that fit when a tap is refused, the tutorial's
## hint) and a plank's glowing edge (UX 6.1). Each fades in and out and holds steady between;
## nothing pulses or flashes (UX 7.5). A fixed pool, reused, so nothing allocates per frame.

const MAX_MARKS := 48
const FADE := 0.15
const RIPPLE_SECONDS := 0.25

## Mark kinds.
const RING := 0
const RIPPLE := 1
const OUTLINE := 2

var _kind := PackedInt32Array()
var _center := PackedVector2Array()
var _radius := PackedFloat32Array()
var _age := PackedFloat32Array()
var _hold := PackedFloat32Array()
var _color := PackedColorArray()
var _outline: Array[PackedVector2Array] = []
var _active := 0


func _init() -> void:
	_kind.resize(MAX_MARKS)
	_center.resize(MAX_MARKS)
	_radius.resize(MAX_MARKS)
	_age.resize(MAX_MARKS)
	_hold.resize(MAX_MARKS)
	_color.resize(MAX_MARKS)
	_outline.resize(MAX_MARKS)


func _ready() -> void:
	set_process(false)


func clear() -> void:
	_active = 0
	set_process(false)
	queue_redraw()


## A steady ring that fades in, holds for `hold` seconds, and fades out.
func add_ring(center: Vector2, radius: float, color: Color, hold: float) -> void:
	_add(RING, center, radius, hold, color, PackedVector2Array())


## A soft ring that spreads from `center` and fades (250 ms).
func add_ripple(center: Vector2, radius: float, color: Color) -> void:
	_add(RIPPLE, center, radius, RIPPLE_SECONDS, color, PackedVector2Array())


## A glowing edge along a closed outline (scene units).
func add_outline(points: PackedVector2Array, color: Color, hold: float) -> void:
	_add(OUTLINE, Vector2.ZERO, 0.0, hold, color, points)


func active_count() -> int:
	return _active


func _add(kind: int, center: Vector2, radius: float, hold: float, color: Color, points: PackedVector2Array) -> void:
	var i := _active
	if i >= MAX_MARKS:
		i = MAX_MARKS - 1
	else:
		_active += 1
	_kind[i] = kind
	_center[i] = center
	_radius[i] = radius
	_age[i] = 0.0
	_hold[i] = hold
	_color[i] = color
	_outline[i] = points
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var i := 0
	while i < _active:
		_age[i] += delta
		var life := _hold[i] if _kind[i] == RIPPLE else _hold[i] + 2.0 * FADE
		if _age[i] >= life:
			_active -= 1
			_kind[i] = _kind[_active]
			_center[i] = _center[_active]
			_radius[i] = _radius[_active]
			_age[i] = _age[_active]
			_hold[i] = _hold[_active]
			_color[i] = _color[_active]
			_outline[i] = _outline[_active]
		else:
			i += 1
	queue_redraw()
	if _active == 0:
		set_process(false)


func _draw() -> void:
	for i: int in _active:
		var age := _age[i]
		var c := _color[i]
		if _kind[i] == RIPPLE:
			var q := clampf(age / RIPPLE_SECONDS, 0.0, 1.0)
			draw_arc(_center[i], _radius[i] * (0.35 + 0.65 * q), 0.0, TAU, 28, Color(c, c.a * (1.0 - q)), 2.0)
			continue
		var alpha := clampf(age / FADE, 0.0, 1.0)
		var out_start := _hold[i] + FADE
		if age > out_start:
			alpha = clampf(1.0 - (age - out_start) / FADE, 0.0, 1.0)
		var tint := Color(c, c.a * alpha)
		if _kind[i] == RING:
			draw_arc(_center[i], _radius[i], 0.0, TAU, 28, tint, 3.0)
		else:
			draw_polyline(_outline[i], tint, 4.0, true)
