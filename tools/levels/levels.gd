# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Generates levels headless and writes a report (docs/ARCHITECTURE.md 4.5). From the project
## folder:
##   godot --headless --path . -s res://tools/levels/levels.gd -- --from=9 --to=100
## Options:
##   --from=N --to=M      numbered levels N to M (default 1 to 100)
##   --daily=YYYY-MM-DD   dailies from this date (with --days=K, default 1)
##   --relaxed=K          the first K levels of each Relaxed band
##   --out=DIR            where report.md and the PNGs go (default build/levels)
##   --no-png             skip the pictures
##   --repeat             make every level twice and check both are the same
##   --fallback=K         also build K fallback levels per tier into src/logic/fallback/
##                        (at least 11 for the daily's tier, see _write_fallback), and K
##                        more with Relaxed's tray for each tier that needs them
##                        (Generator.needs_relaxed_pool)
##   --fallback-pools=P   which pools --fallback builds: all (the default), tier or relaxed
##   --golden             write tests/logic/golden_levels.json (only with a new
##                        GENERATOR_VERSION)
##   --probe              also measure each level with Solver.probe (report only, slow):
##                        mistake tolerance and novice traps (see ProbeResult)
##   --probe-trials=N     random sets of wrong taps per point and count (default 8)
##   --probe-states=N     state budget of each probe search (default 200000)
##   --tuning=PATH        load this tuning file instead of data/tuning.json (to try data out)
##   --fallback-dir=DIR   where --fallback writes and reads the stored levels (default
##                        src/logic/fallback; use a folder under build/ with --tuning)
## report.md has a table per tier, the daily and each Relaxed band (tray, peak asked, the
## solution's own and the least peak, W, timing, attempts, fallbacks, tray uses, the novice's
## taps and G9a, the last tray use and G9b, trap, pressure), a table per range of GDD 6.8, the
## slowest levels, and a row per level. With the probe option, the forgiveness tables and the
## wrong taps against each level's W (the tray less its least peak).
## Exits with 1 if any level was not solved with a complete search, or a repeat differed.

const GOLDEN_PATH := "res://tests/logic/golden_levels.json"
const FALLBACK_DIR := "res://src/logic/fallback"
const FALLBACK_ATTEMPTS := 160
## The golden set (see golden_requests): three dailies and two Relaxed levels per band, besides
## numbered levels.
const GOLDEN_DAILIES := [20261019, 20261020, 20270101]
const GOLDEN_RELAXED := 2
## Pixels per grid unit in the pictures.
const SCALE := 2
## How many of the slowest levels the report names.
const SLOWEST := 10
## Solver.probe's defaults (see the probe option) and its seed stream.
const PROBE_TRIALS := 8
const PROBE_STATES := 200000
const PROBE_SEED := 0x70726F62
## Plain colors for the pictures: the palette is the renderer's, so the report draws its own.
const SCREW_COLORS := [Color("d1453b"), Color("e8b931"), Color("5ab4e5"), Color("2f5fb8"), Color("4caf50"), Color("9c5fc4"), Color("f08a3c"), Color("7a4e2d")]
const WOOD := [Color("e3c08f"), Color("cfa671"), Color("b98d58"), Color("a37645"), Color("8b6236")]


func _initialize() -> void:
	var code := _main(OS.get_cmdline_user_args())
	quit(code)


func _main(args: PackedStringArray) -> int:
	var opt := _options(args)
	if not LevelCatalog.load_all(opt["tuning"]):
		print("The catalog did not load cleanly (errors above).")
	if opt["fallback-dir"] != FALLBACK_DIR and opt["fallback"] == 0 and not LevelCatalog.reload_fallback(opt["fallback-dir"]):
		print("The stored levels in %s did not load." % opt["fallback-dir"])
	var out_dir: String = opt["out"]
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("png"))
	var failed := 0
	if opt["fallback"] > 0:
		failed += _write_fallback(opt["fallback"], opt["fallback-dir"], opt["fallback-pools"])
		if not LevelCatalog.reload_fallback(opt["fallback-dir"]):
			failed += 1
	if opt["golden"] and not _write_golden():
		failed += 1
	var requests := _requests(opt)
	var rows: Array[Dictionary] = []
	var started := Time.get_ticks_msec()
	for req: Array in requests:
		var g := LevelCatalog.get_level(req[0], req[1], req[2])
		var row := _row(req, g)
		if opt["probe"]:
			_probe_row(row, g, opt)
		if opt["repeat"]:
			var again := LevelCatalog.get_level(req[0], req[1], req[2])
			row["repeat_ok"] = again.level.fingerprint() == g.level.fingerprint()
			if not row["repeat_ok"]:
				failed += 1
		if not (g.solve.solved and g.solve.complete):
			failed += 1
		if opt["png"]:
			_draw(g.level).save_png(out_dir.path_join("png").path_join(str(row["key"]).replace(":", "-") + ".png"))
		rows.append(row)
		print("%s tier %d %s: %d ms, %d attempts, novice %d of %d taps%s%s" % [row["key"], row["tier"], row["blueprint"], row["gen_ms"], row["attempts"], row["novice_taps"], row["screws"], " (fallback)" if row["fell_back"] else "", (", probe %s in %d ms" % [row["probe_text"], row["probe_ms"]]) if opt["probe"] else ""])
	var report := _report(rows, opt, Time.get_ticks_msec() - started)
	var file := FileAccess.open(out_dir.path_join("report.md"), FileAccess.WRITE)
	file.store_string(report)
	file.close()
	print("\nWrote %s with %d levels; %d problems." % [out_dir.path_join("report.md"), rows.size(), failed])
	return 1 if failed > 0 else 0


func _options(args: PackedStringArray) -> Dictionary:
	var opt := {"from": 1, "to": 100, "daily": "", "days": 1, "relaxed": 0, "out": "res://build/levels", "png": true, "repeat": false, "fallback": 0, "golden": false, "probe": false, "probe-trials": PROBE_TRIALS, "probe-states": PROBE_STATES, "tuning": Tuning.PATH, "fallback-dir": FALLBACK_DIR, "fallback-pools": "all"}
	for a: String in args:
		var kv := a.trim_prefix("--").split("=", true, 1)
		var key := kv[0]
		var value := kv[1] if kv.size() > 1 else ""
		match key:
			"from", "to", "days", "relaxed", "fallback", "probe-trials", "probe-states":
				opt[key] = value.to_int()
			"daily", "out", "tuning", "fallback-dir", "fallback-pools":
				opt[key] = value
			"no-png":
				opt["png"] = false
			"repeat", "golden", "probe":
				opt[key] = true
			_:
				print("Unknown option ", a)
	for k: String in ["out", "tuning", "fallback-dir"]:
		var path: String = opt[k]
		if not path.begins_with("res://") and not path.is_absolute_path():
			opt[k] = "res://" + path
	return opt


## [kind, number, band] for every level asked for.
func _requests(opt: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	for n: int in range(opt["from"], int(opt["to"]) + 1):
		out.append([LevelData.NUMBERED, n, ""])
	var daily: String = opt["daily"]
	if daily != "":
		var parts := daily.split("-")
		var y := parts[0].to_int()
		var m := parts[1].to_int()
		var d := parts[2].to_int()
		for _i: int in opt["days"]:
			out.append([LevelData.DAILY, y * 10000 + m * 100 + d, ""])
			var next := _next_day(y, m, d)
			y = next[0]
			m = next[1]
			d = next[2]
	for band: String in Tuning.BANDS:
		for i: int in opt["relaxed"]:
			out.append([LevelData.RELAXED, i, band])
	return out


func _next_day(y: int, m: int, d: int) -> Array[int]:
	var lengths := [31, 29 if (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	d += 1
	if d > lengths[m - 1]:
		d = 1
		m += 1
		if m > 12:
			m = 1
			y += 1
	return [y, m, d]


func _row(req: Array, g: GeneratedLevel) -> Dictionary:
	var level := g.level
	var all := (1 << level.screw_count()) - 1
	var covered := level.geometry.covered(all)
	var covered_count := 0
	for s: int in level.screw_count():
		if covered & (1 << s):
			covered_count += 1
	# A fallback's time went into the blueprint it planned, so the report names both.
	var shown := level.blueprint_id
	var plan := Generator.plan_for(req[0], req[1], req[2])
	if g.fell_back:
		if plan.blueprint >= 0 and LevelCatalog.blueprints[plan.blueprint].id != shown:
			shown += " (planned %s)" % LevelCatalog.blueprints[plan.blueprint].id
	# The peak G10 asked for, and the least peak over every solution (a search per tray size
	# from there up to the solution's own peak; G10 already proved it is at least the peak asked
	# for on a generated level).
	var asked := 0 if level.kind == LevelData.TUTORIAL else plan.peak
	var budget: int = Generator.MAX_STATES[clampi(level.tier, 1, 10) - 1] * 2
	var least := Generator.least_peak(level, g.solve, asked if not g.fell_back else 0, budget)
	var group := "tier %d" % level.tier
	if level.kind == LevelData.DAILY:
		group = "daily"
	elif level.kind == LevelData.RELAXED:
		group = "relaxed %s" % level.band
	elif level.kind == LevelData.TUTORIAL:
		group = "tutorial"
	return {
		"key": LevelPrefetcher.key_for(req[0], req[1], req[2]),
		"kind": LevelData.KIND_NAMES[level.kind],
		"tier": level.tier,
		"blueprint": shown,
		"variation": g.variation,
		"screws": level.screw_count(),
		"colors": level.color_count(),
		"layers": level.layer_count(),
		"covered": int(round(100.0 * covered_count / level.screw_count())),
		"fewest": g.solve.fewest_tray_uses,
		"tray_par": level.tray_par,
		"novice": "win" if g.solve.novice_won else "lose",
		"novice_taps": g.solve.novice_taps,
		"need": Generator.survival_needed(level.screw_count()),
		"g9a": Generator.survives(level, g.solve),
		"last_tray": g.solve.last_tray_use,
		"g9b": Generator.late_tray(level, g.solve),
		"trap": g.solve.trap,
		"attempts": g.attempts,
		"fell_back": g.fell_back,
		"gen_ms": g.gen_ms,
		"solve_ms": g.solve.ms,
		"states": g.solve.states,
		"total_states": g.total_states,
		"solved": g.solve.solved and g.solve.complete,
		"repeat_ok": true,
		"fingerprint": level.fingerprint(),
		"rejections": g.rejections(),
		"pressure": g.pressure,
		"g5": _first_tap_fits(level),
		"tray": level.tray_size,
		"peak": asked,
		"sol_peak": g.solve.peak_tray,
		"least_peak": least,
		"w": level.tray_size - (least if least >= 0 else g.solve.peak_tray),
		"group": group,
		"number": int(req[1]),
		"numbered": level.kind == LevelData.NUMBERED or level.kind == LevelData.TUTORIAL,
	}


func _report(rows: Array[Dictionary], opt: Dictionary, total_ms: int) -> String:
	var lines := PackedStringArray()
	lines.append("# Level report")
	lines.append("")
	lines.append("Generator version %d. Numbered %d to %d%s%s. Made on %s in %d s. Times are this PC's; a phone is several times slower." % [Generator.GENERATOR_VERSION, opt["from"], opt["to"], (", %d dailies from %s" % [opt["days"], opt["daily"]]) if opt["daily"] != "" else "", (", %d Relaxed levels per band" % opt["relaxed"]) if opt["relaxed"] > 0 else "", Time.get_datetime_string_from_system(), total_ms / 1000])
	lines.append("")
	lines.append("## Timing and acceptance per tier")
	lines.append("")
	lines.append("G9 (GDD 6.4.1) is required on tiers %s for G9a (novice taps at least ceil(screws / %d)) and %s for G9b (last tray use after the first third); elsewhere it is only measured." % [_tier_list(Generator.SURVIVAL_TIERS), Generator.SURVIVAL_DIVISOR, _tier_list(Generator.LATE_TRAY_TIERS)])
	lines.append("")
	lines.append("G10 (GDD 6.8): each tier's tray and least peak tray load. Peak: the one asked for / the solution's own (median) / the least over every solution (median, range). W, the wrong taps the tray can take at its tightest moment: the tray less the least peak.")
	lines.append("")
	lines.append("| Tier | Levels | Tray | Peak asked / solution / least | W (median, range) | Generation ms (median / 95th / worst) | Solve ms (worst) | States (median / worst) | States, all tries (worst) | Attempts (median / worst) | Fell back | Fewest tray uses | Novice loses | Novice taps (median / least) | Hold G9a | Last tray use (median / latest) | Hold G9b | Trap (mean) | Pressure kept |")
	lines.append("|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|")
	var labels: Array[String] = ["tutorial"]
	for t: int in range(1, 11):
		labels.append("tier %d" % t)
	labels.append("daily")
	for band: String in Tuning.BANDS:
		labels.append("relaxed %s" % band)
	for label: String in labels:
		var group: Array[Dictionary] = []
		for r: Dictionary in rows:
			if r["group"] == label:
				group.append(r)
		if group.is_empty():
			continue
		var gen := _values(group, "gen_ms")
		var solve := _values(group, "solve_ms")
		var states := _values(group, "states")
		var all_states := _values(group, "total_states")
		var attempts := _values(group, "attempts")
		var taps := _values(group, "novice_taps")
		var last_tray := _values(group, "last_tray")
		var fell := 0
		var lose := 0
		var g9a := 0
		var g9b := 0
		var trap := 0.0
		var fewest := {}
		var pressures := {}
		for r: Dictionary in group:
			if int(r["pressure"]) >= 0:
				pressures[r["pressure"]] = int(pressures.get(r["pressure"], 0)) + 1
			fell += 1 if r["fell_back"] else 0
			lose += 1 if r["novice"] == "lose" else 0
			g9a += 1 if r["g9a"] else 0
			g9b += 1 if r["g9b"] else 0
			trap += float(r["trap"])
			fewest[r["fewest"]] = int(fewest.get(r["fewest"], 0)) + 1
		var fewest_keys := fewest.keys()
		fewest_keys.sort()
		var fewest_text := PackedStringArray()
		for k: Variant in fewest_keys:
			fewest_text.append("%s: %d" % [str(k), fewest[k]])
		var pressure_keys := pressures.keys()
		pressure_keys.sort()
		var pressure_text := PackedStringArray()
		for k: Variant in pressure_keys:
			pressure_text.append("%s: %d" % [str(k), pressures[k]])
		var trays := _values(group, "tray")
		var asked := _values(group, "peak")
		var sol_peaks := _values(group, "sol_peak")
		var leasts := _values(group, "least_peak")
		var ws := _values(group, "w")
		var tray_text := str(trays[0]) if trays[0] == trays[-1] else "%d to %d" % [trays[0], trays[-1]]
		var peak_text := "%s / %d / %d (%d to %d)" % [str(asked[0]) if asked[0] == asked[-1] else "%d to %d" % [asked[0], asked[-1]], _median(sol_peaks), _median(leasts), leasts[0], leasts[-1]]
		lines.append("| %s | %d | %s | %s | %d (%d to %d) | %d / %d / %d | %d | %d / %d | %d | %d / %d | %d (%d%%) | %s | %d | %d / %d | %d | %d / %d | %d | %.2f | %s |" % [label, group.size(), tray_text, peak_text, _median(ws), ws[0], ws[-1], _median(gen), _pct(gen, 0.95), gen[-1], solve[-1], _median(states), states[-1], all_states[-1], _median(attempts), attempts[-1], fell, int(round(100.0 * fell / group.size())), ", ".join(fewest_text), lose, _median(taps), taps[0], g9a, _median(last_tray), last_tray[-1], g9b, trap / group.size(), ", ".join(pressure_text)])
	lines.append("")
	lines.append_array(_range_table(rows))
	var gen_all := _values(rows, "gen_ms")
	lines.append("")
	if not gen_all.is_empty():
		lines.append("All %d levels: generation median %d ms, 95th percentile %d ms, worst %d ms." % [rows.size(), _median(gen_all), _pct(gen_all, 0.95), gen_all[-1]])
		var slow := rows.duplicate()
		slow.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["gen_ms"]) > int(b["gen_ms"]) if a["gen_ms"] != b["gen_ms"] else str(a["key"]) < str(b["key"]))
		var slow_text := PackedStringArray()
		for r: Dictionary in slow.slice(0, SLOWEST):
			slow_text.append("%s (tier %d, %s, %d ms, %d attempts%s)" % [r["key"], r["tier"], r["blueprint"], r["gen_ms"], r["attempts"], ", fell back" if r["fell_back"] else ""])
		lines.append("Slowest: %s." % ", ".join(slow_text))
	var unsolved := 0
	var repeats := 0
	for r: Dictionary in rows:
		unsolved += 0 if r["solved"] else 1
		repeats += 0 if r["repeat_ok"] else 1
	var g5_missing := 0
	for r: Dictionary in rows:
		g5_missing += 0 if r["g5"] else 1
	lines.append("Solved with a complete search: %d of %d.%s First tap fits a box (G5): %d of %d." % [rows.size() - unsolved, rows.size(), (" Made twice: %d differed." % repeats) if opt["repeat"] else "", rows.size() - g5_missing, rows.size()])
	lines.append("")
	if opt["probe"]:
		lines.append_array(_probe_tiers(rows, opt))
	lines.append("## Levels")
	lines.append("")
	lines.append("Novice taps: the taps the novice makes before the level is lost (all of them when it wins), with G9a's need in brackets. Last tray use: the tap number of the solution's last tray use, of the screws (0: none).")
	lines.append("")
	lines.append("| Level | Kind | Tier | Blueprint | Variation | Screws | Colors | Layers | Covered % | First tap fits a box (G5) | Fewest tray uses | Tray par | Tray | Peak asked / solution / least | W | Novice | Novice taps (need) | Last tray use | Trap | Attempts | Fallback | Generation ms | Solve ms | States | Turned down | Picture |")
	lines.append("|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|")
	for r: Dictionary in rows:
		lines.append("| %s | %s | %d | %s | %s | %d | %d | %d | %d | %s | %d | %d | %d | %d / %d / %s | %d | %s | %d (%d)%s | %d of %d%s | %.2f | %d | %s | %d | %d | %d | %s | %s |" % [r["key"], r["kind"], r["tier"], r["blueprint"], r["variation"], r["screws"], r["colors"], r["layers"], r["covered"], "yes" if r["g5"] else "NO", r["fewest"], r["tray_par"], r["tray"], r["peak"], r["sol_peak"], str(r["least_peak"]) if int(r["least_peak"]) >= 0 else "not proven", r["w"], r["novice"], r["novice_taps"], r["need"], "" if r["g9a"] else " short", r["last_tray"], r["screws"], "" if r["g9b"] else " early", r["trap"], r["attempts"], "yes" if r["fell_back"] else "", r["gen_ms"], r["solve_ms"], r["states"], r["rejections"], "png/%s.png" % str(r["key"]).replace(":", "-")])
	if opt["probe"]:
		lines.append_array(_probe_levels(rows))
	return "\n".join(lines) + "\n"


## Solver.probe for one level, into its row (report only; see ProbeResult).
func _probe_row(row: Dictionary, g: GeneratedLevel, opt: Dictionary) -> void:
	var started := Time.get_ticks_msec()
	var plan := Generator.plan_for(g.level.kind, g.level.number, g.level.band)
	var p := Solver.probe(g.level, g.solve.solution, opt["probe-trials"], opt["probe-states"], Seeds.mix(PROBE_SEED, plan.seed_value))
	var tolerance := PackedStringArray()
	var unknown := 0
	var skipped := 0
	var trials := 0
	for k: int in range(1, ProbeResult.MAX_MISTAKES + 1):
		row["tol%d" % k] = p.tolerance(k)
		tolerance.append(_share_text(p.tolerance(k)))
		unknown += p.count(p.unknown, k)
		skipped += p.count(p.skipped, k)
		trials += p.count(p.won, k) + p.count(p.lost, k) + p.count(p.unknown, k) + p.count(p.skipped, k)
	var by_point := PackedStringArray()
	for point: int in ProbeResult.POINTS:
		var parts := PackedStringArray()
		for k: int in range(1, ProbeResult.MAX_MISTAKES + 1):
			parts.append(_share_text(p.tolerance_at(point, k)))
		by_point.append("/".join(parts))
	var delays := p.trap_delays.duplicate()
	delays.sort()
	row["probe_unknown"] = unknown + p.greedy_unknown
	row["probe_skipped"] = skipped
	row["probe_trials"] = trials
	row["traps"] = p.greedy_fatal
	row["trap_states"] = p.greedy_states
	row["trap_differs"] = p.greedy_differs
	row["trap_share"] = p.trap_share()
	row["trap_delays"] = delays
	row["probe_ms"] = p.ms
	row["probe_searches"] = p.searches
	row["probe_points"] = " ; ".join(by_point)
	row["no_return"] = p.no_return
	row["no_return_unknown"] = p.no_return_unknown
	row["hidden"] = p.hidden
	row["peak_tray"] = p.peak_tray
	row["probe_text"] = "%s, %d traps" % ["/".join(tolerance), p.greedy_fatal]
	# Against the level's W: W and W + 1 wrong taps in a row from the start, just before the
	# solution's tray first reaches its peak, and two thirds in; and the second half's tray.
	var loads := Solver.tray_loads(g.level, g.solve.solution)
	var peak_at := 0
	for i: int in loads.size():
		if loads[i] == g.solve.peak_tray:
			peak_at = i
			break
	var w: int = row["w"]
	var counts := PackedInt32Array()
	for point: int in [0, peak_at, g.level.screw_count() * 2 / 3]:
		for k: int in [w, w + 1]:
			var c := Solver.mistakes_at(g.level, g.solve.solution, point, k, opt["probe-trials"], opt["probe-states"], Seeds.mix(PROBE_SEED + 1, plan.seed_value)) if k >= 1 else Vector4i(0, 0, 0, 0)
			counts.append_array([c.x, c.y])
	row["w_counts"] = counts
	var half := PackedInt32Array()
	for i: int in range(loads.size() / 2, loads.size()):
		half.append(loads[i])
	half.sort()
	row["half_load"] = half[half.size() / 2] if not half.is_empty() else 0
	row["probe_ms"] = Time.get_ticks_msec() - started


## won of won + lost as a whole percent, with the trials in brackets, or "-".
func _won_text(won: int, lost: int) -> String:
	return "%d%% (%d)" % [int(round(100.0 * won / (won + lost))), won + lost] if won + lost > 0 else "-"


## Numbered levels per range of GDD 6.8: fallbacks, generation time, tray, peak and W.
func _range_table(rows: Array[Dictionary]) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Numbered levels per range (GDD 6.8):")
	lines.append("")
	lines.append("| Levels | Levels made | Fell back | Generation ms (median / 95th / worst) | Tray | Peak asked | Least peak (median, range) | W (median, range) |")
	lines.append("|-|-|-|-|-|-|-|-|")
	for span: Vector2i in [Vector2i(1, 8), Vector2i(9, 11), Vector2i(12, 15), Vector2i(16, 20), Vector2i(21, 49), Vector2i(50, 99), Vector2i(100, 1 << 30)]:
		var group: Array[Dictionary] = []
		for r: Dictionary in rows:
			if r["numbered"] and int(r["number"]) >= span.x and int(r["number"]) <= span.y:
				group.append(r)
		if group.is_empty():
			continue
		var fell := 0
		for r: Dictionary in group:
			fell += 1 if r["fell_back"] else 0
		var gen := _values(group, "gen_ms")
		var trays := _values(group, "tray")
		var asked := _values(group, "peak")
		var leasts := _values(group, "least_peak")
		var ws := _values(group, "w")
		lines.append("| %s | %d | %d (%d%%) | %d / %d / %d | %s | %s | %d (%d to %d) | %d (%d to %d) |" % ["%d on" % span.x if span.y > 100000 else "%d to %d" % [span.x, span.y], group.size(), fell, int(round(100.0 * fell / group.size())), _median(gen), _pct(gen, 0.95), gen[-1], _span_text(trays), _span_text(asked), _median(leasts), leasts[0], leasts[-1], _median(ws), ws[0], ws[-1]])
	lines.append("")
	return lines


## "3", or "3 to 5" for sorted values that differ.
func _span_text(sorted: PackedInt32Array) -> String:
	return str(sorted[0]) if sorted[0] == sorted[-1] else "%d to %d" % [sorted[0], sorted[-1]]


## A share as a whole percent, or "n/a" for -1 (nothing proven).
func _share_text(share: float) -> String:
	return "%d%%" % int(round(100.0 * share)) if share >= 0.0 else "n/a"


## The median and the 25th to 75th percentile of some shares, as percents, leaving out -1.
func _spread_text(values: Array[float]) -> String:
	var list: Array[float] = []
	for v: float in values:
		if v >= 0.0:
			list.append(v)
	if list.is_empty():
		return "n/a"
	list.sort()
	var parts := PackedStringArray()
	for q: float in [0.5, 0.25, 0.75]:
		parts.append(str(int(round(100.0 * list[mini(list.size() - 1, int(list.size() * q))]))))
	return "%s [%s to %s]" % [parts[0], parts[1], parts[2]]


## The median and the 25th to 75th percentile of sorted whole numbers, or "none".
func _int_spread(sorted: PackedInt32Array) -> String:
	if sorted.is_empty():
		return "none"
	return "%d [%d to %d]" % [_median(sorted), _pct(sorted, 0.25), _pct(sorted, 0.75)]


## The per tier forgiveness table (with the probe option).
func _probe_tiers(rows: Array[Dictionary], opt: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("## Forgiveness and lookahead per tier (Solver.probe, report only)")
	lines.append("")
	lines.append("Winnable after k wrong taps: from the start, a third and two thirds of the way along the level's solution, k wrong taps in a row (a free screw that goes to the tray while another free screw fits a box), %d random sets per point and k, then a search (%d states at most): the share of trials after which the level can still be won, among those proven either way. Per tier: the median level and, in brackets, the 25th to 75th percentile. Novice trap states: states along the solution where the novice's move (the topmost free screw that fits a box) leaves no win, in percent of the states; the delay is how many more taps the novice makes before it is stuck. Random win: the share of careless playouts that win (1 minus trap)." % [opt["probe-trials"], opt["probe-states"]])
	lines.append("")
	lines.append("Novice's point of no return: following the novice from the start, the tap after which no win is left, and the hidden stretch, the taps it makes after that before it is stuck (levels it wins have neither). Peak tray load: the most screws in the tray at once along the level's solution (the tray holds %d)." % Tuning.tray_size)
	lines.append("")
	lines.append("| Tier | Levels | Winnable after 1 wrong tap (%) | After 2 (%) | After 3 (%) | Levels winnable after every single wrong tap tried | Trials not proven / skipped / all | Novice trap states (%) | Levels with a trap | Trap delay in taps (median / most) | Novice wins | Novice taps (median) | Novice's point of no return, tap (median [25th to 75th]) | Hidden stretch, taps (median [25th to 75th]) | Peak tray load (median [least to most]) | Random win (mean) | Probe ms (median / worst) |")
	lines.append("|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|")
	for t: int in range(1, 11):
		var group: Array[Dictionary] = []
		for r: Dictionary in rows:
			if r["tier"] == t and r.has("tol1"):
				group.append(r)
		if group.is_empty():
			continue
		var cols := PackedStringArray()
		for k: int in range(1, ProbeResult.MAX_MISTAKES + 1):
			var values: Array[float] = []
			for r: Dictionary in group:
				values.append(float(r["tol%d" % k]))
			cols.append(_spread_text(values))
		var all_one := 0
		var unknown := 0
		var skipped := 0
		var trials := 0
		var trap_values: Array[float] = []
		var with_trap := 0
		var delays := PackedInt32Array()
		var novice := 0
		var random_win := 0.0
		for r: Dictionary in group:
			all_one += 1 if float(r["tol1"]) >= 1.0 else 0
			unknown += int(r["probe_unknown"])
			skipped += int(r["probe_skipped"])
			trials += int(r["probe_trials"])
			trap_values.append(float(r["trap_share"]))
			with_trap += 1 if int(r["traps"]) > 0 else 0
			delays.append_array(r["trap_delays"])
			novice += 1 if r["novice"] == "win" else 0
			random_win += 1.0 - float(r["trap"])
		delays.sort()
		var taps := _values(group, "novice_taps")
		var ms := _values(group, "probe_ms")
		var peak := _values(group, "peak_tray")
		var no_return := PackedInt32Array()
		var hidden := PackedInt32Array()
		for r: Dictionary in group:
			if int(r["no_return"]) >= 0:
				no_return.append(int(r["no_return"]))
				hidden.append(int(r["hidden"]))
		no_return.sort()
		hidden.sort()
		var delay_text := ("%d / %d" % [delays[delays.size() >> 1], delays[-1]]) if not delays.is_empty() else "none"
		lines.append("| %d | %d | %s | %s | %s | %d | %d / %d / %d | %s | %d | %s | %d (%d%%) | %d | %s | %s | %d [%d to %d] | %.2f | %d / %d |" % [t, group.size(), cols[0], cols[1], cols[2], all_one, unknown, skipped, trials, _spread_text(trap_values), with_trap, delay_text, novice, int(round(100.0 * novice / group.size())), _median(taps), _int_spread(no_return), _int_spread(hidden), _median(peak), peak[0], peak[-1], random_win / group.size(), _median(ms), ms[-1]])
	var ms_all := _values(rows, "probe_ms")
	lines.append("")
	lines.append("Probe time per level on this PC: median %d ms, 95th percentile %d ms, worst %d ms." % [_median(ms_all), _pct(ms_all, 0.95), ms_all[-1]])
	lines.append("")
	lines.append("### Wrong taps against each level's W")
	lines.append("")
	lines.append("W is the tray less the least peak. k wrong taps in a row, then a search, from the start, just before the solution's tray first reaches its peak, and two thirds in: the share of trials still winnable, over the tier's levels (trials proven either way in brackets). Second-half tray: the median of each level's median tray load over its second half.")
	lines.append("")
	lines.append("| Tier | Levels | W (median) | Start: after W / W + 1 | At the peak: after W / W + 1 | Two thirds in: after W / W + 1 | Second-half tray (median) |")
	lines.append("|-|-|-|-|-|-|-|")
	var labels: Array[String] = []
	for t: int in range(1, 11):
		labels.append("tier %d" % t)
	labels.append("daily")
	for band: String in Tuning.BANDS:
		labels.append("relaxed %s" % band)
	for label: String in labels:
		var group: Array[Dictionary] = []
		for r: Dictionary in rows:
			if r["group"] == label and r.has("w_counts"):
				group.append(r)
		if group.is_empty():
			continue
		var sums := PackedInt32Array()
		sums.resize(12)
		for r: Dictionary in group:
			var c: PackedInt32Array = r["w_counts"]
			for i: int in 12:
				sums[i] += c[i]
		var cells := PackedStringArray()
		for point: int in 3:
			cells.append("%s / %s" % [_won_text(sums[point * 4], sums[point * 4 + 1]), _won_text(sums[point * 4 + 2], sums[point * 4 + 3])])
		lines.append("| %s | %d | %d | %s | %s | %s | %d |" % [label, group.size(), _median(_values(group, "w")), cells[0], cells[1], cells[2], _median(_values(group, "half_load"))])
	lines.append("")
	return lines


## The per level forgiveness table (with the probe option).
func _probe_levels(rows: Array[Dictionary]) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("")
	lines.append("## Forgiveness and lookahead per level")
	lines.append("")
	lines.append("Winnable after 1, 2 and 3 wrong taps, over all points, then per point (start ; a third in ; two thirds in). Novice traps: fatal novice moves / novice moves that differ from the solution / states looked at.")
	lines.append("")
	lines.append("| Level | Tier | Blueprint | Winnable after 1 / 2 / 3 wrong taps | Per point | Not proven / skipped / trials | Novice traps | Trap delays | Novice | No return after tap (hidden stretch) | Peak tray load | W | After W / W + 1 wrong taps: start ; peak ; two thirds | Second-half tray | Searches | Probe ms |")
	lines.append("|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|")
	for r: Dictionary in rows:
		if not r.has("tol1"):
			continue
		var delays := PackedStringArray()
		for d: int in r["trap_delays"]:
			delays.append(str(d))
		var no_return := ("%d (%d)%s" % [r["no_return"], r["hidden"], " or sooner" if r["no_return_unknown"] else ""]) if int(r["no_return"]) >= 0 else "none"
		var wc: PackedInt32Array = r["w_counts"]
		var w_text := PackedStringArray()
		for point: int in 3:
			w_text.append("%s / %s" % [_won_text(wc[point * 4], wc[point * 4 + 1]), _won_text(wc[point * 4 + 2], wc[point * 4 + 3])])
		lines.append("| %s | %d | %s | %s / %s / %s | %s | %d / %d / %d | %d / %d / %d | %s | %s %d of %d | %s | %d | %d | %s | %d | %d | %d |" % [r["key"], r["tier"], r["blueprint"], _share_text(r["tol1"]), _share_text(r["tol2"]), _share_text(r["tol3"]), r["probe_points"], r["probe_unknown"], r["probe_skipped"], r["probe_trials"], r["traps"], r["trap_differs"], r["trap_states"], ", ".join(delays) if not delays.is_empty() else "none", r["novice"], r["novice_taps"], r["screws"], no_return, r["peak_tray"], r["w"], " ; ".join(w_text), r["half_load"], r["probe_searches"], r["probe_ms"]])
	return lines


func _tier_list(tiers: Array[int]) -> String:
	if tiers.is_empty():
		return "none"
	var parts := PackedStringArray()
	for t: int in tiers:
		parts.append(str(t))
	return ", ".join(parts)


func _values(rows: Array[Dictionary], key: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for r: Dictionary in rows:
		out.append(int(r[key]))
	out.sort()
	return out


func _median(sorted: PackedInt32Array) -> int:
	return sorted[sorted.size() >> 1] if not sorted.is_empty() else 0


func _pct(sorted: PackedInt32Array, p: float) -> int:
	return sorted[mini(sorted.size() - 1, int(sorted.size() * p))] if not sorted.is_empty() else 0


## G5: at the start some free screw fits an open box.
func _first_tap_fits(level: LevelData) -> bool:
	var state := PlayState.start(level)
	for s: int in level.screw_count():
		if state.is_free(s) and state.destination(s).x == PlayState.BOX:
			return true
	return false


## A small picture of the level as it starts: planks back to front, then the screws (covered
## ones paler, with a dark ring).
func _draw(level: LevelData) -> Image:
	var w := LevelData.BOARD_W * SCALE
	var h := LevelData.BOARD_H * SCALE
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color("f4ead8"))
	for layer: int in range(4, -1, -1):
		for p: PlankData in level.planks:
			if p.layer == layer:
				_fill(img, [p.outline_xy, p.inner_xy], WOOD[layer])
				_edge(img, p.outline_xy, Color(0.25, 0.15, 0.08))
				if not p.inner_xy.is_empty():
					_edge(img, p.inner_xy, Color(0.25, 0.15, 0.08))
	var all := (1 << level.screw_count()) - 1
	var covered := level.geometry.covered(all)
	for s: int in level.screw_count():
		var c: Color = SCREW_COLORS[level.screw_colors[s] % SCREW_COLORS.size()] if level.has_colors() else Color.GRAY
		var center := level.screw_center(s) * SCALE
		if covered & (1 << s):
			_disc(img, center, 3.5 * SCALE, Color(0.2, 0.2, 0.2))
			_disc(img, center, 2.5 * SCALE, c.lerp(Color.WHITE, 0.55))
		else:
			_disc(img, center, 3.5 * SCALE, Color(0.1, 0.1, 0.1))
			_disc(img, center, 3.0 * SCALE, c)
	return img


## Even-odd scanline fill of a plank (its outline and a ring's hole).
func _fill(img: Image, loops: Array, color: Color) -> void:
	var lo := INF
	var hi := -INF
	for loop: PackedFloat64Array in loops:
		for i: int in loop.size() >> 1:
			lo = minf(lo, loop[2 * i + 1])
			hi = maxf(hi, loop[2 * i + 1])
	for py: int in range(maxi(0, int(lo * SCALE)), mini(img.get_height(), int(hi * SCALE) + 1)):
		var y := (py + 0.5) / SCALE
		var xs := PackedFloat64Array()
		for loop: PackedFloat64Array in loops:
			var n := loop.size() >> 1
			for i: int in n:
				var j := (i + 1) % n
				var y1 := loop[2 * i + 1]
				var y2 := loop[2 * j + 1]
				if (y1 > y) != (y2 > y):
					xs.append(loop[2 * i] + (y - y1) * (loop[2 * j] - loop[2 * i]) / (y2 - y1))
		xs.sort()
		for k: int in range(0, xs.size() - 1, 2):
			for px: int in range(maxi(0, int(xs[k] * SCALE + 0.5)), mini(img.get_width(), int(xs[k + 1] * SCALE + 0.5))):
				img.set_pixel(px, py, color)


func _edge(img: Image, loop: PackedFloat64Array, color: Color) -> void:
	var n := loop.size() >> 1
	for i: int in n:
		var j := (i + 1) % n
		var a := Vector2(loop[2 * i], loop[2 * i + 1]) * SCALE
		var b := Vector2(loop[2 * j], loop[2 * j + 1]) * SCALE
		var steps := int(maxf(1.0, a.distance_to(b)))
		for k: int in steps + 1:
			var p := a.lerp(b, float(k) / steps)
			if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
				img.set_pixel(int(p.x), int(p.y), color)


func _disc(img: Image, center: Vector2, r: float, color: Color) -> void:
	for py: int in range(maxi(0, int(center.y - r)), mini(img.get_height(), int(center.y + r) + 1)):
		for px: int in range(maxi(0, int(center.x - r)), mini(img.get_width(), int(center.x + r) + 1)):
			if Vector2(px + 0.5, py + 0.5).distance_to(center) <= r:
				img.set_pixel(px, py, color)


## Builds `count` fallback levels per tier and writes src/logic/fallback/tier-NN.json, and as
## many with Relaxed's tray for each tier that needs them, in relaxed-NN.json (a stale
## relaxed-NN.json of a tier that no longer needs one is removed). pools: "all", "tier" or
## "relaxed", which of the two to build. Returns how many pools got no level.
func _write_fallback(count: int, dir: String, pools: String) -> int:
	DirAccess.make_dir_recursive_absolute(dir)
	var missing := 0
	for t: int in range(1, Tuning.tiers.size() + 1):
		if pools != "relaxed":
			# Every day draws on the daily tier's pool, so a day can have 2R lower ranked neighbors
			# on it (Generator.stored_pick): with 2R + 1 stored levels one is always left for it.
			var r := maxi(Tuning.recent_blueprints_excluded, 1)
			missing += _write_pool(t, maxi(count, 2 * r + 1) if t == Tuning.daily_tier else count, false, dir.path_join("tier-%02d.json" % t))
		if pools != "tier":
			var path := dir.path_join("relaxed-%02d.json" % t)
			if Generator.needs_relaxed_pool(t):
				missing += _write_pool(t, count, true, path)
			elif FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	return missing


## Builds one pool (Generator.build_fallback) and writes it to path. 1 if it got no level.
func _write_pool(t: int, count: int, relaxed: bool, path: String) -> int:
	var started := Time.get_ticks_msec()
	var list := Generator.build_fallback(t, count, FALLBACK_ATTEMPTS, relaxed)
	var levels := []
	for g: GeneratedLevel in list:
		levels.append({
			"level": g.level.to_dict(),
			"solve": {
				"fewest": g.solve.fewest_tray_uses,
				"states": g.solve.states,
				"novice_won": g.solve.novice_won,
				"novice_taps": g.solve.novice_taps,
				"last_tray_use": g.solve.last_tray_use,
				"peak_tray": g.solve.peak_tray,
				"trap": g.solve.trap,
				"solution": Array(g.solve.solution),
				"variation": g.variation,
			},
		})
	# One level per line: small, and a changed level shows as one changed line.
	var lines := PackedStringArray()
	for entry: Variant in levels:
		lines.append(JSON.stringify(entry))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"format": 1, "tier": %d, "levels": [\n%s\n]}\n' % [t, ",\n".join(lines)])
	file.close()
	print("fallback tier %d%s: %d levels in %d ms" % [t, " (Relaxed)" if relaxed else "", list.size(), Time.get_ticks_msec() - started])
	return 1 if list.is_empty() else 0


## Writes the golden fingerprints. Refuses if the file already holds this GENERATOR_VERSION:
## changed fingerprints at the same version mean levels changed without a new version.
func _write_golden() -> bool:
	var existing: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_PATH)) if FileAccess.file_exists(GOLDEN_PATH) else null
	if existing is Dictionary and int((existing as Dictionary).get("generator_version", 0)) == Generator.GENERATOR_VERSION:
		print("Not writing %s: it already holds GENERATOR_VERSION %d. Raise the version first if the levels are meant to change." % [GOLDEN_PATH, Generator.GENERATOR_VERSION])
		return false
	var levels := []
	for req: Array in golden_requests():
		var g := LevelCatalog.get_level(req[0], req[1], req[2])
		levels.append({"key": LevelPrefetcher.key_for(req[0], req[1], req[2]), "fingerprint": g.level.fingerprint(), "tier": g.level.tier, "fell_back": g.fell_back, "pressure": g.pressure})
	var file := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"generator_version": Generator.GENERATOR_VERSION, "levels": levels}, "  ") + "\n")
	file.close()
	print("Wrote %s (%d levels)." % [GOLDEN_PATH, levels.size()])
	return true


## Numbered 9 to 40, a spread of 50 to 160 (tiers 7 to 10, with deep openings, and the first
## levels there that fall back), three dailies and two Relaxed levels per band.
func golden_requests() -> Array[Array]:
	var out: Array[Array] = []
	for n: int in range(9, 41):
		out.append([LevelData.NUMBERED, n, ""])
	var picked := PackedInt32Array([52, 54, 101, 104, 155])
	var fallbacks := 0
	var deep := 0
	for n: int in range(50, 161):
		if fallbacks >= 2 and deep >= 1:
			break
		var g := LevelCatalog.get_level(LevelData.NUMBERED, n, "")
		if g.fell_back and fallbacks < 2 and not picked.has(n):
			picked.append(n)
			fallbacks += 1
		elif g.pressure >= 2 and g.pressure % 2 == 0 and deep < 1 and not picked.has(n):
			picked.append(n)
			deep += 1
	picked.sort()
	for n: int in picked:
		out.append([LevelData.NUMBERED, n, ""])
	for d: int in GOLDEN_DAILIES:
		out.append([LevelData.DAILY, d, ""])
	for band: String in ["easy", "medium", "hard"]:
		for i: int in GOLDEN_RELAXED:
			out.append([LevelData.RELAXED, i, band])
	return out
