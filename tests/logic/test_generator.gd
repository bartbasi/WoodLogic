# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The generator (GDD 6.3 to 6.6, G1 to G7; docs/ARCHITECTURE.md 4.4).

const FIRST := 9


func _ready_catalog() -> void:
	check(LevelCatalog.load_all(), "the catalog loads")


func _id(kind: int, number: int, band: String) -> String:
	return LevelCatalog.blueprints[Generator.blueprint_for(kind, number, band)].id


func test_g7_no_blueprint_repeats_within_five_numbered_levels() -> void:
	_ready_catalog()
	var recent: Array[String] = []
	var bad := 0
	for n: int in range(FIRST, 3000):
		var b := Generator.blueprint_for(LevelData.NUMBERED, n, "")
		var id := LevelCatalog.blueprints[b].id
		if recent.has(id):
			bad += 1
			if bad < 5:
				check(false, "level %d repeats %s from the last five" % [n, id])
		if not LevelCatalog.suits[Tuning.tier_for_level(n) - 1].has(b):
			check(false, "level %d: %s does not suit tier %d" % [n, id, Tuning.tier_for_level(n)])
		recent.append(id)
		if recent.size() > Tuning.recent_blueprints_excluded:
			recent.pop_front()
	check_eq(bad, 0, "repeats within five levels, 9 to 2999")


func test_g7_is_a_pure_function_of_the_level_number() -> void:
	_ready_catalog()
	# Asking for a level far out first, or out of order, gives the same answers.
	var far := _id(LevelData.NUMBERED, 2718, "")
	for n: int in range(FIRST, 60):
		_id(LevelData.NUMBERED, n, "")
	check_eq(_id(LevelData.NUMBERED, 2718, ""), far, "level 2718's blueprint does not depend on what was asked before")


func test_g7_relaxed_streams_and_the_daily() -> void:
	_ready_catalog()
	for band: String in Tuning.BANDS:
		var recent: Array[String] = []
		var range_ok := true
		for i: int in 1500:
			var tier := Generator.relaxed_tier(band, i)
			var r: Vector2i = Tuning.relaxed[band]
			range_ok = range_ok and tier >= r.x and tier <= r.y
			var id := _id(LevelData.RELAXED, i, band)
			check(not recent.has(id), "relaxed %s %d repeats %s" % [band, i, id])
			recent.append(id)
			if recent.size() > Tuning.recent_blueprints_excluded:
				recent.pop_front()
		check(range_ok, "relaxed %s tiers stay in the band" % band)
	var recent_days: Array[String] = []
	for day: int in 400:
		var date := _date_of(Seeds.day_number(2026, 10, 19) + day)
		var id := _id(LevelData.DAILY, date, "")
		check(not recent_days.has(id), "daily %d repeats %s" % [date, id])
		recent_days.append(id)
		if recent_days.size() > Tuning.recent_blueprints_excluded:
			recent_days.pop_front()
	check_eq(_date_of(Seeds.day_number(2026, 10, 19)), 20261019, "the date walk")
	check_eq(_date_of(Seeds.day_number(2028, 3, 1)), 20280301, "the date walk over a leap day")


func test_6_3_plans_follow_the_sawtooth_daily_and_bands() -> void:
	_ready_catalog()
	for n: int in range(FIRST, 200):
		var plan := Generator.plan_for(LevelData.NUMBERED, n, "")
		check_eq(plan.tier, Tuning.tier_for_level(n), "level %d tier" % n)
		check_eq(plan.slack, Tuning.slack_for_level(n), "level %d slack" % n)
	var daily := Generator.plan_for(LevelData.DAILY, 20261019, "")
	check(daily.tier == 6 and daily.slack == 1 and daily.group == "medium", "the daily is tier 6, slack 1, medium")


func test_g1_to_g6_hold_and_every_level_is_solved() -> void:
	_ready_catalog()
	var requests: Array[Array] = []
	for n: int in range(FIRST, 41):
		requests.append([LevelData.NUMBERED, n, ""])
	for n: int in [101, 152, 155]:
		requests.append([LevelData.NUMBERED, n, ""])
	for d: int in [20261019, 20261231, 20270301]:
		requests.append([LevelData.DAILY, d, ""])
	for band: String in Tuning.BANDS:
		requests.append([LevelData.RELAXED, 3, band])
	var fell := 0
	for req: Array in requests:
		var g := Generator.make(req[0], req[1], req[2])
		var where := LevelPrefetcher.key_for(req[0], req[1], req[2])
		check(g != null and g.level != null, "%s: a level" % where)
		if g == null or g.level == null:
			continue
		var level := g.level
		var r := g.solve
		check(r.solved and r.complete, "%s: solved with a complete search" % where)
		check_eq(_replay(level, r.solution), r.fewest_tray_uses, "%s: the solution replays with the fewest tray uses" % where)
		check_eq(level.kind, req[0], "%s: kind" % where)
		check_eq(level.number, req[1], "%s: number" % where)
		check_eq(level.generator_version, Generator.GENERATOR_VERSION, "%s: generator version" % where)
		var plan := Generator.plan_for(req[0], req[1], req[2])
		check_eq(level.tray_par, r.fewest_tray_uses + plan.slack, "%s: tray par is fewest plus slack (S7)" % where)
		check_eq(level.par_time_s, Tuning.par_time_for(level.screw_count(), level.group), "%s: par time (S8)" % where)
		# G6.
		for i: int in range(1, level.queue.size()):
			check(level.queue[i] != level.queue[i - 1], "%s: G6, no color twice in a row" % where)
		# G5.
		check(_g5(level), "%s: G5, a free screw fits an open box at the start" % where)
		if g.fell_back:
			fell += 1
			continue
		var spec := Tuning.tier(level.tier)
		check_eq(level.tier, plan.tier, "%s: tier" % where)
		# G1.
		var n := level.screw_count()
		check(n >= spec.screws.x and n <= spec.screws.y, "%s: G1 screws %d in %s" % [where, n, spec.screws])
		check(level.color_count() >= spec.colors.x and level.color_count() <= spec.colors.y, "%s: G1 colors %d in %s" % [where, level.color_count(), spec.colors])
		check(level.layer_count() >= spec.layers.x and level.layer_count() <= spec.layers.y, "%s: G1 layers" % where)
		# G2.
		check(BlueprintValidator.check(level).is_empty(), "%s: G2, the varied board keeps the blueprint rules" % where)
		# G3 and G4.
		check(r.fewest_tray_uses >= spec.tray_uses.x and r.fewest_tray_uses <= spec.tray_uses.y, "%s: G3 fewest tray uses %d in %s" % [where, r.fewest_tray_uses, spec.tray_uses])
		if spec.novice == Tuning.NOVICE_WIN:
			check(r.novice_won, "%s: G4, the novice must win" % where)
		elif spec.novice == Tuning.NOVICE_LOSE:
			check(not r.novice_won, "%s: G4, the novice must lose" % where)
	print("        %d levels made, %d from a fallback" % [requests.size(), fell])


func test_same_seed_same_level() -> void:
	_ready_catalog()
	for req: Array in [[LevelData.NUMBERED, 9, ""], [LevelData.NUMBERED, 25, ""], [LevelData.NUMBERED, 60, ""], [LevelData.DAILY, 20261019, ""], [LevelData.RELAXED, 11, "hard"]]:
		var a := Generator.make(req[0], req[1], req[2])
		var b := Generator.make(req[0], req[1], req[2])
		check_eq(a.level.fingerprint(), b.level.fingerprint(), "%s: the same level twice" % str(req))
		check_eq(a.solve.solution, b.solve.solution, "%s: the same solution" % str(req))
		check_eq(a.attempts, b.attempts, "%s: the same tries" % str(req))


func test_fallback_files_hold_good_levels_for_every_tier() -> void:
	_ready_catalog()
	for t: int in range(1, Tuning.tiers.size() + 1):
		var pool: Array = LevelCatalog.fallback[t - 1]
		check(pool.size() >= 1, "tier %d has fallback levels" % t)
		for stored: GeneratedLevel in pool:
			var level := stored.level
			var spec := Tuning.tier(t)
			check_eq(level.tier, t, "%s: tier" % level.id)
			check(BlueprintValidator.check(level).is_empty(), "%s: keeps the blueprint rules" % level.id)
			var r := Solver.solve(level, 400000)
			check(r.solved and r.complete, "%s: solves" % level.id)
			check_eq(r.fewest_tray_uses, stored.solve.fewest_tray_uses, "%s: the stored fewest tray uses" % level.id)
			check(r.fewest_tray_uses >= spec.tray_uses.x and r.fewest_tray_uses <= spec.tray_uses.y, "%s: G3" % level.id)
			check_eq(_replay(level, stored.solve.solution), r.fewest_tray_uses, "%s: the stored solution replays" % level.id)
			check_eq(r.novice_won, stored.solve.novice_won, "%s: the stored novice result" % level.id)


func test_deal_gives_distinct_blueprints_from_one_half() -> void:
	_ready_catalog()
	for block: int in 400:
		var tiers := PackedInt32Array()
		for p: int in Tuning.recent_blueprints_excluded:
			tiers.append(Tuning.tier_for_level(FIRST + block * Tuning.recent_blueprints_excluded + p))
		var half := LevelCatalog.halves[block % 2]
		var picks := Generator.deal(half, tiers, block)
		for p: int in picks.size():
			check(half.has(picks[p]), "block %d: pick %d comes from its half" % [block, p])
			check_eq(picks.count(picks[p]), 1, "block %d: pick %d is not repeated" % [block, p])


func _replay(level: LevelData, solution: PackedInt32Array) -> int:
	var state := PlayState.start(level)
	for s: int in solution:
		if not state.tap(s).ok:
			return -1
	return state.tray_uses() if state.status() == PlayState.WON else -1


func _g5(level: LevelData) -> bool:
	var state := PlayState.start(level)
	for s: int in level.screw_count():
		if state.is_free(s) and state.destination(s).x == PlayState.BOX:
			return true
	return false


## The yyyymmdd date of a day number (days since 2000-01-01), by walking months.
func _date_of(day_number: int) -> int:
	var y := 2000
	var m := 1
	var d := 1
	var left := day_number
	while left > 0:
		var lengths := [31, 29 if (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
		var rest: int = lengths[m - 1] - d + 1
		if left >= rest:
			left -= rest
			d = 1
			m += 1
			if m > 12:
				m = 1
				y += 1
		else:
			d += left
			left = 0
	return y * 10000 + m * 100 + d
