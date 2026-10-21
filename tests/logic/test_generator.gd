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
		var date := Seeds.date_of_day(Seeds.day_number(2026, 10, 19) + day)
		var id := _id(LevelData.DAILY, date, "")
		check(not recent_days.has(id), "daily %d repeats %s" % [date, id])
		recent_days.append(id)
		if recent_days.size() > Tuning.recent_blueprints_excluded:
			recent_days.pop_front()
	check_eq(_date_of(Seeds.day_number(2028, 3, 1)), Seeds.date_of_day(Seeds.day_number(2028, 3, 1)), "date_of_day agrees with a walk through the months")


func test_6_6_relaxed_bands_give_each_tier_its_share() -> void:
	_ready_catalog()
	for band: String in Tuning.BANDS:
		var span: Vector2i = Tuning.relaxed[band]
		var count := {}
		var n := 600
		for i: int in n:
			var t := Generator.relaxed_tier(band, i)
			count[t] = int(count.get(t, 0)) + 1
			var b := Generator.blueprint_for(LevelData.RELAXED, i, band)
			check(LevelCatalog.suits[t - 1].has(b), "relaxed %s %d: the blueprint suits its tier" % [band, i])
		for t: int in range(span.x, span.y + 1):
			var share := float(count.get(t, 0)) / n
			check(share >= 0.8 / (span.y - span.x + 1), "relaxed %s: tier %d gets %.0f%% of levels" % [band, t, 100.0 * share])
		print("        relaxed %s: %s" % [band, str(count)])


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
		# G9 where the tier requires it.
		check(Generator.g9_holds(level.tier, level, r), "%s: G9 (novice taps %d of %d)" % [where, r.novice_taps, n])
	print("        %d levels made, %d from a fallback" % [requests.size(), fell])


func test_g9a_survival_needed_follows_the_gdd_table() -> void:
	# GDD 6.4.1: ceil(n / 3) taps, 9 for 27 screws up to 12 for 34 to 36.
	var table := {27: 9, 28: 10, 30: 10, 31: 11, 33: 11, 34: 12, 36: 12}
	for n: int in table:
		check_eq(Generator.survival_needed(n), table[n], "%d screws" % n)
	check_eq(str(Generator.SURVIVAL_TIERS), "[7, 8]", "G9a is required on tiers 7 and 8 (GDD 6.4.1 as proposed)")
	check(Generator.LATE_TRAY_TIERS.is_empty(), "G9b is reported only")
	for t: int in range(1, 11):
		check_eq(Generator.budget_scale(t), 2 if t == 7 or t == 8 else 1, "tier %d budget scale" % t)


func test_g9a_tier_7_and_8_levels_let_the_novice_survive_a_third() -> void:
	_ready_catalog()
	var requests: Array[Array] = []
	for n: int in range(111, 200):
		var t := Tuning.tier_for_level(n)
		if Generator.SURVIVAL_TIERS.has(t) and requests.size() < 10:
			requests.append([LevelData.NUMBERED, n, ""])
	for i: int in 6:
		if Generator.SURVIVAL_TIERS.has(Generator.relaxed_tier("hard", i)) and requests.size() < 13:
			requests.append([LevelData.RELAXED, i, "hard"])
	var fell := 0
	var tiers := {}
	for req: Array in requests:
		var g := Generator.make(req[0], req[1], req[2])
		var where := LevelPrefetcher.key_for(req[0], req[1], req[2])
		var level := g.level
		var r := g.solve
		tiers[level.tier] = true
		fell += 1 if g.fell_back else 0
		check(not r.novice_won, "%s: G4, the novice loses" % where)
		check_eq(r.novice_taps, _novice_taps(level), "%s: the novice taps agree with PlayState" % where)
		if Generator.SURVIVAL_TIERS.has(level.tier):
			check(Generator.survives(level, r), "%s (tier %d, %d screws): G9a, the novice survives %d taps, needs %d" % [where, level.tier, level.screw_count(), r.novice_taps, Generator.survival_needed(level.screw_count())])
		print("        %s tier %d %s: novice %d of %d taps (needs %d), last tray use %d, %d attempts%s" % [where, level.tier, level.blueprint_id, r.novice_taps, level.screw_count(), Generator.survival_needed(level.screw_count()), r.last_tray_use, g.attempts, ", fell back" if g.fell_back else ""])
	check(tiers.has(7) and tiers.has(8), "levels of both tiers were made")
	check(fell < requests.size(), "not every level fell back")


func test_g9_is_only_reported_on_tiers_9_and_10() -> void:
	_ready_catalog()
	for n: int in [154, 155, 159, 160]:
		var g := Generator.make(LevelData.NUMBERED, n, "")
		check(g.level.tier >= 9, "level %d is expert" % n)
		check_eq(g.short_survival + g.early_tray, 0, "level %d: nothing turned down for G9" % n)
		check_eq(g.solve.novice_taps, _novice_taps(g.level), "level %d: but the novice taps are measured" % n)


func test_g9_closest_try_prefers_one_that_holds_g9a() -> void:
	_ready_catalog()
	var board := LevelCatalog.blueprints[LevelCatalog.blueprint_index("skyline")]
	check_eq(board.screw_count(), 30, "a 30 screw board, so G9a needs 10 taps")
	var deep := SolveResult.new()
	deep.solved = true
	deep.fewest_tray_uses = 3
	deep.novice_taps = 6
	var soft := SolveResult.new()
	soft.solved = true
	soft.fewest_tray_uses = 2
	soft.novice_taps = 12
	for t: int in [7, 8, 9, 10]:
		var plan := Generator.Plan.new()
		plan.tier = t
		var spec := Tuning.tier(t)
		var a := Generator._closeness(plan, spec, board, deep)
		var b := Generator._closeness(plan, spec, board, soft)
		if Generator.SURVIVAL_TIERS.has(t):
			check(b > a, "tier %d: two tray uses holding G9a beat three that do not" % t)
		else:
			check(a > b, "tier %d: G9a is not required, so the most tray uses come first" % t)


func test_4_1_generated_levels_read_back_from_json_with_the_same_fingerprint_and_solve() -> void:
	# The app saves the next level as JSON and plays it from the file (ARCHITECTURE 10.3).
	_ready_catalog()
	var requests: Array[Array] = []
	for n: int in range(FIRST, 61):
		requests.append([LevelData.NUMBERED, n, ""])
	for n: int in [101, 152, 153, 155]:
		requests.append([LevelData.NUMBERED, n, ""])
	for d: int in [20261019, 20261231]:
		requests.append([LevelData.DAILY, d, ""])
	for band: String in Tuning.BANDS:
		requests.append([LevelData.RELAXED, 2, band])
	var made: Array[GeneratedLevel] = []
	for req: Array in requests:
		made.append(Generator.make(req[0], req[1], req[2]))
	# Stored fallback levels too, as they are handed out (relabeled, with play fields).
	for n: int in [12, 47, 158]:
		var g := GeneratedLevel.new()
		Generator._fall_back(Generator.plan_for(LevelData.NUMBERED, n, ""), g)
		made.append(g)
	var moved_centers := 0
	for g: GeneratedLevel in made:
		var level := g.level
		var where := level.id
		var errors := PackedStringArray()
		var back := LevelData.parse(JSON.stringify(level.to_dict()), errors)
		check(back != null and errors.is_empty(), "%s reads back: %s" % [where, "; ".join(errors)])
		if back == null:
			continue
		check_eq(back.fingerprint(), level.fingerprint(), "%s: the same fingerprint" % where)
		check_eq(back.to_dict(), level.to_dict(), "%s: the same data" % where)
		for p: PlankData in level.planks:
			if p.shape != PlankData.DISC and p.shape != PlankData.RING and p.center != Vector2.ZERO:
				moved_centers += 1
		# The same search the generator ran, on both.
		var budget: int = Generator.MAX_STATES[level.tier - 1]
		var cap := Tuning.tier(level.tier).tray_uses.y
		var a := g.solve if not g.fell_back else Solver.solve(level, budget * 4, cap)
		var b := Solver.solve(back, budget * 4 if g.fell_back else budget, cap)
		check(b.solved and b.complete, "%s: the file solves" % where)
		check_eq([b.fewest_tray_uses, b.solution, b.novice_won, b.novice_taps, b.last_tray_use, b.trap], [a.fewest_tray_uses, a.solution, a.novice_won, a.novice_taps, a.last_tray_use, a.trap], "%s: the same solve" % where)
		if not g.fell_back:
			check_eq(b.states, a.states, "%s: the same search, state for state" % where)
	check_eq(moved_centers, 0, "no bar or polygon carries a center the file would drop")
	print("        %d levels read back from JSON" % made.size())


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
			check_eq(r.novice_taps, stored.solve.novice_taps, "%s: the stored novice taps" % level.id)
			check_eq(_last_tray_tap(level, stored.solve.solution), stored.solve.last_tray_use, "%s: the stored last tray use" % level.id)
			# GDD 6.4.1: the stored levels of tiers that require G9 hold it too.
			check(Generator.g9_holds(t, level, stored.solve), "%s: G9 as tier %d requires it (novice taps %d of %d, last tray use %d)" % [level.id, t, stored.solve.novice_taps, level.screw_count(), stored.solve.last_tray_use])


func test_fallbacks_hand_out_the_stored_pick_relabeled() -> void:
	_ready_catalog()
	# A level that falls back hands out the stored level stored_pick names, and the relabeled
	# colors keep the stored solve.
	for n: int in range(100, 241):
		var plan := Generator.plan_for(LevelData.NUMBERED, n, "")
		var g := GeneratedLevel.new()
		Generator._fall_back(plan, g)
		var stored: GeneratedLevel = LevelCatalog.fallback[Generator.fallback_tier(plan.tier) - 1][Generator.stored_pick(LevelData.NUMBERED, n, "", {})]
		check(g.level.blueprint_id == stored.level.blueprint_id and g.variation == "fallback " + stored.variation, "level %d hands out the stored pick" % n)
		check_eq(g.solve, stored.solve, "level %d: with the stored solve" % n)
		check_eq(_replay(g.level, g.solve.solution), g.solve.fewest_tray_uses, "level %d: the relabeled fallback keeps its solve" % n)
	var a := Generator.relabeled(LevelCatalog.fallback[7][0].level, 1)
	var b := Generator.relabeled(LevelCatalog.fallback[7][0].level, 2)
	check(a.screw_colors != b.screw_colors, "different seeds relabel differently")
	var r := Solver.solve(a, 400000)
	check_eq(r.fewest_tray_uses, LevelCatalog.fallback[7][0].solve.fewest_tray_uses, "relabeling keeps the fewest tray uses")
	check_eq(r.novice_won, LevelCatalog.fallback[7][0].solve.novice_won, "and the novice result")
	check_eq(r.trap, LevelCatalog.fallback[7][0].solve.trap, "and the trap measure")


func test_6_4_1_no_two_levels_within_5_hand_out_the_same_stored_level() -> void:
	_ready_catalog()
	# For numbered levels 9 to 1000, 400 days and 300 Relaxed levels per band, the stored level
	# each would hand out if it fell back: never the same as a level within 5 of it on the same
	# pool, and otherwise as far from its blueprint's planned uses as the pool allows once the
	# lower ranked neighbors' picks (rank: stream position mod 6) are taken out.
	var r := Tuning.recent_blueprints_excluded
	var streams: Array[Array] = [[LevelData.NUMBERED, "", range(FIRST, 1001)]]
	var days: Array[int] = []
	for day: int in 400:
		days.append(Seeds.date_of_day(Seeds.day_number(2026, 10, 19) + day))
	streams.append([LevelData.DAILY, "", days])
	for band: String in Tuning.BANDS:
		streams.append([LevelData.RELAXED, band, range(0, 300)])
	var levels := 0
	var same := 0
	var too_close := 0
	var full := 0
	var most := PackedStringArray()
	for stream: Array in streams:
		var kind: int = stream[0]
		var band: String = stream[1]
		var memo := {}
		var picks := {}
		var pools := {}
		var most_taken := 0
		for number: int in stream[2]:
			var at := Generator.stream_position(kind, number)
			picks[at] = Generator.stored_pick(kind, number, band, memo)
			pools[at] = Generator.fallback_tier(Generator.tier_of(kind, number, band))
		for at: int in picks:
			levels += 1
			var number := Generator.stream_number(kind, at)
			var pool: Array = LevelCatalog.fallback[int(pools[at]) - 1]
			for k: int in range(1, r + 1):
				if picks.has(at + k) and pools[at + k] == pools[at] and picks[at + k] == picks[at]:
					same += 1
					if same <= 5:
						check(false, "%s and %d ahead hand out the same stored level" % [LevelPrefetcher.key_for(kind, number, band), k])
			var taken := PackedInt32Array()
			for k: int in range(-r, r + 1):
				var other := at + k
				var in_stream := other > Tuning.tutorial_levels if kind == LevelData.NUMBERED else (other >= 0 if kind == LevelData.RELAXED else true)
				if k == 0 or posmod(other, r + 1) >= posmod(at, r + 1) or not in_stream:
					continue
				var other_number := Generator.stream_number(kind, other)
				if Generator.fallback_tier(Generator.tier_of(kind, other_number, band)) == pools[at]:
					taken.append(Generator.stored_pick(kind, other_number, band, memo))
			most_taken = maxi(most_taken, taken.size())
			var nearest := Generator.neighbor_distances(kind, number, band)
			var best := 0
			var left := 0
			for i: int in pool.size():
				if not taken.has(i):
					left += 1
					best = maxi(best, int(nearest.get((pool[i] as GeneratedLevel).level.blueprint_id, r + 1)))
			if left == 0:
				full += 1
				continue
			var got := int(nearest.get((pool[int(picks[at])] as GeneratedLevel).level.blueprint_id, r + 1))
			if taken.has(int(picks[at])) or got != best:
				too_close += 1
				if too_close <= 5:
					check(false, "%s: stored level %d is %d from a planned use; %d was possible" % [LevelPrefetcher.key_for(kind, number, band), picks[at], got, best])
		most.append("%s %s %d" % [LevelData.KIND_NAMES[kind], band, most_taken])
	print("        most lower ranked neighbors on one pool: %s" % ", ".join(most))
	check_eq(same, 0, "pairs within 5 on one pool with the same stored level, of %d levels" % levels)
	check_eq(full, 0, "levels whose lower ranked neighbors took every stored level")
	check_eq(too_close, 0, "picks nearer their blueprint than the pool allows")


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


## The novice policy (GDD 6.4) through PlayState: the taps it makes before the level ends.
func _novice_taps(level: LevelData) -> int:
	var order: Array[int] = []
	for s: int in level.screw_count():
		order.append(s)
	order.sort_custom(func(a: int, b: int) -> bool:
		var pa := level.screw_center(a)
		var pb := level.screw_center(b)
		return pa.y < pb.y if pa.y != pb.y else (pa.x < pb.x if pa.x != pb.x else a < b))
	var state := PlayState.start(level)
	var taps := 0
	while state.status() == PlayState.PLAYING:
		var pick := -1
		for s: int in order:
			if state.is_free(s) and (pick < 0 or state.destination(s).x == PlayState.BOX):
				pick = s
				if state.destination(s).x == PlayState.BOX:
					break
		if pick < 0 or not state.tap(pick).ok:
			break
		taps += 1
	return taps


## The tap number of the last tap of a solution that PlayState sends to the tray, or 0.
func _last_tray_tap(level: LevelData, solution: PackedInt32Array) -> int:
	var state := PlayState.start(level)
	var last := 0
	for i: int in solution.size():
		if state.destination(solution[i]).x == PlayState.TRAY:
			last = i + 1
		state.tap(solution[i])
	return last


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
