# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name CachedDrawing
extends Node2D
## A view drawn with many small _draw calls (panels, circles, symbols) that changes only now and
## then. While it changes it draws live; once it has been still for two frames it draws itself
## once into a small texture and from then on is one textured rect, a single draw call instead of
## dozens (docs/DESIGN.md 10). Subclasses paint in `_paint(ci)` within `_paint_rect()` and call
## `repaint()` when their look changes. Frames are counted in _process, never awaited, so a view
## freed or taken out of the tree at any moment simply stops.

## Frames a view must stay unchanged before it is cached.
const SETTLE_FRAMES := 2
## Frames from asking the viewport to draw until its texture is ready.
const CAPTURE_FRAMES := 2
## At most this many texels a design unit.
const MAX_SCALE := 3.0
const CACHED_SHADER := preload("res://src/render/shaders/cached.gdshader")

var _live := true
var _viewport: SubViewport
var _canvas: _Canvas
var _settle := 0
## Frames left until a capture in progress is done; -1 when none is.
var _capture := -1
var _scale_cached := 0.0
var _blend: ShaderMaterial


class _Canvas extends Node2D:
	var view: CachedDrawing

	func _draw() -> void:
		view._paint(self)


## Draws the view. Everything must stay inside `_paint_rect()`.
func _paint(_ci: CanvasItem) -> void:
	pass


## The local area the painting covers, shadows included.
func _paint_rect() -> Rect2:
	return Rect2(0, 0, 1, 1)


## Call when the look changes: it draws live now and is cached again once still.
func repaint() -> void:
	_live = true
	material = null
	_settle = SETTLE_FRAMES
	_capture = -1
	set_process(true)
	queue_redraw()


func is_cached() -> bool:
	return not _live


func _ready() -> void:
	set_notify_transform(true)
	repaint()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and not _live and is_inside_tree():
		var s := _pixels_per_unit()
		if absf(s - _scale_cached) > _scale_cached * 0.05:
			repaint()


func _process(_delta: float) -> void:
	if not _live:
		set_process(false)
		return
	if _capture >= 0:
		_capture -= 1
		if _capture < 0:
			_finish_cache()
		return
	if _settle > 0:
		_settle -= 1
		return
	_start_cache()


func _start_cache() -> void:
	var rect := _paint_rect()
	var s := clampf(_pixels_per_unit(), 1.0, MAX_SCALE)
	var size := Vector2i(maxi(1, ceili(rect.size.x * s)), maxi(1, ceili(rect.size.y * s)))
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.transparent_bg = true
		_viewport.disable_3d = true
		_canvas = _Canvas.new()
		_canvas.view = self
		_viewport.add_child(_canvas)
		add_child(_viewport)
	_viewport.size = size
	_canvas.scale = Vector2(s, s)
	_canvas.position = -rect.position * s
	_canvas.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_scale_cached = s
	_capture = CAPTURE_FRAMES - 1


func _finish_cache() -> void:
	if _viewport == null or not is_inside_tree():
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _blend == null:
		# The texture holds premultiplied color (drawn over a clear background), so it is laid
		# down premultiplied too, or its soft edges would darken; the shader also applies the
		# node's modulate to color and alpha, so a modulate fade still works.
		_blend = ShaderMaterial.new()
		_blend.shader = CACHED_SHADER
	material = _blend
	_live = false
	set_process(false)
	queue_redraw()


func _draw() -> void:
	if _live or _viewport == null:
		_paint(self)
	else:
		draw_texture_rect(_viewport.get_texture(), _paint_rect(), false)


func _pixels_per_unit() -> float:
	var t := get_global_transform_with_canvas().get_scale()
	var f := get_viewport().get_final_transform().get_scale() if get_viewport() != null else Vector2.ONE
	return maxf(absf(t.x * f.x), absf(t.y * f.y))
