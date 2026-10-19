# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Tuning
extends RefCounted
## The designer's numbers from data/tuning.json (docs/ARCHITECTURE.md 3.3, GDD 9.4). Until a
## file is loaded these hold the GDD's values. LevelCatalog.load_all() loads the file once at
## startup, on the main thread, before any worker thread starts; after that everyone, worker
## threads included, only reads them. A file that fails any check changes nothing.
##
## The numbers the generator reads count toward Generator.GENERATOR_VERSION.

const PATH := "res://data/tuning.json"
const GROUPS: Array[String] = ["easy", "medium", "hard", "expert"]
const BANDS: Array[String] = ["easy", "medium", "hard"]
const HELPERS: Array[String] = ["undo", "extra_slot", "screwdriver"]
## Novice policy results a tier asks for (GDD 6.4, G4).
const NOVICE_WIN := 0
const NOVICE_EITHER := 1
const NOVICE_LOSE := 2
const NOVICE_NAMES: Array[String] = ["win", "either", "lose"]


## One row of GDD 6.1. Ranges are inclusive.
class TierSpec extends RefCounted:
	var tier: int
	var group: String
	var screws := Vector2i()
	var colors := Vector2i()
	var layers := Vector2i()
	var tray_uses := Vector2i()
	var novice: int
	var covered_pct := Vector2i()


## Tray slots at the start of an attempt (R1).
static var tray_size: int = 5
## Open box positions (R2, R4).
static var open_boxes: int = 2
## Screws per box (R3, R18).
static var box_slots: int = 3
## Queue boxes shown after the open ones (R4).
static var preview: int = 2
static var tutorial_levels: int = 8
## Tier rows, index tier - 1.
static var tiers: Array[TierSpec] = _default_tiers()
## Sawtooth steps for levels N with (N - 1) mod 5 = 0 .. 4, and [first level, base] pairs.
static var sawtooth_steps := PackedInt32Array([-2, -1, 0, 1, 2])
static var sawtooth_bases: Array[Vector2i] = [Vector2i(9, 2), Vector2i(21, 3), Vector2i(36, 4), Vector2i(56, 5), Vector2i(81, 6), Vector2i(111, 7), Vector2i(151, 8)]
## [first level, slack] pairs for tray par (S7).
static var tray_par_slack: Array[Vector2i] = [Vector2i(9, 2), Vector2i(31, 1), Vector2i(101, 0)]
## Par time (S8): base seconds, tenths of a second per screw by group, and the rounding step.
static var par_base_s: int = 10
static var par_tenths: Dictionary = {"easy": 30, "medium": 35, "hard": 40, "expert": 45}
static var par_round_s: int = 5
static var daily_tier: int = 6
static var daily_slack: int = 1
static var daily_group: String = "medium"
## Tier range per Relaxed band.
static var relaxed: Dictionary = {"easy": Vector2i(1, 3), "medium": Vector2i(4, 6), "hard": Vector2i(7, 8)}
## For the app flow: {"undo": {"price", "first_level", "free"}, ...}.
static var helpers: Dictionary = {
	"undo": {"price": 4, "first_level": 8, "free": 2},
	"extra_slot": {"price": 6, "first_level": 15, "free": 2},
	"screwdriver": {"price": 8, "first_level": 25, "free": 2},
}
## For the app flow: [{"what", "id", "level" or "best_streak"}, ...] in file order.
static var unlocks: Array[Dictionary] = []
static var modes_open_after_level: int = 8
static var recent_blueprints_excluded: int = 5


## Loads data/tuning.json. Logs and returns false on bad data (and changes nothing).
static func load_file(path: String = PATH) -> bool:
	var errors := PackedStringArray()
	var ok := load_text(FileAccess.get_file_as_string(path), errors)
	if not ok:
		push_error("bad tuning data in %s: %s" % [path, "; ".join(errors)])
	return ok


## Checks a tuning file and, only if every check passes, makes its numbers current. Quiet:
## problems go in errors.
static func load_text(text: String, errors: PackedStringArray) -> bool:
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("not valid JSON: %s (line %d)" % [json.get_error_message(), json.get_error_line()])
		return false
	if not json.data is Dictionary:
		errors.append("the file is not a JSON object")
		return false
	var d: Dictionary = json.data
	var before := errors.size()
	var keys: Array[String] = ["format", "tray_size", "open_boxes", "box_slots", "preview", "tutorial_levels", "tiers", "sawtooth", "tray_par_slack", "par_time", "daily", "relaxed", "helpers", "unlocks", "modes_open_after_level", "recent_blueprints_excluded"]
	_exact_keys(d, keys, "tuning", errors)
	if _int(d, "format", 1, 1, "tuning", errors) != 1:
		return false
	var new_tray := _int(d, "tray_size", 1, 7, "tuning", errors)
	var new_open := _int(d, "open_boxes", 1, 3, "tuning", errors)
	var new_slots := _int(d, "box_slots", 2, 4, "tuning", errors)
	var new_preview := _int(d, "preview", 0, 4, "tuning", errors)
	var new_tutorials := _int(d, "tutorial_levels", 0, 20, "tuning", errors)
	# Tiers.
	var new_tiers: Array[TierSpec] = []
	var tier_list: Variant = d.get("tiers")
	if not (tier_list is Array and (tier_list as Array).size() == 10):
		errors.append("tiers must list the ten tiers")
	else:
		for i: int in 10:
			var row: Variant = (tier_list as Array)[i]
			if not row is Dictionary:
				errors.append("tier %d is not an object" % (i + 1))
				continue
			var where := "tier %d" % (i + 1)
			_exact_keys(row, ["tier", "group", "screws", "colors", "layers", "tray_uses", "novice", "covered_pct"], where, errors)
			var t := TierSpec.new()
			t.tier = _int(row, "tier", i + 1, i + 1, where, errors)
			t.group = _choice(row, "group", GROUPS, where, errors)
			t.screws = _range(row, "screws", 3, 60, where, errors)
			t.colors = _range(row, "colors", 1, LevelData.MAX_COLORS, where, errors)
			t.layers = _range(row, "layers", 1, 5, where, errors)
			t.tray_uses = _range(row, "tray_uses", 0, 20, where, errors)
			t.novice = NOVICE_NAMES.find(_choice(row, "novice", NOVICE_NAMES, where, errors))
			t.covered_pct = _range(row, "covered_pct", 0, 100, where, errors)
			var fits := false
			for m: int in range(t.screws.x, t.screws.y + 1):
				fits = fits or m % maxi(new_slots, 1) == 0
			if not fits:
				errors.append("%s: no screw count in range is a multiple of %d" % [where, new_slots])
			if new_slots > 0 and t.colors.x * new_slots > t.screws.y:
				errors.append("%s: %d colors need more than %d screws" % [where, t.colors.x, t.screws.y])
			new_tiers.append(t)
	# Sawtooth.
	var new_steps := PackedInt32Array()
	var new_bases: Array[Vector2i] = []
	var saw: Variant = d.get("sawtooth")
	if not saw is Dictionary:
		errors.append("sawtooth must be an object")
	else:
		_exact_keys(saw, ["steps", "bases"], "sawtooth", errors)
		var steps: Variant = (saw as Dictionary).get("steps")
		if not (steps is Array and (steps as Array).size() == 5):
			errors.append("sawtooth.steps must list five steps")
		else:
			for v: Variant in steps:
				new_steps.append(_whole(v, -9, 9, "sawtooth.steps", errors))
		new_bases = _pairs((saw as Dictionary).get("bases"), "sawtooth.bases", 1, 10, new_tutorials + 1, errors)
	var new_slack := _pairs(d.get("tray_par_slack"), "tray_par_slack", 0, 20, new_tutorials + 1, errors)
	# Par time.
	var new_base_s := 0
	var new_round := 1
	var new_tenths := {}
	var par: Variant = d.get("par_time")
	if not par is Dictionary:
		errors.append("par_time must be an object")
	else:
		_exact_keys(par, ["base_s", "per_screw_s", "round_to_s"], "par_time", errors)
		new_base_s = _int(par, "base_s", 0, 600, "par_time", errors)
		new_round = _int(par, "round_to_s", 1, 60, "par_time", errors)
		var per: Variant = (par as Dictionary).get("per_screw_s")
		if not per is Dictionary:
			errors.append("par_time.per_screw_s must be an object")
		else:
			_exact_keys(per, GROUPS, "par_time.per_screw_s", errors)
			for g: String in GROUPS:
				var v: Variant = (per as Dictionary).get(g)
				var tenths := roundf(float(v) * 10.0) if (v is float or v is int) else -1.0
				if tenths < 1.0 or tenths > 600.0 or absf(tenths - float(v) * 10.0) > 1e-6:
					errors.append("par_time.per_screw_s.%s must be seconds in tenths, from 0.1 to 60" % g)
				new_tenths[g] = int(tenths)
	# Daily and Relaxed.
	var new_daily_tier := 0
	var new_daily_slack := 0
	var new_daily_group := ""
	var daily: Variant = d.get("daily")
	if not daily is Dictionary:
		errors.append("daily must be an object")
	else:
		_exact_keys(daily, ["tier", "tray_par_slack", "group"], "daily", errors)
		new_daily_tier = _int(daily, "tier", 1, 10, "daily", errors)
		new_daily_slack = _int(daily, "tray_par_slack", 0, 20, "daily", errors)
		new_daily_group = _choice(daily, "group", GROUPS, "daily", errors)
	var new_relaxed := {}
	var rel: Variant = d.get("relaxed")
	if not rel is Dictionary:
		errors.append("relaxed must be an object")
	else:
		_exact_keys(rel, BANDS, "relaxed", errors)
		for b: String in BANDS:
			new_relaxed[b] = _range(rel, b, 1, 10, "relaxed", errors)
	# Helpers and unlocks, for the app flow.
	var new_helpers := {}
	var hel: Variant = d.get("helpers")
	if not hel is Dictionary:
		errors.append("helpers must be an object")
	else:
		_exact_keys(hel, HELPERS, "helpers", errors)
		for h: String in HELPERS:
			var row: Variant = (hel as Dictionary).get(h)
			if not row is Dictionary:
				errors.append("helpers.%s must be an object" % h)
				continue
			_exact_keys(row, ["price", "first_level", "free"], "helpers." + h, errors)
			new_helpers[h] = {
				"price": _int(row, "price", 0, 1000, "helpers." + h, errors),
				"first_level": _int(row, "first_level", 1, 100000, "helpers." + h, errors),
				"free": _int(row, "free", 0, 100, "helpers." + h, errors),
			}
	var new_unlocks: Array[Dictionary] = []
	var unl: Variant = d.get("unlocks")
	if not unl is Array:
		errors.append("unlocks must be a list")
	else:
		for i: int in (unl as Array).size():
			var row: Variant = (unl as Array)[i]
			var where := "unlocks[%d]" % i
			if not row is Dictionary:
				errors.append(where + " must be an object")
				continue
			var what := _choice(row, "what", ["wood", "metal"], where, errors)
			var id: Variant = (row as Dictionary).get("id")
			if not (id is String and LevelData.is_id(id)):
				errors.append(where + ": id must be lowercase letters, digits and hyphens")
				continue
			var entry := {"what": what, "id": id}
			if (row as Dictionary).has("level") and not (row as Dictionary).has("best_streak"):
				_exact_keys(row, ["what", "id", "level"], where, errors)
				entry["level"] = _int(row, "level", 0, 100000, where, errors)
			elif (row as Dictionary).has("best_streak") and not (row as Dictionary).has("level"):
				_exact_keys(row, ["what", "id", "best_streak"], where, errors)
				entry["best_streak"] = _int(row, "best_streak", 1, 10000, where, errors)
			else:
				errors.append(where + " needs exactly one of level and best_streak")
			new_unlocks.append(entry)
	var new_modes := _int(d, "modes_open_after_level", 0, 100000, "tuning", errors)
	var new_recent := _int(d, "recent_blueprints_excluded", 0, 10, "tuning", errors)
	if errors.size() > before:
		return false
	tray_size = new_tray
	open_boxes = new_open
	box_slots = new_slots
	preview = new_preview
	tutorial_levels = new_tutorials
	tiers = new_tiers
	sawtooth_steps = new_steps
	sawtooth_bases = new_bases
	tray_par_slack = new_slack
	par_base_s = new_base_s
	par_tenths = new_tenths
	par_round_s = new_round
	daily_tier = new_daily_tier
	daily_slack = new_daily_slack
	daily_group = new_daily_group
	relaxed = new_relaxed
	helpers = new_helpers
	unlocks = new_unlocks
	modes_open_after_level = new_modes
	recent_blueprints_excluded = new_recent
	return true


## The tier row (1 to 10).
static func tier(t: int) -> TierSpec:
	return tiers[clampi(t, 1, tiers.size()) - 1]


## GDD 6.3: tier(N) = clamp(base(N) + steps[(N - 1) mod 5], 1, 10), for numbered levels after
## the tutorial.
static func tier_for_level(n: int) -> int:
	return clampi(_step_value(sawtooth_bases, n) + sawtooth_steps[(n - 1) % sawtooth_steps.size()], 1, tiers.size())


## S7's slack for numbered level n.
static func slack_for_level(n: int) -> int:
	return _step_value(tray_par_slack, n)


## S8's par time for a level of this many screws in this group.
static func par_time_for(screws: int, group: String) -> int:
	return Stars.par_time(screws, int(par_tenths.get(group, 35)), par_base_s, par_round_s)


## The value of the last [first level, value] pair whose first level is at most n (the first
## pair's value before it).
static func _step_value(pairs: Array[Vector2i], n: int) -> int:
	var value := pairs[0].y
	for p: Vector2i in pairs:
		if p.x <= n:
			value = p.y
	return value


static func _default_tiers() -> Array[TierSpec]:
	var rows := [
		[1, "easy", 9, 12, 2, 3, 1, 2, 0, 0, NOVICE_WIN, 0, 20],
		[2, "easy", 12, 15, 3, 3, 2, 3, 0, 1, NOVICE_WIN, 0, 30],
		[3, "easy", 15, 18, 3, 4, 2, 4, 0, 1, NOVICE_WIN, 0, 35],
		[4, "medium", 18, 21, 4, 4, 3, 4, 1, 2, NOVICE_EITHER, 0, 35],
		[5, "medium", 21, 24, 4, 5, 3, 5, 1, 2, NOVICE_EITHER, 0, 50],
		[6, "medium", 24, 27, 5, 5, 3, 5, 1, 3, NOVICE_EITHER, 5, 50],
		[7, "hard", 27, 30, 5, 6, 4, 5, 2, 3, NOVICE_LOSE, 14, 50],
		[8, "hard", 30, 33, 6, 7, 4, 5, 2, 4, NOVICE_LOSE, 25, 50],
		[9, "expert", 33, 36, 7, 7, 4, 5, 3, 4, NOVICE_LOSE, 25, 55],
		[10, "expert", 33, 36, 7, 8, 4, 5, 3, 5, NOVICE_LOSE, 25, 60],
	]
	var out: Array[TierSpec] = []
	for r: Array in rows:
		var t := TierSpec.new()
		t.tier = r[0]
		t.group = r[1]
		t.screws = Vector2i(r[2], r[3])
		t.colors = Vector2i(r[4], r[5])
		t.layers = Vector2i(r[6], r[7])
		t.tray_uses = Vector2i(r[8], r[9])
		t.novice = r[10]
		t.covered_pct = Vector2i(r[11], r[12])
		out.append(t)
	return out


static func _exact_keys(d: Dictionary, keys: Array, where: String, errors: PackedStringArray) -> void:
	for k: Variant in d.keys():
		if not (k is String and keys.has(k)):
			errors.append("%s: unknown field %s" % [where, str(k)])
	for k: Variant in keys:
		if not d.has(k):
			errors.append("%s: missing %s" % [where, str(k)])


static func _whole(v: Variant, low: int, high: int, where: String, errors: PackedStringArray) -> int:
	if (v is float or v is int) and float(v) == floorf(float(v)) and float(v) >= low and float(v) <= high:
		return int(v)
	errors.append("%s must be whole numbers from %d to %d" % [where, low, high])
	return low


static func _int(d: Dictionary, key: String, low: int, high: int, where: String, errors: PackedStringArray) -> int:
	return _whole(d.get(key), low, high, "%s.%s" % [where, key], errors)


static func _choice(d: Dictionary, key: String, options: Array, where: String, errors: PackedStringArray) -> String:
	var v: Variant = d.get(key)
	if v is String and options.has(v):
		return v
	errors.append("%s.%s must be one of %s" % [where, key, ", ".join(PackedStringArray(options))])
	return str(options[0])


## An inclusive [low, high] range with low at most high.
static func _range(d: Dictionary, key: String, low: int, high: int, where: String, errors: PackedStringArray) -> Vector2i:
	var v: Variant = d.get(key)
	if not (v is Array and (v as Array).size() == 2):
		errors.append("%s.%s must be [low, high]" % [where, key])
		return Vector2i(low, low)
	var a := _whole((v as Array)[0], low, high, "%s.%s" % [where, key], errors)
	var b := _whole((v as Array)[1], low, high, "%s.%s" % [where, key], errors)
	if a > b:
		errors.append("%s.%s: low is above high" % [where, key])
	return Vector2i(a, b)


## [first level, value] pairs: at least one, first levels rising, the first one at first_level.
static func _pairs(v: Variant, where: String, low: int, high: int, first_level: int, errors: PackedStringArray) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not (v is Array and not (v as Array).is_empty()):
		errors.append(where + " must be a list of [first level, value] pairs")
		return out
	for item: Variant in v:
		if not (item is Array and (item as Array).size() == 2):
			errors.append(where + " must be a list of [first level, value] pairs")
			return out
		var lv := _whole((item as Array)[0], 1, 100000, where, errors)
		var val := _whole((item as Array)[1], low, high, where, errors)
		if not out.is_empty() and lv <= out[-1].x:
			errors.append(where + ": first levels must rise")
		out.append(Vector2i(lv, val))
	if out[0].x != first_level:
		errors.append("%s: the first pair must start at level %d, after the tutorial" % [where, first_level])
	return out
