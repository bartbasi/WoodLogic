# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The Phase 5 bots: the retrying people of `retry_player.gd`, and the rule checks of every bot
## on the new tray sizes (5, 4 and 3 slots, and one more after Extra slot).

## Levels across the tray ranges: 9 to 11 (5), 12 to 20 (4), 21 and up (3).
const LEVELS: Array[int] = [10, 12, 18, 21, 40, 60, 105]


func _entry(n: int) -> BotEntry:
	var g := LevelCatalog.get_level(LevelData.NUMBERED, n, "")
	var entry := BotEntry.new()
	entry.level = g.level
	entry.solve = g.solve
	entry.label = "level %d" % n
	return entry


func test_a_person_who_never_slips_follows_the_plan_and_wins_with_the_fewest_tray_uses() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for n: int in LEVELS:
		var entry := _entry(n)
		var session := BotSession.start(entry.level, false)
		var r := RetryPlayer.try_once(entry.level, entry.solve.solution, rng, 0, 0.0, false, session)
		check(bool(r["won"]), "%s: the plan wins" % entry.label)
		check_eq(int(r["wrong"]), 0, "%s: no wrong tap" % entry.label)
		check_eq(int(r["taps"]), entry.level.screw_count(), "%s: one tap per screw" % entry.label)
		check_eq(session.state.tray_uses(), entry.solve.fewest_tray_uses, "%s: the fewest tray uses" % entry.label)
		check_eq(session.violation_count, 0, "%s: %s" % [entry.label, str(Array(session.violations))])


func test_wrong_taps_are_counted_and_checked_against_the_rules() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var wrong_seen := 0
	var outcomes := {"won": 0, "lost": 0}
	for n: int in LEVELS:
		var entry := _entry(n)
		for k: int in [1, 2, 3]:
			var session := BotSession.start(entry.level, false)
			var r := RetryPlayer.try_once(entry.level, entry.solve.solution, rng, k, 0.0, true, session)
			check(int(r["wrong"]) <= k, "%s: at most %d wrong taps (%d)" % [entry.label, k, int(r["wrong"])])
			wrong_seen += int(r["wrong"])
			outcomes["won" if bool(r["won"]) else "lost"] = int(outcomes["won" if bool(r["won"]) else "lost"]) + 1
			check(bool(r["won"]) != bool(r["lost"]), "%s k=%d: it ended won or lost" % [entry.label, k])
			check_eq(session.violation_count, 0, "%s k=%d: %s" % [entry.label, k, str(Array(session.violations))])
	check(wrong_seen >= 15, "wrong taps were really made (%d)" % wrong_seen)
	check(int(outcomes["won"]) > 0 and int(outcomes["lost"]) >= 0, "some tries won (%s)" % str(outcomes))


func test_the_thinker_and_the_mixed_person_play_legally_on_every_tray_size() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for n: int in LEVELS:
		var entry := _entry(n)
		var s1 := BotSession.start(entry.level, false)
		var thinker := RetryPlayer.try_heuristic(entry.level, rng, 0.05, s1)
		check(bool(thinker["won"]) != bool(thinker["lost"]), "%s: the thinker ended" % entry.label)
		check_eq(s1.violation_count, 0, "%s thinker: %s" % [entry.label, str(Array(s1.violations))])
		check(int(thinker["peak"]) <= entry.level.tray_size, "%s: the tray never holds more than its slots" % entry.label)
		var s2 := BotSession.start(entry.level, false)
		var mixed := RetryPlayer.try_mixed(entry.level, entry.solve.solution, rng, 0.5, s2)
		check(bool(mixed["won"]) != bool(mixed["lost"]), "%s: the mixed person ended" % entry.label)
		check_eq(s2.violation_count, 0, "%s mixed: %s" % [entry.label, str(Array(s2.violations))])
		# Skill 1 is the plan.
		var s3 := BotSession.start(entry.level, false)
		var planned := RetryPlayer.try_mixed(entry.level, entry.solve.solution, rng, 1.0, s3)
		check(bool(planned["won"]), "%s: skill 1 wins" % entry.label)


func test_a_retrying_person_is_repeatable_and_slips_less_each_try() -> void:
	var entry := _entry(60)
	var profile := {"wrong": 2.0, "decay": 0.8}
	var a := RetryPlayer.play_until_win(entry.level, entry.solve.solution, 33, profile, 30)
	var b := RetryPlayer.play_until_win(entry.level, entry.solve.solution, 33, profile, 30)
	check_eq(var_to_str(a), var_to_str(b), "the same seed gives the same person")
	check(int(a["tries"]) >= 1 and int(a["tries"]) <= 30, "tries are counted from 1")
	# With a person who slips a lot at first and never after, every level is won by the second
	# try at the latest on an easy level.
	var easy := _entry(9)
	var r := RetryPlayer.play_until_win(easy.level, easy.solve.solution, 1, {"wrong": 3.0, "decay": 0.0}, 30)
	check(bool(r["won"]) and int(r["tries"]) <= 2, "a slip-free retry wins level 9: %s" % str(r))
	# A thinker retrying is also repeatable.
	var t1 := RetryPlayer.heuristic_until_win(entry.level, 9, {"wrong": 0.0, "decay": 0.8}, 6)
	var t2 := RetryPlayer.heuristic_until_win(entry.level, 9, {"wrong": 0.0, "decay": 0.8}, 6)
	check_eq(var_to_str(t1), var_to_str(t2), "the thinker is repeatable too")


func test_the_novice_and_random_bots_agree_with_the_rules_on_the_new_trays() -> void:
	for n: int in LEVELS:
		var entry := _entry(n)
		var novice := BotRunner.play(entry, NoviceBot.new(), true)
		check_eq(novice.won, entry.solve.novice_won, "%s: the novice bot against Solver.novice_won" % entry.label)
		check_eq(novice.violation_count, 0, "%s novice: %s" % [entry.label, str(Array(novice.violations))])
		check(novice.peak_tray <= entry.level.tray_size, "%s: the novice's tray peak %d fits %d slots" % [entry.label, novice.peak_tray, entry.level.tray_size])
		var perfect := BotRunner.play(entry, PerfectBot.new(entry.solve.solution), true)
		check(perfect.won, "%s: the perfect bot wins" % entry.label)
		check_eq(perfect.tray_uses, entry.solve.fewest_tray_uses, "%s: and uses the tray as the solver says" % entry.label)
		check_eq(perfect.violation_count, 0, "%s perfect: %s" % [entry.label, str(Array(perfect.violations))])
		for run: int in 2:
			var random := BotRunner.play(entry, RandomBot.new(70 + run), run == 0)
			check_eq(random.violation_count, 0, "%s random %d: %s" % [entry.label, run, str(Array(random.violations))])
			var chaos := BotRunner.play(entry, ChaosBot.new(90 + run), true)
			check_eq(chaos.violation_count, 0, "%s chaos %d: %s" % [entry.label, run, str(Array(chaos.violations))])
