# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends QaFlowCase
## Updating from the previous build (PROMPT 18, "survive closing the app and updating"). The
## files in tests/bots/fixtures/phase4/ were written by the Phase 4 build's own Save code (commit
## f627812: a player at level 45 with stars spent, helpers, walnut and brass, a 5 day Daily
## streak, Relaxed positions, sound and symbols off, and a saved next level from generator
## version 5). They are loaded into this build.

const DIR := "res://tests/bots/fixtures/phase4/"


func _copy_fixture_into_the_save_folder() -> void:
	var save := save_node()
	save.erase_all()
	DirAccess.make_dir_recursive_absolute(str(save.dir))
	for file_name: String in ["progress.json", "settings.json", "next_level.json"]:
		var text := FileAccess.get_file_as_string(DIR + file_name)
		var f := FileAccess.open(str(save.dir) + file_name, FileAccess.WRITE)
		f.store_string(text)
		f.close()


func _fixture(file_name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + file_name))
	return parsed if parsed is Dictionary else {}


func test_a_phase_4_save_loads_with_everything_kept() -> void:
	var raw := _fixture("progress.json")
	check(not raw.is_empty(), "the fixture is there")
	_copy_fixture_into_the_save_folder()
	var save := save_node()
	save.load_all()
	check_eq(PackedStringArray(save.problems).size(), 0, "no problem reported: %s" % str(Array(save.problems)))
	check(not FileAccess.file_exists(str(save.dir) + "progress.json.bad"), "nothing was set aside as bad")
	check_eq(save.highest_cleared(), int(raw["highest_cleared"]), "levels cleared")
	check_eq(save.next_level(), int(raw["next_level"]), "the next level")
	check_eq(save.star_bank(), int(raw["star_bank"]), "the star bank")
	check_eq(save.stars_earned(), int(raw["stars_earned"]), "stars earned")
	for h: String in ["undo", "extra_slot", "screwdriver"]:
		check_eq(save.helper_count(h), int(raw["helpers"][h]), "%s owned" % h)
		check(save.is_helper_met(h), "%s was met" % h)
	check_eq(Array(save.unlocked_ids("wood")), Array(raw["unlocked"]["wood"]), "woods")
	check_eq(Array(save.unlocked_ids("metal")), Array(raw["unlocked"]["metal"]), "metals")
	var daily: Dictionary = save.daily_record()
	check_eq(int(daily["streak"]), 5, "the 5 day streak")
	check_eq(int(daily["best_streak"]), 5, "the best streak")
	check_eq(str(daily["last_date"]), "2026-10-21", "the last counted day")
	check_eq(int(daily["solved"]), 5, "dailies solved")
	check_eq(save.relaxed_next("easy"), 3, "Relaxed easy position")
	check_eq(save.relaxed_next("medium"), 2, "Relaxed medium position")
	check_eq(save.relaxed_next("hard"), 0, "Relaxed hard position")
	for n: int in [1, 20, 45]:
		check_eq(int(save.level_record(n)["stars"]), int(raw["levels"][str(n)]["stars"]), "level %d's stars" % n)
		check_eq(int(save.level_record(n)["best_ms"]), int(raw["levels"][str(n)]["best_ms"]), "level %d's best time" % n)
	var stats: Dictionary = save.progress_copy()["stats"]
	check_eq(int(stats["cleared"]), 45, "stats: cleared")
	check_eq(int(stats["helpers_used"]), int(raw["stats"]["helpers_used"]), "stats: helpers used")
	check_eq(str(save.wood()), "walnut", "walnut is in use")
	check_eq(str(save.metal()), "brass", "brass is in use")
	check(not save.sound and save.music and not save.symbols, "sound off, music on, symbols off, as saved")
	# The new fields start empty: nothing is pretended.
	check_eq(Array(save.gifts_given()), [], "no gift given yet")
	check(not save.tray_note_shown(), "the shrink line has not been shown")


func test_the_app_starts_on_a_phase_4_save_plays_the_next_level_and_writes_it_back() -> void:
	_copy_fixture_into_the_save_folder()
	boot("2026-10-22")
	check(await until(func() -> bool: return flow.state == AppFlow.State.TITLE), "the title shows (a returning player)")
	check(not Looks.symbols_on(), "the symbols setting was kept (off)")
	check(Looks.current_wood()["id"] == "walnut" and Looks.current_metal()["id"] == "brass", "the looks were kept")
	check(not tree.root.get_node("Audio").is_sound_on(), "sound is still off")
	# Map: cleared levels with stars, the next one is 46.
	tap("Map")
	await frames(3)
	var map := flow.screen as MapScreen
	check_eq(map.highest, 45, "the map knows 45 levels")
	flow.show_menu("title")
	await frames(2)
	tap("Play")
	check(await in_state(AppFlow.State.LEVEL), "level 46 starts")
	var level := fake().played[-1]
	check_eq(level.number, 46, "it is level 46")
	check_eq(level.generator_version, Generator.GENERATOR_VERSION, "made by this build's generator, not the saved one of version 5")
	check_eq(level.tray_size, 3, "with the 3 slot tray of levels 21 and up")
	check_eq(level.tier, Tuning.tier_for_level(46), "of its tier in the new schedule")
	check_eq(fake().tray_notes.size(), 1, "the player's first smaller tray gets the shrink line, once")
	while flow.overlay != null:
		tap("Got it", true)
	fake().win()
	await past_clear_delay()
	# The save was written with the old fields intact and the new ones added.
	var written := FileAccess.get_file_as_string(str(save_node().dir) + "progress.json")
	var parsed: Variant = JSON.parse_string(written)
	check(parsed is Dictionary, "progress.json is valid JSON")
	var back: Dictionary = parsed
	check_eq(int(back["highest_cleared"]), 46, "level 46 is recorded")
	check_eq(int(back["daily"]["streak"]), 5, "the Daily streak is still 5")
	check((back["unlocked"]["wood"] as Array).has("walnut"), "walnut is still unlocked")
	check(back.has("gifts_given"), "the new gift record is written")
	check(bool(back.get("tray_note_shown", back.get("tray_note", false))) or save_node().tray_note_shown(), "the shrink line is marked shown")
	# Close the app (a new flow over the same files) and come back.
	flow.queue_free()
	await frames(2)
	save_node().load_all()
	check_eq(save_node().highest_cleared(), 46, "after closing and reopening")
	check_eq(save_node().helper_count("extra_slot"), 5, "helpers are as they were")
	check_eq(save_node().relaxed_next("easy"), 3, "Relaxed position as it was")
	boot("2026-10-22")
	await until(func() -> bool: return flow.state == AppFlow.State.TITLE)
	# Today's Daily continues the streak.
	tap("Daily")
	check(await in_state(AppFlow.State.LEVEL), "the Daily starts")
	check_eq(fake().played[-1].tray_size, 3, "the Daily has 3 slots")
	while flow.overlay != null:
		tap("Got it", true)
	fake().win()
	await past_clear_delay()
	check_eq(int(save_node().daily_record()["streak"]), 6, "the 5 day streak became 6")
	save_node().erase_all()


func test_the_saved_next_level_of_version_5_is_never_played() -> void:
	_copy_fixture_into_the_save_folder()
	var raw := _fixture("next_level.json")
	check_eq(int(raw.get("generator", 0)), 5, "the fixture's saved level is from generator version 5")
	var read: LevelData = save_node().read_next_level("numbered:46", Generator.GENERATOR_VERSION)
	check(read == null, "this build refuses it (another generator version)")
	var same: LevelData = save_node().read_next_level("numbered:46", 5)
	check(same != null, "it is a good file for the version that wrote it")
	save_node().erase_all()
