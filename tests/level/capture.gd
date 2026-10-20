# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Screenshots of the level scene. Needs a window (headless draws nothing):
##   C:/Tools/Godot/Godot_v4.7.2-stable_win64.exe --path . -s res://tests/level/capture.gd
## Saves PNGs to build/shots/. Add "-- tiers" to shoot the first stored level of every tier instead.
## Each size is drawn in a SubViewport laid out the way the engine's
## stretch settings (canvas_items, expand) lay out a window of that many pixels.

const OUT := "res://build/shots"
const SCENE := "res://src/level/level_scene.tscn"
## name, window pixels, dp per design unit (0 for the default)
const SIZES := [
	["phone-360x640", Vector2i(360, 640), 0.0],
	["phone-412x915", Vector2i(412, 915), 0.0],
	["foldable-1080x1200", Vector2i(1080, 1200), 0.0],
	["foldable-split-840x720units", Vector2i(1680, 1440), 1.25],
	["tablet-1200x1920", Vector2i(1200, 1920), 2.14],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if not LevelCatalog.load_all():
		print("The game data failed to load.")
		quit(1)
		return
	if OS.get_cmdline_user_args().has("tiers"):
		await _shoot_tiers()
		quit(0)
		return
	var tier_six := _level_of_tier(6, 30)
	var g := LevelCatalog.get_level(LevelData.NUMBERED, tier_six, "")
	print("mid level shots on level %d (tier %d, %d screws)" % [tier_six, g.level.tier, g.level.screw_count()])
	for entry: Array in SIZES:
		await _shoot_size(entry, g)
	# One mid flight frame and one mid swing frame, on the phone size.
	await _shoot_flight(g)
	await _shoot_swing()
	await _shoot_hang()
	await _shoot_hand()
	await _shoot_cascade()
	print("done")
	quit(0)


func _level_of_tier(tier: int, from: int) -> int:
	var n := from
	while Tuning.tier_for_level(n) != tier:
		n += 1
	return n


func _units(pixels: Vector2i) -> Vector2:
	var scale := minf(pixels.x / 360.0, pixels.y / 640.0)
	return Vector2(pixels) / scale


func _scene_in(pixels: Vector2i, dpu: float) -> Array:
	var vp := SubViewport.new()
	vp.size = pixels
	var units := _units(pixels)
	vp.size_2d_override = Vector2i(roundi(units.x), roundi(units.y))
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene: Variant = (load(SCENE) as PackedScene).instantiate()
	scene.dp_per_unit = dpu
	vp.add_child(scene)
	scene.set_layout_size(Vector2(roundi(units.x), roundi(units.y)))
	return [vp, scene]


func _save(vp: SubViewport, file: String) -> void:
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT.path_join(file))
	image.save_png(path)
	print("saved ", path, " ", image.get_size())


func _shoot_size(entry: Array, g: GeneratedLevel) -> void:
	var made := _scene_in(entry[1], entry[2])
	var vp: SubViewport = made[0]
	var scene: Variant = made[1]
	scene.set_instant(true)
	scene.play(g.level, false)
	for i: int in 4:
		scene.tap_screw(g.solve.solution[i])
	scene.set_instant(false)
	await create_timer(0.4).timeout
	var l: LevelLayout = scene.get_layout()
	print("%s: units %s, split %s, b %.2f, f %.2f" % [entry[0], str(_units(entry[1])), str(l.split), l.b, l.f])
	await _save(vp, "%s.png" % entry[0])
	vp.queue_free()
	await process_frame


func _shoot_flight(g: GeneratedLevel) -> void:
	var made := _scene_in(Vector2i(412, 915), 0.0)
	var vp: SubViewport = made[0]
	var scene: Variant = made[1]
	scene.set_instant(true)
	scene.play(g.level, false)
	for i: int in 4:
		scene.tap_screw(g.solve.solution[i])
	scene.set_instant(false)
	await create_timer(0.4).timeout
	scene.tap_screw(g.solve.solution[4])
	await create_timer(0.3).timeout
	scene.tap_screw(g.solve.solution[5])
	await create_timer(0.12).timeout
	await _save(vp, "midflight-412x915.png")
	vp.queue_free()
	await process_frame


func _shoot_swing() -> void:
	var g := LevelCatalog.get_level(LevelData.NUMBERED, 6, "")
	var made := _scene_in(Vector2i(412, 915), 0.0)
	var vp: SubViewport = made[0]
	var scene: Variant = made[1]
	scene.set_instant(true)
	scene.play(g.level, false)
	var swung := false
	for s: int in g.solve.solution:
		var r: TapResult = scene.tap_screw(s)
		if r.kinds().has(LogicEvent.PLANK_SWUNG):
			swung = true
			scene.set_instant(false)
			await create_timer(0.0).timeout
			break
	print("swing level reached a swing: ", swung)
	scene.set_instant(false)
	# The swing started at the tap in instant mode and jumped; tap the next one animated.
	for s: int in g.solve.solution:
		if scene.get_state().is_on_board(s) and scene.get_state().is_free(s):
			var r: TapResult = scene.tap_screw(s)
			if r.kinds().has(LogicEvent.PLANK_SWUNG):
				await create_timer(0.2).timeout
				break
			await create_timer(0.7).timeout
	await _save(vp, "midswing-412x915.png")
	vp.queue_free()
	await process_frame


func _shoot_hand() -> void:
	var g := LevelCatalog.get_level(LevelData.NUMBERED, 1, "")
	var made := _scene_in(Vector2i(360, 640), 0.0)
	var vp: SubViewport = made[0]
	var scene: Variant = made[1]
	scene.play(g.level, false)
	await create_timer(1.0).timeout
	await _save(vp, "tutorial1-hand-360x640.png")
	vp.queue_free()
	await process_frame


## The tray filling up, then a box closing with tray screws jumping into the next one.
func _shoot_cascade() -> void:
	var levels: GDScript = load("res://tests/level/levels.gd")
	var level: LevelData = levels.cascade_level()
	var taps: Array[int] = levels.CASCADE_SOLUTION
	var made := _scene_in(Vector2i(360, 640), 0.0)
	var vp: SubViewport = made[0]
	var scene: Variant = made[1]
	scene.play(level, false)
	await create_timer(0.6).timeout
	for i: int in 5:
		scene.tap_screw(taps[i])
		await create_timer(0.15).timeout
	await create_timer(0.8).timeout
	await _save(vp, "tray-full-360x640.png")
	scene.tap_screw(taps[5])
	await create_timer(0.1).timeout
	scene.tap_screw(taps[6])
	await create_timer(0.1).timeout
	scene.tap_screw(taps[7])
	await create_timer(0.85).timeout
	await _save(vp, "box-closing-360x640.png")
	await create_timer(0.35).timeout
	await _save(vp, "tray-jumping-360x640.png")
	await create_timer(1.5).timeout
	await _save(vp, "cascade-done-360x640.png")
	vp.queue_free()
	await process_frame


## The first stored level of every tier, as it opens, to look at every plank shape.
func _shoot_tiers() -> void:
	for tier: int in range(1, 11):
		var g: GeneratedLevel = LevelCatalog.fallback[tier - 1][0]
		var made := _scene_in(Vector2i(360, 640), 0.0)
		var vp: SubViewport = made[0]
		var scene: Variant = made[1]
		scene.set_instant(true)
		scene.play(g.level, false)
		await create_timer(0.3).timeout
		await _save(vp, "tier-%02d-%s.png" % [tier, g.level.blueprint_id])
		vp.queue_free()
		await process_frame


## A bar hanging far below the board: it is cut off at the board panel (GDD V1).
func _shoot_hang() -> void:
	var levels: GDScript = load("res://tests/level/levels.gd")
	var level: LevelData = levels.hang_level()
	var made := _scene_in(Vector2i(360, 640), 0.0)
	var vp: SubViewport = made[0]
	var scene: Variant = made[1]
	scene.set_instant(true)
	scene.play(level, false)
	scene.tap_screw(0)
	await create_timer(0.3).timeout
	await _save(vp, "hang-clipped-360x640.png")
	vp.queue_free()
	await process_frame
