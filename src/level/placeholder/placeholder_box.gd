# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name PlaceholderBox
extends Node2D
## The placeholder box: a small wooden tray with three dark wells, a front band in its color
## with the color's symbol, and a lid that leans back when open. A preview box is the closed
## queue look: 62 by 44, painted lid, symbol, no wells. Same setup and methods as
## docs/ARCHITECTURE.md 7's BoxView. The origin is the top left of the body (UX 3.2.2).

const BODY := Color("b98046")
const BODY_EDGE := Color("6e4421")
const WELL := Color("2b1c10")
const OPEN_SIZE := Vector2(92.0, 56.0)
const PREVIEW_SIZE := Vector2(62.0, 44.0)

var _color := 0
var _preview := false
var _count := 0
var _lid := 1.0
var _tween: Tween


func setup(color: int, preview: bool) -> void:
	_color = color
	_preview = preview
	_lid = 0.0 if preview else 1.0
	queue_redraw()


func set_count(n: int) -> void:
	_count = n


func set_lid(open: float) -> void:
	_lid = clampf(open, 0.0, 1.0)
	queue_redraw()


## The lid swings down and shuts: 180 ms with a small bounce at the end (DESIGN.md 9).
func close() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var from := _lid
	_tween.tween_method(func(p: float) -> void:
		set_lid(from * (1.0 - LevelAnim.in_quad(p)) + 0.07 * sin(PI * clampf((p - 0.8) / 0.2, 0.0, 1.0))), 0.0, 1.0, 0.18)
	_tween.tween_callback(set_lid.bind(0.0))


func _draw() -> void:
	var paint := PlaceholderSymbols.color_of(_color)
	var ink := PlaceholderSymbols.ink_for(_color)
	if _preview:
		var rect := Rect2(Vector2.ZERO, PREVIEW_SIZE)
		draw_rect(rect, BODY)
		draw_rect(rect.grow(-4.0), paint)
		draw_rect(rect, BODY_EDGE, false, 2.0)
		PlaceholderSymbols.draw(self, _color, rect.get_center(), 10.0, 0.0, ink, 2.4)
		return
	var body := Rect2(Vector2.ZERO, OPEN_SIZE)
	draw_rect(body, BODY)
	for i: int in 3:
		draw_circle(Vector2(LevelLayout.WELL_FIRST_X + LevelLayout.WELL_STEP * i, LevelLayout.WELL_Y), 12.0, WELL)
	var band := Rect2(6.0, 36.0, 80.0, 18.0)
	draw_rect(band, paint)
	draw_rect(band, BODY_EDGE, false, 1.5)
	PlaceholderSymbols.draw(self, _color, band.get_center(), 7.0, 0.0, ink, 2.2)
	draw_rect(body, BODY_EDGE, false, 2.0)
	# The lid: a thin strip leaning back when open, a plate over the wells when shut.
	var lid_top := lerpf(6.0, -5.0, _lid)
	var lid_height := lerpf(30.0, 3.0, _lid)
	var lid := Rect2(3.0, lid_top, 86.0, lid_height)
	draw_rect(lid, paint)
	draw_rect(lid, BODY_EDGE, false, 1.5)
	if _lid < 0.5:
		PlaceholderSymbols.draw(self, _color, lid.get_center(), 8.0, 0.0, ink, 2.2)
