# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The Phase 4 parts of Save: helpers, stars spent, unlocks, the daily, Relaxed and reset.

const SaveScript := preload("res://src/save/save.gd")


func _new_save(test_name: String) -> Node:
	var s: Node = SaveScript.new()
	s.dir = "%s%s/" % [tree.root.get_node("Save").get("dir"), test_name]
	add_node(s)
	DirAccess.make_dir_recursive_absolute(s.dir)
	s.load_all()
	return s


func test_helpers_are_given_once_taken_and_never_below_zero() -> void:
	var s := _new_save("helpers")
	check_eq(s.helper_count("undo"), 0, "none at first")
	check(s.mark_helper_met("undo", 2), "the first explanation gives the free ones")
	check(not s.mark_helper_met("undo", 2), "and only once")
	check_eq(s.helper_count("undo"), 2, "two free")
	check(s.is_helper_met("undo"), "met")
	check(s.take_helper("undo"), "one used")
	check(s.take_helper("undo"), "two used")
	check(not s.take_helper("undo"), "none left")
	check_eq(s.helper_count("undo"), 0, "zero")
	s.add_helper("screwdriver", 1)
	check_eq(s.helper_counts()["screwdriver"], 1, "bought one")
	s.add_helper("hammer", 3)
	check(not s.helper_counts().has("hammer"), "an unknown helper is ignored")
	var again := _new_save("helpers")
	check_eq(again.helper_count("screwdriver"), 1, "saved")
	check(again.is_helper_met("undo"), "met is saved")


func test_stars_are_spent_from_the_bank_only() -> void:
	var s := _new_save("spend")
	s.record_win(LevelCatalog.get_level(LevelData.NUMBERED, 9, "").level, 9000, Vector3i(1, 1, 1))
	check_eq(s.star_bank(), 3, "bank")
	check(not s.spend_stars(4), "cannot overspend")
	check(s.spend_stars(2), "spend 2")
	check_eq(s.star_bank(), 1, "bank after")
	check_eq(s.stars_earned(), 3, "earned never drops")


func test_unlocks() -> void:
	var s := _new_save("unlocks")
	check(s.add_unlock("wood", "walnut"), "added")
	check(not s.add_unlock("wood", "walnut"), "not twice")
	check(not s.add_unlock("paint", "red"), "unknown kind")
	check(not s.add_unlock("wood", "../x"), "bad id")
	check_eq(Array(s.unlocked_ids("wood")), ["oak", "walnut"], "wood")
	check_eq(Array(s.unlocked_ids("metal")), ["steel"], "metal")
	s.set_look("walnut", "steel")
	check_eq(s.wood(), "walnut", "an unlocked wood is used")


func test_the_daily_streak() -> void:
	var s := _new_save("daily")
	var r: Dictionary = s.record_daily("2026-10-19", 50000, Vector3i(1, 1, 0))
	check_eq(r["streak"], 1, "first day")
	check_eq(r["gain"], 2, "stars")
	check(r["counted"], "counted")
	check(s.daily_done("2026-10-19"), "done")
	r = s.record_daily("2026-10-19", 40000, Vector3i(1, 1, 1))
	check(not r["counted"], "a replay does not move the streak")
	check_eq(r["gain"], 1, "only the stars above best")
	r = s.record_daily("2026-10-20", 60000, Vector3i(1, 0, 0))
	check_eq(r["streak"], 2, "the next day adds one")
	r = s.record_daily("2026-10-22", 60000, Vector3i(1, 0, 0))
	check_eq(r["streak"], 1, "a gap starts again")
	r = s.record_daily("2026-10-21", 60000, Vector3i(1, 0, 0))
	check(not r["counted"], "an earlier date does not count (the clock moved back)")
	var d: Dictionary = s.daily_record()
	check_eq(d["best_streak"], 2, "best streak")
	check_eq(d["solved"], 3, "solved counts counted days")
	check_eq(d["last_date"], "2026-10-22", "last date")
	var stats: Dictionary = s.progress_copy()["stats"]
	check_eq((stats["time"] as Dictionary)["medium"]["n"], 5, "the daily counts in Medium")


func test_a_streak_crosses_a_month_end() -> void:
	var s := _new_save("month")
	s.record_daily("2026-10-31", 1000, Vector3i(1, 0, 0))
	var r: Dictionary = s.record_daily("2026-11-01", 1000, Vector3i(1, 0, 0))
	check_eq(r["streak"], 2, "31 October then 1 November")


func test_relaxed_positions() -> void:
	var s := _new_save("relaxed")
	check_eq(s.relaxed_next("easy"), 0, "starts at 0")
	check_eq(s.relaxed_last_band(), "", "no last band")
	s.record_relaxed("hard")
	s.record_relaxed("hard")
	s.record_relaxed("easy")
	check_eq(s.relaxed_next("hard"), 2, "hard moved on")
	check_eq(s.relaxed_next("easy"), 1, "easy moved on")
	check_eq(s.relaxed_next("medium"), 0, "medium did not")
	check_eq(s.relaxed_last_band(), "easy", "last band")
	check_eq(s.highest_cleared(), 0, "the level count is untouched")
	s.record_relaxed("insane")
	var again := _new_save("relaxed")
	check_eq(again.relaxed_next("hard"), 2, "saved")


func test_reset_progress_keeps_settings() -> void:
	var s := _new_save("reset")
	s.record_win(LevelCatalog.get_level(LevelData.NUMBERED, 9, "").level, 9000, Vector3i(1, 1, 1))
	s.add_helper("undo", 3)
	s.set_sound(false)
	s.reset_progress()
	check_eq(s.next_level(), 1, "back to level 1")
	check_eq(s.star_bank(), 0, "no stars")
	check_eq(s.helper_count("undo"), 0, "no helpers")
	check(not s.sound, "settings stay")
	var again := _new_save("reset")
	check_eq(again.next_level(), 1, "saved reset")
	check(not again.sound, "settings stay on disk")


func test_note_helper_used_counts_in_stats() -> void:
	var s := _new_save("used")
	s.note_helper_used()
	s.note_helper_used()
	check_eq(s.progress_copy()["stats"]["helpers_used"], 2, "helpers used")
