# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Screenshots of the tray at 3, 4, 5 and 6 slots, Extra slot, the shrink line and the closing.
## Needs a window (headless draws nothing):
##   C:/Tools/Godot/Godot_v4.7.2-stable_win64.exe --path . -s res://tests/level/capture_tray.gd
## Saves PNGs to build/shots-tray/. Each size is drawn in a SubViewport laid out the way the
## engine's stretch settings (canvas_items, expand) lay out a window of that many pixels.

const OUT := "res://build/shots-tray"
const SCENE := "res://src/level/level_scene.tscn"
const NOTE := "The tray is smaller now. Every slot counts."
## name, window pixels, dp per design unit
const SIZES := [
	["phone-360x640", Vector2i(360, 640), 1.0],
	["tablet-1200x1920", Vector2i(1200, 1920), 2.14],
	["split-1680x1440", Vector2i(1680, 1440), 1.25],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if not LevelCatalog.load_all():
		print("The game data failed to load.")
		quit(1)
		return
	for entry: Array in SIZES:
		await _shoot_trays(entry)
		await _shoot_note(entry)
	await _shoot_closing(SIZES[0])
	print("done")
	quit(0)


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


## A stored level with this many tray slots.
func _level(slots: int) -> GeneratedLevel:
	var n := 40
	var g := LevelCatalog.get_level(LevelData.NUMBERED, n, "")
	var errors := PackedStringArray()
	var copy := g.level.with_colors(g.level.screw_colors, g.level.queue, errors, {"tray": slots})
	var out := GeneratedLevel.new()
	out.level = copy
	out.solve = g.solve
	return out


## Taps the first `count` free screws that have nowhere but the tray to go, in an instant scene.
func _fill_tray(scene: Variant, level: LevelData, count: int) -> int:
	var put := 0
	var state: PlayState = scene.get_state()
	for s: int in level.screw_count():
		if put >= count:
			break
		if state.is_free(s) and state.destination(s).x == PlayState.TRAY:
			if (scene.tap_screw(s) as TapResult).ok:
				put += 1
	return put


func _shoot_trays(entry: Array) -> void:
	var name: String = entry[0]
	# 3 slots with two screws waiting (the warning), 4 slots with two waiting, 5 and 6 empty.
	for spec: Array in [[3, 2, "tray3"], [4, 2, "tray4"], [5, 1, "tray5"]]:
		var g := _level(spec[0])
		var made := _scene_in(entry[1], entry[2])
		var vp: SubViewport = made[0]
		var scene: Variant = made[1]
		scene.set_instant(true)
		scene.set_helpers({"undo": 2, "extra_slot": 2, "screwdriver": 2}, PackedStringArray(["undo", "extra_slot", "screwdriver"]))
		scene.play(g.level, false)
		var put := _fill_tray(scene, g.level, spec[1])
		print("%s %s: %d screws in the tray" % [name, spec[2], put])
		scene.set_instant(false)
		scene.refresh_looks()
		await create_timer(0.8).timeout
		await _save(vp, "%s-%s.png" % [spec[2], name])
		vp.queue_free()
		await process_frame
	# 3 slots plus Extra slot, with the three screws that now fit: a four slot tray, one free.
	var g3 := _level(3)
	var made3 := _scene_in(entry[1], entry[2])
	var vp3: SubViewport = made3[0]
	var scene3: Variant = made3[1]
	scene3.set_instant(true)
	scene3.set_helpers({"undo": 2, "extra_slot": 2, "screwdriver": 2}, PackedStringArray(["undo", "extra_slot", "screwdriver"]))
	scene3.play(g3.level, false)
	_fill_tray(scene3, g3.level, 2)
	scene3.set_instant(false)
	scene3.refresh_looks()
	await create_timer(0.6).timeout
	scene3.use_helper("extra_slot")
	await create_timer(0.1).timeout
	await _save(vp3, "tray3-extra-growing-%s.png" % name)
	await create_timer(0.6).timeout
	await _save(vp3, "tray3-extra-%s.png" % name)
	vp3.queue_free()
	await process_frame
	# 5 slots plus Extra slot: the widest tray, six slots.
	var g5 := _level(5)
	var made5 := _scene_in(entry[1], entry[2])
	var vp5: SubViewport = made5[0]
	var scene5: Variant = made5[1]
	scene5.set_instant(true)
	scene5.set_helpers({"undo": 2, "extra_slot": 2, "screwdriver": 2}, PackedStringArray(["undo", "extra_slot", "screwdriver"]))
	scene5.play(g5.level, false)
	_fill_tray(scene5, g5.level, 2)
	scene5.use_helper("extra_slot")
	scene5.set_instant(false)
	scene5.refresh_looks()
	await create_timer(0.8).timeout
	await _save(vp5, "tray5-extra-%s.png" % name)
	vp5.queue_free()
	await process_frame


func _shoot_note(entry: Array) -> void:
	var g := _level(4)
	var made := _scene_in(entry[1], entry[2])
	var vp: SubViewport = made[0]
	var scene: Variant = made[1]
	scene.set_helpers({"undo": 2, "extra_slot": 2, "screwdriver": 2}, PackedStringArray(["undo", "extra_slot", "screwdriver"]))
	scene.play(g.level, false)
	scene.show_tray_note(NOTE)
	await create_timer(1.4).timeout
	await _save(vp, "note-%s.png" % entry[0])
	vp.queue_free()
	await process_frame


## The closing, halfway: the old frame fading out as the new one slides in.
func _shoot_closing(entry: Array) -> void:
	var g := _level(4)
	var made := _scene_in(entry[1], entry[2])
	var vp: SubViewport = made[0]
	var scene: Variant = made[1]
	scene.play(g.level, false)
	scene.play_tray_closing()
	await create_timer(0.2).timeout
	await _save(vp, "closing-before-%s.png" % entry[0])
	await create_timer(0.45).timeout
	await _save(vp, "closing-mid-%s.png" % entry[0])
	await create_timer(0.6).timeout
	await _save(vp, "closing-after-%s.png" % entry[0])
	vp.queue_free()
	await process_frame
