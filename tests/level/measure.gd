# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Draw calls and frame time of a level, on this PC. Needs a window:
##   C:/Tools/Godot/Godot_v4.7.2-stable_win64.exe --path . -s res://tests/level/measure.gd
## Draws a mid play level (a tier 6 numbered level a few taps in, with the helper row and the
## cup) in a 1080 x 2400 viewport, once at rest and once with screws flying, and prints the draw
## calls (of the whole frame; the window itself draws nothing else) and the CPU and GPU render
## time of that viewport.

const SCENE := "res://src/level/level_scene.tscn"
const PIXELS := Vector2i(1080, 2400)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not LevelCatalog.load_all():
		print("The game data failed to load.")
		quit(1)
		return
	var n := 40
	while Tuning.tier_for_level(n) != 6:
		n += 1
	var g := LevelCatalog.get_level(LevelData.NUMBERED, n, "")
	var vp := SubViewport.new()
	vp.size = PIXELS
	var units := Vector2(PIXELS) / minf(PIXELS.x / 360.0, PIXELS.y / 640.0)
	vp.size_2d_override = Vector2i(roundi(units.x), roundi(units.y))
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	var scene: Variant = (load(SCENE) as PackedScene).instantiate()
	vp.add_child(scene)
	scene.set_layout_size(Vector2(roundi(units.x), roundi(units.y)))
	scene.set_coffee(true)
	scene.set_star_bank(12)
	scene.set_helpers({"undo": 2, "extra_slot": 1, "screwdriver": 1}, PackedStringArray(["undo", "extra_slot", "screwdriver"]))
	scene.play(g.level, false)
	await create_timer(1.0).timeout
	var solution: PackedInt32Array = g.solve.solution
	for i: int in 4:
		scene.tap_screw(solution[i])
		await create_timer(0.7).timeout
	await create_timer(1.0).timeout
	print("level %d (tier %d), %d screws, %d planks, viewport %s px" % [n, g.level.tier, g.level.screw_count(), g.level.planks.size(), str(PIXELS)])
	await _measure(vp, "at rest")
	# Where the draw calls go: hide one part at a time.
	for part: String in ["_board_view", "_plank_clip", "_screw_layer", "_box_root", "_hud", "_marks"]:
		var node: CanvasItem = scene.get(part)
		node.visible = false
		await _measure(vp, "  without " + part)
		node.visible = true
	# Three screws in the air at once.
	for i: int in range(4, 7):
		scene.tap_screw(solution[i])
	await create_timer(0.3).timeout
	await _measure(vp, "three screws flying")
	quit(0)


@warning_ignore("integer_division")
func _measure(vp: SubViewport, what: String) -> void:
	var rid := vp.get_viewport_rid()
	var counts := PackedInt32Array()
	var cpu := 0.0
	var gpu := 0.0
	var frames := 60
	for i: int in frames:
		await process_frame
		counts.append(int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	counts.sort()
	var calls := counts[counts.size() / 2]
	print("%s: %d draw calls (min %d, max %d), render cpu %.2f ms, gpu %.2f ms (mean of %d frames)" % [what, calls, counts[0], counts[counts.size() - 1], cpu / frames, gpu / frames, frames])
