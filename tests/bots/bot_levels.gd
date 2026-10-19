# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BotLevels
extends RefCounted
## Where the bots get levels. Every source gives a BotLevelSet of BotEntry, each a LevelData
## plus the solver's answer, so the bots do not care where a level came from. Today: the
## tutorial files and seeded random colorings of the blueprints. When the generator lands,
## `from_levels` takes its output.

const TUTORIAL_DIR := "res://data/tutorial"
const BLUEPRINT_DIR := "res://data/blueprints"
const DEFAULT_MAX_STATES := 400000

static func json_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".json"):
			out.append(file)
		elif file.ends_with(".json.remap"):
			out.append(file.trim_suffix(".remap"))
	out.sort()
	return out


## The group name for Stats: "Easy", "Medium", "Hard" or "Expert".
static func group_of_tier(tier: int) -> String:
	return Tuning.tier(tier).group.capitalize()


## The tier whose ranges a level of this size fits best (an estimate, for levels that do not
## carry a tier): the tiers whose screw range holds it, preferring those whose color and
## layer ranges hold it too.
static func estimate_tier(screws: int, colors: int, layers: int) -> int:
	var by_size: Array[Tuning.TierSpec] = _tiers_for_size(screws)
	if by_size.is_empty():
		return 1 if screws < Tuning.tiers[0].screws.x else Tuning.tiers.size()
	for want_layers: bool in [true, false]:
		for spec: Tuning.TierSpec in by_size:
			if colors < spec.colors.x or colors > spec.colors.y:
				continue
			if want_layers and (layers < spec.layers.x or layers > spec.layers.y):
				continue
			return spec.tier
	return by_size[0].tier


static func _tiers_for_size(screws: int) -> Array[Tuning.TierSpec]:
	var out: Array[Tuning.TierSpec] = []
	for spec: Tuning.TierSpec in Tuning.tiers:
		if screws >= spec.screws.x and screws <= spec.screws.y:
			out.append(spec)
	return out



# Sources

## The tutorial files, solved.
static func tutorials(max_states: int = DEFAULT_MAX_STATES) -> BotLevelSet:
	var set := BotLevelSet.new()
	for file: String in json_files(TUTORIAL_DIR):
		var errors := PackedStringArray()
		var level := LevelData.parse(FileAccess.get_file_as_string(TUTORIAL_DIR.path_join(file)), errors)
		if level == null:
			push_error("tutorial %s: %s" % [file, "; ".join(errors)])
			continue
		var entry := _entry(level, "tutorial", max_states, set)
		if entry != null:
			entry.tier = 0
			entry.tier_given = true
			entry.group = "Tutorial"
			entry.number = level.number
			entry.label = level.id
			set.entries.append(entry)
	return set


## Any list of levels with colors (generated ones, later), solved here with a complete search.
## Levels the search cannot finish or finds unsolvable are dropped and counted.
static func from_levels(levels: Array[LevelData], source: String = "generated", max_states: int = DEFAULT_MAX_STATES) -> BotLevelSet:
	var set := BotLevelSet.new()
	for level: LevelData in levels:
		var entry := _entry(level, source, max_states, set)
		if entry == null:
			continue
		entry.number = level.number
		entry.label = "%s-%d" % [level.blueprint_id, level.number]
		if level.tier >= 1:
			entry.tier = level.tier
			entry.tier_given = true
		else:
			entry.tier = estimate_tier(level.screw_count(), level.color_count(), level.layer_count())
		entry.group = group_of_tier(entry.tier)
		set.entries.append(entry)
	return set


## Seeded random colorings of the shipped blueprints: `per_blueprint` levels each (fewer if
## the tries run out), colors chosen from the tier ranges, queue with no color twice in a row,
## a free screw that fits at the start, and a solver answer that is complete and solved.
## `only` limits it to those blueprint ids. `slack` is added to the fewest tray uses to make
## the level's tray par.
static func colorings(per_blueprint: int, seed_value: int, max_states: int = DEFAULT_MAX_STATES, slack: int = 1, only: PackedStringArray = PackedStringArray(), tries: int = 8) -> BotLevelSet:
	var set := BotLevelSet.new()
	var files := json_files(BLUEPRINT_DIR)
	var counter := 0
	for bi: int in files.size():
		var id := files[bi].get_basename()
		if not only.is_empty() and not only.has(id):
			continue
		var errors := PackedStringArray()
		var blueprint := LevelData.parse(FileAccess.get_file_as_string(BLUEPRINT_DIR.path_join(files[bi])), errors)
		if blueprint == null:
			push_error("blueprint %s: %s" % [id, "; ".join(errors)])
			continue
		for v: int in per_blueprint:
			for attempt: int in tries:
				var rng := RandomNumberGenerator.new()
				rng.seed = seed_value * 1000003 + bi * 7919 + v * 104729 + attempt * 13 + 1
				set.tried += 1
				var colored := random_coloring(blueprint, rng)
				if colored == null:
					set.bad_queue += 1
					continue
				if not _has_first_move(colored):
					set.no_first_move += 1
					continue
				var solve := Solver.solve(colored, max_states)
				if not solve.complete:
					set.incomplete += 1
					continue
				if not solve.solved:
					set.unsolvable += 1
					continue
				counter += 1
				var tier := estimate_tier(colored.screw_count(), colored.color_count(), colored.layer_count())
				var played := _with_pars(colored, tier, solve.fewest_tray_uses, slack, 1000 + counter)
				if played == null:
					continue
				var entry := BotEntry.new()
				entry.level = played
				entry.solve = solve
				entry.source = "coloring"
				entry.tier = tier
				entry.tier_given = false
				entry.group = group_of_tier(tier)
				entry.number = 0
				entry.blueprint = id
				entry.label = "%s#%d" % [id, v]
				entry.seed_base = seed_value * 31 + bi * 101 + v + 1
				set.entries.append(entry)
				break
	return set


## A random valid coloring of a blueprint: colors from the size's tier range, a shuffled
## queue with no color twice in a row (G6), and the screws' colors dealt at random. Null if no
## queue can be made.
static func random_coloring(blueprint: LevelData, rng: RandomNumberGenerator) -> LevelData:
	var n := blueprint.screw_count()
	if n % 3 != 0:
		return null
	@warning_ignore("integer_division")
	var boxes := n / 3
	var fits := _tiers_for_size(n)
	var low := 2
	var high := 8
	if not fits.is_empty():
		var pick := fits[rng.randi_range(0, fits.size() - 1)]
		low = pick.colors.x
		high = pick.colors.y
	high = mini(high, mini(8, boxes))
	low = clampi(low, 1, high)
	var color_count := rng.randi_range(low, high)
	for _try: int in 20:
		var per := PackedInt32Array()
		per.resize(color_count)
		per.fill(1)
		for _i: int in boxes - color_count:
			per[rng.randi_range(0, color_count - 1)] += 1
		var queue: Array[int] = []
		for c: int in color_count:
			for _j: int in per[c]:
				queue.append(c)
		if not _shuffle_without_runs(queue, rng):
			continue
		var screw_colors: Array[int] = []
		for c: int in queue:
			for _k: int in Tuning.box_slots:
				screw_colors.append(c)
		_shuffle(screw_colors, rng)
		var errors := PackedStringArray()
		return blueprint.with_colors(PackedInt32Array(screw_colors), PackedInt32Array(queue), errors)
	return null


static func _shuffle(list: Array[int], rng: RandomNumberGenerator) -> void:
	for i: int in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := list[i]
		list[i] = list[j]
		list[j] = t


static func _shuffle_without_runs(list: Array[int], rng: RandomNumberGenerator) -> bool:
	for _try: int in 60:
		_shuffle(list, rng)
		var ok := true
		for i: int in range(1, list.size()):
			if list[i] == list[i - 1]:
				ok = false
				break
		if ok:
			return true
	return false


## G5: some free screw fits an open box at the start.
static func _has_first_move(level: LevelData) -> bool:
	var state := PlayState.start(level)
	if state == null:
		return false
	for s: int in level.screw_count():
		if state.is_free(s) and state.destination(s).x == PlayState.BOX:
			return true
	return false


## The level with its par numbers filled in, so Stars.award has something to compare with
## (LevelData.with_colors takes them in its `play` argument and shares the geometry).
static func _with_pars(colored: LevelData, tier: int, fewest: int, slack: int, number: int) -> LevelData:
	var group := group_of_tier(tier)
	var play := {
		"kind": LevelData.NUMBERED,
		"number": number,
		"tier": tier,
		"group": group.to_lower(),
		"tray_par": fewest + slack,
		"par_time": Tuning.par_time_for(colored.screw_count(), group.to_lower()),
		"blueprint": colored.blueprint_id,
		"generator": 1,
	}
	var errors := PackedStringArray()
	var level := colored.with_colors(colored.screw_colors, colored.queue, errors, play)
	if level == null:
		push_error("coloring of %s: %s" % [colored.id, "; ".join(errors)])
	return level


## Solves a level and makes its entry, or null (counted in the set) if the search does not
## finish or finds no solution.
static func _entry(level: LevelData, source: String, max_states: int, set: BotLevelSet) -> BotEntry:
	set.tried += 1
	var solve := Solver.solve(level, max_states)
	if not solve.complete:
		set.incomplete += 1
		return null
	if not solve.solved:
		set.unsolvable += 1
		return null
	var entry := BotEntry.new()
	entry.level = level
	entry.solve = solve
	entry.source = source
	entry.blueprint = level.blueprint_id
	entry.seed_base = level.number * 17 + level.screw_count()
	return entry
