# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The bots on the eight tutorial levels (GDD 8): the perfect bot wins with no tray use, the
## novice wins all eight, and since no tutorial has a reachable losing state, nor does the
## random bot ever lose.


func _entries() -> BotLevelSet:
	return BotLevels.tutorials()


func test_there_are_eight_tutorial_levels() -> void:
	var set := _entries()
	check_eq(set.entries.size(), 8, "tutorial levels solved")
	check_eq(set.unsolvable + set.incomplete, 0, "tutorial levels dropped")


func test_perfect_bot_wins_every_tutorial_with_zero_tray_uses() -> void:
	for entry: BotEntry in _entries().entries:
		var r := BotRunner.play(entry, PerfectBot.new(entry.solve.solution))
		check(r.won, "%s: the perfect bot won" % entry.label)
		check_eq(r.tray_uses, 0, "%s: tray uses" % entry.label)
		check_eq(r.tray_uses, entry.solve.fewest_tray_uses, "%s: tray uses against the solver's fewest" % entry.label)
		check_eq(r.taps, entry.screws(), "%s: taps" % entry.label)
		check_eq(r.peak_tray, 0, "%s: tray pressure" % entry.label)
		check_eq(r.stars, Vector3i(1, 1, 1), "%s: stars" % entry.label)
		check_eq(r.violation_count, 0, "%s: rule violations %s" % [entry.label, str(Array(r.violations))])


func test_novice_bot_wins_every_tutorial() -> void:
	for entry: BotEntry in _entries().entries:
		var r := BotRunner.play(entry, NoviceBot.new())
		check(r.won, "%s: the novice bot won" % entry.label)
		check_eq(r.won, entry.solve.novice_won, "%s: the bot against Solver.novice_won" % entry.label)
		check_eq(r.violation_count, 0, "%s: rule violations %s" % [entry.label, str(Array(r.violations))])


func test_random_bot_never_loses_a_tutorial() -> void:
	for entry: BotEntry in _entries().entries:
		for run: int in 25:
			var r := BotRunner.play(entry, RandomBot.new(1000 + run), run == 0)
			check(r.won, "%s: random run %d won (lost=%s)" % [entry.label, run, str(r.lost)])
			check_eq(r.violation_count, 0, "%s: random run %d violations %s" % [entry.label, run, str(Array(r.violations))])
			check(r.stars.x == 1 or not r.won, "%s: a win earns the Cleared star" % entry.label)


func test_a_lost_game_earns_no_stars_and_a_won_one_the_cleared_star() -> void:
	var entry: BotEntry = _entries().entries[2]
	var level := entry.level
	check_eq(Stars.award(level, false, 1000, 0, PackedStringArray()), Vector3i.ZERO, "stars for a loss")
	check_eq(Stars.award(level, true, level.par_time_s * 1000, level.tray_par, PackedStringArray()), Vector3i(1, 1, 1), "stars at exactly par")
	check_eq(Stars.award(level, true, level.par_time_s * 1000 + 1, level.tray_par + 1, PackedStringArray()), Vector3i(1, 0, 0), "stars one millisecond and one tray use over par")
