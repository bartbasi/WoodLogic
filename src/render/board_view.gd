# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BoardView
extends Node2D
## The workbench behind the level (docs/ARCHITECTURE.md 7, docs/DESIGN.md 7 and 8, docs/UX.md
## 3.2.1a): the lamp-lit pegboard over the whole screen, and the theme's back board panels on it,
## each casting a long soft shadow on the wall. Give it one panel for the stacked phone layout,
## or the board panel plus the rail and bars for the split layout, so it reads as one bench. In
## design units from its own origin. `bake()` draws the panels into textures like a plank.

const PEGBOARD := preload("res://src/render/shaders/pegboard.gdshader")
const PANEL_CORNER := 14.0

var _wall: Wall
var _panels: Array[PlankView] = []


## The pegboard, drawn by one full-screen quad.
class Wall extends Node2D:
	var size := Vector2(360, 640)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


func _init() -> void:
	_wall = Wall.new()
	var mat := ShaderMaterial.new()
	mat.shader = PEGBOARD
	mat.set_shader_parameter("board", Tokens.PEGBOARD)
	mat.set_shader_parameter("hole", Tokens.PEGBOARD_HOLE)
	mat.set_shader_parameter("noise_tex", WoodNoise.texture())
	_wall.material = mat
	add_child(_wall)


## `size` is the whole area to cover with pegboard (full bleed, behind the safe area insets);
## `panels` are the back board rects in the same units.
func setup(size: Vector2, panels: Array[Rect2]) -> void:
	_wall.size = size
	(_wall.material as ShaderMaterial).set_shader_parameter("size", size)
	_wall.queue_redraw()
	for p: PlankView in _panels:
		p.queue_free()
	_panels.clear()
	for i in panels.size():
		var p := PlankView.new()
		add_child(p)
		p.setup_panel(panels[i], PANEL_CORNER, 9001 + i)
		_panels.append(p)


## Draws the panels into their textures (call while hidden, like PlankView.bake).
func bake() -> void:
	for p: PlankView in _panels:
		p.bake()


func is_baked() -> bool:
	for p: PlankView in _panels:
		if not p.is_baked():
			return false
	return true
