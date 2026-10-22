# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Phase 5 acceptance items that live in the logic (GDD 12, 22b): the tray by tier and by level,
## the least peak (G10) and its search, checked from outside on real generator output. The
## full run, 100 levels per tier with the true least peak of each, is `acceptance.gd`.

const TRAY_BY_TIER: Array[int] = [5, 5, 4, 4, 3, 3, 3, 3, 3, 3]
const PEAK_BY_TIER: Array[int] = [0, 0, 0, 1, 1, 1, 2, 2, 3, 3]
## The levels looked at: both ends of every range, a few inside, and a fallback-prone stretch.
const LEVELS: Array[int] = [9, 10, 11, 12, 13, 15, 16, 18, 20, 21, 22, 25, 30, 41, 49, 50, 51, 55, 60, 75, 99, 100, 101, 104, 105, 120, 150]

var _gdd := ""


func _flat() -> String:
	if _gdd == "":
		var out := FileAccess.get_file_as_string("res://docs/GDD.md").replace("\n", " ").replace("\r", " ")
		while out.contains("  "):
			out = out.replace("  ", " ")
		_gdd = out
	return _gdd


## The tray the GDD gives numbered level n (6.8): 5 to level 11, 4 to level 20, 3 from 21.
func _gdd_tray(n: int) -> int:
	if n <= 11:
		return 5
	if n <= 20:
		return 4
	return 3


func _with_tray(level: LevelData, slots: int) -> LevelData:
	var errors := PackedStringArray()
	var copy := level.with_colors(level.screw_colors, level.queue, errors, {"tray": slots})
	if copy == null:
		push_error("a copy with %d slots: %s" % [slots, "; ".join(errors)])
	return copy


func test_acc_22b_the_data_holds_the_tray_and_least_peak_of_gdd_6_8() -> void:
	for t: int in range(1, 11):
		check_eq(Tuning.tier(t).tray, TRAY_BY_TIER[t - 1], "tier %d tray" % t)
		check_eq(Tuning.tier(t).peak.x, PEAK_BY_TIER[t - 1], "tier %d least peak" % t)
	check_eq(Tuning.tray_size, 5, "the starting tray (the tutorial's) is 5")
	check_eq(Tuning.relaxed_tray, 5, "Relaxed keeps 5")
	# The table of 6.8, row by row: levels, tiers, tray, least peak.
	for row: String in ["| 9 to 11 | 1, 1, 2 | 5 | 0 |", "| 12 to 15 | 3 | 4 | 0 |", "| 16 to 20 | 4 | 4 | 1 |", "| 21 to 49 | 5, 5, 5, 6, 6 | 3 | 1 |", "| 50 to 99 | 7, 7, 7, 8, 8 | 3 | 2 |", "| 100 on | 9, 9, 9, 10, 10 | 3 | 3 |"]:
		check(_flat().contains(row), "the GDD table has the row %s" % row)
	# Per level, through the tier it is dealt.
	for n: int in range(9, 400):
		var spec := Tuning.tier(Tuning.tier_for_level(n))
		check_eq(spec.tray, _gdd_tray(n), "level %d: the tray of its tier" % n)
	check_eq(Tuning.tier(Tuning.daily_tier).tray, 3, "the Daily's tier has a 3 slot tray")
	check_eq(Tuning.tier(Tuning.daily_tier).peak.x, 1, "and least peak 1")


func test_acc_22b_generated_levels_have_their_tray_and_no_solution_one_slot_short_of_the_peak() -> void:
	var made := 0
	var checked_g10 := 0
	var reqs: Array[Array] = []
	for n: int in LEVELS:
		reqs.append([LevelData.NUMBERED, n, ""])
	for d: int in [20261021, 20270315, 20281231]:
		reqs.append([LevelData.DAILY, d, ""])
	for band: String in Tuning.BANDS:
		for i: int in [1, 2, 3]:
			reqs.append([LevelData.RELAXED, i, band])
	for req: Array in reqs:
		var g := LevelCatalog.get_level(req[0], req[1], req[2])
		var where := LevelPrefetcher.key_for(req[0], req[1], req[2])
		check(g != null and g.level != null, "%s: a level" % where)
		if g == null or g.level == null:
			continue
		made += 1
		var level := g.level
		# The tray the level carries, and the rules' tray.
		var want := 5
		match int(req[0]):
			LevelData.NUMBERED:
				want = _gdd_tray(int(req[1]))
			LevelData.DAILY:
				want = 3
		check_eq(level.tray_size, want, "%s: tray size" % where)
		check_eq(PlayState.start(level).tray().size(), want, "%s: PlayState's tray" % where)
		var spec := Tuning.tier(level.tier)
		if int(req[0]) == LevelData.NUMBERED:
			check_eq(level.tier, Tuning.tier_for_level(int(req[1])), "%s: tier" % where)
		check_eq(spec.peak.x, PEAK_BY_TIER[level.tier - 1], "%s: the tier's least peak" % where)
		# G10: no solution with one slot fewer than the least peak P (P of 2 or more); for P = 1
		# it is G3 (the tray is needed at least once).
		var peak := spec.peak.x
		check(g.solve.solved and g.solve.complete, "%s: solved with a complete search" % where)
		if peak >= 2:
			var short := Solver.solve(_with_tray(level, peak - 1), 600000)
			checked_g10 += 1
			check(short.complete, "%s: the search with %d slots finished (%d states)" % [where, peak - 1, short.states])
			check(not short.solved, "%s: G10, no solution with %d slots (least peak %d)" % [where, peak - 1, peak])
		elif peak == 1:
			check(g.solve.fewest_tray_uses >= 1, "%s: a least peak of 1 needs the tray at least once" % where)
	check(made >= 35, "%d levels were made" % made)
	check(checked_g10 >= 8, "G10 was searched on %d levels" % checked_g10)


func test_acc_22b_tutorial_levels_keep_5_slots_and_the_tray_never_grows_with_the_level() -> void:
	for n: int in range(1, 9):
		var level := LevelCatalog.get_level(LevelData.NUMBERED, n, "").level
		check_eq(level.tray_size, 5, "tutorial level %d" % n)
		check_eq(PlayState.start(level).tray().size(), 5, "tutorial level %d: PlayState" % n)
	var last := 5
	for n: int in range(9, 140):
		var slots := Tuning.tier(Tuning.tier_for_level(n)).tray
		check(slots <= last, "level %d: the tray (%d) is never bigger than the level before (%d)" % [n, slots, last])
		last = slots


func test_acc_22b_a_stored_fallback_carries_the_tray_of_the_level_it_stands_in_for() -> void:
	# Fallback levels are handed out relabeled for any number; their tray must follow the tier
	# they are served as, not the tray they were stored with.
	for t: int in range(1, 11):
		for stored: GeneratedLevel in LevelCatalog.fallback[t - 1]:
			check_eq(stored.level.tier, t, "tier %d fallback: its tier" % t)
			check_eq(stored.level.tray_size, Tuning.tier(t).tray, "tier %d fallback %s: tray size" % [t, stored.level.blueprint_id])
