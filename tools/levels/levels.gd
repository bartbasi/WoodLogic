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
##   --golden             write tests/logic/golden_levels.json (only with a new
##                        GENERATOR_VERSION)
## Exits with 1 if any level was not solved with a complete search, or a repeat differed.

const GOLDEN_PATH := "res://tests/logic/golden_levels.json"
const FALLBACK_DIR := "res://src/logic/fallback"
const FALLBACK_ATTEMPTS := 160
## The golden set: numbered 9 to 40, three dailies, two Relaxed levels per band.
const GOLDEN_DAILIES := [20261019, 20261020, 20270101]
const GOLDEN_RELAXED := 2
## Pixels per grid unit in the pictures.
const SCALE := 2
## Plain colors for the pictures: the palette is the renderer's, so the report draws its own.
const SCREW_COLORS := [Color("d1453b"), Color("e8b931"), Color("5ab4e5"), Color("2f5fb8"), Color("4caf50"), Color("9c5fc4"), Color("f08a3c"), Color("7a4e2d")]
const WOOD := [Color("e3c08f"), Color("cfa671"), Color("b98d58"), Color("a37645"), Color("8b6236")]


func _initialize() -> void:
	var code := _main(OS.get_cmdline_user_args())
	quit(code)


func _main(args: PackedStringArray) -> int:
	var opt := _options(args)
	if not LevelCatalog.load_all():
		print("The catalog did not load cleanly (errors above).")
	var out_dir: String = opt["out"]
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("png"))
	var failed := 0
	if opt["fallback"] > 0:
		failed += _write_fallback(opt["fallback"])
		LevelCatalog.reload_fallback()
	if opt["golden"]:
		_write_golden()
	var requests := _requests(opt)
	var rows: Array[Dictionary] = []
	var started := Time.get_ticks_msec()
	for req: Array in requests:
		var g := LevelCatalog.get_level(req[0], req[1], req[2])
		var row := _row(req, g)
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
		print("%s tier %d %s: %d ms%s" % [row["key"], row["tier"], row["blueprint"], row["gen_ms"], " (fallback)" if row["fell_back"] else ""])
	var report := _report(rows, opt, Time.get_ticks_msec() - started)
	var file := FileAccess.open(out_dir.path_join("report.md"), FileAccess.WRITE)
	file.store_string(report)
	file.close()
	print("\nWrote %s with %d levels; %d problems." % [out_dir.path_join("report.md"), rows.size(), failed])
	return 1 if failed > 0 else 0


func _options(args: PackedStringArray) -> Dictionary:
	var opt := {"from": 1, "to": 100, "daily": "", "days": 1, "relaxed": 0, "out": "res://build/levels", "png": true, "repeat": false, "fallback": 0, "golden": false}
	for a: String in args:
		var kv := a.trim_prefix("--").split("=", true, 1)
		var key := kv[0]
		var value := kv[1] if kv.size() > 1 else ""
		match key:
			"from", "to", "days", "relaxed", "fallback":
				opt[key] = value.to_int()
			"daily", "out":
				opt[key] = value
			"no-png":
				opt["png"] = false
			"repeat", "golden":
				opt[key] = true
			_:
				print("Unknown option ", a)
	var out: String = opt["out"]
	if not out.begins_with("res://") and not out.is_absolute_path():
		opt["out"] = "res://" + out
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
	return {
		"key": LevelPrefetcher.key_for(req[0], req[1], req[2]),
		"kind": LevelData.KIND_NAMES[level.kind],
		"tier": level.tier,
		"blueprint": level.blueprint_id,
		"variation": g.variation,
		"screws": level.screw_count(),
		"colors": level.color_count(),
		"layers": level.layer_count(),
		"covered": int(round(100.0 * covered_count / level.screw_count())),
		"fewest": g.solve.fewest_tray_uses,
		"tray_par": level.tray_par,
		"novice": "win" if g.solve.novice_won else "lose",
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
	}


func _report(rows: Array[Dictionary], opt: Dictionary, total_ms: int) -> String:
	var lines := PackedStringArray()
	lines.append("# Level report")
	lines.append("")
	lines.append("Generator version %d. Numbered %d to %d%s%s. Made on %s in %d s. Times are this PC's; a phone is several times slower." % [Generator.GENERATOR_VERSION, opt["from"], opt["to"], (", %d dailies from %s" % [opt["days"], opt["daily"]]) if opt["daily"] != "" else "", (", %d Relaxed levels per band" % opt["relaxed"]) if opt["relaxed"] > 0 else "", Time.get_datetime_string_from_system(), total_ms / 1000])
	lines.append("")
	lines.append("## Timing and acceptance per tier")
	lines.append("")
	lines.append("| Tier | Levels | Generation ms (median / 95th / worst) | Solve ms (worst) | States (median / worst) | States, all tries (worst) | Attempts (median / worst) | Fell back | Fewest tray uses | Novice loses | Trap (mean) | Pressure kept |")
	lines.append("|-|-|-|-|-|-|-|-|-|-|-|-|")
	for t: int in range(1, 11):
		var group: Array[Dictionary] = []
		for r: Dictionary in rows:
			if r["tier"] == t:
				group.append(r)
		if group.is_empty():
			continue
		var gen := _values(group, "gen_ms")
		var solve := _values(group, "solve_ms")
		var states := _values(group, "states")
		var all_states := _values(group, "total_states")
		var attempts := _values(group, "attempts")
		var fell := 0
		var lose := 0
		var trap := 0.0
		var fewest := {}
		var pressures := {}
		for r: Dictionary in group:
			if int(r["pressure"]) >= 0:
				pressures[r["pressure"]] = int(pressures.get(r["pressure"], 0)) + 1
			fell += 1 if r["fell_back"] else 0
			lose += 1 if r["novice"] == "lose" else 0
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
		lines.append("| %d | %d | %d / %d / %d | %d | %d / %d | %d | %d / %d | %d (%d%%) | %s | %d | %.2f | %s |" % [t, group.size(), _median(gen), _pct(gen, 0.95), gen[-1], solve[-1], _median(states), states[-1], all_states[-1], _median(attempts), attempts[-1], fell, int(round(100.0 * fell / group.size())), ", ".join(fewest_text), lose, trap / group.size(), ", ".join(pressure_text)])
	var gen_all := _values(rows, "gen_ms")
	lines.append("")
	if not gen_all.is_empty():
		lines.append("All %d levels: generation median %d ms, 95th percentile %d ms, worst %d ms." % [rows.size(), _median(gen_all), _pct(gen_all, 0.95), gen_all[-1]])
	var unsolved := 0
	var repeats := 0
	for r: Dictionary in rows:
		unsolved += 0 if r["solved"] else 1
		repeats += 0 if r["repeat_ok"] else 1
	lines.append("Solved with a complete search: %d of %d.%s" % [rows.size() - unsolved, rows.size(), (" Made twice: %d differed." % repeats) if opt["repeat"] else ""])
	lines.append("")
	lines.append("## Levels")
	lines.append("")
	lines.append("| Level | Kind | Tier | Blueprint | Variation | Screws | Colors | Layers | Covered % | Fewest tray uses | Tray par | Novice | Trap | Attempts | Fallback | Generation ms | Solve ms | States | Turned down | Picture |")
	lines.append("|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|")
	for r: Dictionary in rows:
		lines.append("| %s | %s | %d | %s | %s | %d | %d | %d | %d | %d | %d | %s | %.2f | %d | %s | %d | %d | %d | %s | %s |" % [r["key"], r["kind"], r["tier"], r["blueprint"], r["variation"], r["screws"], r["colors"], r["layers"], r["covered"], r["fewest"], r["tray_par"], r["novice"], r["trap"], r["attempts"], "yes" if r["fell_back"] else "", r["gen_ms"], r["solve_ms"], r["states"], r["rejections"], "png/%s.png" % str(r["key"]).replace(":", "-")])
	return "\n".join(lines) + "\n"


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


## Builds `count` fallback levels per tier and writes src/logic/fallback/tier-NN.json. Returns
## how many tiers got none.
func _write_fallback(count: int) -> int:
	DirAccess.make_dir_recursive_absolute(FALLBACK_DIR)
	var missing := 0
	for t: int in range(1, Tuning.tiers.size() + 1):
		var started := Time.get_ticks_msec()
		var list := Generator.build_fallback(t, count, FALLBACK_ATTEMPTS)
		var levels := []
		for g: GeneratedLevel in list:
			levels.append({
				"level": g.level.to_dict(),
				"solve": {
					"fewest": g.solve.fewest_tray_uses,
					"states": g.solve.states,
					"novice_won": g.solve.novice_won,
					"trap": snappedf(g.solve.trap, 0.001),
					"solution": Array(g.solve.solution),
					"variation": g.variation,
				},
			})
		if list.is_empty():
			missing += 1
		# One level per line: small, and a changed level shows as one changed line.
		var lines := PackedStringArray()
		for entry: Variant in levels:
			lines.append(JSON.stringify(entry))
		var file := FileAccess.open(FALLBACK_DIR.path_join("tier-%02d.json" % t), FileAccess.WRITE)
		file.store_string('{"format": 1, "tier": %d, "levels": [\n%s\n]}\n' % [t, ",\n".join(lines)])
		file.close()
		print("fallback tier %d: %d levels in %d ms" % [t, list.size(), Time.get_ticks_msec() - started])
	return missing


func _write_golden() -> void:
	var levels := []
	for req: Array in golden_requests():
		var g := LevelCatalog.get_level(req[0], req[1], req[2])
		levels.append({"key": LevelPrefetcher.key_for(req[0], req[1], req[2]), "fingerprint": g.level.fingerprint()})
	var file := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"generator_version": Generator.GENERATOR_VERSION, "levels": levels}, "  ") + "\n")
	file.close()
	print("Wrote %s (%d levels)." % [GOLDEN_PATH, levels.size()])


static func golden_requests() -> Array[Array]:
	var out: Array[Array] = []
	for n: int in range(9, 41):
		out.append([LevelData.NUMBERED, n, ""])
	for d: int in GOLDEN_DAILIES:
		out.append([LevelData.DAILY, d, ""])
	for band: String in ["easy", "medium", "hard"]:
		for i: int in GOLDEN_RELAXED:
			out.append([LevelData.RELAXED, i, band])
	return out
