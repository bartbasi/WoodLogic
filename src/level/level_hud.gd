# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelHud
extends Node2D
## The level screen's text and small controls, drawn in code on plaques (UX 1.3, 3.2.2): the top
## bar (level label, the timer and its two pips, the pause button), the tutorial line in the
## helper bar's place, and the toast. Placeholder look. It holds no game state: the level scene
## tells it what to show.

const PLAQUE := Color(0.173, 0.114, 0.075, 0.94)
const PLAQUE_EDGE := Color(0.847, 0.643, 0.271, 0.55)
const TEXT := Color("f7ead4")
const BRASS := Color("d8a445")

var _layout: LevelLayout
var _label := ""
var _show_timer := false
var _timer_text := "0:00"
var _line := ""
var _fast_ok := true
var _clean_ok := true
var _toast := ""
var _toast_left := 0.0
var _pause_pressed := false


func _ready() -> void:
	set_process(false)


func configure(layout: LevelLayout, label: String, show_timer: bool, line: String) -> void:
	_layout = layout
	_label = label
	_show_timer = show_timer
	_line = line
	_timer_text = "0:00"
	_fast_ok = true
	_clean_ok = true
	_toast = ""
	_toast_left = 0.0
	queue_redraw()


func set_layout(layout: LevelLayout) -> void:
	_layout = layout
	queue_redraw()


func set_timer_text(text: String) -> void:
	if text != _timer_text:
		_timer_text = text
		queue_redraw()


func set_pips(fast_ok: bool, clean_ok: bool) -> void:
	if fast_ok != _fast_ok or clean_ok != _clean_ok:
		_fast_ok = fast_ok
		_clean_ok = clean_ok
		queue_redraw()


func set_line(text: String) -> void:
	if text != _line:
		_line = text
		queue_redraw()


func get_line() -> String:
	return _line


func get_toast() -> String:
	return _toast if _toast_left > 0.0 else ""


func show_toast(text: String, seconds: float = 2.0) -> void:
	_toast = text
	_toast_left = seconds
	set_process(true)
	queue_redraw()


func set_pause_pressed(on: bool) -> void:
	if on != _pause_pressed:
		_pause_pressed = on
		queue_redraw()


## The pause button's touch target: 48 by 48 at the top right, scaled with the bars (UX 3.2.2).
func pause_target() -> Rect2:
	if _layout == null:
		return Rect2()
	var top := _layout.top_bar
	var f := _layout.f
	return Rect2(top.end.x - 52.0 * f, top.position.y, 48.0 * f, 48.0 * f)


func _process(delta: float) -> void:
	_toast_left -= delta
	if _toast_left <= 0.0:
		_toast_left = 0.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _layout == null:
		return
	var f := _layout.f
	var font := ThemeDB.fallback_font
	var top := _layout.top_bar
	# Top bar: the level label on the left, the timer and pips, the pause button on the right.
	var mid_y := top.position.y + top.size.y * 0.5
	_plaque(Rect2(top.position.x + 8.0 * f, top.position.y + 4.0 * f, 96.0 * f, top.size.y - 8.0 * f))
	draw_string(font, Vector2(top.position.x + 14.0 * f, mid_y + 7.0 * f), _label, HORIZONTAL_ALIGNMENT_LEFT, 84.0 * f, int(round(20.0 * f)), TEXT)
	if _show_timer:
		var box := Rect2(top.position.x + 112.0 * f, top.position.y + 4.0 * f, 108.0 * f, top.size.y - 8.0 * f)
		_plaque(box)
		draw_string(font, Vector2(box.position.x + 8.0 * f, mid_y + 6.0 * f), _timer_text, HORIZONTAL_ALIGNMENT_LEFT, 60.0 * f, int(round(16.0 * f)), TEXT)
		_pip_stopwatch(Vector2(box.position.x + 72.0 * f, mid_y), 7.0 * f, _fast_ok)
		_pip_tray(Vector2(box.position.x + 94.0 * f, mid_y), 7.0 * f, _clean_ok)
	var target := pause_target()
	var button := Rect2(target.position.x + 4.0 * f, top.position.y + 4.0 * f, 40.0 * f, top.size.y - 8.0 * f)
	var press := 0.96 if _pause_pressed else 1.0
	button = Rect2(button.get_center() - button.size * 0.5 * press, button.size * press)
	draw_rect(button, BRASS.darkened(0.25) if _pause_pressed else BRASS)
	var bar := Vector2(5.0 * f, 16.0 * f)
	draw_rect(Rect2(button.get_center() + Vector2(-8.0 * f, -bar.y * 0.5), bar), Color("2a1708"))
	draw_rect(Rect2(button.get_center() + Vector2(3.0 * f, -bar.y * 0.5), bar), Color("2a1708"))
	# The tutorial line sits where the helper buttons will be.
	if _line != "":
		var width := minf(_layout.helper_bar.size.x - 24.0, 336.0 * f)
		var plaque := Rect2(_layout.helper_bar.get_center() - Vector2(width, 48.0 * f) * 0.5, Vector2(width, 48.0 * f))
		_plaque(plaque)
		var size := int(round(18.0 * f))
		var wide: float = font.get_string_size(_line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		var two_lines := wide > width - 16.0
		var y := plaque.get_center().y + (-size * 0.2 if two_lines else size * 0.35)
		draw_multiline_string(font, Vector2(plaque.position.x + 8.0, y), _line, HORIZONTAL_ALIGNMENT_CENTER, width - 16.0, size, 2, TEXT)
	if _toast_left > 0.0 and _toast != "":
		var size := int(round(16.0 * f))
		var text_w: float = minf(font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x, _layout.content.size.x - 40.0)
		var two := font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x > text_w
		var h := (52.0 if two else 32.0) * f
		var rect := Rect2(_layout.content.get_center().x - (text_w + 24.0) * 0.5, _layout.content.end.y - 24.0 * f - h, text_w + 24.0, h)
		_plaque(rect)
		draw_multiline_string(font, Vector2(rect.position.x + 12.0, rect.position.y + (20.0 if not two else 20.0) * f), _toast, HORIZONTAL_ALIGNMENT_CENTER, text_w, size, 2, TEXT)


func _plaque(rect: Rect2) -> void:
	draw_rect(rect, PLAQUE)
	draw_rect(rect, PLAQUE_EDGE, false, 1.0)


## A stopwatch pip: a filled disc while the speed star is still possible, an outline after.
func _pip_stopwatch(c: Vector2, r: float, on: bool) -> void:
	if on:
		draw_circle(c, r, BRASS)
	else:
		draw_arc(c, r - 1.0, 0.0, TAU, 20, BRASS, 1.8)
	var ink := Color("2a1708") if on else BRASS
	draw_line(c, c + Vector2(0.0, -r * 0.6), ink, 1.6)
	draw_line(c, c + Vector2(r * 0.4, r * 0.2), ink, 1.6)


## A tray pip: a filled little tray while the clean star is still possible, an outline after.
func _pip_tray(c: Vector2, r: float, on: bool) -> void:
	var rect := Rect2(c - Vector2(r, r * 0.6), Vector2(r * 2.0, r * 1.2))
	if on:
		draw_rect(rect, BRASS)
	else:
		draw_rect(rect, BRASS, false, 1.8)
	var ink := Color("2a1708") if on else BRASS
	for i: int in 3:
		draw_circle(rect.position + Vector2(r * (0.4 + 0.6 * i), r * 0.6), 1.2, ink)
