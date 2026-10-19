# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelCatalog
extends RefCounted
## Everything levels are made from (docs/ARCHITECTURE.md 4.4): the tuning numbers, the
## blueprints, the tutorial levels and the fallback levels. load_all() reads them once, on the
## main thread at startup; after that they are read-only, so worker threads may read them
## freely. get_level() is what the app flow (through LevelPrefetcher) asks for.

const BLUEPRINT_DIR := "res://data/blueprints"
const TUTORIAL_DIR := "res://data/tutorial"
const FALLBACK_DIR := "res://src/logic/fallback"
## See suits_tier.
const COVER_PER_TRAY_USE := 2
## States for solving a tutorial level (they are tiny).
const TUTORIAL_STATES := 100000

static var _loaded := false
## Blueprints sorted by id.
static var blueprints: Array[LevelData] = []
## Tutorial level n at index n - 1.
static var tutorials: Array[LevelData] = []
## Per tier (index tier - 1): the blueprints (indices) that suit it as authored, by id.
static var suits: Array[PackedInt32Array] = []
## The blueprints split in two halves for the G7 deal (Generator): each half has some of every
## tier's blueprints.
static var halves: Array[PackedInt32Array] = []
## The daily's blueprints: those that suit the daily tier, topped up (if there are fewer than
## Tuning.recent_blueprints_excluded + 1, which G7 needs for a one a day cycle) with the
## most covered blueprints whose screws and layers suit the tier.
static var daily_pool := PackedInt32Array()
## Per tier (index tier - 1): stored fallback levels, each with its stored solve.
static var fallback: Array[Array] = []


static func is_loaded() -> bool:
	return _loaded


## Reads tuning, blueprints, tutorial levels and fallback levels. Main thread only, once at
## startup (later calls do nothing). Logs and returns false if anything is broken; what did
## load stays usable.
static func load_all() -> bool:
	if _loaded:
		return true
	var ok := Tuning.load_file()
	blueprints.clear()
	for path: String in json_files(BLUEPRINT_DIR):
		var level := LevelData.from_json(read_text(path))
		if level == null or level.kind != LevelData.BLUEPRINT:
			push_error("blueprint %s could not be read" % path)
			ok = false
			continue
		blueprints.append(level)
	tutorials.clear()
	for n: int in range(1, Tuning.tutorial_levels + 1):
		var path := TUTORIAL_DIR.path_join("tutorial-%d.json" % n)
		var level := LevelData.from_json(read_text(path))
		if level == null or level.kind != LevelData.TUTORIAL:
			push_error("tutorial level %s could not be read" % path)
			ok = false
			continue
		tutorials.append(level)
	_load_fallback()
	_sort_blueprints()
	_loaded = true
	return ok


## The level for (kind, number, band): the tutorial file for numbered levels 1 to
## Tuning.tutorial_levels, otherwise the generator. Safe on a worker thread after load_all().
static func get_level(kind: int, number: int, band: String) -> GeneratedLevel:
	if not _loaded:
		push_error("LevelCatalog.get_level before load_all")
		return null
	if kind == LevelData.NUMBERED and number >= 1 and number <= tutorials.size():
		var started := Time.get_ticks_usec()
		var out := GeneratedLevel.new()
		out.level = tutorials[number - 1]
		out.solve = Solver.solve(out.level, TUTORIAL_STATES)
		out.attempts = 1
		@warning_ignore("integer_division")
		out.gen_ms = (Time.get_ticks_usec() - started) / 1000
		return out
	return Generator.make(kind, number, band)


## The index of a blueprint by id, or -1.
static func blueprint_index(id: String) -> int:
	for i: int in blueprints.size():
		if blueprints[i].id == id:
			return i
	return -1


## The .json files in a folder, sorted by name. In an exported build a file can show up as
## name.json.remap; it is listed under its own name.
static func json_files(dir: String) -> PackedStringArray:
	var names := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return names
	for file: String in DirAccess.get_files_at(dir):
		var name := file.trim_suffix(".remap")
		if name.ends_with(".json") and not names.has(name):
			names.append(name)
	names.sort()
	var out := PackedStringArray()
	for name: String in names:
		out.append(dir.path_join(name))
	return out


## The text of a data file. If an export turned it into a JSON resource, its data as text.
static func read_text(path: String) -> String:
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	if ResourceLoader.exists(path):
		var res := load(path) as JSON
		if res != null:
			return JSON.stringify(res.data)
	return ""


## Reads the fallback files again (for tools/levels after it writes them). Main thread only,
## with no level being made.
static func reload_fallback() -> void:
	_load_fallback()


## Fallback files: src/logic/fallback/tier-<t>.json, each
## {"format": 1, "tier": t, "levels": [{"level": {...}, "solve": {...}}, ...]}.
static func _load_fallback() -> void:
	fallback.clear()
	for t: int in Tuning.tiers.size():
		fallback.append([])
	for path: String in json_files(FALLBACK_DIR):
		var errors := PackedStringArray()
		var list := parse_fallback(read_text(path), errors)
		if not errors.is_empty():
			push_error("fallback file %s: %s" % [path, "; ".join(errors)])
			continue
		for g: GeneratedLevel in list:
			fallback[g.level.tier - 1].append(g)


## Reads a fallback file. Quiet: problems go in errors.
static func parse_fallback(text: String, errors: PackedStringArray) -> Array[GeneratedLevel]:
	var out: Array[GeneratedLevel] = []
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		errors.append("not a JSON object")
		return out
	var d: Dictionary = json.data
	var levels: Variant = d.get("levels")
	if not (d.get("format") is float and float(d.get("format")) == 1.0 and levels is Array):
		errors.append("format 1 with a list of levels expected")
		return out
	for item: Variant in levels:
		if not (item is Dictionary and (item as Dictionary).get("level") is Dictionary and (item as Dictionary).get("solve") is Dictionary):
			errors.append("each entry needs level and solve")
			return out
		var level := LevelData.from_dict((item as Dictionary)["level"], errors)
		var s: Dictionary = (item as Dictionary)["solve"]
		if level == null:
			return out
		var r := SolveResult.new()
		r.solved = true
		r.complete = true
		r.fewest_tray_uses = PlankData.read_int(s, "fewest", 0, 20, "solve", errors)
		r.states = PlankData.read_int(s, "states", 0, 100000000, "solve", errors)
		r.novice_won = s.get("novice_won") == true
		r.trap = float(s.get("trap", 0.0)) if (s.get("trap") is float or s.get("trap") is int) else 0.0
		var solution: Variant = s.get("solution")
		if solution is Array:
			for v: Variant in solution:
				r.solution.append(int(v) if (v is float or v is int) else -1)
		if r.solution.size() != level.screw_count():
			errors.append("the stored solution must have one tap per screw")
		if not errors.is_empty():
			return out
		var g := GeneratedLevel.new()
		g.level = level
		g.solve = r
		g.variation = str(s.get("variation", ""))
		out.append(g)
	return out


## Which blueprints suit which tier, and the two halves for the G7 deal. Deterministic: it
## depends only on the blueprints (sorted by id) and the tuning.
static func _sort_blueprints() -> void:
	blueprints.sort_custom(func(a: LevelData, b: LevelData) -> bool: return a.id < b.id)
	suits.clear()
	for t: Tuning.TierSpec in Tuning.tiers:
		var list := PackedInt32Array()
		for i: int in blueprints.size():
			if suits_tier(blueprints[i], t):
				list.append(i)
		suits.append(list)
	daily_pool = suits[Tuning.daily_tier - 1].duplicate()
	var extra: Array[int] = []
	var spec := Tuning.tier(Tuning.daily_tier)
	for i: int in blueprints.size():
		var bp := blueprints[i]
		var n := bp.screw_count()
		if not daily_pool.has(i) and n >= spec.screws.x and n <= spec.screws.y and bp.layer_count() >= spec.layers.x and bp.layer_count() <= spec.layers.y:
			extra.append(i)
	extra.sort_custom(func(a: int, b: int) -> bool:
		var ca := covered_at_start(blueprints[a])
		var cb := covered_at_start(blueprints[b])
		return ca > cb if ca != cb else a < b)
	for i: int in extra:
		if daily_pool.size() <= Tuning.recent_blueprints_excluded:
			daily_pool.append(i)
	daily_pool.sort()
	# Halves: blueprints that suit the fewest tiers first; each goes to the half that has fewer
	# blueprints for the tiers it suits, so every tier ends up in both halves.
	var order: Array[int] = []
	for i: int in blueprints.size():
		order.append(i)
	var tier_count := func(i: int) -> int:
		var c := 0
		for list: PackedInt32Array in suits:
			if list.has(i):
				c += 1
		return c
	order.sort_custom(func(a: int, b: int) -> bool:
		var ca: int = tier_count.call(a)
		var cb: int = tier_count.call(b)
		return ca < cb if ca != cb else a < b)
	# (Packed arrays inside an Array are copies when read, so the halves and their counts are
	# kept in plain variables until the end.)
	var half0 := PackedInt32Array()
	var half1 := PackedInt32Array()
	var count0 := PackedInt32Array()
	var count1 := PackedInt32Array()
	count0.resize(suits.size())
	count1.resize(suits.size())
	for i: int in order:
		var score0 := 0
		var score1 := 0
		var any := false
		for t: int in suits.size():
			if suits[t].has(i):
				any = true
				score0 += count0[t] * 100 + 1
				score1 += count1[t] * 100 + 1
		var to_second := score1 < score0 or (score1 == score0 and half1.size() < half0.size())
		if not any:
			to_second = half1.size() < half0.size()
		if to_second:
			half1.append(i)
		else:
			half0.append(i)
		for t: int in suits.size():
			if suits[t].has(i):
				if to_second:
					count1[t] += 1
				else:
					count0[t] += 1
	half0.sort()
	half1.sort()
	halves.clear()
	halves.append(half0)
	halves.append(half1)


## A blueprint suits a tier when its screws and layers as authored are in the tier's ranges,
## and, for a tier that needs tray uses, when enough of its screws are covered at the start to
## make them: at least COVER_PER_TRAY_USE times the tier's fewest tray uses, plus one. (A board
## with nothing covered never needs the tray, whatever its colors: every screw can be taken in
## queue order.)
static func suits_tier(bp: LevelData, t: Tuning.TierSpec) -> bool:
	var n := bp.screw_count()
	var layers := bp.layer_count()
	if n < t.screws.x or n > t.screws.y or layers < t.layers.x or layers > t.layers.y:
		return false
	return t.tray_uses.x == 0 or covered_at_start(bp) >= COVER_PER_TRAY_USE * t.tray_uses.x + 1


## How many screws are covered at the start.
static func covered_at_start(bp: LevelData) -> int:
	var all := (1 << bp.screw_count()) - 1
	var covered := bp.geometry.covered(all)
	var count := 0
	for s: int in bp.screw_count():
		if covered & (1 << s):
			count += 1
	return count
