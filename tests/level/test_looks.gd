# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Looks changed while a level is kept alive (refresh_looks), and a new level started on a scene
## that was paused (play always starts unpaused).

const Kit := preload("res://tests/level/kit.gd")
const Levels := preload("res://tests/level/levels.gd")

var _saved := {}


func _restore() -> void:
	Looks.current = _saved.duplicate()


func _screw_symbols(scene: LevelScene) -> Array[int]:
	var out: Array[int] = []
	var screws: Array = scene.get("_screws")
	for slot: Variant in screws:
		var view: ScrewView = slot.view as ScrewView
		out.append(int((view.material as ShaderMaterial).get_shader_parameter("symbol")))
	return out


func test_refresh_looks_applies_the_symbols_setting_and_keeps_the_state() -> void:
	_saved = Looks.current.duplicate()
	var scene := Kit.make_scene(self, Levels.cascade_level(), true)
	for s: int in [0, 1, 2, 3, 4, 6]:
		scene.tap_screw(s)
	var state_before := scene.get_state().snapshot()
	var picture_before := scene.debug_snapshot()
	check(_screw_symbols(scene).any(func(v: int) -> bool: return v >= 0), "symbols are on to begin with")
	Looks.current["symbols"] = false
	scene.refresh_looks()
	var symbols := _screw_symbols(scene)
	check(symbols.all(func(v: int) -> bool: return v == -1), "every screw draws without symbols: %s" % str(symbols))
	check_eq(scene.get_state().snapshot(), state_before, "the state is untouched")
	var after := scene.debug_snapshot()
	check_eq(after["screws"], picture_before["screws"], "every screw is where it was")
	check_eq(after["planks"], picture_before["planks"], "every plank has its pose")
	check_eq(after["boxes"], picture_before["boxes"], "the boxes hold what they held")
	check_eq(after["tray"], picture_before["tray"], "and the tray")
	check_eq(Kit.mismatches(scene).size(), 0, "the picture agrees: %s" % "; ".join(Kit.mismatches(scene)))
	Looks.current["symbols"] = true
	scene.refresh_looks()
	check(_screw_symbols(scene).any(func(v: int) -> bool: return v >= 0), "and back on")
	_restore()


func test_refresh_looks_keeps_covered_screws_the_hand_and_bakes_again() -> void:
	_saved = Looks.current.duplicate()
	var g := Kit.numbered(4)
	var scene := Kit.make_scene(self, g.level, false)
	await Kit.settle(self, scene)
	await frames(30)
	var hand_before: bool = scene.debug_snapshot()["hint"]
	var covered_before: Dictionary = scene.debug_snapshot()["covered"]
	var planks: Array = scene.get("_planks")
	Looks.current["wood"] = "walnut" if Looks.current.get("wood") != "walnut" else "oak"
	scene.refresh_looks()
	check(not (planks[0].view as PlankView).is_baked(), "setting a plank up again clears its bake")
	await frames(10)
	var all_baked := true
	for slot: Variant in planks:
		all_baked = all_baked and (slot.view as PlankView).is_baked()
	check(all_baked, "and every plank is baked again")
	check_eq(scene.debug_snapshot()["covered"], covered_before, "covered screws stay covered")
	check_eq(scene.debug_snapshot()["hint"], hand_before, "the hand stays")
	check_eq(Kit.mismatches(scene).size(), 0, "the picture agrees: %s" % "; ".join(Kit.mismatches(scene)))
	_restore()


func test_play_after_a_pause_starts_unpaused_and_listening() -> void:
	var first := Kit.numbered(5)
	var scene := Kit.make_scene(self, first.level, false)
	await Kit.settle(self, scene)
	scene.tap_screw(first.solve.solution[0])
	scene.hold_clock(true)
	scene.pause()
	check(scene.debug_snapshot()["board_covered"], "paused and covered")
	var second := Kit.numbered(6)
	scene.play(second.level, false)
	var snap := scene.debug_snapshot()
	check(not snap["paused"] and not snap["board_covered"], "the new level is shown")
	check(not snap["clock_running"] and snap["elapsed_ms"] == 0, "with a fresh clock")
	await frames(20)
	var r := scene.tap_screw(second.solve.solution[0])
	check(r.ok, "it takes taps")
	check(scene.debug_snapshot()["clock_running"], "and the clock runs")
	# The same through retry, and through a touch.
	scene.pause()
	scene.retry()
	check(not scene.debug_snapshot()["paused"], "retry starts unpaused too")
	var l := scene.get_layout()
	var at := l.gu_to_scene(second.level.screw_center(second.solve.solution[0]))
	var touch := InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = true
	scene.call("_gui_input", touch)
	check(not scene.get_state().is_on_board(second.solve.solution[0]), "a touch takes the screw")
