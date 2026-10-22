# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## How hard are the numbered levels for a person who slips and retries? Plays levels FROM to TO
## as generated, with the greedy novice (GDD 6.4) and with RetryPlayer (a person who follows the
## solver's plan but makes wrong taps, loses, and retries slipping less each time), and prints
## per range of levels: the share won on the first try, the tries to win (median and 90th
## percentile), and how many wrong taps a level forgives. Writes one CSV row per level.
##
##   godot --headless --path . -s res://tests/bots/retry_report.gd -- [options]
##
##   --from=9 --to=200      the numbered levels (default 9 to 200)
##   --persons=8            retrying people per level and profile (default 8)
##   --samples=8            tries per wrong tap count in the tolerance table (default 8)
##   --max-tries=30         a person gives up after this many tries (default 30)
##   --seed=1               seed for every random choice
##   --out=build/qa5        where the CSV goes (under build/)
## Exit code 1 if nothing was played, 2 for a bad option.

const RANGES: Array[Vector2i] = [Vector2i(9, 20), Vector2i(21, 49), Vector2i(50, 99), Vector2i(100, 200)]
## Expected wrong taps in a first try, and the factor per retry.
const PROFILES := {"careful": 1.0, "average": 2.0, "careless": 3.0, "thinker": 0.0, "thinker_slips": 2.0, "learner5": 0.05, "learner10": 0.10}
## The first three know the solver's plan; the thinkers only look one move ahead.
const THINKERS: Array[String] = ["thinker", "thinker_slips"]
## Learners start as the thinker and see the plan on this much more of the taps after each loss.
const LEARNERS: Array[String] = ["learner5", "learner10"]
const DECAY := 0.8
const TOLERANCE_COUNTS: Array[int] = [0, 1, 2, 3, 4]
## How often a person sees the planned move, for the skill curve.
const SKILLS: Array[float] = [0.0, 0.25, 0.5, 0.75, 0.9, 1.0]

var _from := 9
var _to := 200
var _persons := 8
var _samples := 8
var _max_tries := 30
var _seed := 1
var _out := "build/qa5"

## Per level: a Dictionary of what was measured.
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	quit(_run())


func _number(option: String, value: String, low: int, high: int) -> int:
	if not value.is_valid_int() or value.to_int() < low or value.to_int() > high:
		print("%s needs a whole number from %d to %d, not \"%s\"" % [option, low, high, value])
		return -1
	return value.to_int()


func _parse() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		var value := parts[1] if parts.size() > 1 else ""
		var got := 0
		match parts[0]:
			"--from":
				got = _number("--from", value, 9, 100000)
				_from = got
			"--to":
				got = _number("--to", value, 9, 100000)
				_to = got
			"--persons":
				got = _number("--persons", value, 1, 200)
				_persons = got
			"--samples":
				got = _number("--samples", value, 1, 200)
				_samples = got
			"--max-tries":
				got = _number("--max-tries", value, 1, 500)
				_max_tries = got
			"--seed":
				got = _number("--seed", value, 0, 1000000)
				_seed = got
			"--out":
				var path := value.replace("\\", "/").trim_suffix("/")
				var segments := path.split("/")
				var bad := path.is_empty() or path.begins_with("/") or path.contains(":") or segments[0] != "build"
				for segment: String in segments:
					if segment.is_empty() or segment == ".." or segment == ".":
						bad = true
				if bad:
					print("--out must be a relative folder under build/, not \"%s\"" % value)
					return false
				_out = path
			_:
				print("Unknown option ", arg)
				return false
		if got < 0:
			return false
	if _to < _from:
		print("--to must not be below --from")
		return false
	return true


func _run() -> int:
	if not _parse():
		return 2
	Tuning.load_file()
	LevelCatalog.load_all()
	var started := Time.get_ticks_msec()
	for n: int in range(_from, _to + 1):
		var g := LevelCatalog.get_level(LevelData.NUMBERED, n, "")
		if g == null or g.level == null or not g.solve.solved:
			print("level %d could not be made" % n)
			continue
		_rows.append(_measure(n, g))
	var done := Time.get_ticks_msec()
	if _rows.is_empty():
		print("no level was played")
		return 1
	print("WoodLogic retry report: generator version %d, levels %d to %d, seed %d" % [Generator.GENERATOR_VERSION, _from, _to, _seed])
	print("%d people per level and profile, %d tries per wrong tap count, up to %d tries each; took %.0f s" % [_persons, _samples, _max_tries, (done - started) / 1000.0])
	print("The person follows the solver's plan, slips (a random free screw instead of the planned one), then plays plan guided,")
	print("and after a loss retries with %.0f percent of the slips of the try before. It never uses a helper.\n" % (DECAY * 100.0))
	print(_tables())
	print("CSV: ", _write_csv())
	return 0


## Everything measured on one level.
func _measure(n: int, g: GeneratedLevel) -> Dictionary:
	var level := g.level
	var plan := g.solve.solution
	var row := {"level": n, "tier": level.tier, "tray": level.tray_size, "screws": level.screw_count(), "fewest": g.solve.fewest_tray_uses, "fell_back": g.fell_back, "novice_won": g.solve.novice_won}
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 100003 + n
	# What a level forgives: wins with exactly k wrong taps (each a needless tray tap).
	var tolerance := {}
	for k: int in TOLERANCE_COUNTS:
		var wins := 0
		for _i: int in _samples:
			if bool(RetryPlayer.try_once(level, plan, rng, k, 0.0, true)["won"]):
				wins += 1
		tolerance[k] = float(wins) / _samples
	row["tolerance"] = tolerance
	var skill_wins := {}
	for skill: float in SKILLS:
		var wins2 := 0
		for _j: int in _samples:
			if bool(RetryPlayer.try_mixed(level, plan, rng, skill)["won"]):
				wins2 += 1
		skill_wins[skill] = float(wins2) / _samples
	row["skill"] = skill_wins
	# The retrying people.
	var people := {}
	for name: String in PROFILES:
		var tries: Array[int] = []
		var first := 0
		var gave_up := 0
		for p: int in _persons:
			var profile := {"wrong": PROFILES[name], "decay": DECAY}
			var r: Dictionary
			if LEARNERS.has(name):
				r = RetryPlayer.learning_until_win(level, plan, _seed * 7919 + n * 131 + p, float(PROFILES[name]), _max_tries)
			elif THINKERS.has(name):
				r = RetryPlayer.heuristic_until_win(level, _seed * 7919 + n * 131 + p, profile, _max_tries)
			else:
				r = RetryPlayer.play_until_win(level, plan, _seed * 7919 + n * 131 + p, profile, _max_tries)
			tries.append(int(r["tries"]))
			if int(r["tries"]) == 1 and bool(r["won"]):
				first += 1
			if not bool(r["won"]):
				gave_up += 1
		people[name] = {"tries": tries, "first": first, "gave_up": gave_up}
	row["people"] = people
	return row


func _percentile(sorted: Array[int], share: float) -> int:
	if sorted.is_empty():
		return 0
	return sorted[mini(sorted.size() - 1, int(ceil(share * sorted.size())) - 1 if share > 0.0 else 0)]


func _in_range(row: Dictionary, r: Vector2i) -> bool:
	return int(row["level"]) >= r.x and int(row["level"]) <= r.y


func _label(r: Vector2i) -> String:
	return "%d to %d" % [r.x, r.y]


func _tables() -> String:
	var out := ""
	var head := "levels   n   tray  tiers      novice 1st  novice never   average: 1st try  tries median  p90   gave up"
	out += "Greedy novice and the average retrying person (about 2 wrong taps in a first try)\n" + head + "\n"
	for r: Vector2i in RANGES:
		var rows: Array[Dictionary] = []
		for row: Dictionary in _rows:
			if _in_range(row, r):
				rows.append(row)
		if rows.is_empty():
			continue
		var novice_win := 0
		var trays := {}
		var tiers := {}
		for row: Dictionary in rows:
			novice_win += 1 if bool(row["novice_won"]) else 0
			trays[int(row["tray"])] = true
			tiers[int(row["tier"])] = true
		var pooled := _pool(rows, "average")
		var tray_text := "/".join(PackedStringArray(_sorted_keys(trays).map(func(k: int) -> String: return str(k))))
		var tier_text := ",".join(PackedStringArray(_sorted_keys(tiers).map(func(k: int) -> String: return str(k))))
		out += "%-9s %3d  %-5s %-9s %8.0f%%  %11.0f%%   %14.0f%%  %12d  %4d  %7.0f%%\n" % [_label(r), rows.size(), tray_text, tier_text, 100.0 * novice_win / rows.size(), 100.0 * (rows.size() - novice_win) / rows.size(), pooled["first"], pooled["median"], pooled["p90"], pooled["gave_up"]]
	out += "\nTries to win by profile (careful: 1 wrong tap in a first try, average: 2, careless: 3; each retry slips %.0f percent as much)\n" % (DECAY * 100.0)
	out += "levels      careful: 1st  median  p90  gave up   average: 1st  median  p90  gave up   careless: 1st  median  p90  gave up\n"
	for r: Vector2i in RANGES:
		var rows: Array[Dictionary] = []
		for row: Dictionary in _rows:
			if _in_range(row, r):
				rows.append(row)
		if rows.is_empty():
			continue
		var line := "%-9s" % _label(r)
		for name: String in ["careful", "average", "careless"]:
			var p := _pool(rows, name)
			line += "   %10.0f%%  %6d  %3d  %6.0f%% " % [p["first"], p["median"], p["p90"], p["gave_up"]]
		out += line + "\n"
	out += "\nA person who does not know the solution and thinks one move ahead (a screw that completes a box first, then one that fits a box, then a tray screw whose box is in the preview), tie breaks at random, retries after a loss\n"
	out += "levels      no slips: 1st  median  p90  gave up   with about 2 slips a try: 1st  median  p90  gave up\n"
	for r: Vector2i in RANGES:
		var rows: Array[Dictionary] = []
		for row: Dictionary in _rows:
			if _in_range(row, r):
				rows.append(row)
		if rows.is_empty():
			continue
		var line := "%-9s" % _label(r)
		for name: String in THINKERS:
			var p := _pool(rows, name)
			line += "   %10.0f%%  %6d  %3d  %6.0f%%   " % [p["first"], p["median"], p["p90"], p["gave_up"]]
		out += line + "\n"
	out += "\nA person who starts as the thinker and LEARNS the level: after each loss it sees the best move on 5 (or 10) percent more of the taps, never slips; tries to win\n"
	out += "levels      +5% a try: 1st  median  p90  gave up   +10% a try: 1st  median  p90  gave up\n"
	for r: Vector2i in RANGES:
		var rows: Array[Dictionary] = []
		for row: Dictionary in _rows:
			if _in_range(row, r):
				rows.append(row)
		if rows.is_empty():
			continue
		var line := "%-9s" % _label(r)
		for name: String in LEARNERS:
			var p := _pool(rows, name)
			line += "   %10.0f%%  %6d  %3d  %6.0f%%   " % [p["first"], p["median"], p["p90"], p["gave_up"]]
		out += line + "\n"
	out += "\nSkill curve: the share of first tries won by a person who sees the planned move on that share of taps (0 = the thinker, 1 = the plan), no slips\n"
	out += "levels    "
	for skill: float in SKILLS:
		out += "  %4.0f%%" % (skill * 100.0)
	out += "\n"
	for r: Vector2i in RANGES:
		var rows: Array[Dictionary] = []
		for row: Dictionary in _rows:
			if _in_range(row, r):
				rows.append(row)
		if rows.is_empty():
			continue
		var line := "%-9s " % _label(r)
		for skill: float in SKILLS:
			var total := 0.0
			for row: Dictionary in rows:
				total += float((row["skill"] as Dictionary)[skill])
			line += "  %5.0f%%" % (100.0 * total / rows.size())
		out += line + "\n"
	out += "\nWhat a level forgives: the share of tries won with exactly k wrong taps (a wrong tap is a free screw sent to the tray needlessly, at a random moment; the rest follows the plan, then plan guided)\n"
	out += "levels      "
	for k: int in TOLERANCE_COUNTS:
		out += "  k=%d   " % k
	out += "  levels where k=1 always wins, k=2 always wins, k=3 always wins\n"
	for r: Vector2i in RANGES:
		var rows: Array[Dictionary] = []
		for row: Dictionary in _rows:
			if _in_range(row, r):
				rows.append(row)
		if rows.is_empty():
			continue
		var line := "%-9s " % _label(r)
		for k: int in TOLERANCE_COUNTS:
			var total := 0.0
			for row: Dictionary in rows:
				total += float((row["tolerance"] as Dictionary)[k])
			line += " %5.0f%%  " % (100.0 * total / rows.size())
		for k: int in [1, 2, 3]:
			var always := 0
			for row: Dictionary in rows:
				if float((row["tolerance"] as Dictionary)[k]) >= 0.999:
					always += 1
			line += "   %3.0f%%" % (100.0 * always / rows.size())
		out += line + "\n"
	out += "\nBy tier (the first try of the average person, and the tolerance with 1 and 2 wrong taps)\n"
	out += "tier  tray  levels  fallback  novice wins  average 1st try  median tries  k=1 wins  k=2 wins\n"
	for t: int in range(1, 11):
		var rows: Array[Dictionary] = []
		for row: Dictionary in _rows:
			if int(row["tier"]) == t:
				rows.append(row)
		if rows.is_empty():
			continue
		var fell := 0
		var novice := 0
		var k1 := 0.0
		var k2 := 0.0
		for row: Dictionary in rows:
			fell += 1 if bool(row["fell_back"]) else 0
			novice += 1 if bool(row["novice_won"]) else 0
			k1 += float((row["tolerance"] as Dictionary)[1])
			k2 += float((row["tolerance"] as Dictionary)[2])
		var p := _pool(rows, "average")
		out += "%4d  %4d  %6d  %7.0f%%  %10.0f%%  %14.0f%%  %12d  %8.0f%%  %8.0f%%\n" % [t, int(rows[0]["tray"]), rows.size(), 100.0 * fell / rows.size(), 100.0 * novice / rows.size(), p["first"], p["median"], 100.0 * k1 / rows.size(), 100.0 * k2 / rows.size()]
	return out


func _sorted_keys(d: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for k: Variant in d.keys():
		out.append(int(k))
	out.sort()
	return out


## Pooled over the levels of `rows`: the first try win share (percent), the median and 90th
## percentile of tries, and the share that gave up (percent).
func _pool(rows: Array[Dictionary], profile: String) -> Dictionary:
	var tries: Array[int] = []
	var first := 0
	var gave_up := 0
	for row: Dictionary in rows:
		var p: Dictionary = (row["people"] as Dictionary)[profile]
		tries.append_array(p["tries"])
		first += int(p["first"])
		gave_up += int(p["gave_up"])
	tries.sort()
	var count := maxi(tries.size(), 1)
	return {"first": 100.0 * first / count, "median": _percentile(tries, 0.5), "p90": _percentile(tries, 0.9), "gave_up": 100.0 * gave_up / count}


func _write_csv() -> String:
	var dir := ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("retry-seed%d-%d-%d.csv" % [_seed, _from, _to])
	var lines := PackedStringArray()
	var head := "level,tier,tray,screws,fewest_tray_uses,fell_back,novice_won"
	for k: int in TOLERANCE_COUNTS:
		head += ",tolerance_k%d" % k
	for skill: float in SKILLS:
		head += ",skill_%d" % int(skill * 100.0)
	for name: String in PROFILES:
		head += ",%s_first_try,%s_median_tries,%s_gave_up" % [name, name, name]
	lines.append(head)
	for row: Dictionary in _rows:
		var cells: Array[String] = [str(row["level"]), str(row["tier"]), str(row["tray"]), str(row["screws"]), str(row["fewest"]), "1" if row["fell_back"] else "0", "1" if row["novice_won"] else "0"]
		for k: int in TOLERANCE_COUNTS:
			cells.append("%.3f" % float((row["tolerance"] as Dictionary)[k]))
		for skill: float in SKILLS:
			cells.append("%.3f" % float((row["skill"] as Dictionary)[skill]))
		for name: String in PROFILES:
			var p: Dictionary = (row["people"] as Dictionary)[name]
			var tries: Array[int] = []
			tries.append_array(p["tries"])
			tries.sort()
			cells.append("%.3f" % (float(p["first"]) / _persons))
			cells.append(str(_percentile(tries, 0.5)))
			cells.append("%.3f" % (float(p["gave_up"]) / _persons))
		lines.append(",".join(cells))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "(not written)"
	file.store_string("\n".join(lines) + "\n")
	file.close()
	return path
