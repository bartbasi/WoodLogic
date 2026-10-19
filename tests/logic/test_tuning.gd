# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## data/tuning.json (GDD 9.4, 12 item 15a; docs/ARCHITECTURE.md 3.3 and 4.4).


func _load_real() -> void:
	var errors := PackedStringArray()
	check(Tuning.load_text(FileAccess.get_file_as_string(Tuning.PATH), errors), "data/tuning.json loads: %s" % "; ".join(errors))


func test_15a_tuning_file_loads_and_matches_the_gdd() -> void:
	_load_real()
	# Section 3.
	check_eq([Tuning.tray_size, Tuning.open_boxes, Tuning.box_slots, Tuning.preview, Tuning.tutorial_levels], [5, 2, 3, 2, 8], "tray, open boxes, slots, preview, tutorial levels")
	# Section 6.1, row by row: tier, group, screws, colors, layers, fewest tray uses, novice.
	var rows := [
		[1, "easy", 9, 12, 2, 3, 1, 2, 0, 0, "win"],
		[2, "easy", 12, 15, 3, 3, 2, 3, 0, 1, "win"],
		[3, "easy", 15, 18, 3, 4, 2, 4, 0, 1, "win"],
		[4, "medium", 18, 21, 4, 4, 3, 4, 1, 2, "either"],
		[5, "medium", 21, 24, 4, 5, 3, 5, 1, 2, "either"],
		[6, "medium", 24, 27, 5, 5, 3, 5, 1, 3, "either"],
		[7, "hard", 27, 30, 5, 6, 4, 5, 2, 3, "lose"],
		[8, "hard", 30, 33, 6, 7, 4, 5, 2, 4, "lose"],
		[9, "expert", 33, 36, 7, 7, 4, 5, 3, 4, "lose"],
		[10, "expert", 33, 36, 7, 8, 4, 5, 3, 5, "lose"],
	]
	check_eq(Tuning.tiers.size(), 10, "ten tiers")
	for r: Array in rows:
		var t := Tuning.tier(r[0])
		var got := [t.tier, t.group, t.screws.x, t.screws.y, t.colors.x, t.colors.y, t.layers.x, t.layers.y, t.tray_uses.x, t.tray_uses.y, Tuning.NOVICE_NAMES[t.novice]]
		check_eq(got, r, "tier %d" % r[0])
	# Section 6.3.
	check_eq(Tuning.sawtooth_steps, PackedInt32Array([-2, -1, 0, 1, 2]), "sawtooth steps")
	check_eq(Tuning.sawtooth_bases, [Vector2i(9, 2), Vector2i(21, 3), Vector2i(36, 4), Vector2i(56, 5), Vector2i(81, 6), Vector2i(111, 7), Vector2i(151, 8)], "sawtooth bases")
	# Sections 3 and 4 (S7, S8).
	check_eq(Tuning.tray_par_slack, [Vector2i(9, 2), Vector2i(31, 1), Vector2i(101, 0)], "tray par slack")
	check_eq(Tuning.par_base_s, 10, "par base")
	check_eq(Tuning.par_tenths, {"easy": 30, "medium": 35, "hard": 40, "expert": 45}, "par seconds per screw, in tenths")
	check_eq(Tuning.par_round_s, 5, "par rounding")
	# Section 6.6.
	check_eq([Tuning.daily_tier, Tuning.daily_slack, Tuning.daily_group], [6, 1, "medium"], "daily")
	check_eq(Tuning.relaxed, {"easy": Vector2i(1, 3), "medium": Vector2i(4, 6), "hard": Vector2i(7, 8)}, "relaxed bands")
	# Section 5.
	check_eq(Tuning.helpers, {
		"undo": {"price": 4, "first_level": 8, "free": 2},
		"extra_slot": {"price": 6, "first_level": 15, "free": 2},
		"screwdriver": {"price": 8, "first_level": 25, "free": 2},
	}, "helpers")
	# Section 7.
	var unlocks := PackedStringArray()
	for u: Dictionary in Tuning.unlocks:
		unlocks.append("%s %s %s" % [u["what"], u["id"], ("level %d" % u["level"]) if u.has("level") else ("streak %d" % u["best_streak"])])
	check_eq(unlocks, PackedStringArray(["wood oak level 0", "metal steel level 0", "wood walnut level 10", "metal brass level 25", "wood maple level 50", "wood cherry level 100", "wood ebony level 150", "metal copper streak 3", "metal black streak 7"]), "unlocks")
	check_eq(Tuning.modes_open_after_level, 8, "modes open after level 8")
	check_eq(Tuning.recent_blueprints_excluded, 5, "G7 looks back 5 levels")


func test_6_3_sawtooth_tiers_for_levels_9_to_30_and_151_to_160() -> void:
	_load_real()
	var expected := [3, 4, 1, 1, 2, 3, 4, 1, 1, 2, 3, 4, 1, 2, 3, 4, 5, 1, 2, 3, 4, 5]
	for i: int in expected.size():
		check_eq(Tuning.tier_for_level(9 + i), expected[i], "tier of level %d" % (9 + i))
	for n: int in range(151, 161):
		check_eq(Tuning.tier_for_level(n), [6, 7, 8, 9, 10][(n - 151) % 5], "tier of level %d" % n)
	check_eq(Tuning.tier_for_level(10000), Tuning.tier_for_level(10000 - 5), "the cycle holds far out")


func test_s7_s8_slack_and_par_time_by_level_and_group() -> void:
	_load_real()
	check_eq([Tuning.slack_for_level(9), Tuning.slack_for_level(30), Tuning.slack_for_level(31), Tuning.slack_for_level(100), Tuning.slack_for_level(101), Tuning.slack_for_level(5000)], [2, 2, 1, 1, 0, 0], "slack")
	check_eq(Tuning.par_time_for(18, "medium"), 75, "18 screws medium")
	check_eq(Tuning.par_time_for(30, "hard"), 130, "30 screws hard")
	check_eq(Tuning.par_time_for(36, "expert"), 175, "36 screws expert")
	check_eq(Tuning.par_time_for(12, "easy"), 50, "12 screws easy: 46, so 50")


func test_15a_a_bad_tuning_file_is_caught_and_changes_nothing() -> void:
	_load_real()
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Tuning.PATH))
	var before := _state()
	var edits := {
		"format 2": func(d: Dictionary) -> void: d["format"] = 2,
		"missing tray_size": func(d: Dictionary) -> void: d.erase("tray_size"),
		"unknown key": func(d: Dictionary) -> void: d["extra"] = 1,
		"tray_size 0": func(d: Dictionary) -> void: d["tray_size"] = 0,
		"nine tiers": func(d: Dictionary) -> void: (d["tiers"] as Array).pop_back(),
		"tier out of order": func(d: Dictionary) -> void: d["tiers"][3]["tier"] = 5,
		"novice maybe": func(d: Dictionary) -> void: d["tiers"][0]["novice"] = "maybe",
		"low above high": func(d: Dictionary) -> void: d["tiers"][2]["screws"] = [18, 15],
		"fractional screws": func(d: Dictionary) -> void: d["tiers"][2]["screws"] = [15.5, 18],
		"more colors than screws allow": func(d: Dictionary) -> void: d["tiers"][0]["colors"] = [5, 5],
		"four steps": func(d: Dictionary) -> void: (d["sawtooth"]["steps"] as Array).pop_back(),
		"bases not rising": func(d: Dictionary) -> void: d["sawtooth"]["bases"][2] = [20, 4],
		"slack starts at 10": func(d: Dictionary) -> void: d["tray_par_slack"][0] = [10, 2],
		"per screw 3.33": func(d: Dictionary) -> void: d["par_time"]["per_screw_s"]["easy"] = 3.33,
		"no expert par": func(d: Dictionary) -> void: (d["par_time"]["per_screw_s"] as Dictionary).erase("expert"),
		"daily group": func(d: Dictionary) -> void: d["daily"]["group"] = "tough",
		"relaxed band missing": func(d: Dictionary) -> void: (d["relaxed"] as Dictionary).erase("hard"),
		"helper missing": func(d: Dictionary) -> void: (d["helpers"] as Dictionary).erase("screwdriver"),
		"negative price": func(d: Dictionary) -> void: d["helpers"]["undo"]["price"] = -1,
		"unlock with both": func(d: Dictionary) -> void: d["unlocks"][2]["best_streak"] = 3,
		"unlock bad id": func(d: Dictionary) -> void: d["unlocks"][2]["id"] = "Walnut",
		"recent 11": func(d: Dictionary) -> void: d["recent_blueprints_excluded"] = 11,
	}
	for label: String in edits:
		var d: Dictionary = good.duplicate(true)
		(edits[label] as Callable).call(d)
		var errors := PackedStringArray()
		check(not Tuning.load_text(JSON.stringify(d), errors) and not errors.is_empty(), "rejected: " + label)
		check_eq(_state(), before, "nothing changed after: " + label)
	var errors := PackedStringArray()
	check(not Tuning.load_text("{", errors), "not JSON")
	check(not Tuning.load_text("[]", errors), "not an object")
	check_eq(_state(), before, "nothing changed")


func _state() -> String:
	var tiers := PackedStringArray()
	for t: Tuning.TierSpec in Tuning.tiers:
		tiers.append("%d %s %s %s %s %s %d" % [t.tier, t.group, t.screws, t.colors, t.layers, t.tray_uses, t.novice])
	return var_to_str([Tuning.tray_size, Tuning.open_boxes, Tuning.box_slots, Tuning.preview, Tuning.tutorial_levels, tiers, Tuning.sawtooth_steps, Tuning.sawtooth_bases, Tuning.tray_par_slack, Tuning.par_base_s, Tuning.par_tenths, Tuning.par_round_s, Tuning.daily_tier, Tuning.daily_slack, Tuning.daily_group, Tuning.relaxed, Tuning.helpers, Tuning.unlocks, Tuning.modes_open_after_level, Tuning.recent_blueprints_excluded])
