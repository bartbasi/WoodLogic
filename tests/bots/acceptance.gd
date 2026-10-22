# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## The generated-level items of the GDD 12 acceptance list, checked from outside on real
## generator output: 22 (G1 to G7 and G9a per tier, with the fallback rate, the novice's
## survival and the last tray use), 23 (the novice bot against G4), 24 (the readability caps)
## and 25 (free screws 48 du apart along the solution), plus 2 and 8 (R10 and I1 over the
## random bot's games) on the same levels.
##
##   godot --headless --path . -s res://tests/bots/acceptance.gd -- [--per-tier=N] [--seed=S]
##         [--g7=A-B] [--random-games=R] [--peaks=A-B]
##
## Tiers 1 to 8 come from the Relaxed streams (the only place those tiers are plentiful: the
## numbered levels visit tiers 1 and 2 only a few times), tiers 9 and 10 from numbered levels.
## G7 is checked on consecutive numbered levels A to B (default 9 to 200) and on each Relaxed
## stream. Exit code 1 if any check failed, 2 for a bad option.

const MAX_SCREWS := 36
const MAX_COLORS := 8
const MAX_LAYERS := 5
const MAX_FREE := 24
## 48 du in grid units (1 gu = 4 du).
const MIN_FREE_GAP := 12.0

var _per_tier := 100
var _seed := 7
var _g7_from := 9
var _g7_to := 200
var _numbered_from := 9
var _numbered_to := 400
var _games := 2

## Per tier: an Array of Dictionary {level, solve, fell, attempts, where}.
var _by_tier: Dictionary = {}
var _fails: Dictionary = {}
var _fail_counts: Dictionary = {}


func _initialize() -> void:
	quit(_run())


func _parse() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		var value := parts[1] if parts.size() > 1 else ""
		match parts[0]:
			"--per-tier":
				if not value.is_valid_int() or value.to_int() < 1 or value.to_int() > 1000:
					print("--per-tier needs a whole number from 1 to 1000")
					return false
				_per_tier = value.to_int()
			"--seed":
				if not value.is_valid_int() or value.to_int() < 0 or value.to_int() > 1000000:
					print("--seed needs a whole number from 0 to 1000000")
					return false
				_seed = value.to_int()
			"--random-games":
				if not value.is_valid_int() or value.to_int() < 0 or value.to_int() > 50:
					print("--random-games needs a whole number from 0 to 50")
					return false
				_games = value.to_int()
			"--g7":
				var span := value.split("-")
				if span.size() != 2 or not span[0].is_valid_int() or not span[1].is_valid_int() or span[0].to_int() < 9 or span[1].to_int() < span[0].to_int() or span[1].to_int() > 5000:
					print("--g7 needs a range like 9-200 (from level 9)")
					return false
				_g7_from = span[0].to_int()
				_g7_to = span[1].to_int()
			"--peaks":
				var pk := value.split("-")
				if pk.size() != 2 or not pk[0].is_valid_int() or not pk[1].is_valid_int() or pk[0].to_int() < 9 or pk[1].to_int() < pk[0].to_int() or pk[1].to_int() > 3000:
					print("--peaks needs a range like 9-400 (from level 9)")
					return false
				_numbered_from = pk[0].to_int()
				_numbered_to = pk[1].to_int()
			_:
				print("Unknown option ", arg)
				return false
	return true


func _fail(rule: String, where: String, detail: String) -> void:
	_fail_counts[rule] = int(_fail_counts.get(rule, 0)) + 1
	var list: PackedStringArray = _fails.get(rule, PackedStringArray())
	if list.size() < 3:
		list.append("%s: %s" % [where, detail])
	_fails[rule] = list


func _collect() -> void:
	for t: int in range(1, 11):
		_by_tier[t] = []
	# Tiers 1 to 8: the Relaxed streams, until every tier has enough.
	for band: String in Tuning.BANDS:
		var wanted: Array[int] = []
		var span: Vector2i = Tuning.relaxed[band]
		for t: int in range(span.x, span.y + 1):
			wanted.append(t)
		var i := 1
		while i < 4000:
			var t := Generator.relaxed_tier(band, i)
			if (_by_tier[t] as Array).size() < _per_tier:
				_add(LevelData.RELAXED, i, band)
			var done := true
			for w: int in wanted:
				if (_by_tier[w] as Array).size() < _per_tier:
					done = false
			if done:
				break
			i += 1
	# Tiers 9 and 10: numbered levels.
	var n := 9
	while n < 20000:
		var t := Tuning.tier_for_level(n)
		if t >= 9 and (_by_tier[t] as Array).size() < _per_tier:
			_add(LevelData.NUMBERED, n, "")
		if (_by_tier[9] as Array).size() >= _per_tier and (_by_tier[10] as Array).size() >= _per_tier:
			break
		n += 1


func _add(kind: int, number: int, band: String) -> void:
	var g := LevelCatalog.get_level(kind, number, band)
	var where := LevelPrefetcher.key_for(kind, number, band)
	if g == null or g.level == null:
		_fail("a level exists", where, "the generator gave nothing")
		return
	(_by_tier[g.level.tier] as Array).append({"level": g.level, "solve": g.solve, "fell": g.fell_back, "attempts": g.attempts, "where": where, "ms": g.gen_ms})


func _run() -> int:
	if not _parse():
		return 2
	Tuning.load_file()
	LevelCatalog.load_all()
	var started := Time.get_ticks_msec()
	_collect()
	var made := Time.get_ticks_msec()
	var rows: Array = []
	for t: int in range(1, 11):
		rows.append(_check_tier(t))
	_check_g7()
	var peak_lines := _numbered_peaks()
	var done := Time.get_ticks_msec()
	print("WoodLogic acceptance run: generator version %d, %d levels per tier, seed %d" % [Generator.GENERATOR_VERSION, _per_tier, _seed])
	print("took %.0f s to make the levels and %.0f s to check them\n" % [(made - started) / 1000.0, (done - made) / 1000.0])
	print("tier  levels  fallback  screws    colors  layers  free(max)  fewest tray  novice win  novice taps(median)/needed  last tray use(median)  random wins  generation ms (median / p95 / max)")
	for r: Variant in rows:
		print(r)
	print("")
	for line: String in peak_lines:
		print(line)
	print("")
	if _fail_counts.is_empty():
		print("Every check passed.")
		return 0
	print("FAILED checks:")
	for rule: Variant in _fail_counts.keys():
		print("  %s: %d" % [rule, _fail_counts[rule]])
		for example: String in _fails[rule]:
			print("      ", example)
	return 1


func _check_tier(t: int) -> String:
	var list: Array = _by_tier[t]
	var spec := Tuning.tier(t)
	var fell := 0
	var lo_s := 999
	var hi_s := 0
	var lo_c := 99
	var hi_c := 0
	var lo_l := 99
	var hi_l := 0
	var hi_free := 0
	var lo_f := 99
	var hi_f := 0
	var novice_wins := 0
	var taps: Array[int] = []
	var last_use: Array[int] = []
	var needed := 0
	var random_wins := 0
	var random_games := 0
	var gen_times: Array[int] = []
	for item: Variant in list:
		var d: Dictionary = item
		var level: LevelData = d["level"]
		var solve: SolveResult = d["solve"]
		var where: String = d["where"]
		fell += 1 if d["fell"] else 0
		gen_times.append(int(d["ms"]))
		var n := level.screw_count()
		var colors := level.color_count()
		var layers := level.layer_count()
		lo_s = mini(lo_s, n)
		hi_s = maxi(hi_s, n)
		lo_c = mini(lo_c, colors)
		hi_c = maxi(hi_c, colors)
		lo_l = mini(lo_l, layers)
		hi_l = maxi(hi_l, layers)
		lo_f = mini(lo_f, solve.fewest_tray_uses)
		hi_f = maxi(hi_f, solve.fewest_tray_uses)
		# G1.
		if n < spec.screws.x or n > spec.screws.y:
			_fail("G1 screws in the tier range", where, "%d screws, tier %d wants %s" % [n, t, spec.screws])
		if colors < spec.colors.x or colors > spec.colors.y:
			_fail("G1 colors in the tier range", where, "%d colors, tier %d wants %s" % [colors, t, spec.colors])
		if layers < spec.layers.x or layers > spec.layers.y:
			_fail("G1 layers in the tier range", where, "%d layers, tier %d wants %s" % [layers, t, spec.layers])
		for c: int in LevelData.MAX_COLORS:
			if level.screw_colors.count(c) != 3 * level.queue.count(c):
				_fail("G1/R3 color counts are multiples of 3", where, "color %d" % c)
		# G3: solved with a complete search, fewest tray uses in the tier's range.
		if not (solve.solved and solve.complete):
			_fail("G3 solved with a complete search", where, "solved=%s complete=%s" % [str(solve.solved), str(solve.complete)])
			continue
		var replay := _replay(level, solve.solution)
		if replay != solve.fewest_tray_uses:
			_fail("G3 the solution replays with the fewest tray uses", where, "replay %d, solver %d" % [replay, solve.fewest_tray_uses])
		if solve.fewest_tray_uses < spec.tray_uses.x or solve.fewest_tray_uses > spec.tray_uses.y:
			_fail("G3 fewest tray uses in the tier range", where, "%d, tier %d wants %s" % [solve.fewest_tray_uses, t, spec.tray_uses])
		# G4: the greedy novice bot, which must agree with the solver's flag.
		var entry := BotEntry.new()
		entry.level = level
		entry.solve = solve
		entry.label = where
		var novice := BotRunner.play(entry, NoviceBot.new(), false)
		if novice.won != solve.novice_won:
			_fail("G4 the novice bot agrees with Solver.novice_won", where, "bot %s, solver %s" % [str(novice.won), str(solve.novice_won)])
		if novice.violation_count > 0:
			_fail("rule checks while the novice plays", where, str(Array(novice.violations).slice(0, 1)))
		novice_wins += 1 if novice.won else 0
		if spec.novice == Tuning.NOVICE_WIN and not novice.won:
			_fail("G4 the novice must win", where, "tier %d" % t)
		if spec.novice == Tuning.NOVICE_LOSE and novice.won:
			_fail("G4 the novice must lose", where, "tier %d" % t)
		taps.append(solve.novice_taps)
		last_use.append(solve.last_tray_use)
		# G9a on the tiers the generator checks.
		if Generator.SURVIVAL_TIERS.has(t):
			needed = Generator.survival_needed(n)
			if not Generator.survives(level, solve):
				_fail("G9a the novice survives enough taps", where, "%d taps of %d, needs %d" % [solve.novice_taps, n, needed])
		# G5 and G6.
		if not _first_tap_fits(level):
			_fail("G5 a free screw fits an open box at the start", where, "none")
		for i: int in range(1, level.queue.size()):
			if level.queue[i] == level.queue[i - 1]:
				_fail("G6 no color twice in a row", where, "at box %d" % i)
		# 24: the readability caps.
		var free := _free_at_start(level)
		hi_free = maxi(hi_free, free)
		if n > MAX_SCREWS or colors > MAX_COLORS or layers > MAX_LAYERS or free > MAX_FREE or level.planks.size() > 16:
			_fail("24 readability caps", where, "%d screws, %d colors, %d layers, %d planks, %d free" % [n, colors, layers, level.planks.size(), free])
		var deepest := 0
		for s: int in n:
			deepest = maxi(deepest, BotSession.planks_over(level, s))
		if deepest > 3:
			_fail("6.2 at most 3 planks over any screw at the start", where, "%d planks over one screw" % deepest)
		# 25: free screws 48 du apart in every state of the solution.
		var gap := _tightest_free_gap(level, solve.solution)
		if gap < MIN_FREE_GAP:
			_fail("25 free screws at least 48 du apart on the solution path", where, "%.2f gu" % gap)
		# 2 and 8: the random bot, with R10 and I1 checked after every action.
		for g: int in _games:
			var r := BotRunner.play(entry, RandomBot.new(_seed * 1009 + g * 31 + n), false)
			random_games += 1
			random_wins += 1 if r.won else 0
			if r.violation_count > 0:
				_fail("2/8 R10 and I1 and the rest of the session checks under the random bot", where, str(Array(r.violations).slice(0, 1)))
	taps.sort()
	gen_times.sort()
	@warning_ignore("integer_division")
	var gen_med := gen_times[gen_times.size() / 2] if not gen_times.is_empty() else 0
	@warning_ignore("integer_division")
	var gen_p95 := gen_times[gen_times.size() * 95 / 100] if not gen_times.is_empty() else 0
	var gen_max := gen_times[-1] if not gen_times.is_empty() else 0
	last_use.sort()
	@warning_ignore("integer_division")
	var med_taps := taps[taps.size() / 2] if not taps.is_empty() else 0
	@warning_ignore("integer_division")
	var med_last := last_use[last_use.size() / 2] if not last_use.is_empty() else 0
	return "%4d  %6d  %7.0f%%  %3d-%-3d   %d-%d     %d-%d     %3d        %d-%d          %5.0f%%        %3d / %s              %3d                  %5.0f%%          %d / %d / %d" % [
		t, list.size(), 100.0 * fell / maxi(list.size(), 1), lo_s, hi_s, lo_c, hi_c, lo_l, hi_l, hi_free, lo_f, hi_f,
		100.0 * novice_wins / maxi(list.size(), 1), med_taps, str(needed) if needed > 0 else "-", med_last,
		100.0 * random_wins / maxi(random_games, 1), gen_med, gen_p95, gen_max]



## The tray and the least peak of numbered levels `_numbered_from` to `_numbered_to` (22b): each
## level's tray is its tier's; no solution exists with one slot fewer than the least peak when
## that is 2 or more (G10); and the TRUE least peak (the fewest slots any solution needs, from
## a search with 1, 2, ... slots) against the schedule's, so the wrong moves a level really
## forgives (tray minus true peak) can be read off. Returns the lines of the table.
func _numbered_peaks() -> PackedStringArray:
	var lines := PackedStringArray()
	var by_range: Dictionary = {}
	var ranges: Array[Vector2i] = [Vector2i(9, 11), Vector2i(12, 15), Vector2i(16, 20), Vector2i(21, 49), Vector2i(50, 99), Vector2i(100, 100000)]
	var unproven := 0
	for n: int in range(_numbered_from, _numbered_to + 1):
		var g := LevelCatalog.get_level(LevelData.NUMBERED, n, "")
		var where := LevelPrefetcher.key_for(LevelData.NUMBERED, n, "")
		if g == null or g.level == null:
			_fail("a level exists", where, "the generator gave nothing")
			continue
		var level := g.level
		var spec := Tuning.tier(level.tier)
		var want_tray := 5 if n <= 11 else (4 if n <= 20 else 3)
		if level.tray_size != want_tray:
			_fail("22b the level's tray is its range's (5, 4, 3)", where, "tray %d, wanted %d" % [level.tray_size, want_tray])
		if level.tray_size != spec.tray:
			_fail("22b the level's tray is its tier's", where, "tray %d, tier %d has %d" % [level.tray_size, level.tier, spec.tray])
		var peak := 0
		var proven := true
		var s := level.tray_size - 1
		peak = level.tray_size
		while s >= 1:
			var r := Solver.solve(_tray_copy(level, s), 600000)
			if not r.complete:
				proven = false
				break
			if not r.solved:
				break
			peak = s
			s -= 1
		if not proven:
			unproven += 1
			continue
		if spec.peak.x >= 2 and peak < spec.peak.x:
			_fail("G10 no solution with one slot fewer than the least peak", where, "a solution needs only %d slots, tier %d wants a least peak of %d" % [peak, level.tier, spec.peak.x])
		if spec.peak.x == 1 and g.solve.fewest_tray_uses < 1:
			_fail("G3 a least peak of 1 needs the tray", where, "fewest tray uses %d" % g.solve.fewest_tray_uses)
		for r: Vector2i in ranges:
			if n >= r.x and n <= r.y:
				var key := "%d-%d" % [r.x, mini(r.y, _numbered_to)]
				if not by_range.has(key):
					by_range[key] = {"n": 0, "tray": level.tray_size, "peak": spec.peak.x, "exact": 0, "forgiven": [], "fell": 0}
				var d: Dictionary = by_range[key]
				d["n"] = int(d["n"]) + 1
				d["exact"] = int(d["exact"]) + (1 if peak == spec.peak.x else 0)
				d["fell"] = int(d["fell"]) + (1 if g.fell_back else 0)
				(d["forgiven"] as Array).append(level.tray_size - peak)
	lines.append("Numbered levels %d to %d: the tray and the least peak (true = the fewest slots any solution needs)" % [_numbered_from, _numbered_to])
	lines.append("levels       n   tray  schedule peak  true peak = schedule   wrong moves forgiven (tray - true peak): min / mean / max   fallback")
	for key: Variant in by_range.keys():
		var d: Dictionary = by_range[key]
		var list: Array = d["forgiven"]
		var lo := 99
		var hi := 0
		var sum := 0
		for f: Variant in list:
			lo = mini(lo, int(f))
			hi = maxi(hi, int(f))
			sum += int(f)
		lines.append("%-11s %3d  %4d  %13d  %18.0f%%   %5d / %.2f / %d                                    %3.0f%%" % [key, d["n"], d["tray"], d["peak"], 100.0 * int(d["exact"]) / maxi(int(d["n"]), 1), lo, float(sum) / maxi(list.size(), 1), hi, 100.0 * int(d["fell"]) / maxi(int(d["n"]), 1)])
	if unproven > 0:
		lines.append("(%d levels whose smaller-tray search did not finish are left out)" % unproven)
	return lines


## A copy of a level with another tray (the board, colors and queue are shared).
func _tray_copy(level: LevelData, slots: int) -> LevelData:
	var errors := PackedStringArray()
	var copy := level.with_colors(level.screw_colors, level.queue, errors, {"tray": slots})
	if copy == null:
		push_error("a copy with %d slots: %s" % [slots, "; ".join(errors)])
	return copy

func _check_g7() -> void:
	# Numbered levels A to B in a row, then each Relaxed stream in a row.
	var ids: Array[String] = []
	var fell: Array[bool] = []
	for n: int in range(_g7_from, _g7_to + 1):
		var g := LevelCatalog.get_level(LevelData.NUMBERED, n, "")
		ids.append(g.level.blueprint_id if g != null and g.level != null else "?")
		fell.append(g.fell_back if g != null else true)
	_g7_run("numbered", ids, fell)
	for band: String in Tuning.BANDS:
		ids.clear()
		fell.clear()
		for i: int in range(1, 41):
			var g := LevelCatalog.get_level(LevelData.RELAXED, i, band)
			ids.append(g.level.blueprint_id if g != null and g.level != null else "?")
			fell.append(g.fell_back if g != null else true)
		_g7_run("relaxed " + band, ids, fell)


func _g7_run(stream: String, ids: Array[String], fell: Array[bool]) -> void:
	for i: int in ids.size():
		for back: int in range(1, 6):
			if i - back < 0:
				continue
			if ids[i] == ids[i - back] and not fell[i] and not fell[i - back]:
				_fail("G7 no blueprint twice within 5 levels", "%s position %d" % [stream, i], "%s repeats after %d" % [ids[i], back])


## The fewest tray uses of a solution, replayed in PlayState.
func _replay(level: LevelData, solution: PackedInt32Array) -> int:
	var state := PlayState.start(level)
	for s: int in solution:
		if not state.tap(s).ok:
			return -1
	return state.tray_uses() if state.status() == PlayState.WON else -2


func _first_tap_fits(level: LevelData) -> bool:
	var state := PlayState.start(level)
	for s: int in level.screw_count():
		if state.is_free(s) and state.destination(s).x == PlayState.BOX:
			return true
	return false


func _free_at_start(level: LevelData) -> int:
	var state := PlayState.start(level)
	var n := 0
	for s: int in level.screw_count():
		if state.is_free(s):
			n += 1
	return n


## The smallest distance between two free screws in any state on the solution path.
func _tightest_free_gap(level: LevelData, solution: PackedInt32Array) -> float:
	var state := PlayState.start(level)
	var best := INF
	for step: int in solution.size() + 1:
		var free: Array[Vector2] = []
		for s: int in level.screw_count():
			if state.is_free(s):
				free.append(level.screw_center(s))
		for i: int in free.size():
			for j: int in range(i + 1, free.size()):
				best = minf(best, free[i].distance_to(free[j]))
		if step < solution.size():
			state.tap(solution[step])
	return best
