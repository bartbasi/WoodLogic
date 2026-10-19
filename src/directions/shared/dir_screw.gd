# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name DirScrew
extends Node2D
## A free screw head drawn with screw.gdshader. `finish` holds the direction's metal and paint
## settings. The node is never rotated: `turn` spins the recess and the rim marks instead, so
## the light stays fixed while the screw turns under it.

const SHADER := preload("res://src/directions/shared/screw.gdshader")

var _rect := Rect2()


func setup(color_index: int, radius: float, finish: Dictionary, turn: float = 0.0) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var c := DirColors.color(color_index)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("head_color", c)
	mat.set_shader_parameter("symbol", DirColors.symbol(color_index))
	mat.set_shader_parameter("recess_light", 1.0 if DirColors.luminance(c) < 0.17 else 0.0)
	mat.set_shader_parameter("angle", turn)
	for key: String in finish:
		mat.set_shader_parameter(key, finish[key])
	material = mat
	var m := radius * 1.6
	_rect = Rect2(-m, -m, m * 2.0, m * 2.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(_rect, Color.WHITE)
