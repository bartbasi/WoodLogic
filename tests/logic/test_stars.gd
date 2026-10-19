# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Stars (GDD S1 to S8, R32).

const Kit := preload("res://tests/logic/kit.gd")


func _level(tray_par: int, par_time_s: int, kind: int = LevelData.NUMBERED) -> LevelData:
	var errors := PackedStringArray()
	var base := Kit.level([Kit.bar(0, [[20, 45], [66, 45]], 10, [[22, 45], [43, 45], [64, 45]], [0, 0, 0])], [0])
	var level := base.with_colors(base.screw_colors, base.queue, errors)
	level.kind = kind
	level.tray_par = tray_par
	level.par_time_s = par_time_s
	return level


func test_s1_a_win_clears_and_a_loss_earns_nothing() -> void:
	var level := _level(2, 60)
	check_eq(Stars.award(level, true, 999999, 99, PackedStringArray(["undo"])), Vector3i(1, 0, 0), "a slow messy win still clears")
	check_eq(Stars.award(level, false, 1000, 0, PackedStringArray()), Vector3i.ZERO, "a loss earns nothing")


func test_s2_s6_fast_at_exactly_par_and_not_one_second_over() -> void:
	var level := _level(2, 60)
	check_eq(Stars.award(level, true, 60000, 0, PackedStringArray()).y, 1, "60.000 s on a 60 s par")
	check_eq(Stars.award(level, true, 60001, 0, PackedStringArray()).y, 0, "60.001 s")
	check_eq(Stars.award(level, true, 61000, 0, PackedStringArray()).y, 0, "par plus one second")
	check_eq(Stars.award(level, true, 10000, 0, PackedStringArray(["screwdriver"])).y, 1, "helpers are allowed for Fast")


func test_s3_r32_clean_lost_by_one_tray_use_over_par_or_any_helper() -> void:
	var level := _level(2, 60)
	check_eq(Stars.award(level, true, 1000, 2, PackedStringArray()).z, 1, "at tray par")
	check_eq(Stars.award(level, true, 1000, 3, PackedStringArray()).z, 0, "one over")
	for helper: String in ["undo", "extra_slot", "screwdriver"]:
		check_eq(Stars.award(level, true, 1000, 0, PackedStringArray([helper])).z, 0, "Clean is lost by %s" % helper)


func test_s4_stars_are_independent() -> void:
	var level := _level(1, 30)
	check_eq(Stars.award(level, true, 99000, 0, PackedStringArray()), Vector3i(1, 0, 1), "Clean without Fast")
	check_eq(Stars.award(level, true, 1000, 5, PackedStringArray()), Vector3i(1, 1, 0), "Fast without Clean")
	check_eq(Stars.award(level, true, 1000, 0, PackedStringArray()), Vector3i(1, 1, 1), "all three")


func test_relaxed_has_no_stars() -> void:
	check_eq(Stars.award(_level(2, 60, LevelData.RELAXED), true, 1000, 0, PackedStringArray()), Vector3i.ZERO, "Relaxed")


func test_s8_par_time_examples() -> void:
	check_eq(Stars.par_time(18, 35), 75, "18 screws at 3.5 s: 73, so 75")
	check_eq(Stars.par_time(30, 40), 130, "30 screws at 4.0 s")
	check_eq(Stars.par_time(36, 45), 175, "36 screws at 4.5 s: 172, so 175")
	check_eq(Stars.par_time(3, 60), 30, "tutorial 1: 3 screws at 6 s")
	check_eq(Stars.par_time(24, 35), 95, "a mid level of 24 screws gets 1:35")
