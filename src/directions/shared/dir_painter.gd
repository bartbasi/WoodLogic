# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name DirPainter
extends Node2D
## A node that draws whatever its callable draws, so a style can paint backgrounds, boxes,
## buttons and text with plain _draw calls at the right place in the draw order.

var paint := Callable()


func _init(fn: Callable = Callable()) -> void:
	paint = fn


func _draw() -> void:
	if paint.is_valid():
		paint.call(self)
