# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name PlaceholderScrew
extends Node2D
## The placeholder screw: a flat disc with a metal rim and a line symbol for its color. Same
## setup and methods as docs/ARCHITECTURE.md 7's ScrewView. Free screws are solid with a
## shadow; covered ones are flat and faint with a dashed ring (DESIGN.md 4). Drawn in design
## units, centered on its own origin; the level scene scales it for the box well and the tray.

const BOARD := 0
const WELL := 1
const TRAY := 2
## Head diameters in design units (UX 3.2.1 and 3.2.2).
const DIAMETERS: Array[float] = [28.0, 24.0, 32.0]
## How fast the free and covered looks cross-fade (DESIGN.md 4: 150 ms).
const FADE_SECONDS := 0.15

var _color := 0
var _size := BOARD
var _covered := false
## 0 is the free look, 1 the covered look.
var _cover_mix := 0.0
var _turn := 0.0
var _lift := 0.0


func setup(color: int, size: int) -> void:
	_color = color
	_size = size
	queue_redraw()


func set_covered(covered: bool) -> void:
	if covered == _covered:
		return
	_covered = covered
	if not is_inside_tree():
		_cover_mix = 1.0 if covered else 0.0
		queue_redraw()
		return
	set_process(true)


func set_turn(degrees: float) -> void:
	_turn = degrees
	queue_redraw()


func set_lift(amount: float) -> void:
	_lift = amount
	queue_redraw()


func is_covered() -> bool:
	return _covered


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	var target := 1.0 if _covered else 0.0
	_cover_mix = move_toward(_cover_mix, target, delta / FADE_SECONDS)
	queue_redraw()
	if _cover_mix == target:
		set_process(false)


func _draw() -> void:
	var r: float = DIAMETERS[_size] * 0.5
	var cap := PlaceholderSymbols.color_of(_color)
	var ink := PlaceholderSymbols.ink_for(_color)
	var free_a := 1.0 - _cover_mix
	if free_a > 0.01:
		var offset := Vector2(0.14, 0.26) * r * (1.0 + _lift)
		draw_circle(offset, r * (1.0 + 0.12 * _lift), Color(0.1, 0.05, 0.02, 0.5 * free_a))
		draw_circle(Vector2.ZERO, r, Color(PlaceholderSymbols.RIM_LIGHT, free_a))
		draw_arc(Vector2.ZERO, r * 0.92, deg_to_rad(110.0), deg_to_rad(250.0), 10, Color(PlaceholderSymbols.RIM_DARK, free_a), 1.2)
		draw_circle(Vector2.ZERO, r * 0.78, Color(cap, free_a))
		draw_arc(Vector2.ZERO, r * 0.78, 0.0, TAU, 24, Color(0.1, 0.05, 0.02, 0.6 * free_a), 1.0)
		draw_arc(Vector2.ZERO, r * 0.6, deg_to_rad(205.0), deg_to_rad(265.0), 8, Color(1.0, 1.0, 1.0, 0.45 * free_a), 1.6)
		PlaceholderSymbols.draw(self, _color, Vector2.ZERO, r * 0.57, _turn, Color(ink, free_a), 2.2)
		# A mark on the rim that turns with the screw, so a round symbol still shows the turn.
		var a := deg_to_rad(_turn - 90.0)
		draw_line(Vector2(cos(a), sin(a)) * r * 0.84, Vector2(cos(a), sin(a)) * r * 0.98, Color(PlaceholderSymbols.RIM_DARK, free_a), 1.6)
	if _cover_mix > 0.01:
		var ghost := _cover_mix
		draw_circle(Vector2.ZERO, r * 0.92, Color(cap, 0.45 * ghost))
		var dark := Color(cap.darkened(0.55), 0.7 * ghost)
		PlaceholderSymbols.draw(self, _color, Vector2.ZERO, r * 0.52, 0.0, dark, 2.0)
		for i: int in 12:
			var a0 := i * TAU / 12.0
			draw_arc(Vector2.ZERO, r, a0, a0 + TAU / 12.0 * 0.55, 4, Color(0.165, 0.09, 0.03, 0.7 * ghost), 1.6)
