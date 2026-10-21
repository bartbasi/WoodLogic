# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name TrayView
extends CachedDrawing
## The holding tray (docs/ARCHITECTURE.md 7, docs/UX.md 3.2.2, docs/DESIGN.md 7): a brushed steel
## magnetic parts tray with riveted ends and dished slots. With one slot free it warms toward the
## warning tone over 200 ms and a warning triangle sits in the free slot, then stays steady (no
## blinking). Full, it keeps the warm tone and shows a small shut-lid mark in the corner. The
## origin is the center of the frame. Screws in the slots are separate ScrewViews.

const SLOT_W := 44.0
const SLOT_GAP := 6.0
const PAD := 16.0
const HEIGHT := 52.0
const HOLLOW_RADIUS := 19.0
const WARM_SECONDS := 0.2

var _slots := 5
var _warning := false
var _full := false
var _filled := PackedByteArray()
var _warm := 0.0
var _tween: Tween


func setup(slots: int) -> void:
	_slots = maxi(1, slots)
	if _filled.size() != _slots:
		_filled.resize(_slots)
	repaint()


func set_filled(filled: PackedByteArray) -> void:
	_filled = filled.duplicate()
	repaint()


func set_warning(on: bool) -> void:
	if on == _warning:
		return
	_warning = on
	_fade()


func set_full(on: bool) -> void:
	if on == _full:
		return
	_full = on
	_fade()


static func width(slots: int) -> float:
	return slots * SLOT_W + (slots - 1) * SLOT_GAP + PAD


## A slot's center x from the frame's center.
static func slot_x(slot: int, slots: int) -> float:
	return -width(slots) * 0.5 + PAD * 0.5 + SLOT_W * 0.5 + slot * (SLOT_W + SLOT_GAP)


func _paint_rect() -> Rect2:
	var w := width(_slots)
	return Rect2(-w * 0.5 - 12.0, -HEIGHT * 0.5 - 12.0, w + 26.0, HEIGHT + 28.0)


func _fade() -> void:
	var target := 1.0 if (_warning or _full) else 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		_warm = target
		repaint()
		return
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void:
		_warm = v
		repaint(), _warm, target, WARM_SECONDS)


func _paint(ci: CanvasItem) -> void:
	var w := width(_slots)
	var frame := Rect2(-w * 0.5, -HEIGHT * 0.5, w, HEIGHT)
	var steel := Tokens.STEEL.lerp(Tokens.WARN, 0.55 * _warm)
	Paint.panel(ci, Rect2(frame.position + Vector2(0, 4), frame.size), Tokens.STEEL_EDGE, 12, Color(), 0, Color(0, 0, 0, 0.5), 8, Vector2(2, 3))
	Paint.panel(ci, frame, steel, 12)
	for i in 9:
		var y := frame.position.y + 4.0 + i * (frame.size.y - 8.0) / 8.0
		ci.draw_line(Vector2(frame.position.x + 8, y), Vector2(frame.end.x - 8, y), Color(1, 1, 1, 0.05 + 0.04 * (i % 2)), 1.0)
	Paint.panel(ci, Rect2(frame.position + Vector2(4, 2), Vector2(frame.size.x - 8, 3)), Color(1, 1, 1, 0.35), 2)
	var free_slot := -1
	for i in _slots:
		var c := Vector2(slot_x(i, _slots), 0.0)
		ci.draw_circle(c, HOLLOW_RADIUS, Tokens.STEEL_DARK, true, -1.0, true)
		ci.draw_circle(c + Vector2(0.8, 1.4), HOLLOW_RADIUS - 2.0, Tokens.STEEL_DARK.lightened(0.12), true, -1.0, true)
		ci.draw_arc(c, HOLLOW_RADIUS, PI * 0.1, PI * 0.9, 14, Color(1, 1, 1, 0.35), 1.4, true)
		ci.draw_arc(c, HOLLOW_RADIUS, PI * 1.15, PI * 1.85, 14, Color(0, 0, 0, 0.35), 1.4, true)
		if free_slot < 0 and (i >= _filled.size() or _filled[i] == 0):
			free_slot = i
	for x: float in [frame.position.x + 4.5, frame.end.x - 4.5]:
		var rc := Vector2(x, 0.0)
		ci.draw_circle(rc, 2.6, Tokens.STEEL_DARK, true, -1.0, true)
		ci.draw_circle(rc - Vector2(0.6, 0.6), 1.5, Color("e6e2da"), true, -1.0, true)
	if _warning and free_slot >= 0:
		_warning_mark(ci, Vector2(slot_x(free_slot, _slots), 1.0))
	if _full:
		var lid := Rect2(frame.end.x - 22.0, frame.position.y - 5.0, 18.0, 11.0)
		Paint.panel(ci, lid, Tokens.WARN_MARK, 3)
		Paint.panel(ci, lid.grow(-2.0), Tokens.WARN, 2)
		ci.draw_line(Vector2(lid.position.x + 4, lid.get_center().y), Vector2(lid.end.x - 4, lid.get_center().y), Tokens.WARN_MARK, 1.6, true)


## The triangle with an exclamation mark: warm fill, dark outline and mark (UX 3.2.2).
func _warning_mark(ci: CanvasItem, c: Vector2) -> void:
	var tri := PackedVector2Array([c + Vector2(0.0, -13.0), c + Vector2(13.5, 11.0), c + Vector2(-13.5, 11.0)])
	ci.draw_colored_polygon(tri, Tokens.WARN)
	ci.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Tokens.WARN_MARK, 2.0, true)
	ci.draw_line(c + Vector2(0.0, -5.0), c + Vector2(0.0, 3.0), Tokens.WARN_MARK, 2.4, true)
	ci.draw_circle(c + Vector2(0.0, 7.0), 1.6, Tokens.WARN_MARK, true, -1.0, true)
