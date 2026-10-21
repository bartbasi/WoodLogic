# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The effect each action of the level scene plays (docs/ARCHITECTURE.md 10.2 and 11.5). The Audio
## autoload keeps `last_played` and `play_count`, so a test can see what was played and when.

const Kit := preload("res://tests/level/kit.gd")
const Levels := preload("res://tests/level/levels.gd")

var _scene: LevelScene
var _spy: Spy


## Stands in for the Audio autoload and writes down every effect asked for, in order.
class Spy extends Node:
	var log: Array[String] = []

	func play(effect: String, _pitch: float = 1.0, _volume_db: float = 0.0) -> void:
		log.append(effect)


func _make(level: LevelData) -> LevelScene:
	_scene = Kit.make_scene(self, level, false)
	_spy = add_node(Spy.new()) as Spy
	_scene.set("_audio", _spy)
	return _scene


## Waits `count` frames and gives back what was played meanwhile, in order.
func _heard(count: int) -> Array[String]:
	_spy.log.clear()
	await frames(count)
	return _spy.log.duplicate()


func _last() -> String:
	return _spy.log[_spy.log.size() - 1] if not _spy.log.is_empty() else ""


func test_a_tap_on_a_screw_ratchets_pops_and_clinks() -> void:
	var g := Kit.numbered(2)
	var scene := _make(g.level)
	await Kit.settle(self, scene)
	await frames(30)
	_spy.log.clear()
	scene.tap_screw(g.solve.solution[0])
	check_eq(_last(), "ratchet", "the ratchet plays in the same call as the tap")
	var heard := await _heard(60)
	check(heard.has("pop"), "the pop as it comes free: %s" % str(heard))
	check(heard.has("clink"), "the clink as it lands: %s" % str(heard))


func test_a_screw_to_the_tray_clinks_dull_and_the_warning_ticks_once() -> void:
	var scene := _make(Levels.cascade_level())
	await Kit.settle(self, scene)
	await frames(30)
	var heard: Array[String] = []
	for s: int in [0, 1, 2, 3]:
		scene.tap_screw(s)
		heard.append_array(await _heard(45))
	check(heard.has("clink_tray"), "the tray's clink: %s" % str(heard))
	check_eq(heard.count("tick"), 1, "one tick as the tray reaches one free slot: %s" % str(heard))
	scene.tap_screw(4)
	var more := await _heard(45)
	check(not more.has("tick"), "and none when it fills")


func test_covered_and_refused_taps_knock_dull() -> void:
	var scene := _make(Levels.swing_level())
	await Kit.settle(self, scene)
	scene.tap_screw(1)
	scene.tap_screw(Levels.SWING_COVERED)
	check_eq(_last(), "knock_dull", "a covered tap")
	var full := _make(Levels.cascade_level())
	await Kit.settle(self, full)
	for s: int in [0, 1, 2, 3, 4]:
		full.tap_screw(s)
	full.tap_screw(5)
	check_eq(_last(), "knock_dull", "a refused tap")


func test_taps_on_a_plank_and_on_bare_board_are_quiet_taps() -> void:
	var scene := _make(Levels.swing_level())
	await Kit.settle(self, scene)
	await frames(30)
	var l := scene.get_layout()
	scene.tap_at(l.gu_to_scene(Vector2(43.0, 62.0)))
	check_eq(_last(), "tap", "a tap on a plank")
	scene.tap_screw(1)
	scene.tap_screw(0)
	await frames(10)
	scene.tap_at(l.gu_to_scene(Vector2(80.0, 10.0)))
	check_eq(_last(), "tap", "a tap on the empty board")


func test_the_level_start_taps_the_planks_in() -> void:
	var g := Kit.numbered(Kit.level_of_tier(4, 12))
	_make(g.level)
	var heard := await _heard(30)
	check(heard.has("tap"), "planks drop in with taps: %s" % str(heard))


func test_a_swing_creaks_and_a_fall_knocks() -> void:
	var scene := _make(Levels.swing_level())
	await Kit.settle(self, scene)
	scene.tap_screw(Levels.SWING_SOLUTION[0])
	check_eq(_last(), "creak", "the swing")
	await Kit.settle(self, scene)
	scene.tap_screw(Levels.SWING_SOLUTION[1])
	var heard := await _heard(20)
	check(heard.has("knock"), "the plank's knock as it leaves: %s" % str(heard))


func test_the_lid_closes_with_a_lid_sound() -> void:
	var scene := _make(Levels.cascade_level())
	await Kit.settle(self, scene)
	for s: int in [0, 1, 2, 3, 4, 6, 7]:
		scene.tap_screw(s)
		await frames(2)
	await Kit.settle(self, scene)
	_spy.log.clear()
	scene.tap_screw(8)
	var heard := await _heard(60)
	heard.insert(0, _last())
	check(heard.has("lid"), "the lid: %s" % str(heard))


func test_helpers_play_their_own_effects() -> void:
	var scene := _make(Levels.cascade_level())
	scene.set_helpers({"undo": 2, "extra_slot": 2, "screwdriver": 2}, PackedStringArray(["undo", "extra_slot", "screwdriver"]))
	await Kit.settle(self, scene)
	await frames(30)
	scene.tap_screw(0)
	_spy.log.clear()
	scene.use_helper("undo")
	check_eq(_spy.log, ["undo"] as Array[String], "Undo plays its sound and nothing from the flights it finishes")
	_spy.log.clear()
	scene.use_helper("extra_slot")
	check_eq(_spy.log, ["wood_pop"] as Array[String], "Extra slot")
	_spy.log.clear()
	scene.use_helper("screwdriver")
	check_eq(_spy.log, ["tick"] as Array[String], "the Screwdriver tap")


func test_the_real_audio_autoload_sees_the_same_calls() -> void:
	# The scene talks to the Audio autoload by default; its own counters show what was played.
	var g := Kit.numbered(2)
	var scene := Kit.make_scene(self, g.level, false)
	await Kit.settle(self, scene)
	await frames(30)
	var audio := tree.root.get_node("Audio")
	var before := int(audio.get("play_count"))
	scene.tap_screw(g.solve.solution[0])
	check_eq(String(audio.get("last_played")), "ratchet", "the autoload heard the ratchet")
	check(int(audio.get("play_count")) > before, "and counted it")
