# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends QaFlowCase
## Checks for the Phase 6 fix round: Relaxed levels measured as they are played (generator
## version 7: the novice and G9a on 5 slots), the Relaxed pools of stored levels, and quitting
## in the middle of a long generation (GenerationStop).

## Quitting must come back within this many milliseconds (the brief for the fix says about 1 s).
const QUIT_LIMIT_MS := 1000


func _played(g: GeneratedLevel) -> BotEntry:
	var entry := BotEntry.new()
	entry.level = g.level
	entry.solve = g.solve
	return entry


func _check_as_played(g: GeneratedLevel, where: String, counts: Dictionary) -> void:
	var level := g.level
	check_eq(level.tray_size, Tuning.relaxed_tray, "%s: Relaxed has its own tray" % where)
	var spec := Tuning.tier(level.tier)
	var fresh := Solver.solve(level, 600000)
	var novice := BotRunner.play(_played(g), NoviceBot.new(), false)
	check_eq(novice.violation_count, 0, "%s: rule checks while the novice plays" % where)
	check_eq(novice.won, fresh.novice_won, "%s: the novice bot agrees with a fresh solve of the level as played" % where)
	check_eq(g.solve.novice_won, fresh.novice_won, "%s: the stored novice result describes the level as played" % where)
	if spec.novice == Tuning.NOVICE_WIN:
		check(novice.won, "%s: tier %d, the novice must win (5 slots)" % [where, level.tier])
	elif spec.novice == Tuning.NOVICE_LOSE:
		check(not novice.won, "%s: tier %d, the novice must lose (5 slots)" % [where, level.tier])
	if Generator.SURVIVAL_TIERS.has(level.tier):
		check(Generator.survives(level, fresh), "%s: tier %d, G9a as played: %d novice taps of %d screws, needs %d" % [where, level.tier, fresh.novice_taps, level.screw_count(), Generator.survival_needed(level.screw_count())])
		counts["g9a"] = int(counts.get("g9a", 0)) + 1
	counts["levels"] = int(counts.get("levels", 0)) + 1
	counts["fell_back"] = int(counts.get("fell_back", 0)) + (1 if g.fell_back else 0)
	if novice.won:
		counts["novice_wins"] = int(counts.get("novice_wins", 0)) + 1


func test_relaxed_levels_hold_the_novice_and_g9a_rules_as_they_are_played() -> void:
	check_eq(Generator.GENERATOR_VERSION, 7, "the fix round is generator version 7")
	var counts := {}
	var numbers := {"easy": range(1, 21), "medium": range(1, 21), "hard": range(1, 41)}
	numbers["hard"].append_array([52, 92])
	for band: String in numbers:
		for i: int in numbers[band]:
			var g := LevelCatalog.get_level(LevelData.RELAXED, i, band)
			_check_as_played(g, "relaxed %s %d" % [band, i], counts)
	print("        relaxed as played: %s" % str(counts))
	check(int(counts.get("g9a", 0)) >= 5, "some tier 7 or 8 Relaxed levels were checked for G9a")


func test_the_relaxed_pools_are_made_and_measured_with_five_slots() -> void:
	var tiers_with_pool := 0
	for t: int in range(1, 11):
		if not Generator.needs_relaxed_pool(t):
			continue
		tiers_with_pool += 1
		var pool: Array = LevelCatalog.relaxed_fallback[t - 1]
		check(pool.size() >= 3, "tier %d has a Relaxed pool (%d levels)" % [t, pool.size()])
		var spec := Tuning.tier(t)
		var sampled := 0
		for g: GeneratedLevel in pool:
			check_eq(g.level.tray_size, Tuning.relaxed_tray, "tier %d pool: stored with 5 slots" % t)
			if spec.novice == Tuning.NOVICE_WIN:
				check(g.solve.novice_won, "tier %d pool: stored novice wins" % t)
			elif spec.novice == Tuning.NOVICE_LOSE:
				check(not g.solve.novice_won, "tier %d pool: stored novice loses" % t)
			if Generator.SURVIVAL_TIERS.has(t):
				check(Generator.survives(g.level, g.solve), "tier %d pool: G9a holds as stored" % t)
			# A few are solved again to make sure the stored numbers are for the level as stored.
			if sampled < 3:
				sampled += 1
				var fresh := Solver.solve(g.level, 600000)
				check_eq(fresh.novice_won, g.solve.novice_won, "tier %d pool: a fresh solve agrees about the novice" % t)
				check(fresh.fewest_tray_uses >= 0 and fresh.solution.size() == g.level.screw_count(), "tier %d pool: a fresh solve wins" % t)
	check(tiers_with_pool >= 3, "%d tiers need a Relaxed pool" % tiers_with_pool)


func _slow_tier_10_numbers() -> Array[int]:
	var out: Array[int] = []
	var n := 100
	while out.size() < 6 and n < 2000:
		if Tuning.tier_for_level(n) == 10:
			out.append(n)
		n += 7
	return out


func test_stopping_a_prefetch_in_the_middle_of_a_tier_10_generation_returns_fast() -> void:
	var mid_generation := 0
	var worst := 0
	for n: int in _slow_tier_10_numbers():
		var prefetch := LevelPrefetcher.new()
		var key := prefetch.request(LevelData.NUMBERED, n, "", true)
		OS.delay_msec(250)
		prefetch.poll()
		var running := prefetch.is_running(key)
		var started := Time.get_ticks_msec()
		prefetch.shutdown()
		var took := Time.get_ticks_msec() - started
		if running:
			mid_generation += 1
			worst = maxi(worst, took)
		check(took < QUIT_LIMIT_MS, "level %d: shutdown took %d ms" % [n, took])
		check(not prefetch.is_ready(key) or running == false, "level %d: a stopped level is not handed out" % n)
		await frames(1)
	print("        tier 10 stops: %d of 6 were mid generation, worst shutdown %d ms" % [mid_generation, worst])
	check(mid_generation >= 2, "at least two of the six were still being made when stopped (%d)" % mid_generation)


func test_quitting_the_app_while_a_tier_10_level_is_being_made_returns_within_a_second() -> void:
	var done := 0
	for n: int in _slow_tier_10_numbers().slice(0, 3):
		start_real_at(20)
		flow.play_number(n)
		check_eq(flow.state, AppFlow.State.LOADING, "level %d is being made" % n)
		OS.delay_msec(250)
		var quits := quit_calls
		var started := Time.get_ticks_msec()
		flow.quit()
		var took := Time.get_ticks_msec() - started
		check(took < QUIT_LIMIT_MS, "level %d: quitting took %d ms" % [n, took])
		check_eq(quit_calls, quits + 1, "the app asked the engine to quit once")
		done += 1
		flow.queue_free()
		await frames(2)
	check_eq(done, 3, "three levels tried")
