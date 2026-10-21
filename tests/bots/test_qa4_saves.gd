# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends QaFlowCase
## Hand-edited, damaged and odd save files: the app must still start, show every menu and play,
## and nothing may log an error (the runner fails any test that does). Files are written into
## the runner's temporary Save folder, never the player's.

const MENUS: Array[String] = ["title", "map", "stats", "info", "settings", "about", "relaxed"]


func _write(file_name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(str(save_node().dir))
	var f := FileAccess.open(str(save_node().dir) + file_name, FileAccess.WRITE)
	if text == "NULS":
		f.store_buffer(PackedByteArray([0, 0, 0, 0]))
	else:
		f.store_string(text)
	f.close()


func _progress(changes: Dictionary) -> String:
	var p: Dictionary = save_node().default_progress()
	p.merge(changes, true)
	return JSON.stringify(p)


## Boots the app over this progress text and walks every menu. Returns the state it reached.
func _boot_with(progress_text: String, settings_text: String = "") -> int:
	Links.opener = func(address: String) -> Variant:
		opened.append(address)
		return OK
	var save := save_node()
	save.erase_all()
	if progress_text != "":
		_write("progress.json", progress_text)
	if settings_text != "":
		_write("settings.json", settings_text)
	boot()
	var ok := await until(func() -> bool: return flow.state == AppFlow.State.TITLE or flow.state == AppFlow.State.LEVEL or flow.state == AppFlow.State.ERROR)
	check(ok, "the app reached a screen")
	var reached := int(flow.state)
	if flow.state == AppFlow.State.TITLE:
		for menu_name: String in MENUS:
			flow.show_menu(menu_name)
			await frames(2)
			check(flow.screen != null, "%s builds" % menu_name)
	check(int(save.next_level()) >= 1, "Play never points below level 1")
	return reached


func _done() -> void:
	save_node().erase_all()


func test_hand_edited_numbers_are_clamped_and_the_app_starts() -> void:
	var cases: Array[Dictionary] = [
		{"next_level": -5, "highest_cleared": -1},
		{"next_level": 0, "highest_cleared": 3},
		{"next_level": 1e12, "highest_cleared": 5},
		{"next_level": "7", "highest_cleared": "3"},
		{"next_level": 7.5, "highest_cleared": 2.5},
		{"next_level": null, "highest_cleared": null},
		{"next_level": 1000001, "highest_cleared": 1000001},
		{"next_level": 3, "highest_cleared": 900000},
		{"star_bank": -4, "stars_earned": -9},
		{"star_bank": 1e30, "stars_earned": 1e30, "highest_cleared": 12, "next_level": 13},
		{"helpers": {"undo": -1, "extra_slot": 1e9, "screwdriver": "many"}, "highest_cleared": 20, "next_level": 21},
		{"helpers_met": ["undo", "undo", "bogus", 5, null]},
		{"levels": {"abc": {"stars": 3}, "0": {"stars": 1}, "-1": {}, "99999999999": {}, "4": {"stars": 99, "best_ms": -1, "gen": "x"}, "5": 7}, "highest_cleared": 5, "next_level": 6},
		{"daily": {"last_date": "2026-13-45", "streak": -3, "best_streak": 1e20, "solved": "x", "days": {"nope": {"stars": 9}, "2026-02-30": {}, "2026-10-21": {"stars": 7, "best_ms": 0}}}, "highest_cleared": 9, "next_level": 10},
		{"relaxed": {"next": {"easy": -1, "medium": 1e20, "hard": "z"}, "last_band": "expert"}, "highest_cleared": 9, "next_level": 10},
		{"stats": {"cleared": -1, "three_star": 1e30, "time": {"easy": {"n": -1, "total_ms": 1e30, "best_ms": -4}, "bogus": {}}}},
		{"unlocked": {"wood": ["walnut", "../../evil", "x".repeat(200), 5], "metal": "brass"}},
		{"unlocked": {"wood": ["zzz"], "metal": ["qqq"]}},
		{"format": 99, "extra_field": {"a": 1}},
		{"format": "one"},
	]
	for i: int in cases.size():
		var reached := await _boot_with(_progress(cases[i]))
		check(reached != AppFlow.State.ERROR, "case %d %s reaches a screen without an error screen" % [i, str(cases[i])])
		if flow != null:
			flow.queue_free()
			await frames(2)
	_done()


func test_damaged_files_start_a_fresh_game_and_keep_the_bad_one_aside() -> void:
	var texts: Array[String] = ["", "{", "[]", "null", "123", "\"text\"", "{\"format\":1,", "﻿{}", "{\"next_level\": NaN}", "{\"next_level\": Infinity}", "[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]", "\u0000\u0000\u0000", "{\"levels\": " + "{\"1\":".repeat(50) + "1" + "}".repeat(50) + "}"]
	for i: int in texts.size():
		save_node().erase_all()
		_write("progress.json", texts[i])
		boot()
		var ok := await until(func() -> bool: return flow.state == AppFlow.State.TITLE or flow.state == AppFlow.State.LEVEL or flow.state == AppFlow.State.ERROR)
		check(ok and flow.state != AppFlow.State.ERROR, "damaged file %d: the app starts" % i)
		check_eq(int(save_node().highest_cleared()), 0, "damaged file %d: a fresh game" % i)
		flow.queue_free()
		await frames(2)
	_done()


func test_edited_settings_fall_back() -> void:
	var texts: Array[String] = [
		"{\"sound\": \"yes\", \"music\": 1, \"symbols\": null, \"wood\": \"../x\", \"metal\": 5}",
		"{\"wood\": \"ebony\", \"metal\": \"black\"}",
		"{\"wood\": \"WALNUT\"}",
		"[]",
		"{\"sound\": false, \"music\": false, \"symbols\": false}",
	]
	for i: int in texts.size():
		var p := _progress({"highest_cleared": 12, "next_level": 13})
		var reached := await _boot_with(p, texts[i])
		check(reached != AppFlow.State.ERROR, "settings %d: the app starts" % i)
		check(["oak", "walnut"].has(str(save_node().wood())), "settings %d: a wood that is not unlocked reads as the default (%s)" % [i, str(save_node().wood())])
		check_eq(str(save_node().metal()), "steel", "settings %d: a metal that is not unlocked reads as the default" % i)
		check(Looks.current_wood()["id"] != "", "settings %d: Looks has a wood" % i)
		flow.queue_free()
		await frames(2)
	_done()


func test_a_tampered_next_level_file_is_ignored_or_played_without_errors() -> void:
	var save := save_node()
	var good := LevelCatalog.get_level(LevelData.NUMBERED, 14, "").level
	var d: Dictionary = good.to_dict()
	d["key"] = "numbered:14"
	var variants: Array[String] = []
	variants.append(JSON.stringify(d))
	var bad_queue := d.duplicate(true)
	bad_queue["queue"] = [0, 0, 0]
	variants.append(JSON.stringify(bad_queue))
	var bad_colors := d.duplicate(true)
	bad_colors["planks"][0]["colors"] = [7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7]
	variants.append(JSON.stringify(bad_colors))
	var other_version := d.duplicate(true)
	other_version["generator"] = 999
	variants.append(JSON.stringify(other_version))
	var no_planks := d.duplicate(true)
	no_planks["planks"] = []
	variants.append(JSON.stringify(no_planks))
	variants.append("{\"key\": \"numbered:14\"}")
	for i: int in variants.size():
		var p := _progress({"highest_cleared": 13, "next_level": 14})
		save.erase_all()
		_write("progress.json", p)
		_write("next_level.json", variants[i])
		boot()
		var ok := await until(func() -> bool: return flow.state == AppFlow.State.TITLE or flow.state == AppFlow.State.ERROR)
		check(ok and flow.state == AppFlow.State.TITLE, "next_level.json variant %d: the title shows" % i)
		tap("Play")
		check(await in_state(AppFlow.State.LEVEL), "variant %d: Play starts a level" % i)
		check_eq(fake().played[-1].number, 14, "variant %d: it is level 14" % i)
		check(fake().played[-1].screw_count() >= 9, "variant %d: with a real board" % i)
		flow.queue_free()
		await frames(2)
	_done()


func test_a_save_from_a_newer_build_keeps_what_it_understands_and_is_not_lost_on_start() -> void:
	var p := _progress({"highest_cleared": 30, "next_level": 31, "format": 7, "future": {"x": [1, 2, 3]}})
	var reached := await _boot_with(p)
	check_eq(int(save_node().highest_cleared()), 30, "the levels cleared survive")
	check_eq(reached, AppFlow.State.TITLE, "the title shows")
	_done()
