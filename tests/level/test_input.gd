# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Touch input and hit testing (UX 6.1 and 7.3): a free screw is hit by a circle of 24 design
## units at any board scale, never overlapping another one, and the board answers on touch down.

const Kit := preload("res://tests/level/kit.gd")
const Levels := preload("res://tests/level/levels.gd")

var _paused := 0


func _on_pause_requested() -> void:
	_paused += 1


func _touch(scene: LevelScene, p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = p
	e.pressed = pressed
	scene.call("_gui_input", e)


func test_every_pair_of_screws_is_far_enough_apart_that_targets_never_overlap() -> void:
	var levels: Array[LevelData] = [Levels.swing_level(), Levels.cascade_level()]
	for n: int in range(1, 9):
		levels.append(Kit.numbered(n).level)
	for tier: int in LevelCatalog.fallback.size():
		for g: GeneratedLevel in LevelCatalog.fallback[tier]:
			levels.append(g.level)
	check(levels.size() > 40, "checked %d levels" % levels.size())
	for level: LevelData in levels:
		for a: int in level.screw_count():
			for b: int in range(a + 1, level.screw_count()):
				var d := level.screw_center(a).distance_to(level.screw_center(b))
				if d < 2.0 * LevelHit.RADIUS_GU:
					check(false, "%s: screws %d and %d are %.1f gu apart, their targets overlap" % [level.id, a, b, d])
					return


func test_the_target_is_a_circle_of_24_units_at_every_board_scale() -> void:
	var g := Kit.numbered(2)
	var scene := Kit.make_scene(self, g.level, true)
	for area: Vector2 in [Vector2(360, 640), Vector2(840, 720)]:
		scene.set_layout_size(area)
		var l := scene.get_layout()
		var s: int = g.solve.solution[0]
		var center := l.gu_to_scene(g.level.screw_center(s))
		var radius := 24.0 * l.b
		check_eq(LevelHit.free_screw(scene.get_state(), l.scene_to_gu(center + Vector2(radius - 1.0, 0.0))), s, "inside the circle at b %.2f" % l.b)
		check_eq(LevelHit.free_screw(scene.get_state(), l.scene_to_gu(center + Vector2(0.0, -(radius - 1.0)))), s, "inside, above, at b %.2f" % l.b)
		check_eq(LevelHit.free_screw(scene.get_state(), l.scene_to_gu(center + Vector2(radius + 1.0, 0.0))), -1, "outside the circle at b %.2f" % l.b)
	scene.set_layout_size(Vector2(840, 720))
	var l2 := scene.get_layout()
	var first: int = g.solve.solution[0]
	var r := scene.get_level().screw_center(first)
	scene.tap_at(l2.gu_to_scene(r) + Vector2(20.0 * l2.b, 0.0))
	check(not scene.get_state().is_on_board(first), "a tap 20 units from the center, scaled with the board, takes the screw")


func test_a_touch_acts_on_touch_down_and_an_emulated_click_is_ignored() -> void:
	var g := Kit.numbered(2)
	var scene := Kit.make_scene(self, g.level, true)
	var first: int = g.solve.solution[0]
	var at := scene.get_layout().gu_to_scene(g.level.screw_center(first))
	# An emulated mouse click (what a touch also sends) does nothing on its own.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = at
	click.device = InputEvent.DEVICE_ID_EMULATION
	scene.call("_gui_input", click)
	check(scene.get_state().is_on_board(first), "an emulated click is not a second tap")
	_touch(scene, at, true)
	check(not scene.get_state().is_on_board(first), "the screw is taken on touch down, before the finger lifts")
	_touch(scene, at, false)
	# A real mouse click on the next screw works (desktop).
	var second: int = g.solve.solution[1]
	var real := InputEventMouseButton.new()
	real.button_index = MOUSE_BUTTON_LEFT
	real.pressed = true
	real.position = scene.get_layout().gu_to_scene(g.level.screw_center(second))
	scene.call("_gui_input", real)
	check(not scene.get_state().is_on_board(second), "a mouse click takes a screw")


func test_covered_screws_planks_and_bare_board_answer_without_changing_the_state() -> void:
	var scene := Kit.make_scene(self, Levels.swing_level(), false)
	await Kit.settle(self, scene)
	scene.tap_screw(1)
	var l := scene.get_layout()
	var level := scene.get_level()
	var state_before := scene.get_state().snapshot()
	# A covered screw: the plank in front wiggles, the screw's ring and the plank's edge glow.
	scene.tap_at(l.gu_to_scene(level.screw_center(Levels.SWING_COVERED)))
	check_eq(scene.get_state().snapshot(), state_before, "a covered tap changes nothing")
	check(scene.debug_snapshot()["marks"] >= 2, "the ring and the edge glow show")
	await frames(60)
	check_eq(scene.debug_snapshot()["marks"], 0, "and fade after 0.6 s plus the fades")
	# Bare board inside the panel: a ripple.
	var bare := l.gu_to_scene(Vector2(80.0, 10.0))
	check_eq(LevelHit.plank(scene.get_state(), l.scene_to_gu(bare)), -1, "nothing there")
	scene.tap_at(bare)
	check_eq(scene.debug_snapshot()["marks"], 1, "a ripple spreads from a tap on the bare board")
	check_eq(scene.get_state().snapshot(), state_before, "and nothing changes")
	# On a plank, away from its screws: no change.
	await frames(30)
	var on_plank := l.gu_to_scene(Vector2(30.0, 75.0))
	check(LevelHit.plank(scene.get_state(), l.scene_to_gu(on_plank)) >= 0, "the swung bar is there")
	scene.tap_at(on_plank)
	check_eq(scene.get_state().snapshot(), state_before, "a tap on a plank changes nothing")


func test_the_pause_button_acts_on_release_inside_it() -> void:
	var scene := Kit.make_scene(self, Kit.numbered(5).level, true)
	scene.pause_requested.connect(_on_pause_requested)
	var l := scene.get_layout()
	var inside := l.top_bar.end - Vector2(28.0, 20.0)
	_paused = 0
	_touch(scene, inside, true)
	check_eq(_paused, 0, "nothing on press")
	_touch(scene, inside, false)
	check_eq(_paused, 1, "pause_requested on release")
	_touch(scene, inside, true)
	_touch(scene, Vector2(10.0, 300.0), false)
	check_eq(_paused, 1, "a finger that slides off cancels it")
	check_eq(scene.get_state().tray_uses(), 0, "and a press on the button is not a tap on the board")
