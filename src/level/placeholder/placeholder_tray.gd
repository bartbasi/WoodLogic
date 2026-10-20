# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name PlaceholderTray
extends Node2D
## The placeholder tray: a steel frame with a dark hollow for each slot. At one free slot the
## frame turns a warm tone and a warning triangle shows in the free slot; when full, a closed
## lid mark shows in the corner (UX 3.2.2). Same setup and methods as docs/ARCHITECTURE.md 7's
## TrayView, plus set_filled, which the contract's TrayView lacks (see the level report). The
## origin is the center of the frame.

const STEEL := Color("8c9096")
const STEEL_WARM := Color("d49a45")
const RIVET := Color("565a60")
const HOLLOW := Color("33373c")
const WARN_MARK := Color("2a1708")
const WARN_FILL := Color("e9a23b")

var _slots := 5
var _warning := false
var _full := false
var _filled := PackedByteArray()


func setup(slots: int) -> void:
	_slots = slots
	_filled.resize(slots)
	queue_redraw()


func set_warning(on: bool) -> void:
	_warning = on
	queue_redraw()


func set_full(on: bool) -> void:
	_full = on
	queue_redraw()


## Which slots hold a screw (1) or are free (0), so the warning can sit in a free slot.
func set_filled(slots_filled: PackedByteArray) -> void:
	_filled = slots_filled
	queue_redraw()


func _draw() -> void:
	var w := LevelLayout.tray_width(_slots)
	var frame := Rect2(-w * 0.5, -LevelLayout.TRAY_H * 0.5, w, LevelLayout.TRAY_H)
	var tone := STEEL_WARM if (_warning or _full) else STEEL
	draw_rect(frame, tone)
	draw_rect(frame, RIVET, false, 2.0)
	draw_circle(Vector2(frame.position.x + 4.0, frame.position.y + 4.0), 1.8, RIVET)
	draw_circle(Vector2(frame.end.x - 4.0, frame.position.y + 4.0), 1.8, RIVET)
	draw_circle(Vector2(frame.position.x + 4.0, frame.end.y - 4.0), 1.8, RIVET)
	draw_circle(Vector2(frame.end.x - 4.0, frame.end.y - 4.0), 1.8, RIVET)
	var free_slot := -1
	for i: int in _slots:
		var cx := LevelLayout.tray_slot_x(i, _slots)
		draw_rect(Rect2(cx - 19.0, -19.0, 38.0, 38.0), HOLLOW)
		if (i >= _filled.size() or _filled[i] == 0) and free_slot < 0:
			free_slot = i
	if _warning and free_slot >= 0:
		var c := Vector2(LevelLayout.tray_slot_x(free_slot, _slots), 2.0)
		var tri := PackedVector2Array([c + Vector2(0.0, -13.0), c + Vector2(13.0, 11.0), c + Vector2(-13.0, 11.0)])
		draw_colored_polygon(tri, WARN_FILL)
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), WARN_MARK, 2.0, true)
		draw_line(c + Vector2(0.0, -5.0), c + Vector2(0.0, 3.0), WARN_MARK, 2.4)
		draw_circle(c + Vector2(0.0, 7.0), 1.6, WARN_MARK)
	if _full:
		var lid := Rect2(frame.end.x - 18.0, frame.position.y - 2.0, 16.0, 10.0)
		draw_rect(lid, WARN_MARK)
		draw_rect(lid, WARN_FILL, false, 1.5)
