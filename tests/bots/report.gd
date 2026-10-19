# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## The bot report. Plays levels with the perfect, novice and random bots through PlayState,
## prints tables per band (or tier, or blueprint) and writes one CSV row per level.
##
##   godot --headless --path . -s res://tests/bots/report.gd -- [options]
##
## (Run `godot --headless --path . --import` once first if scripts are new, as tools/test.sh
## does.) Options, all optional:
##   --levels=N        random colorings to play, 0 to 2000 (default 80). They are spread over
##                     the blueprints, a whole number each, so N rounds up to a multiple of
##                     the number of blueprints (40 unless --blueprints is given)
##   --seed=S          seed for colorings and the random bot, 0 to 1000000 (default 1)
##   --random-runs=R   games the random bot plays on each level, 0 to 1000 (default 20)
##   --by=band|tier|blueprint   how to group the tables (default band)
##   --max-states=M    solver budget per level, 1000 to 50000000; levels it cannot finish
##                     are dropped and counted (default 400000)
##   --blueprints=a,b  only these blueprint ids (they must exist)
##   --slack=K         tray par slack added to the fewest tray uses, 0 to 10 (default 1)
##   --generated=A-B   also play the generator's numbered levels A to B (needs the generator
##                     and LevelCatalog in src/logic)
##   --no-tutorials    skip the tutorial levels
##   --quick           no independent covering check at all (faster). Without it, the perfect
##                     bot, the novice bot and the first random game on each level are checked
##   --out=DIR         where to write the CSV, under build/ (default build/bots)
##
## Exit codes: 0 all good; 1 a rule check failed, a bot disagreed with the solver, no level
## was played, a tutorial level was dropped or a requested generated level was missing;
## 2 a bad option.

const MAX_LEVELS := 2000
const MAX_RANDOM_RUNS := 1000
const MAX_GENERATED_SPAN := 5000

var _levels := 80
var _seed := 1
var _random_runs := 20
var _by := "band"
var _max_states := BotLevels.DEFAULT_MAX_STATES
var _only := PackedStringArray()
var _slack := 1
var _tutorials := true
var _deep := true
var _out := "build/bots"
var _gen_from := 0
var _gen_to := -1


func _initialize() -> void:
	var status := _run()
	quit(status)


## Reads a whole number in a range, or says what is wrong and returns false.
func _number(option: String, value: String, low: int, high: int, into: Array[int]) -> bool:
	if not value.is_valid_int() or value.to_int() < low or value.to_int() > high:
		print("%s needs a whole number from %d to %d, not \"%s\"" % [option, low, high, value])
		return false
	into[0] = value.to_int()
	return true


func _parse() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		var value := parts[1] if parts.size() > 1 else ""
		var got: Array[int] = [0]
		match parts[0]:
			"--levels":
				if not _number("--levels", value, 0, MAX_LEVELS, got):
					return false
				_levels = got[0]
			"--seed":
				if not _number("--seed", value, 0, 1000000, got):
					return false
				_seed = got[0]
			"--random-runs":
				if not _number("--random-runs", value, 0, MAX_RANDOM_RUNS, got):
					return false
				_random_runs = got[0]
			"--max-states":
				if not _number("--max-states", value, 1000, 50000000, got):
					return false
				_max_states = got[0]
			"--slack":
				if not _number("--slack", value, 0, 10, got):
					return false
				_slack = got[0]
			"--by":
				if not ["band", "tier", "blueprint"].has(value):
					print("--by must be band, tier or blueprint, not \"%s\"" % value)
					return false
				_by = value
			"--blueprints":
				_only = value.split(",", false)
				var known := BotLevels.json_files(BotLevels.BLUEPRINT_DIR)
				for id: String in _only:
					if not known.has(id + ".json"):
						print("--blueprints: no blueprint called \"%s\"" % id)
						return false
				if _only.is_empty():
					print("--blueprints needs at least one id")
					return false
			"--generated":
				var span := value.split("-")
				if span.size() != 2 or not span[0].is_valid_int() or not span[1].is_valid_int():
					print("--generated needs a range like 9-40")
					return false
				_gen_from = span[0].to_int()
				_gen_to = span[1].to_int()
				if _gen_from < 1 or _gen_to < _gen_from or _gen_to - _gen_from >= MAX_GENERATED_SPAN or _gen_to > 99999999:
					print("--generated needs 1 <= A <= B and at most %d levels" % MAX_GENERATED_SPAN)
					return false
			"--no-tutorials":
				_tutorials = false
			"--quick":
				_deep = false
			"--out":
				if not _valid_out(value):
					print("--out must be a relative folder under build/ with no \"..\", not \"%s\"" % value)
					return false
				_out = value.replace("\\", "/").trim_suffix("/")
			_:
				print("Unknown option ", arg)
				return false
	return true


## True for build or build/anything: relative, no "..", no drive letter, nothing empty.
func _valid_out(value: String) -> bool:
	var path := value.replace("\\", "/").trim_suffix("/")
	if path.is_empty() or path.begins_with("/") or path.contains(":") or path.is_absolute_path():
		return false
	var segments := path.split("/")
	for segment: String in segments:
		if segment.is_empty() or segment == ".." or segment == ".":
			return false
	return segments[0] == "build"


func _run() -> int:
	if not _parse():
		return 2
	Tuning.load_file()
	var started := Time.get_ticks_msec()
	var failures := PackedStringArray()
	var set := BotLevelSet.new()
	var tutorials := BotLevelSet.new()
	var colorings := BotLevelSet.new()
	var generated_set := BotLevelSet.new()
	if _tutorials:
		tutorials = BotLevels.tutorials(_max_states)
		var expected := BotLevels.json_files(BotLevels.TUTORIAL_DIR).size()
		if tutorials.entries.size() < expected:
			failures.append("only %d of %d tutorial levels were played" % [tutorials.entries.size(), expected])
		set.entries.append_array(tutorials.entries)
	var blueprints := BotLevels.json_files(BotLevels.BLUEPRINT_DIR).size() if _only.is_empty() else _only.size()
	@warning_ignore("integer_division")
	var per_blueprint := (_levels + blueprints - 1) / maxi(blueprints, 1)
	if per_blueprint > 0:
		colorings = BotLevels.colorings(per_blueprint, _seed, _max_states, _slack, _only)
		set.entries.append_array(colorings.entries)
	var generated_missing := 0
	if _gen_from > 0:
		LevelCatalog.load_all()
		var made: Array[LevelData] = []
		for n: int in range(_gen_from, _gen_to + 1):
			var one := LevelCatalog.get_level(LevelData.NUMBERED, n, "")
			if one != null and one.level != null:
				made.append(one.level)
			else:
				generated_missing += 1
		generated_set = BotLevels.from_levels(made, "generated", _max_states)
		set.entries.append_array(generated_set.entries)
		if generated_missing > 0:
			failures.append("the generator gave no level for %d of the %d numbers asked for" % [generated_missing, _gen_to - _gen_from + 1])
	var built := Time.get_ticks_msec()
	var records: Array[BotRecord] = []
	for entry: BotEntry in set.entries:
		records.append(BotRunner.play_entry(entry, _random_runs, _seed, _deep, 1 if _random_runs > 0 else 0))
	var played := Time.get_ticks_msec()
	if records.is_empty():
		failures.append("no level was played")
	var problems := 0
	var lines := PackedStringArray()
	for r: BotRecord in records:
		problems += r.problems.size() + r.mismatches.size()
		for m: String in r.mismatches:
			lines.append("MISMATCH " + m)
		for p: String in r.problems:
			lines.append("RULE " + p)
	print("WoodLogic bot report")
	print("command: godot --headless --path . -s res://tests/bots/report.gd -- %s" % " ".join(OS.get_cmdline_user_args()))
	print("seed %d, %d levels played (%d tutorial, %d colorings, %d generated), random bot %d games each, grouped by %s" % [_seed, records.size(), _count(records, "tutorial"), _count(records, "coloring"), _count(records, "generated"), _random_runs, _by])
	if per_blueprint > 0:
		print("colorings tried %d: dropped %d with no first move (G5), %d unsolvable, %d where the solver stopped at %d states, %d with no legal queue" % [colorings.tried, colorings.no_first_move, colorings.unsolvable, colorings.incomplete, _max_states, colorings.bad_queue])
	if _gen_from > 0:
		print("generated levels re-solved here: %d, dropped %d unsolvable and %d where the solver stopped at %d states" % [generated_set.tried, generated_set.unsolvable, generated_set.incomplete, _max_states])
	print("simulated time per tap: perfect %d ms, novice %d ms, random %d ms (an assumption, not a measurement)" % [PerfectBot.new().tap_ms, NoviceBot.new().tap_ms, RandomBot.new().tap_ms])
	print("a * after a tier means the tier is estimated from the level's size; tutorial levels have none")
	print("took %.1f s to build the levels and %.1f s to play them\n" % [(built - started) / 1000.0, (played - built) / 1000.0])
	if not records.is_empty():
		print(BotReport.tables(records, _by))
		print("CSV: ", _write_csv(records))
	if lines.is_empty():
		print("Rule checks: no violations, and every bot agreed with the solver.")
	else:
		print("Rule checks: %d problems" % problems)
		for i: int in mini(lines.size(), 40):
			print("  ", lines[i])
	for f: String in failures:
		print("FAILED: ", f)
	return 1 if problems > 0 or not failures.is_empty() else 0


func _count(records: Array[BotRecord], source: String) -> int:
	var n := 0
	for r: BotRecord in records:
		if r.entry.source == source:
			n += 1
	return n


func _write_csv(records: Array[BotRecord]) -> String:
	var dir := ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("bots-seed%d-n%d.csv" % [_seed, records.size()])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("Could not write ", path)
		return "(not written)"
	file.store_string(BotReport.csv(records))
	file.close()
	return path
