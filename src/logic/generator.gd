# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Generator
extends RefCounted
## Makes numbered, daily and relaxed levels (docs/ARCHITECTURE.md 4.4, GDD 6.3 to 6.6). The same
## kind, number, band and version give the same level on every phone and PC: every choice comes
## from a RandomNumberGenerator seeded by Seeds, lists are walked in a fixed order, and every
## budget is a count. Safe on a worker thread once LevelCatalog.load_all() has run.
##
## Steps for one level:
## 1. Plan: the tier (the sawtooth, the daily tier, or a seeded pick in a Relaxed band) and the
##    blueprint (G7, a pure function of kind, number and version: see blueprint_for).
## 2. Up to VARIATIONS varied boards (mirrored, shifted, two layers swapped, a plank dropped),
##    each checked against the blueprint rules (G2) and the tier's screws and layers (G1).
## 3. Up to COLORINGS colorings per board, colored with intent (see _color). The novice plays
##    each one first (G4, and G9a where the tier requires it); one that passes is searched with
##    the tier's MAX_STATES and with the tier's top tray use count as the cap. A coloring is
##    kept if the search completes and G1 to G6 hold, and G9 where the tier requires it.
##    Between tries the coloring pressure goes up when a level came out too easy and down when
##    it came out too hard; a G9 failure leaves it alone (GDD 6.4.1).
## 4. If no try is kept after MAX_ATTEMPTS tries or LEVEL_STATES states in all (G9_BUDGET times
##    as many on a tier that requires G9), a stored fallback level for the tier (exempt from
##    G7; see _fall_back).
##
## Every number here counts toward GENERATOR_VERSION: changing one changes levels.

const GENERATOR_VERSION := 4
## Seed purposes for Seeds.derive.
const DEAL := 11
const VARY := 12
const COLOR := 13
const TIER := 14
const PICK := 15
const DAILY_ORDER := 16
const SCHEDULE := 17
const RELABEL := 18
## Length of a Relaxed band's schedule, in levels.
const RELAXED_SCHEDULE := 60
const FALLBACK_STREAM := 0x66616C6C
const VARIATIONS := 12
const COLORINGS := 5
const MAX_ATTEMPTS := 60
## Search budget per try, per tier (index tier - 1), in states, and for all the tries of one
## level together. (See the Hard Stop 2 report for how they were picked.)
const MAX_STATES: Array[int] = [20000, 20000, 20000, 30000, 30000, 40000, 60000, 60000, 80000, 80000]
const LEVEL_STATES := 1200000
## G9, the soft step into Hard (GDD 6.4.1). G9a: on SURVIVAL_TIERS the novice must survive at
## least ceil(n / SURVIVAL_DIVISOR) taps of a level of n screws. G9b: on LATE_TRAY_TIERS the
## solution's last tray use must come after the first LATE_TRAY_PART of its taps. Everywhere
## else both are measured and reported, never required. A tier that requires either rule gets
## G9_BUDGET times VARIATIONS, MAX_ATTEMPTS and LEVEL_STATES, for the colorings G9 turns down.
## (Bart approved G9 at Hard Stop 2 for tiers 7 to 10. These lists are the designer's proposed
## form in GDD 6.4.1, put to Bart: G9a on tiers 7 and 8 only, G9b reported only. Requiring G9a
## on 9 and 10 too, or G9b anywhere, is a change to one list.)
const SURVIVAL_TIERS: Array[int] = [7, 8]
const LATE_TRAY_TIERS: Array[int] = []
const SURVIVAL_DIVISOR := 3
const LATE_TRAY_PART := 3
const G9_BUDGET := 2
## In _closeness, holding G9 outranks any tray use count.
const G9_RANK := 100
## Coloring pressure to start with, per tier (index tier - 1), and the most it goes to (see
## _color).
const START_PRESSURE: Array[int] = [0, 0, 0, 2, 2, 3, 4, 4, 6, 6]
const MAX_PRESSURE := 10
## A deep opening needs at least this many screws that are not free at the start, and judges
## how deep a screw is by this many random removal orders.
const MIN_DEEP := 2
const DEPTH_SAMPLES := 1
## Largest shift of a varied board, in gu.
const SHIFT := 3
## Percent chances (whole numbers, so no float decides a level) of swapping two layers and of
## dropping a plank, from the second variation on.
const SWAP_PERCENT := 30
const DROP_PERCENT := 30


## The plan for one level: what it is and where its randomness comes from.
class Plan extends RefCounted:
	var kind: int
	var number: int
	var band: String
	var tier: int
	var group: String
	var slack: int
	var seed_value: int
	## Index into LevelCatalog.blueprints, or -1 if no blueprint suits the tier.
	var blueprint: int = -1


## How a board was varied.
class Variation extends RefCounted:
	var mirror := false
	var dx := 0
	var dy := 0
	## Layers swap and swap + 1 trade places (after a dropped plank's gap is closed); -1 none.
	var swap := -1
	## The plank dropped, or -1.
	var drop := -1

	func describe() -> String:
		var parts := PackedStringArray()
		if mirror:
			parts.append("mirror")
		if dx != 0 or dy != 0:
			parts.append("shift %d,%d" % [dx, dy])
		if swap >= 0:
			parts.append("swap %d-%d" % [swap, swap + 1])
		if drop >= 0:
			parts.append("drop %d" % drop)
		return " ".join(parts) if not parts.is_empty() else "as drawn"


## Makes the level. Never null once LevelCatalog is loaded.
static func make(kind: int, number: int, band: String) -> GeneratedLevel:
	var started := Time.get_ticks_usec()
	var out := GeneratedLevel.new()
	var plan := plan_for(kind, number, band)
	if plan.blueprint >= 0:
		_try(plan, out)
	if out.level == null:
		_fall_back(plan, out)
	@warning_ignore("integer_division")
	out.gen_ms = (Time.get_ticks_usec() - started) / 1000
	return out


## The plan for (kind, number, band). number is the level number, the date as yyyymmdd, or
## the Relaxed stream index.
static func plan_for(kind: int, number: int, band: String) -> Plan:
	var plan := Plan.new()
	plan.kind = kind
	plan.number = number
	plan.band = band if kind == LevelData.RELAXED else ""
	match kind:
		LevelData.DAILY:
			plan.tier = Tuning.daily_tier
			plan.group = Tuning.daily_group
			plan.slack = Tuning.daily_slack
			@warning_ignore("integer_division")
			plan.seed_value = Seeds.daily(number / 10000, (number / 100) % 100, number % 100)
		LevelData.RELAXED:
			plan.tier = relaxed_tier(band, number)
			plan.group = Tuning.tier(plan.tier).group
			plan.slack = 0
			plan.seed_value = Seeds.relaxed(band, number)
		_:
			plan.kind = LevelData.NUMBERED
			plan.tier = Tuning.tier_for_level(number)
			plan.group = Tuning.tier(plan.tier).group
			plan.slack = Tuning.slack_for_level(number)
			plan.seed_value = Seeds.numbered(number)
	plan.blueprint = blueprint_for(plan.kind, number, plan.band)
	return plan


## The tier of a Relaxed level (GDD 6.6), from the band's schedule (see relaxed_schedule).
static func relaxed_tier(band: String, index: int) -> int:
	var schedule: Array = LevelCatalog.relaxed_schedule.get(band, [])
	if schedule.is_empty() or (schedule[1] as PackedInt32Array).is_empty():
		var span: Vector2i = Tuning.relaxed.get(band, Vector2i(1, 3))
		return span.x
	var tiers: PackedInt32Array = schedule[1]
	return tiers[posmod(index, tiers.size())]


## A Relaxed band's schedule, built once by LevelCatalog.load_all(): [blueprints, tiers], one
## entry per stream index, repeating every RELAXED_SCHEDULE levels. Built by a seeded walk:
## at each index the tier picked so far the least often comes first (a seeded tie break, so
## every tier of the band gets its share), then the blueprint for that tier used the least
## that is not among the last R; a tier with no such blueprint gives way to the next. The walk
## is kept only if it also holds G7 where the schedule wraps round, else the next seed is
## tried.
static func relaxed_schedule(band: String) -> Array:
	var span: Vector2i = Tuning.relaxed.get(band, Vector2i(1, 3))
	var r := maxi(Tuning.recent_blueprints_excluded, 1)
	var length := RELAXED_SCHEDULE
	for attempt: int in 64:
		var rng := RandomNumberGenerator.new()
		rng.seed = Seeds.derive(Seeds.relaxed(band, -1), SCHEDULE, attempt)
		var blueprints := PackedInt32Array()
		var tiers := PackedInt32Array()
		var tier_count := {}
		var use_count := {}
		var ok := true
		for i: int in length:
			var order: Array[int] = []
			for t: int in range(span.x, span.y + 1):
				order.append(t)
			var ties := {}
			for t: int in order:
				ties[t] = rng.randi()
			order.sort_custom(func(a: int, b: int) -> bool:
				var ca: int = tier_count.get(a, 0)
				var cb: int = tier_count.get(b, 0)
				return ca < cb if ca != cb else int(ties[a]) < int(ties[b]))
			var chosen := -1
			var chosen_tier := -1
			for t: int in order:
				var best := -1
				var best_key := 0
				for b: int in LevelCatalog.suits[t - 1]:
					var recent := false
					for k: int in range(maxi(0, i - r), i):
						recent = recent or blueprints[k] == b
					if recent:
						continue
					var key: int = int(use_count.get(b, 0)) * 1000000 + rng.randi_range(0, 999999)
					if best < 0 or key < best_key:
						best = b
						best_key = key
				if best >= 0:
					chosen = best
					chosen_tier = t
					break
			if chosen < 0:
				ok = false
				break
			blueprints.append(chosen)
			tiers.append(chosen_tier)
			tier_count[chosen_tier] = int(tier_count.get(chosen_tier, 0)) + 1
			use_count[chosen] = int(use_count.get(chosen, 0)) + 1
		if ok:
			for i: int in length:
				for k: int in range(1, r + 1):
					ok = ok and blueprints[i] != blueprints[(i + k) % length]
		if ok:
			return [blueprints, tiers]
	return [PackedInt32Array(), PackedInt32Array()]


## G7 as a pure function of (kind, number, version), with no other level generated.
##
## Numbered levels from the first after the tutorial run in blocks of
## R = Tuning.recent_blueprints_excluded (5) levels. LevelCatalog
## splits the blueprints into two halves that each hold some of every tier's blueprints;
## even blocks deal from one half and odd blocks from the other. Within a block the deal gives
## each level a different blueprint that suits its tier (a seeded matching). So any R + 1 levels
## in a row span at most two blocks: within a block they differ, and two neighboring blocks
## draw from different halves. Hence no blueprint repeats within R levels.
##
## The daily walks one seeded order of LevelCatalog.daily_pool, one per day, so it repeats only
## after that many days, which needs a pool of at least R + 1. Each Relaxed band follows its
## schedule (relaxed_schedule), which holds G7 by construction, wrap included. The tests check
## both with the shipped data.
static func blueprint_for(kind: int, number: int, band: String) -> int:
	if kind == LevelData.DAILY:
		var list := LevelCatalog.daily_pool
		if list.is_empty():
			return -1
		var order := _shuffled(list, Seeds.mix(Seeds.DAILY, GENERATOR_VERSION + DAILY_ORDER))
		@warning_ignore("integer_division")
		var day := Seeds.day_number(number / 10000, (number / 100) % 100, number % 100)
		return order[posmod(day, order.size())]
	if kind == LevelData.RELAXED:
		var schedule: Array = LevelCatalog.relaxed_schedule.get(band, [])
		if schedule.is_empty() or (schedule[0] as PackedInt32Array).is_empty():
			return -1
		var blueprints: PackedInt32Array = schedule[0]
		return blueprints[posmod(number, blueprints.size())]
	var first := Tuning.tutorial_levels + 1
	return _stream_pick(Seeds.mix(Seeds.NUMBERED, GENERATOR_VERSION), maxi(number - first, 0), func(i: int) -> int: return Tuning.tier_for_level(first + i))


static func _stream_pick(stream: int, i: int, tier_of: Callable) -> int:
	var r := maxi(Tuning.recent_blueprints_excluded, 1)
	@warning_ignore("integer_division")
	var block := i / r
	var tiers := PackedInt32Array()
	for p: int in r:
		tiers.append(tier_of.call(block * r + p))
	var picks := deal(LevelCatalog.halves[block % 2], tiers, Seeds.derive(stream, DEAL, block))
	return picks[i % r]


## A different blueprint for each position, each suiting that position's tier, all from the
## given half, in a seeded order. A position the half cannot serve takes any blueprint that
## suits its tier (tests check this never happens with the shipped data).
static func deal(half: PackedInt32Array, tiers: PackedInt32Array, seed_value: int) -> PackedInt32Array:
	var count := tiers.size()
	var candidates: Array[PackedInt32Array] = []
	for p: int in count:
		var list := PackedInt32Array()
		for b: int in LevelCatalog.suits[tiers[p] - 1]:
			if half.has(b):
				list.append(b)
		candidates.append(_shuffled(list, Seeds.derive(seed_value, p, 1)))
	var picks := _assign(candidates)
	for p: int in count:
		if picks[p] < 0:
			var all := LevelCatalog.suits[tiers[p] - 1]
			picks[p] = all[Seeds.derive(seed_value, p, 2) % all.size()] if not all.is_empty() else -1
	return picks


## A different blueprint for each position from its candidate list (earlier candidates
## first), most constrained positions first. Positions it cannot fill are -1.
static func _assign(candidates: Array[PackedInt32Array]) -> PackedInt32Array:
	var count := candidates.size()
	var order: Array[int] = []
	for p: int in count:
		order.append(p)
	order.sort_custom(func(a: int, b: int) -> bool:
		return candidates[a].size() < candidates[b].size() if candidates[a].size() != candidates[b].size() else a < b)
	var picks := PackedInt32Array()
	picks.resize(count)
	picks.fill(-1)
	if not _match(order, 0, candidates, picks):
		picks.fill(-1)
		var used := PackedInt32Array()
		for p: int in order:
			for b: int in candidates[p]:
				if not used.has(b):
					picks[p] = b
					used.append(b)
					break
	return picks


static func _match(order: Array[int], k: int, candidates: Array[PackedInt32Array], picks: PackedInt32Array) -> bool:
	if k == order.size():
		return true
	var p := order[k]
	for b: int in candidates[p]:
		if picks.has(b):
			continue
		picks[p] = b
		if _match(order, k + 1, candidates, picks):
			return true
		picks[p] = -1
	return false


static func _shuffled(list: PackedInt32Array, seed_value: int) -> PackedInt32Array:
	var out := list.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := out[i]
		out[i] = out[j]
		out[j] = t
	return out


## G9a's least survival for a level of this many screws: ceil(screws / SURVIVAL_DIVISOR) taps.
static func survival_needed(screws: int) -> int:
	@warning_ignore("integer_division")
	return (screws + SURVIVAL_DIVISOR - 1) / SURVIVAL_DIVISOR


## G9a: the novice survives at least survival_needed taps.
static func survives(level: LevelData, r: SolveResult) -> bool:
	return r.novice_taps >= survival_needed(level.screw_count())


## G9b: the solution's tray uses are not all in the first third: its last tray use's tap number
## p has 3p > n. A solution with no tray use passes.
static func late_tray(level: LevelData, r: SolveResult) -> bool:
	return r.last_tray_use == 0 or r.last_tray_use * LATE_TRAY_PART > level.screw_count()


## G9 as this tier requires it (true on a tier that requires neither rule).
static func g9_holds(tier: int, level: LevelData, r: SolveResult) -> bool:
	return (not SURVIVAL_TIERS.has(tier) or survives(level, r)) and (not LATE_TRAY_TIERS.has(tier) or late_tray(level, r))


## How many times the base budget (VARIATIONS, MAX_ATTEMPTS, LEVEL_STATES) a tier gets.
static func budget_scale(tier: int) -> int:
	return G9_BUDGET if SURVIVAL_TIERS.has(tier) or LATE_TRAY_TIERS.has(tier) else 1


## G4: the novice result is the one the tier wants.
static func _novice_right(spec: Tuning.TierSpec, r: SolveResult) -> bool:
	return not ((spec.novice == Tuning.NOVICE_WIN and not r.novice_won) or (spec.novice == Tuning.NOVICE_LOSE and r.novice_won))


## How near a measured, solved try came to the tier, for the closest try: holding G9 as the
## tier requires it comes first, then the most tray uses, then the novice result the tier wants
## (GDD 6.4.1). On a tier that requires no G9 every try gets G9_RANK, so only the rest counts.
## (_try only searches colorings that already pass G4 and G9a, so among its tries this ranks by
## G9b where required, then tray uses.)
static func _closeness(plan: Plan, spec: Tuning.TierSpec, level: LevelData, r: SolveResult) -> int:
	return (G9_RANK if g9_holds(plan.tier, level, r) else 0) + r.fewest_tray_uses * 2 + (1 if _novice_right(spec, r) else 0)


## Steps 2 and 3. Tries at most max_attempts (by default the tier's MAX_ATTEMPTS times
## budget_scale); on success out.level is set. Whatever happens, out.closest keeps the solved
## try that came nearest the tier (see _closeness), as a last resort.
static func _try(plan: Plan, out: GeneratedLevel, max_attempts: int = -1) -> void:
	var bp := LevelCatalog.blueprints[plan.blueprint]
	var spec := Tuning.tier(plan.tier)
	var budget: int = MAX_STATES[plan.tier - 1]
	var scale := budget_scale(plan.tier)
	var variations := VARIATIONS * scale
	var level_states := LEVEL_STATES * scale
	if max_attempts < 0:
		max_attempts = MAX_ATTEMPTS * scale
	var pressure: int = START_PRESSURE[plan.tier - 1]
	var closest_score := -1
	for v: int in variations:
		if out.attempts >= max_attempts:
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = Seeds.derive(plan.seed_value, VARY, v)
		var va := _choose_variation(bp, spec, rng, v)
		var board := _vary(bp, va)
		if not _fits_tier(board, spec) or not BlueprintValidator.check(board).is_empty():
			out.attempts += 1
			out.rejected_boards += 1
			continue
		for c: int in COLORINGS:
			if out.attempts >= max_attempts or out.total_states >= level_states:
				return
			out.attempts += 1
			var crng := RandomNumberGenerator.new()
			crng.seed = Seeds.derive(plan.seed_value, COLOR, v * 16 + c)
			var level := _color(board, spec, pressure, crng)
			if level == null:
				out.rejected_colorings += 1
				continue
			# G4 and G9a depend on the coloring alone (one novice playout, no search), so they are
			# checked first and a coloring they turn down is never searched. On the hard tiers most
			# colorings that would come out too easy are ones the novice wins, so this saves most
			# of the searches there. The rules are the same as checking after the search; only
			# the order of the walk differs. A G9 failure keeps the pressure (GDD 6.4.1).
			var novice := SolveResult.new()
			Solver.measure(level, novice, false)
			if not _novice_right(spec, novice):
				out.novice_wrong += 1
				if spec.novice == Tuning.NOVICE_WIN:
					pressure = maxi(0, pressure - 1)
				else:
					pressure = _harder(pressure, plan.tier, spec)
				continue
			if SURVIVAL_TIERS.has(plan.tier) and not survives(level, novice):
				out.short_survival += 1
				continue
			var r := Solver.search_only(level, budget, true, spec.tray_uses.y)
			r.novice_won = novice.novice_won
			r.novice_taps = novice.novice_taps
			r.ms += novice.ms
			out.total_states += r.states
			if not r.complete or not r.solved:
				if not r.complete:
					out.over_budget += 1
				else:
					out.over_cap += 1
				pressure = maxi(0, pressure - 1)
				continue
			var score := _closeness(plan, spec, level, r)
			if score > closest_score:
				closest_score = score
				out.closest = _finish(level, plan, r.fewest_tray_uses)
				out.closest_solve = r
				out.closest_variation = va.describe()
			# G3.
			if r.fewest_tray_uses < spec.tray_uses.x:
				out.too_easy += 1
				pressure = _harder(pressure, plan.tier, spec)
				continue
			# G9b needs the solution.
			if LATE_TRAY_TIERS.has(plan.tier) and not late_tray(level, r):
				out.early_tray += 1
				continue
			# The trap measure decides nothing, so only the level kept gets it.
			Solver.measure(level, r)
			out.level = _finish(level, plan, r.fewest_tray_uses)
			out.solve = r
			out.variation = va.describe()
			out.pressure = pressure
			return


## The next pressure after a try came out too easy. Tiers that need two or more tray uses
## only get them from deep openings (even levels, see _color), so they step by two. After the
## top it starts over at the tier's first level.
static func _harder(pressure: int, tier: int, spec: Tuning.TierSpec) -> int:
	var step := 2 if spec.tray_uses.x >= 2 else 1
	return pressure + step if pressure + step <= MAX_PRESSURE else START_PRESSURE[tier - 1]


static func _choose_variation(bp: LevelData, spec: Tuning.TierSpec, rng: RandomNumberGenerator, v: int) -> Variation:
	var va := Variation.new()
	va.mirror = rng.randi_range(0, 1) == 1
	va.dx = rng.randi_range(-SHIFT, SHIFT)
	va.dy = rng.randi_range(-SHIFT, SHIFT)
	if v == 0:
		va.dx = 0
		va.dy = 0
		return va
	if rng.randi_range(0, 99) < DROP_PERCENT:
		var n := bp.screw_count()
		var options := PackedInt32Array()
		for p: int in bp.planks.size():
			var h := bp.planks[p].hole_count()
			if h % Tuning.box_slots == 0 and n - h >= spec.screws.x and n - h <= spec.screws.y:
				options.append(p)
		if not options.is_empty():
			va.drop = options[rng.randi_range(0, options.size() - 1)]
	if rng.randi_range(0, 99) < SWAP_PERCENT and bp.layer_count() >= 2:
		va.swap = rng.randi_range(0, bp.layer_count() - 2)
	return va


## The varied board. Layers are renumbered to close a dropped plank's gap, then swapped; the
## shift is kept inside the room the board has (B4 and B7).
static func _vary(bp: LevelData, va: Variation) -> LevelData:
	var kept: Array[PlankData] = []
	for p: int in bp.planks.size():
		if p != va.drop:
			kept.append(bp.planks[p])
	var used := PackedInt32Array([0, 0, 0, 0, 0])
	for p: PlankData in kept:
		used[p.layer] = 1
	var layer_map := PackedInt32Array([0, 0, 0, 0, 0])
	var next := 0
	for layer: int in 5:
		if used[layer] == 1:
			layer_map[layer] = next
			next += 1
	if va.swap >= 0 and va.swap + 1 < next:
		for layer: int in 5:
			if layer_map[layer] == va.swap:
				layer_map[layer] = va.swap + 1
			elif layer_map[layer] == va.swap + 1:
				layer_map[layer] = va.swap
	else:
		va.swap = -1
	# Room to shift, after mirroring.
	var lo_x := -INF
	var hi_x := INF
	var lo_y := -INF
	var hi_y := INF
	for p: PlankData in kept:
		var b := Geom.bounds(p.outline_xy)
		var min_x := LevelData.BOARD_W - b[2] if va.mirror else b[0]
		var max_x := LevelData.BOARD_W - b[0] if va.mirror else b[2]
		lo_x = maxf(lo_x, -min_x)
		hi_x = minf(hi_x, LevelData.BOARD_W - max_x)
		lo_y = maxf(lo_y, -b[1])
		hi_y = minf(hi_y, LevelData.BOARD_H - b[3])
		for h: Vector2 in p.holes:
			var x := LevelData.BOARD_W - h.x if va.mirror else h.x
			lo_x = maxf(lo_x, BlueprintValidator.SCREW_INSET - x)
			hi_x = minf(hi_x, LevelData.BOARD_W - BlueprintValidator.SCREW_INSET - x)
			lo_y = maxf(lo_y, BlueprintValidator.SCREW_INSET - h.y)
			hi_y = minf(hi_y, LevelData.BOARD_H - BlueprintValidator.SCREW_INSET - h.y)
	va.dx = clampi(va.dx, int(ceilf(lo_x)), int(floorf(hi_x))) if ceilf(lo_x) <= floorf(hi_x) else 0
	va.dy = clampi(va.dy, int(ceilf(lo_y)), int(floorf(hi_y))) if ceilf(lo_y) <= floorf(hi_y) else 0
	var planks: Array[PlankData] = []
	for p: PlankData in kept:
		planks.append(p.transformed(va.mirror, va.dx, va.dy, layer_map[p.layer]))
	return LevelData.from_planks(bp.id, bp.name, bp.blueprint_kind, planks)


## G1 for the board: screws and layers in the tier's ranges.
static func _fits_tier(board: LevelData, spec: Tuning.TierSpec) -> bool:
	var n := board.screw_count()
	var layers := board.layer_count()
	return n >= spec.screws.x and n <= spec.screws.y and layers >= spec.layers.x and layers <= spec.layers.y and n % Tuning.box_slots == 0


## Colors with intent (GDD 6.5), at a pressure level from 0 (none) up. Every coloring starts
## from a random order of taking screws off the board, each free when taken.
## - Pressure 0, and odd levels: a planned solution. Walking the order, screws go into the open
##   boxes, except that up to `pressure` key screws (whose removal frees others) are sent to the
##   tray with the color of a box at least two arrivals away. The walk is a solution with that
##   many tray uses, so the level is solvable by construction; the solver then finds the fewest.
## - Even levels from 2: a deep opening. The two open boxes get one screw that is free at the
##   start (G5) and five that only come free after `pressure` removals, so the screws in the way
##   belong to later boxes and must wait in the tray. If the board has no such screws, the
##   planned solution is used instead.
## The queue never has a color twice in a row (G6), and at the start some free screw fits an
## open box (G5), or the coloring is rejected (null).
static func _color(board: LevelData, spec: Tuning.TierSpec, pressure: int, rng: RandomNumberGenerator) -> LevelData:
	var g := board.geometry
	var n := g.screw_count
	var slots := Tuning.box_slots
	@warning_ignore("integer_division")
	var boxes := n / slots
	var top := mini(mini(spec.colors.y, boxes), LevelData.MAX_COLORS)
	if top < spec.colors.x or top < 1 or boxes < 1:
		return null
	var color_count := rng.randi_range(spec.colors.x, top)
	var queue := _box_colors(boxes, color_count, rng)
	if queue.is_empty():
		return null
	var color := PackedInt32Array()
	if pressure >= 2 and pressure % 2 == 0:
		color = _deep_opening(g, queue, pressure, rng)
	if color.is_empty():
		color = _planned(g, queue, pressure, rng)
	if color.is_empty():
		return null
	# G5: some screw free at the start fits an open box.
	var all := (1 << n) - 1
	var start_free := all & ~g.covered(all)
	var fits := false
	for s: int in n:
		if start_free & (1 << s) and (color[s] == queue[0] or (boxes > 1 and color[s] == queue[1])):
			fits = true
	if not fits:
		return null
	var errors := PackedStringArray()
	return board.with_colors(color, queue, errors)


## A random order of taking every screw off the board, each one free when it is taken.
## free_at gets, per screw, the number of removals after which it is first free.
static func _removal_order(g: BoardGeometry, rng: RandomNumberGenerator, free_at: PackedInt32Array) -> PackedInt32Array:
	var n := g.screw_count
	free_at.resize(n)
	free_at.fill(-1)
	var on := (1 << n) - 1
	var loose := on & ~g.covered(on)
	var order := PackedInt32Array()
	var choices := PackedInt32Array()
	while on != 0:
		choices.clear()
		for s: int in n:
			if loose & (1 << s):
				choices.append(s)
				if free_at[s] < 0:
					free_at[s] = order.size()
		var s := choices[rng.randi_range(0, choices.size() - 1)]
		order.append(s)
		on &= ~(1 << s)
		loose = on & ~g.covered(on)
	return order


## The planned solution (see _color). Empty if it cannot be built.
static func _planned(g: BoardGeometry, queue: PackedInt32Array, trays: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var n := g.screw_count
	var boxes := queue.size()
	var free_at := PackedInt32Array()
	var order := _removal_order(g, rng, free_at)
	var room := PackedInt32Array()
	room.resize(boxes)
	room.fill(Tuning.box_slots)
	var reserved := PackedInt32Array()
	reserved.resize(boxes)
	var color := PackedInt32Array()
	color.resize(n)
	color.fill(-1)
	var open := PackedInt32Array()
	for p: int in Tuning.open_boxes:
		open.append(p if p < boxes else -1)
	var next := mini(Tuning.open_boxes, boxes)
	var waiting := 0
	var trayed := 0
	for i: int in n:
		var s := order[i]
		# Its removal frees a screw that was not free before it.
		var key := false
		for t: int in n:
			if free_at[t] == i + 1:
				key = true
		var target := -1
		if key and trayed < trays and waiting < Tuning.tray_size - 1 and i > 0:
			var options := PackedInt32Array()
			for j: int in range(next + 1, boxes):
				if room[j] == 0 or options.size() >= 3:
					continue
				var clash := false
				for k: int in range(next, j):
					clash = clash or queue[k] == queue[j]
				for p: int in open.size():
					clash = clash or (open[p] >= 0 and queue[open[p]] == queue[j])
				if not clash:
					options.append(j)
			if not options.is_empty():
				target = options[rng.randi_range(0, options.size() - 1)]
		if target >= 0:
			color[s] = queue[target]
			room[target] -= 1
			reserved[target] += 1
			waiting += 1
			trayed += 1
			continue
		var best := -1
		for p: int in open.size():
			if open[p] >= 0 and room[open[p]] > 0 and (best < 0 or room[open[p]] < room[open[best]]):
				best = p
		if best < 0:
			return PackedInt32Array()
		color[s] = queue[open[best]]
		room[open[best]] -= 1
		while open[best] >= 0 and room[open[best]] == 0:
			if next < boxes:
				open[best] = next
				waiting -= reserved[next]
				next += 1
			else:
				open[best] = -1
	return color


## The deep opening (see _color). Empty if the board has no such screws.
static func _deep_opening(g: BoardGeometry, queue: PackedInt32Array, depth: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var n := g.screw_count
	var slots := Tuning.box_slots
	var opening_size := mini(Tuning.open_boxes, queue.size()) * slots
	var free_at := PackedInt32Array()
	var order := _removal_order(g, rng, free_at)
	# How deep a screw really is: the fewest removals before it was free, over several random
	# orders (a player looks for the short way in).
	for _k: int in DEPTH_SAMPLES - 1:
		var other := PackedInt32Array()
		_removal_order(g, rng, other)
		for s: int in n:
			free_at[s] = mini(free_at[s], other[s])
	var opening := PackedInt32Array()
	for s: int in order:
		if free_at[s] == 0:
			opening.append(s)
			break
	# The screws that come free at `depth` removals or later, earliest first; then, if there are
	# too few, the deepest of the rest that are not free at the start; then free ones.
	var deep: Array[int] = []
	var shallow: Array[int] = []
	var loose: Array[int] = []
	for s: int in order:
		if opening.has(s):
			continue
		if free_at[s] >= depth:
			deep.append(s)
		elif free_at[s] > 0:
			shallow.append(s)
		else:
			loose.append(s)
	deep.sort_custom(func(a: int, b: int) -> bool: return free_at[a] < free_at[b] if free_at[a] != free_at[b] else a < b)
	shallow.sort_custom(func(a: int, b: int) -> bool: return free_at[a] > free_at[b] if free_at[a] != free_at[b] else a < b)
	if deep.size() + shallow.size() < MIN_DEEP:
		return PackedInt32Array()
	for list: Array[int] in [deep, shallow, loose]:
		for s: int in list:
			if opening.size() < opening_size:
				opening.append(s)
	if opening.size() < opening_size:
		return PackedInt32Array()
	var sorted := opening.duplicate()
	for s: int in order:
		if not opening.has(s):
			sorted.append(s)
	var color := PackedInt32Array()
	color.resize(n)
	for i: int in n:
		@warning_ignore("integer_division")
		color[sorted[i]] = queue[i / slots]
	return color


## A color for each box: every color at least once, no color twice in a row (G6).
static func _box_colors(boxes: int, colors: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var left := PackedInt32Array()
	left.resize(colors)
	left.fill(1)
	@warning_ignore("integer_division")
	var cap := (boxes + 1) / 2
	for _i: int in boxes - colors:
		var c := rng.randi_range(0, colors - 1)
		for _j: int in colors:
			if left[c] < cap:
				break
			c = (c + 1) % colors
		left[c] += 1
	var out := PackedInt32Array()
	var prev := -1
	for i: int in boxes:
		var remaining := boxes - i
		var urgent := -1
		var total := 0
		for c: int in colors:
			if c != prev and left[c] > 0:
				total += left[c]
				if left[c] * 2 > remaining and urgent < 0:
					urgent = c
		if total == 0:
			return PackedInt32Array()
		var pick := urgent
		if pick < 0:
			var roll := rng.randi_range(0, total - 1)
			for c: int in colors:
				if c != prev and left[c] > 0:
					if roll < left[c]:
						pick = c
						break
					roll -= left[c]
		out.append(pick)
		left[pick] -= 1
		prev = pick
	return out


## The accepted level with its play fields filled in.
static func _finish(level: LevelData, plan: Plan, fewest: int) -> LevelData:
	var errors := PackedStringArray()
	return level.with_colors(level.screw_colors, level.queue, errors, {
		"kind": plan.kind,
		"number": plan.number,
		"band": plan.band,
		"tier": plan.tier,
		"group": plan.group,
		"generator": GENERATOR_VERSION,
		"id": level_id(plan.kind, plan.number, plan.band),
		"tray_par": fewest + plan.slack,
		"par_time": Tuning.par_time_for(level.screw_count(), plan.group),
	})


## "numbered-42", "daily-20261019", "relaxed-easy-7".
static func level_id(kind: int, number: int, band: String) -> String:
	if kind == LevelData.RELAXED:
		return "relaxed-%s-%d" % [band, number]
	return "%s-%d" % [LevelData.KIND_NAMES[kind], number]


## Builds stored fallback levels for a tier (tools/levels --fallback writes them to
## src/logic/fallback/). It goes through the tier's blueprints in turn on its own seed stream,
## with more tries per level, and keeps up to `count` levels, each on a different blueprint
## while there are enough. Each is accepted by _try, so it holds every rule a generated level
## of its tier holds, G9 included where the tier requires it.
static func build_fallback(tier: int, count: int, max_attempts: int) -> Array[GeneratedLevel]:
	var out: Array[GeneratedLevel] = []
	var list := LevelCatalog.suits[tier - 1]
	var used := PackedStringArray()
	var stream := Seeds.mix(FALLBACK_STREAM, GENERATOR_VERSION)
	for k: int in maxi(list.size() * 12, count * 8):
		if out.size() >= count:
			break
		var b := list[k % list.size()]
		var id := LevelCatalog.blueprints[b].id
		if used.has(id) and used.size() < list.size():
			continue
		var plan := Plan.new()
		plan.kind = LevelData.NUMBERED
		plan.number = 0
		plan.band = ""
		plan.tier = tier
		plan.group = Tuning.tier(tier).group
		plan.slack = 0
		plan.seed_value = Seeds.derive(stream, tier, k)
		plan.blueprint = b
		var g := GeneratedLevel.new()
		_try(plan, g, max_attempts)
		if g.level == null:
			continue
		var errors := PackedStringArray()
		g.level = g.level.with_colors(g.level.screw_colors, g.level.queue, errors, {"id": "fallback-%d-%d" % [tier, out.size() + 1]})
		used.append(id)
		out.append(g)
	return out


## Step 4. First a stored fallback level for the tier. If the tier has none, the closest try
## (solved and proven, but outside the tier's ranges). If there was no such try either, a
## stored fallback level of the nearest tier that has one. Only with no fallback files at all
## and no solved try does the level stay null (and an error is logged).
##
## A stored level is picked (seeded) among those whose blueprint's nearest planned use in the
## same stream is farthest away: not within R levels either side when the pool allows, and
## otherwise as far as it can be, so never next to a level of the same blueprint while another
## blueprint is stored. (A neighbor that itself falls back can still match; that needs both
## to fall back.) Its colors
## are then relabeled by a seeded permutation, the same on screws and queue, so two levels that
## use the same stored level look different while every rule outcome (and so the stored solve)
## stays exactly the same.
static func _fall_back(plan: Plan, out: GeneratedLevel) -> void:
	var pool: Array = LevelCatalog.fallback[plan.tier - 1] if plan.tier >= 1 and plan.tier <= LevelCatalog.fallback.size() else []
	if pool.is_empty() and out.closest != null:
		# _try measured only its novice; the trap too now that it is shown.
		Solver.measure(out.closest, out.closest_solve)
		out.level = out.closest
		out.solve = out.closest_solve
		out.fell_back = true
		out.variation = "closest try " + out.closest_variation
		return
	for distance: int in range(1, Tuning.tiers.size()):
		for t: int in [plan.tier - distance, plan.tier + distance]:
			if pool.is_empty() and t >= 1 and t <= LevelCatalog.fallback.size():
				pool = LevelCatalog.fallback[t - 1]
	if pool.is_empty():
		push_error("no fallback level for tier %d" % plan.tier)
		return
	# Among the stored levels, those whose blueprint's nearest planned use is farthest away
	# (R + 1 means not within R either side), then a seeded pick among them.
	var nearest := neighbor_distances(plan.kind, plan.number, plan.band)
	var far := maxi(Tuning.recent_blueprints_excluded, 1) + 1
	var best := -1
	var choices: Array = []
	for g: GeneratedLevel in pool:
		var d: int = nearest.get(g.level.blueprint_id, far)
		if d > best:
			best = d
			choices = []
		if d == best:
			choices.append(g)
	var stored: GeneratedLevel = choices[Seeds.derive(plan.seed_value, PICK, 0) % choices.size()]
	var level := relabeled(stored.level, Seeds.derive(plan.seed_value, RELABEL, 0))
	var fallback_plan := Plan.new()
	fallback_plan.kind = plan.kind
	fallback_plan.number = plan.number
	fallback_plan.band = plan.band
	fallback_plan.tier = level.tier
	fallback_plan.group = plan.group if plan.kind == LevelData.DAILY else Tuning.tier(level.tier).group
	fallback_plan.slack = plan.slack
	out.level = _finish(level, fallback_plan, stored.solve.fewest_tray_uses)
	out.solve = stored.solve
	out.fell_back = true
	out.variation = "fallback " + stored.variation


## The blueprint ids planned for the R levels before and after this one in its stream (numbered
## levels after the tutorial, days, or a Relaxed band's indices).
static func neighbor_blueprints(kind: int, number: int, band: String) -> PackedStringArray:
	return PackedStringArray(neighbor_distances(kind, number, band).keys())


## For each blueprint planned within R levels either side of this one in its stream, how many
## levels away its nearest planned use is (1 to R). Pure: only blueprint choices, no levels.
static func neighbor_distances(kind: int, number: int, band: String) -> Dictionary:
	var out := {}
	var r := maxi(Tuning.recent_blueprints_excluded, 1)
	for distance: int in range(1, r + 1):
		for k: int in [-distance, distance]:
			var b := -1
			match kind:
				LevelData.DAILY:
					@warning_ignore("integer_division")
					var day := Seeds.day_number(number / 10000, (number / 100) % 100, number % 100) + k
					b = blueprint_for(LevelData.DAILY, Seeds.date_of_day(day), "")
				LevelData.RELAXED:
					if number + k >= 0:
						b = blueprint_for(LevelData.RELAXED, number + k, band)
				_:
					if number + k > Tuning.tutorial_levels:
						b = blueprint_for(LevelData.NUMBERED, number + k, "")
			if b >= 0 and not out.has(LevelCatalog.blueprints[b].id):
				out[LevelCatalog.blueprints[b].id] = distance
	return out


## The same level with its colors renamed by a seeded permutation of the colors it uses (on
## screws and queue alike). Colors only matter by being equal or not, so every rule outcome is
## unchanged.
static func relabeled(level: LevelData, seed_value: int) -> LevelData:
	var used := PackedInt32Array()
	for c: int in level.queue:
		if not used.has(c):
			used.append(c)
	used.sort()
	var to := _shuffled(used, seed_value)
	var map := {}
	for i: int in used.size():
		map[used[i]] = to[i]
	var colors := PackedInt32Array()
	for c: int in level.screw_colors:
		colors.append(map[c])
	var queue := PackedInt32Array()
	for c: int in level.queue:
		queue.append(map[c])
	var errors := PackedStringArray()
	return level.with_colors(colors, queue, errors)
