# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The Save autoload's logic (docs/ARCHITECTURE.md 3.4): defaults, round trips, broken, old and
## hostile files. Each test uses its own Save instance in its own folder under the runner's
## temporary one, so the real user:// files are never touched.

const SaveScript := preload("res://src/save/save.gd")


func _dir_for(test_name: String) -> String:
	return "%s%s/" % [tree.root.get_node("Save").get("dir"), test_name]


## A fresh Save over a clean folder (not loaded yet).
func _new_save(test_name: String) -> Node:
	var s: Node = SaveScript.new()
	s.dir = _dir_for(test_name)
	add_node(s)
	DirAccess.make_dir_recursive_absolute(s.dir)
	return s


func _write(s: Node, file_name: String, text: String) -> void:
	var f := FileAccess.open(s.dir + file_name, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read(s: Node, file_name: String) -> String:
	return FileAccess.get_file_as_string(s.dir + file_name)


func _level(n: int) -> LevelData:
	return LevelCatalog.get_level(LevelData.NUMBERED, n, "").level


func test_defaults_on_a_missing_file() -> void:
	var s := _new_save("defaults")
	s.load_all()
	check_eq(s.next_level(), 1, "next_level")
	check_eq(s.highest_cleared(), 0, "highest_cleared")
	check_eq(s.star_bank(), 0, "star_bank")
	check(s.sound and s.music and s.symbols, "sound, music and symbols default to on")
	check_eq(s.wood(), "oak", "wood")
	check_eq(s.metal(), "steel", "metal")
	check(s.problems.is_empty(), "a missing file is not a problem")
	check(not FileAccess.file_exists(s.dir + "progress.json"), "load_all writes nothing")
	check(not FileAccess.file_exists(s.dir + "progress.json.bad"), "nothing kept as .bad")


func test_nothing_is_written_before_load_all() -> void:
	var s := _new_save("early")
	s.save_progress()
	s.save_settings()
	check(not FileAccess.file_exists(s.dir + "progress.json"), "no progress.json before load_all")
	check(not FileAccess.file_exists(s.dir + "settings.json"), "no settings.json before load_all")


func test_round_trip() -> void:
	var s := _new_save("round_trip")
	s.load_all()
	var level := _level(12)
	var gained: int = s.record_win(level, 15000, Vector3i(1, 1, 0))
	check_eq(gained, 2, "stars gained")
	var again := _new_save("round_trip")
	again.load_all()
	check_eq(again.next_level(), 13, "next_level")
	check_eq(again.highest_cleared(), 12, "highest_cleared")
	check_eq(again.star_bank(), 2, "star_bank")
	check_eq(again.stars_earned(), 2, "stars_earned")
	var rec: Dictionary = again.level_record(12)
	check_eq(rec.get("stars"), 2, "level 12 stars")
	check_eq(rec.get("best_ms"), 15000, "level 12 best_ms")
	check_eq(rec.get("gen"), level.generator_version, "level 12 gen")
	var stats: Dictionary = again.progress_copy()["stats"]
	check_eq(stats["cleared"], 1, "stats.cleared")
	check(again.problems.is_empty(), "no problems: " + str(again.problems))


func test_stars_only_add_and_best_time_only_improves() -> void:
	var s := _new_save("only_add")
	s.load_all()
	var level := _level(10)
	s.record_win(level, 20000, Vector3i(1, 0, 1))
	var gained: int = s.record_win(level, 30000, Vector3i(1, 0, 0))
	check_eq(gained, 0, "a worse replay gains nothing")
	gained = s.record_win(level, 9000, Vector3i(1, 1, 1))
	check_eq(gained, 1, "a better replay adds only the difference")
	var rec: Dictionary = s.level_record(10)
	check_eq(rec["stars"], 3, "stars kept the best")
	check_eq(rec["best_ms"], 9000, "best_ms kept the best")
	check_eq(s.star_bank(), 3, "star_bank")
	var stats: Dictionary = s.progress_copy()["stats"]
	check_eq(stats["cleared"], 1, "a replay does not add to cleared")
	check_eq(stats["three_star"], 1, "three_star counts once")


func test_a_replay_does_not_move_next_level_back() -> void:
	var s := _new_save("replay")
	s.load_all()
	s.record_win(_level(9), 10000, Vector3i(1, 1, 1))
	s.record_win(_level(10), 10000, Vector3i(1, 1, 1))
	check_eq(s.next_level(), 11, "next_level after 9 and 10")
	s.record_win(_level(9), 10000, Vector3i(1, 1, 1))
	check_eq(s.next_level(), 11, "next_level after a replay of 9")
	check_eq(s.highest_cleared(), 10, "highest_cleared")


func test_time_stats_count_every_numbered_win_by_group() -> void:
	var s := _new_save("time")
	s.load_all()
	var level := _level(30)
	s.record_win(level, 8000, Vector3i(1, 0, 0))
	s.record_win(level, 6000, Vector3i(1, 0, 0))
	var time: Dictionary = s.progress_copy()["stats"]["time"]
	var g: Dictionary = time[level.group]
	check_eq(g["n"], 2, "n")
	check_eq(g["total_ms"], 14000, "total_ms")
	check_eq(g["best_ms"], 6000, "best_ms")


func test_a_broken_file_is_kept_as_bad_and_defaults_are_used() -> void:
	var s := _new_save("broken")
	_write(s, "progress.json", "{\"next_level\": 7, ")
	_write(s, "settings.json", "not json at all")
	s.load_all()
	check_eq(s.next_level(), 1, "defaults used")
	check(s.sound, "settings defaults used")
	check_eq(_read(s, "progress.json.bad"), "{\"next_level\": 7, ", "progress kept as .bad")
	check_eq(_read(s, "settings.json.bad"), "not json at all", "settings kept as .bad")
	check(not s.problems.is_empty(), "problems are reported")
	# The next save writes a good file, and the .bad copy stays.
	s.record_win(_level(3), 5000, Vector3i(1, 1, 1))
	var again := _new_save("broken")
	again.load_all()
	check_eq(again.next_level(), 4, "the new file loads")
	check(FileAccess.file_exists(s.dir + "progress.json.bad"), ".bad stays")


func test_a_file_that_is_not_an_object_is_broken() -> void:
	var s := _new_save("array")
	_write(s, "progress.json", "[1, 2, 3]")
	s.load_all()
	check_eq(s.next_level(), 1, "defaults used")
	check(FileAccess.file_exists(s.dir + "progress.json.bad"), "kept as .bad")


func test_object_text_is_never_decoded() -> void:
	var s := _new_save("objects")
	_write(s, "progress.json", "Object(Node,\"name\":\"x\",\"script\":null)")
	_write(s, "settings.json", "{\"sound\": Vector2(1, 2)}")
	s.load_all()
	check_eq(s.next_level(), 1, "defaults used")
	check(s.sound, "sound default")


func test_a_hostile_file_loads_safely() -> void:
	var s := _new_save("hostile")
	var junk := {"a": [[[[[[{"b": [1, 2, {"c": "d"}]}]]]]]]}
	var text := JSON.stringify({
		"format": "two",
		"next_level": 1e30,
		"highest_cleared": -5,
		"star_bank": "lots",
		"stars_earned": 2.5,
		"levels": {
			"5": {"stars": 99, "best_ms": -1, "gen": "x"},
			"abc": 1,
			"0": {"stars": 1},
			"007": {"stars": 1},
			"99999999999": {"stars": 1},
			"7": {"stars": 2, "best_ms": 1234, "gen": 3},
			"8": junk,
		},
		"helpers": [1, 2],
		"helpers_met": ["undo", "undo", "hammer", 7, junk],
		"daily": {"last_date": "2026-13-45", "streak": -1, "days": {"2026-10-19": {"stars": 3, "best_ms": 5}, "nope": {}}},
		"relaxed": {"next": "x", "last_band": "insane"},
		"stats": {"cleared": 1e300, "time": {"easy": {"n": "many", "total_ms": 1e99}, "bogus": {}}},
		"unlocked": {"wood": [{"a": 1}, "walnut", "../../etc", "walnut", 3], "metal": "steel"},
		"extra": junk,
	})
	_write(s, "progress.json", text)
	s.load_all()
	check_eq(s.next_level(), 1, "next_level out of range falls back")
	check_eq(s.highest_cleared(), 0, "highest_cleared")
	check_eq(s.star_bank(), 0, "star_bank")
	check_eq(s.stars_earned(), 0, "stars_earned")
	var p: Dictionary = s.progress_copy()
	var levels: Dictionary = p["levels"]
	check_eq(levels.keys(), ["5", "7", "8"], "only well formed level keys stay")
	check_eq(levels["8"], {"stars": 0, "best_ms": 0, "gen": 0}, "a record of junk is all defaults")
	check_eq(levels["5"], {"stars": 0, "best_ms": 0, "gen": 0}, "level 5's bad fields fall back")
	check_eq(levels["7"], {"stars": 2, "best_ms": 1234, "gen": 3}, "level 7 is kept")
	check_eq(p["helpers"], {"undo": 0, "extra_slot": 0, "screwdriver": 0}, "helpers")
	check_eq(p["helpers_met"], ["undo"], "helpers_met keeps the valid unique names")
	var daily: Dictionary = p["daily"]
	check_eq(daily["last_date"], "", "bad date")
	check_eq(daily["streak"], 0, "streak")
	check_eq((daily["days"] as Dictionary).keys(), ["2026-10-19"], "days")
	var relaxed: Dictionary = p["relaxed"]
	check_eq(relaxed["last_band"], "", "last_band")
	check_eq(p["unlocked"], {"wood": ["oak", "walnut"], "metal": ["steel"]}, "unlocked")
	var stats: Dictionary = p["stats"]
	check_eq(stats["cleared"], 0, "stats.cleared")
	check(FileAccess.file_exists(s.dir + "progress.json.bad"), "a file with bad fields is kept as .bad")
	# It still works afterwards.
	s.record_win(_level(2), 4000, Vector3i(1, 1, 1))
	check_eq(s.next_level(), 3, "play goes on")


func test_extremely_deep_nesting_is_refused() -> void:
	var s := _new_save("deep")
	_write(s, "progress.json", "[".repeat(3000) + "]".repeat(3000))
	s.load_all()
	check_eq(s.next_level(), 1, "defaults used")
	check(FileAccess.file_exists(s.dir + "progress.json.bad"), "kept as .bad")


func test_a_huge_file_is_refused() -> void:
	var s := _new_save("huge")
	_write(s, "progress.json", "{\"pad\": \"" + "x".repeat(SaveScript.MAX_FILE_BYTES + 10) + "\"}")
	s.load_all()
	check_eq(s.next_level(), 1, "defaults used")
	check(FileAccess.file_exists(s.dir + "progress.json.bad"), "kept as .bad")


func test_an_older_save_without_a_format_is_migrated() -> void:
	var s := _new_save("old")
	_write(s, "progress.json", JSON.stringify({"next_level": 5, "highest_cleared": 4, "star_bank": 10, "levels": {"1": {"stars": 3}}}))
	s.load_all()
	check_eq(s.next_level(), 5, "next_level kept")
	check_eq(s.highest_cleared(), 4, "highest_cleared kept")
	check_eq(s.star_bank(), 10, "star_bank kept")
	check_eq(s.level_record(1), {"stars": 3, "best_ms": 0, "gen": 0}, "a record without best_ms and gen")
	check(not FileAccess.file_exists(s.dir + "progress.json.bad"), "an older save is not a bad one")
	check(s.problems.is_empty(), "no problems: " + str(s.problems))
	s.save_all()
	var saved: Dictionary = JSON.parse_string(_read(s, "progress.json"))
	check_eq(saved["format"], 1.0, "saved with the current format")
	check_eq(saved["next_level"], 5.0, "saved next_level")


func test_a_newer_save_keeps_what_this_build_understands() -> void:
	var s := _new_save("newer")
	_write(s, "progress.json", JSON.stringify({"format": 2, "next_level": 40, "highest_cleared": 39, "new_thing": {"a": 1}}))
	s.load_all()
	check_eq(s.next_level(), 40, "next_level kept")
	check_eq(s.highest_cleared(), 39, "highest_cleared kept")
	check(not FileAccess.file_exists(s.dir + "progress.json.bad"), "an unknown field is not a problem")


func test_settings_round_trip() -> void:
	var s := _new_save("settings")
	s.load_all()
	s.set_sound(false)
	s.set_music(false)
	s.set_symbols(false)
	s.set_look("walnut", "brass")
	var again := _new_save("settings")
	again.load_all()
	check(not again.sound, "sound off")
	check(not again.music, "music off")
	check(not again.symbols, "symbols off")
	check_eq(again.wood_id, "walnut", "wood_id")
	check_eq(again.metal_id, "brass", "metal_id")
	var saved: Dictionary = JSON.parse_string(_read(again, "settings.json"))
	check_eq(saved["format"], 1.0, "settings format")
	check_eq(saved.keys().size(), 6, "settings has format, sound, music, symbols, wood, metal")


func test_a_look_that_is_not_unlocked_reads_as_the_default() -> void:
	var s := _new_save("locked_look")
	s.load_all()
	s.set_look("walnut", "brass")
	check_eq(s.wood(), "oak", "walnut is locked")
	check_eq(s.metal(), "steel", "brass is locked")
	_write(s, "progress.json", JSON.stringify({"unlocked": {"wood": ["oak", "walnut"], "metal": ["steel"]}}))
	s.load_all()
	check_eq(s.wood(), "walnut", "walnut is unlocked now")
	check_eq(s.metal(), "steel", "brass is still locked")


func test_hostile_settings_fall_back() -> void:
	var s := _new_save("bad_settings")
	_write(s, "settings.json", JSON.stringify({"sound": "yes", "music": 0, "symbols": false, "wood": "../../x", "metal": ["steel"]}))
	s.load_all()
	check(s.sound and s.music, "bad booleans use the default")
	check(not s.symbols, "a good value is kept")
	check_eq(s.wood_id, "oak", "bad wood")
	check_eq(s.metal_id, "steel", "bad metal")
	check(FileAccess.file_exists(s.dir + "settings.json.bad"), "kept as .bad")


func test_a_save_leaves_no_temporary_file() -> void:
	var s := _new_save("tmp")
	s.load_all()
	s.save_all()
	s.save_all()
	check(FileAccess.file_exists(s.dir + "progress.json"), "progress.json")
	check(FileAccess.file_exists(s.dir + "settings.json"), "settings.json")
	check(not FileAccess.file_exists(s.dir + "progress.json.tmp"), "no progress temp file")
	check(not FileAccess.file_exists(s.dir + "settings.json.tmp"), "no settings temp file")


func test_signals() -> void:
	var s := _new_save("signals")
	s.load_all()
	var counts := [0, 0]
	s.progress_changed.connect(func() -> void: counts[0] += 1)
	s.settings_changed.connect(func() -> void: counts[1] += 1)
	s.set_sound(false)
	s.record_win(_level(2), 1000, Vector3i(1, 0, 0))
	check_eq(counts[1], 1, "settings_changed")
	check_eq(counts[0], 1, "progress_changed")


func test_erase_all() -> void:
	var s := _new_save("erase")
	s.load_all()
	s.record_win(_level(3), 1000, Vector3i(1, 1, 1))
	s.set_music(false)
	s.erase_all()
	check_eq(s.next_level(), 1, "next_level")
	check(s.music, "music back on")
	check(not FileAccess.file_exists(s.dir + "progress.json"), "progress.json gone")
	check(not FileAccess.file_exists(s.dir + "settings.json"), "settings.json gone")


func test_good_fields_survive_a_file_with_one_bad_field() -> void:
	var s := _new_save("partial")
	_write(s, "progress.json", JSON.stringify({"next_level": 9, "highest_cleared": 8, "star_bank": "lots"}))
	s.load_all()
	check(FileAccess.file_exists(s.dir + "progress.json.bad"), "the original is kept as .bad")
	var again := _new_save("partial")
	again.load_all()
	check_eq(again.next_level(), 9, "next_level survives")
	check_eq(again.highest_cleared(), 8, "highest_cleared survives")
	check(again.problems.is_empty(), "the rewritten file is clean: " + str(again.problems))
