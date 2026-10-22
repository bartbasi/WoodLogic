# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## data/tuning.json (GDD 9.4, 12 item 15a; docs/ARCHITECTURE.md 3.3 and 4.4).


const FIXTURE := "res://tests/logic/fixtures/tuning-v6.json"

## Set while a test has loaded other tuning; cleanup() loads data/tuning.json again.
var _changed := false


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
	# Sections 6.3 and 6.8: the deal of Bart's schedule, in the steps and bases form.
	check_eq(Tuning.sawtooth_steps, PackedInt32Array([-1, -1, -1, 0, 0]), "sawtooth steps")
	check_eq(Tuning.sawtooth_bases, [Vector2i(9, 1), Vector2i(11, 3), Vector2i(12, 4), Vector2i(14, 3), Vector2i(16, 5), Vector2i(19, 4), Vector2i(21, 6), Vector2i(50, 8), Vector2i(100, 10)], "sawtooth bases")
	check(Tuning.sawtooth_ranges.is_empty(), "no ranges form")
	# Section 6.8: tray, least peak and skipped boards per tier, the Relaxed tray, the gifts.
	var trays := []
	var peaks := []
	var skips := []
	for t: Tuning.TierSpec in Tuning.tiers:
		trays.append(t.tray)
		peaks.append(t.peak.x)
		skips.append(",".join(t.skip))
	check_eq(trays, [5, 5, 4, 4, 3, 3, 3, 3, 3, 3], "trays")
	check_eq(peaks, [0, 0, 0, 1, 1, 1, 2, 2, 3, 3], "least peaks")
	check_eq(skips, ["", "", "", "", "", "", "skyline", "bookshelf,catface,ferris-wheel,ship-wheel", "", ""], "boards each tier skips")
	check_eq(Tuning.relaxed_tray, 5, "the Relaxed tray")
	check_eq(Tuning.gifts, [{"level": 50, "undo": 2, "extra_slot": 1, "screwdriver": 0}, {"level": 100, "undo": 2, "extra_slot": 1, "screwdriver": 0}], "gifts")
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
		"undo": {"price": 3, "first_level": 8, "free": 2},
		"extra_slot": {"price": 5, "first_level": 15, "free": 2},
		"screwdriver": {"price": 8, "first_level": 25, "free": 2},
	}, "helpers")
	# Section 7.
	var unlocks := PackedStringArray()
	for u: Dictionary in Tuning.unlocks:
		unlocks.append("%s %s %s" % [u["what"], u["id"], ("level %d" % u["level"]) if u.has("level") else ("streak %d" % u["best_streak"])])
	check_eq(unlocks, PackedStringArray(["wood oak level 0", "metal steel level 0", "wood walnut level 10", "metal brass level 25", "wood maple level 50", "wood cherry level 100", "wood ebony level 150", "metal copper streak 3", "metal black streak 7"]), "unlocks")
	check_eq(Tuning.modes_open_after_level, 8, "modes open after level 8")
	check_eq(Tuning.recent_blueprints_excluded, 5, "G7 looks back 5 levels")


func test_6_8_sawtooth_tiers_follow_barts_schedule() -> void:
	_load_real()
	# GDD 6.8: levels 9 to 20 one by one, then (n - 1) mod 5 inside each range.
	var expected := [1, 1, 2, 3, 3, 3, 3, 4, 4, 4, 4, 4, 5, 5, 5, 6, 6, 5, 5, 5, 6, 6]
	for i: int in expected.size():
		check_eq(Tuning.tier_for_level(9 + i), expected[i], "tier of level %d" % (9 + i))
	for n: int in range(50, 60):
		check_eq(Tuning.tier_for_level(n), [8, 7, 7, 7, 8][(n - 50) % 5], "tier of level %d" % n)
	for n: int in range(100, 110):
		check_eq(Tuning.tier_for_level(n), [10, 9, 9, 9, 10][(n - 100) % 5], "tier of level %d" % n)
	check_eq(Tuning.tier_for_level(10000), Tuning.tier_for_level(10000 - 5), "the cycle holds far out")
	# The fixture writes the same deal in the ranges form: both give every level the same tier.
	var real := PackedInt32Array()
	for n: int in range(9, 1001):
		real.append(Tuning.tier_for_level(n))
	var errors := PackedStringArray()
	check(Tuning.load_text(FileAccess.get_file_as_string(FIXTURE), errors), "the fixture loads: %s" % "; ".join(errors))
	_changed = true
	var ranged := PackedInt32Array()
	for n: int in range(9, 1001):
		ranged.append(Tuning.tier_for_level(n))
	check_eq(ranged, real, "the ranges form and the steps and bases form deal the same tiers, levels 9 to 1000")


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
		tiers.append("%d %s %s %s %s %s %d %d %s %s" % [t.tier, t.group, t.screws, t.colors, t.layers, t.tray_uses, t.novice, t.tray, t.peak, t.skip])
	return var_to_str([Tuning.gifts, Tuning.tray_size, Tuning.relaxed_tray, Tuning.open_boxes, Tuning.box_slots, Tuning.preview, Tuning.tutorial_levels, tiers, Tuning.sawtooth_steps, Tuning.sawtooth_bases, Tuning.sawtooth_ranges, Tuning.tray_par_slack, Tuning.par_base_s, Tuning.par_tenths, Tuning.par_round_s, Tuning.daily_tier, Tuning.daily_slack, Tuning.daily_group, Tuning.relaxed, Tuning.helpers, Tuning.unlocks, Tuning.modes_open_after_level, Tuning.recent_blueprints_excluded])


func test_6_8_a_tier_without_tray_peak_or_skip_keeps_the_old_meaning() -> void:
	# A tier row written before Phase 5: the tuning's tray, no peak, no board skipped; and a file
	# without gifts or relaxed_tray gives none.
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Tuning.PATH))
	for row: Dictionary in d["tiers"]:
		for key: String in ["tray", "peak", "skip"]:
			row.erase(key)
	d.erase("gifts")
	d.erase("relaxed_tray")
	var errors := PackedStringArray()
	check(Tuning.load_text(JSON.stringify(d), errors), "loads: %s" % "; ".join(errors))
	_changed = true
	for t: Tuning.TierSpec in Tuning.tiers:
		check_eq([t.tray, t.peak, t.skip.size()], [Tuning.tray_size, Vector2i(0, -1), 0], "tier %d" % t.tier)
	check_eq([Tuning.gifts.size(), Tuning.relaxed_tray], [0, 0], "no gifts, no Relaxed tray of its own")


func test_6_8_fixture_trays_peaks_and_ranges() -> void:
	# The Phase 5 schedule as a fixture (Bart, 22 October 2026), until data/tuning.json has it.
	var errors := PackedStringArray()
	check(Tuning.load_text(FileAccess.get_file_as_string(FIXTURE), errors), "the fixture loads: %s" % "; ".join(errors))
	_changed = true
	var trays := []
	var peaks := []
	for t: Tuning.TierSpec in Tuning.tiers:
		trays.append(t.tray)
		peaks.append(t.peak.x)
	check_eq(trays, [5, 5, 4, 4, 3, 3, 3, 3, 3, 3], "trays by tier")
	check_eq(peaks, [0, 0, 0, 1, 1, 1, 2, 2, 3, 3], "least peaks by tier")
	check_eq(Tuning.tier(4).peak.y, -1, "a single number gives no most")
	check_eq(Tuning.tray_size, 5, "the tutorial's tray")
	# GDD 6.8: 9 to 20 level by level, then (n - 1) mod 5 inside each range.
	var expected := {9: 1, 10: 1, 11: 2, 12: 3, 15: 3, 16: 4, 20: 4, 21: 5, 22: 5, 23: 5, 24: 6, 25: 6, 26: 5, 49: 6, 50: 8, 51: 7, 54: 8, 99: 8, 100: 10, 101: 9, 104: 10, 1001: 9}
	for n: int in expected:
		check_eq(Tuning.tier_for_level(n), expected[n], "tier of level %d" % n)
	# The range a level is in has the tray and peak of Bart's schedule.
	var schedule := [[9, 11, 5, 0], [12, 15, 4, 0], [16, 20, 4, 1], [21, 49, 3, 1], [50, 99, 3, 2], [100, 400, 3, 3]]
	for row: Array in schedule:
		for n: int in range(row[0], int(row[1]) + 1):
			var spec := Tuning.tier(Tuning.tier_for_level(n))
			if spec.tray != row[2] or spec.peak.x != row[3]:
				check(false, "level %d: tray %d and peak %d, expected %d and %d" % [n, spec.tray, spec.peak.x, row[2], row[3]])
	check_eq([Tuning.tier(Tuning.daily_tier).tray, Tuning.tier(Tuning.daily_tier).peak.x], [3, 1], "the daily's tier: 3 slots, peak 1")


func test_6_8_bad_trays_peaks_and_ranges_are_caught() -> void:
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	_load_real()
	var before := _state()
	var edits := {
		"tray 0": func(d: Dictionary) -> void: d["tiers"][4]["tray"] = 0,
		"tray 8": func(d: Dictionary) -> void: d["tiers"][4]["tray"] = 8,
		"peak above tray": func(d: Dictionary) -> void: d["tiers"][4]["peak"] = 4,
		"peak range low above high": func(d: Dictionary) -> void: d["tiers"][4]["peak"] = [2, 1],
		"peak range above tray": func(d: Dictionary) -> void: d["tiers"][4]["peak"] = [1, 4],
		"peak fraction": func(d: Dictionary) -> void: d["tiers"][4]["peak"] = 1.5,
		"relaxed_tray 0": func(d: Dictionary) -> void: d["relaxed_tray"] = 0,
		"ranges and steps": func(d: Dictionary) -> void: d["sawtooth"]["steps"] = [-2, -1, 0, 1, 2],
		"ranges start late": func(d: Dictionary) -> void: d["sawtooth"]["ranges"][0][0] = 10,
		"ranges not rising": func(d: Dictionary) -> void: d["sawtooth"]["ranges"][2][0] = 20,
		"one by one too short": func(d: Dictionary) -> void: (d["sawtooth"]["ranges"][0][1] as Array).pop_back(),
		"last entry not five": func(d: Dictionary) -> void: (d["sawtooth"]["ranges"][3][1] as Array).append(10),
		"tier 11": func(d: Dictionary) -> void: d["sawtooth"]["ranges"][1][1][0] = 11,
		"skip not a list": func(d: Dictionary) -> void: d["tiers"][6]["skip"] = "skyline",
		"skip bad id": func(d: Dictionary) -> void: d["tiers"][6]["skip"] = ["Skyline"],
		"skip twice": func(d: Dictionary) -> void: d["tiers"][6]["skip"] = ["skyline", "skyline"],
		"gifts not a list": func(d: Dictionary) -> void: d["gifts"] = {"level": 50},
		"gift without level": func(d: Dictionary) -> void: d["gifts"] = [{"undo": 2}],
		"gift of nothing": func(d: Dictionary) -> void: d["gifts"] = [{"level": 50}],
		"gift of a coin": func(d: Dictionary) -> void: d["gifts"] = [{"level": 50, "coin": 1}],
		"gifts not rising": func(d: Dictionary) -> void: d["gifts"] = [{"level": 100, "undo": 1}, {"level": 50, "undo": 1}],
		"gift too big": func(d: Dictionary) -> void: d["gifts"] = [{"level": 50, "undo": 101}],
	}
	for label: String in edits:
		var d: Dictionary = good.duplicate(true)
		(edits[label] as Callable).call(d)
		var errors := PackedStringArray()
		check(not Tuning.load_text(JSON.stringify(d), errors) and not errors.is_empty(), "rejected: " + label)
		check_eq(_state(), before, "nothing changed after: " + label)
	var with_relaxed: Dictionary = good.duplicate(true)
	with_relaxed["relaxed_tray"] = 5
	var errors := PackedStringArray()
	check(Tuning.load_text(JSON.stringify(with_relaxed), errors), "a relaxed_tray loads: %s" % "; ".join(errors))
	_changed = true
	check_eq(Tuning.relaxed_tray, 5, "relaxed_tray")
	var ranged: Dictionary = good.duplicate(true)
	ranged["tiers"][6]["peak"] = [2, 3]
	check(Tuning.load_text(JSON.stringify(ranged), errors), "a peak range loads: %s" % "; ".join(errors))
	check_eq(Tuning.tier(7).peak, Vector2i(2, 3), "least and most")


func cleanup() -> void:
	if _changed:
		_load_real()
		_changed = false
	await super()
