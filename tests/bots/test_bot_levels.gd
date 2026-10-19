# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The level sources, the bots' numbers against the solver, and the report tool's output.

const FIXED_BLUEPRINTS: Array[String] = ["bricks", "house", "tree", "fish", "windmill", "rings"]


func _fixed(seed_value: int = 77) -> BotLevelSet:
	return BotLevels.colorings(1, seed_value, 100000, 1, PackedStringArray(FIXED_BLUEPRINTS))


func test_colorings_are_repeatable_for_a_seed() -> void:
	var a := _fixed()
	var b := _fixed()
	check_eq(a.entries.size(), b.entries.size(), "levels made")
	for i: int in mini(a.entries.size(), b.entries.size()):
		check_eq(a.entries[i].level.screw_colors, b.entries[i].level.screw_colors, "%s colors" % a.entries[i].label)
		check_eq(a.entries[i].level.queue, b.entries[i].level.queue, "%s queue" % a.entries[i].label)
		check_eq(a.entries[i].solve.fewest_tray_uses, b.entries[i].solve.fewest_tray_uses, "%s fewest tray uses" % a.entries[i].label)
	var c := _fixed(78)
	var different := false
	for i: int in mini(a.entries.size(), c.entries.size()):
		if a.entries[i].level.screw_colors != c.entries[i].level.screw_colors:
			different = true
	check(different, "another seed gave the same colorings")


func test_colorings_obey_the_acceptance_rules() -> void:
	var set := _fixed()
	check(set.entries.size() >= 4, "only %d colorings were made" % set.entries.size())
	for entry: BotEntry in set.entries:
		var level := entry.level
		check(entry.solve.complete and entry.solve.solved, "%s: solved with a complete search" % entry.label)
		# R3 and G6.
		for c: int in LevelData.MAX_COLORS:
			check_eq(level.screw_colors.count(c), 3 * level.queue.count(c), "%s: R3 for color %d" % [entry.label, c])
		for i: int in range(1, level.queue.size()):
			check(level.queue[i] != level.queue[i - 1], "%s: G6, the same color twice in a row at %d" % [entry.label, i])
		# G5.
		var state := PlayState.start(level)
		var fits := false
		for s: int in level.screw_count():
			if state.is_free(s) and state.destination(s).x == PlayState.BOX:
				fits = true
		check(fits, "%s: G5, a free screw fits an open box at the start" % entry.label)
		# Par numbers for Stars.award.
		check_eq(level.tray_par, entry.solve.fewest_tray_uses + 1, "%s: tray par" % entry.label)
		check(level.par_time_s >= 15 and level.par_time_s % 5 == 0, "%s: par time %d" % [entry.label, level.par_time_s])
		check_eq(entry.tier, BotLevels.estimate_tier(level.screw_count(), level.color_count(), level.layer_count()), "%s: tier" % entry.label)
		check(level.screw_count() <= 36 and level.color_count() <= 8, "%s: readability caps" % entry.label)


func test_the_perfect_bot_matches_the_solver_and_the_novice_bot_matches_its_policy() -> void:
	for entry: BotEntry in _fixed().entries:
		var perfect := BotRunner.play(entry, PerfectBot.new(entry.solve.solution))
		check(perfect.won, "%s: the perfect bot won" % entry.label)
		check_eq(perfect.tray_uses, entry.solve.fewest_tray_uses, "%s: the perfect bot's tray uses" % entry.label)
		check_eq(perfect.violation_count, 0, "%s: %s" % [entry.label, str(Array(perfect.violations))])
		var novice := BotRunner.play(entry, NoviceBot.new())
		check_eq(novice.won, entry.solve.novice_won, "%s: the novice bot against Solver.novice_won" % entry.label)
		check_eq(novice.violation_count, 0, "%s: %s" % [entry.label, str(Array(novice.violations))])
		check(novice.tray_uses >= perfect.tray_uses or not novice.won, "%s: the novice used the tray less than the best" % entry.label)


func test_a_run_is_reproducible() -> void:
	var entry: BotEntry = _fixed().entries[0]
	var a := BotRunner.play_entry(entry, 6, 5, false)
	var b := BotRunner.play_entry(entry, 6, 5, false)
	for bot: String in BotReport.BOTS:
		check_eq(var_to_str(a.bot(bot).star_hist), var_to_str(b.bot(bot).star_hist), "%s: star spread" % bot)
		check_eq(a.bot(bot).sum_taps, b.bot(bot).sum_taps, "%s: taps" % bot)
		check_eq(a.bot(bot).sum_peak, b.bot(bot).sum_peak, "%s: peak" % bot)
	check_eq(a.bot("random").games, 6, "random games")
	check_eq(a.bot("perfect").games, 1, "perfect games")


func test_estimate_tier_follows_the_tuning_table() -> void:
	check_eq(BotLevels.estimate_tier(9, 2, 1), 1, "9 screws")
	check_eq(BotLevels.estimate_tier(12, 2, 1), 1, "12 screws, 2 colors")
	check_eq(BotLevels.estimate_tier(14, 3, 2), 2, "14 screws")
	check_eq(BotLevels.estimate_tier(25, 5, 4), 6, "25 screws, 5 colors")
	check_eq(BotLevels.estimate_tier(36, 7, 4), 9, "36 screws, 7 colors")
	check_eq(BotLevels.estimate_tier(36, 8, 5), 10, "36 screws, 8 colors")
	check_eq(BotLevels.estimate_tier(3, 1, 1), 1, "a tiny level")
	check_eq(BotLevels.group_of_tier(1), "Easy", "tier 1")
	check_eq(BotLevels.group_of_tier(5), "Medium", "tier 5")
	check_eq(BotLevels.group_of_tier(8), "Hard", "tier 8")
	check_eq(BotLevels.group_of_tier(10), "Expert", "tier 10")


func test_any_list_of_levels_can_be_played() -> void:
	# The seam for the generator: a plain list of LevelData in, entries out.
	var levels: Array[LevelData] = []
	for entry: BotEntry in BotLevels.tutorials().entries:
		levels.append(entry.level)
	var set := BotLevels.from_levels(levels, "generated")
	check_eq(set.entries.size(), 8, "entries from a list of levels")
	check_eq(set.entries[0].source, "generated", "source")
	for entry: BotEntry in set.entries:
		var r := BotRunner.play(entry, PerfectBot.new(entry.solve.solution))
		check(r.won, "%s: won" % entry.label)


func test_the_csv_has_one_row_per_level_and_matching_columns() -> void:
	var records: Array[BotRecord] = []
	var entries: Array[BotEntry] = []
	entries.append_array(BotLevels.tutorials().entries.slice(0, 3))
	entries.append_array(_fixed().entries.slice(0, 3))
	for entry: BotEntry in entries:
		records.append(BotRunner.play_entry(entry, 3, 9, false))
	var text := BotReport.csv(records)
	var lines := text.strip_edges().split("\n")
	check_eq(lines.size(), records.size() + 1, "CSV lines")
	var header := lines[0].split(",")
	var wanted: Array[String] = ["source", "label", "group", "tier", "number", "screws", "colors", "layers", "fewest_tray_uses", "solver_states", "perfect_win_rate", "novice_win_rate", "random_win_rate", "random_peak_tray", "novice_stars", "random_time_s"]
	for column: String in wanted:
		check(header.has(column), "CSV column %s" % column)
	for i: int in range(1, lines.size()):
		check_eq(lines[i].split(",").size(), header.size(), "cells in row %d" % i)
	var row := lines[1].split(",")
	check_eq(row[header.find("source")], "tutorial", "first row source")
	check_eq(row[header.find("perfect_win_rate")], "1.000", "first row perfect win rate")
	check_eq(row[header.find("fewest_tray_uses")], "0", "first row fewest tray uses")


func test_the_tables_name_every_group_played() -> void:
	var records: Array[BotRecord] = []
	var entries: Array[BotEntry] = []
	entries.append_array(BotLevels.tutorials().entries.slice(0, 2))
	entries.append_array(_fixed().entries)
	for entry: BotEntry in entries:
		records.append(BotRunner.play_entry(entry, 3, 9, false))
	for by: String in ["band", "tier", "blueprint"]:
		var text := BotReport.tables(records, by)
		check(text.contains("Win rate"), "%s: the win rate table" % by)
		check(text.contains("Tray pressure"), "%s: the tray pressure table" % by)
		check(text.contains("Stars"), "%s: the stars table" % by)
		check(text.contains("ALL"), "%s: the total row" % by)
	var by_band := BotReport.tables(records, "band")
	check(by_band.contains("Tutorial"), "the Tutorial row")
	for r: BotRecord in records:
		check(by_band.contains(r.entry.group), "the %s row" % r.entry.group)
