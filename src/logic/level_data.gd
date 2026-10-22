# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelData
extends RefCounted
## One level (GDD R1, docs/ARCHITECTURE.md 4.1). Read-only once built: GDScript can't enforce
## it, so nothing outside the code that builds a level ever writes to its fields or arrays.
## That makes it safe to hand from a worker thread to the main thread.
##
## from_json reads three kinds of file: a bare blueprint (GDD 9.1, kind "silhouette" or
## "pattern", no colors), a tutorial level (GDD 9.3), and a stored level such as a fallback
## level (the tutorial format with kind "numbered", "daily" or "relaxed" and a few more
## fields, which is what to_dict writes).

const TUTORIAL := 0
const NUMBERED := 1
const DAILY := 2
const RELAXED := 3
## A bare blueprint: planks only, no colors or queue. Not playable until colored.
const BLUEPRINT := 4
const KIND_NAMES: Array[String] = ["tutorial", "numbered", "daily", "relaxed"]
const BLUEPRINT_KINDS: Array[String] = ["silhouette", "pattern"]
## Palette indices a level may use (GDD 9.3: 0 to 7).
const MAX_COLORS := 8
## The most tray slots a level may have.
const MAX_TRAY := 7
## Limits on a level file, so a broken or edited file can't cost much to read or show: planks
## (the blueprint rule B2 allows 16), characters in the line, entries in the hint.
const MAX_PLANKS := 32
const MAX_LINE := 200
const MAX_HINT := 200
const BOARD_W := 86
const BOARD_H := 90

var id: String = ""
var name: String = ""
## For a blueprint: "silhouette" or "pattern".
var blueprint_kind: String = ""
var planks: Array[PlankData] = []
## Palette index per screw (empty for a bare blueprint).
var screw_colors := PackedInt32Array()
## One color per box, in order.
var queue := PackedInt32Array()
## The tray's slots (R1): the level's own (GDD 6.8, from its tier), 5 for the tutorial.
var tray_size: int = 5
## Tray par with the slack already added (GDD S7).
var tray_par: int = 0
var par_time_s: int = 0
var line: String = ""
## Screw ids the tutorial hand points at, in order.
var hint := PackedInt32Array()
var kind: int = BLUEPRINT
## The level number, the date as yyyymmdd, or the relaxed stream index.
var number: int = 0
## Relaxed only: "easy", "medium" or "hard".
var band: String = ""
var tier: int = 0
var group: String = ""
var blueprint_id: String = ""
var generator_version: int = 0
## The shapes' poses and covering, worked out once (it does not depend on colors).
var geometry: BoardGeometry


func screw_count() -> int:
	return geometry.screw_count


func has_colors() -> bool:
	return screw_colors.size() == geometry.screw_count and not queue.is_empty()


## The center of a screw in gu (screws never move: a hanging plank turns about its last one).
func screw_center(screw: int) -> Vector2:
	return Vector2(geometry.screw_x[screw], geometry.screw_y[screw])


func screw_plank(screw: int) -> int:
	return geometry.screw_plank[screw]


## How many layers have planks.
func layer_count() -> int:
	var used := PackedInt32Array([0, 0, 0, 0, 0])
	for p: PlankData in planks:
		used[p.layer] = 1
	return used.count(1)


## How many different colors the screws use.
func color_count() -> int:
	var seen := PackedInt32Array()
	for c: int in screw_colors:
		if not seen.has(c):
			seen.append(c)
	return seen.size()


## A playable copy of this board with these colors and this queue. It shares the planks and
## geometry (both read-only), so nothing is rebuilt. `play` may set the play fields in one go:
## "kind" (an int such as NUMBERED), "number", "band", "tier", "group", "tray_par",
## "par_time" (seconds), "line", "hint" (screw ids), "generator", "blueprint", "id", "name",
## "tray" (slots).
## Fields it leaves out keep this level's values (play fields are 0 or empty on a blueprint).
## Returns null and adds to errors if the colors break R3 or a play field is wrong.
func with_colors(colors: PackedInt32Array, box_queue: PackedInt32Array, errors: PackedStringArray, play: Dictionary = {}) -> LevelData:
	var level := LevelData.new()
	level.id = id
	level.name = name
	level.blueprint_kind = blueprint_kind
	level.planks = planks
	level.geometry = geometry
	level.screw_colors = colors
	level.queue = box_queue
	level.tray_size = tray_size
	level.kind = NUMBERED if kind == BLUEPRINT else kind
	level.blueprint_id = blueprint_id
	level.number = number
	level.band = band
	level.tier = tier
	level.group = group
	level.tray_par = tray_par
	level.par_time_s = par_time_s
	level.line = line
	level.hint = hint
	level.generator_version = generator_version
	var before := errors.size()
	var keys: Array[String] = ["kind", "number", "band", "tier", "group", "tray_par", "par_time", "line", "hint", "generator", "blueprint", "id", "name", "tray"]
	for k: Variant in play.keys():
		if not (k is String and keys.has(k)):
			errors.append("with_colors: unknown play field %s" % str(k))
	if play.has("kind"):
		level.kind = _whole(play["kind"], TUTORIAL, RELAXED, -1)
		if level.kind < 0:
			errors.append("with_colors: kind must be TUTORIAL, NUMBERED, DAILY or RELAXED")
	level.number = _whole(play.get("number", level.number), 0, 99999999, -1)
	level.tier = _whole(play.get("tier", level.tier), 0, 10, -1)
	level.tray_par = _whole(play.get("tray_par", level.tray_par), 0, 100, -1)
	level.par_time_s = _whole(play.get("par_time", level.par_time_s), 0, 3600, -1)
	level.generator_version = _whole(play.get("generator", level.generator_version), 0, 1000000, -1)
	level.tray_size = _whole(play.get("tray", level.tray_size), 1, MAX_TRAY, -1)
	if level.number < 0 or level.tier < 0 or level.tray_par < 0 or level.par_time_s < 0 or level.generator_version < 0 or level.tray_size < 0:
		errors.append("with_colors: number, tier, tray_par, par_time, generator and tray must be whole numbers in range")
	for k: String in ["band", "group", "line", "blueprint", "id", "name"]:
		if play.has(k) and not play[k] is String:
			errors.append("with_colors: %s must be text" % k)
	level.band = str(play.get("band", level.band))
	level.group = str(play.get("group", level.group))
	level.line = str(play.get("line", level.line))
	level.blueprint_id = str(play.get("blueprint", level.blueprint_id))
	level.id = str(play.get("id", level.id))
	level.name = str(play.get("name", level.name))
	if play.has("hint"):
		var h: Variant = play["hint"]
		if h is PackedInt32Array:
			level.hint = h
		else:
			errors.append("with_colors: hint must be a PackedInt32Array of screw ids")
	if errors.size() > before or not _colors_fit(level, errors):
		return null
	return level


## A bare board from planks (built ones, in screw id order): gives the screws their ids and
## works out the geometry. For the generator's variations; tray is the board's tray (0: the
## tuning's tray_size).
static func from_planks(board_id: String, board_name: String, kind_text: String, list: Array[PlankData], tray: int = 0) -> LevelData:
	var level := LevelData.new()
	level.id = board_id
	level.name = board_name
	level.blueprint_kind = kind_text
	level.blueprint_id = board_id
	level.kind = BLUEPRINT
	level.tray_size = tray if tray > 0 else Tuning.tray_size
	var next := 0
	for p: PlankData in list:
		var ids := PackedInt32Array()
		for h: int in p.hole_count():
			ids.append(next)
			next += 1
		p.screws = ids
		level.planks.append(p)
	level.geometry = BoardGeometry.build(level.planks)
	return level


## Reads a level file. Returns null and logs an error on bad data.
static func from_json(text: String) -> LevelData:
	var errors := PackedStringArray()
	var level := parse(text, errors)
	if level == null:
		push_error("bad level data: " + "; ".join(errors))
	return level


## Reads a level file without logging: returns null and adds to errors on bad data.
static func parse(text: String, errors: PackedStringArray) -> LevelData:
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("not valid JSON: %s (line %d)" % [json.get_error_message(), json.get_error_line()])
		return null
	if not json.data is Dictionary:
		errors.append("the file is not a JSON object")
		return null
	return from_dict(json.data, errors)


static func from_dict(d: Dictionary, errors: PackedStringArray) -> LevelData:
	var errors_before := errors.size()
	var level := LevelData.new()
	var kind_name: Variant = d.get("kind")
	if kind_name is String and BLUEPRINT_KINDS.has(kind_name):
		level.kind = BLUEPRINT
		level.blueprint_kind = kind_name
	elif kind_name is String and KIND_NAMES.has(kind_name):
		level.kind = KIND_NAMES.find(kind_name)
	else:
		errors.append("kind must be silhouette, pattern, tutorial, numbered, daily or relaxed")
		return null
	var allowed: Array[String] = ["format", "id", "name", "kind", "board", "planks"]
	if level.kind != BLUEPRINT:
		allowed.append_array(["queue", "tray_par", "par_time", "line", "hint", "tray"])
	if level.kind == NUMBERED or level.kind == DAILY or level.kind == RELAXED:
		allowed.append_array(["number", "tier", "group", "blueprint", "generator", "band"])
	for key: Variant in d.keys():
		if not (key is String and allowed.has(key)):
			errors.append("unknown field %s for kind %s" % [str(key), str(kind_name)])
	# B1.
	if not ((d.get("format") is float or d.get("format") is int) and float(d.get("format")) == 1.0):
		errors.append("B1: format must be 1")
	var board: Variant = d.get("board")
	if not (board is Array and (board as Array).size() == 2 and _whole((board as Array)[0], BOARD_W, BOARD_W, -1) == BOARD_W and _whole((board as Array)[1], BOARD_H, BOARD_H, -1) == BOARD_H):
		errors.append("B1: board must be [86, 90]")
	var id_value: Variant = d.get("id")
	if not (id_value is String and is_id(id_value)):
		errors.append("id must be lowercase letters, digits and hyphens")
	else:
		level.id = id_value
	var name_value: Variant = d.get("name", "")
	if name_value is String:
		level.name = name_value
	else:
		errors.append("name must be text")
	level.blueprint_id = level.id
	level.tray_size = Tuning.tray_size
	var list: Variant = d.get("planks")
	if not list is Array or (list as Array).is_empty():
		errors.append("planks must be a list with at least one plank")
		return null
	if (list as Array).size() > MAX_PLANKS:
		errors.append("a level has at most %d planks" % MAX_PLANKS)
		return null
	var colors := PackedInt32Array()
	var with_colors := level.kind != BLUEPRINT
	for i: int in (list as Array).size():
		var item: Variant = (list as Array)[i]
		if not item is Dictionary:
			errors.append("plank %d is not an object" % i)
			return null
		var plank := PlankData.from_dict(item, i, errors)
		if plank == null:
			return null
		var first := colors.size()
		var ids := PackedInt32Array()
		for h: int in plank.hole_count():
			ids.append(first + h)
		plank.screws = ids
		var item_colors: Variant = (item as Dictionary).get("colors")
		if not with_colors:
			if item_colors != null:
				errors.append("plank %d: a blueprint has no colors" % i)
			for h: int in plank.hole_count():
				colors.append(-1)
		elif not item_colors is Array or (item_colors as Array).size() != plank.hole_count():
			errors.append("plank %d: colors must list one color per hole" % i)
		else:
			for c: Variant in item_colors:
				colors.append(_whole(c, 0, MAX_COLORS - 1, -1))
				if colors[-1] < 0:
					errors.append("plank %d: colors must be whole numbers from 0 to %d" % [i, MAX_COLORS - 1])
		level.planks.append(plank)
	if colors.size() > BoardGeometry.MAX_SCREWS:
		errors.append("a level has at most %d screws" % BoardGeometry.MAX_SCREWS)
	if errors.size() > errors_before:
		return null
	level.geometry = BoardGeometry.build(level.planks)
	if not with_colors:
		return level
	level.screw_colors = colors
	level.queue = _read_colors(d.get("queue"), "queue", errors)
	# A level written before the tray was its own (generator 5 and older) has the tuning's.
	if d.has("tray"):
		level.tray_size = PlankData.read_int(d, "tray", 1, MAX_TRAY, "level", errors)
	level.tray_par = PlankData.read_int(d, "tray_par", 0, 100, "level", errors)
	level.par_time_s = PlankData.read_int(d, "par_time", 1, 3600, "level", errors)
	var line_value: Variant = d.get("line", "")
	if line_value is String and (line_value as String).length() <= MAX_LINE:
		level.line = line_value
	else:
		errors.append("line must be text of at most %d characters" % MAX_LINE)
	level.hint = _read_hint(d.get("hint", []), level, errors)
	if level.kind == TUTORIAL:
		var n_text := level.id.trim_prefix("tutorial-")
		level.number = n_text.to_int() if level.id.begins_with("tutorial-") and n_text.is_valid_int() else 0
		if level.number < 1:
			errors.append("a tutorial level's id is tutorial-<n> with n from 1")
	else:
		level.number = PlankData.read_int(d, "number", 0, 99999999, "level", errors)
		level.tier = PlankData.read_int(d, "tier", 1, 10, "level", errors)
		level.generator_version = PlankData.read_int(d, "generator", 1, 1000000, "level", errors)
		var group_value: Variant = d.get("group")
		var blueprint_value: Variant = d.get("blueprint")
		var band_value: Variant = d.get("band", "")
		if group_value is String and blueprint_value is String and band_value is String:
			level.group = group_value
			level.blueprint_id = blueprint_value
			level.band = band_value
		else:
			errors.append("group, blueprint and band must be text")
	_colors_fit(level, errors)
	if errors.size() > errors_before:
		return null
	return level


## A short text that changes whenever anything that decides the level changes: blueprint,
## tier, tray par, par time, tray slots, colors, queue, and a hash of every plank's layer,
## shape, holes and the fields its shape uses (exactly what to_dict writes, so a level read
## back from its file has the same fingerprint). Only whole numbers go in (no angles or other floats, whose last
## bits can differ between phones). For the golden test, tools/levels and the saved next level.
func fingerprint() -> String:
	var h := 0x57D1
	for p: PlankData in planks:
		h = Seeds.mix(h, p.layer * 16 + p.shape)
		var lists: Array[PackedVector2Array] = [p.holes]
		var sizes := 0
		match p.shape:
			PlankData.BAR:
				lists.append(p.path)
				sizes = p.width * 10000
			PlankData.POLY:
				lists.append(p.points)
			PlankData.DISC:
				lists.append(PackedVector2Array([p.center]))
				sizes = p.radius * 100
			PlankData.RING:
				lists.append(PackedVector2Array([p.center]))
				sizes = p.radius * 100 + p.inner
		for list: PackedVector2Array in lists:
			h = Seeds.mix(h, list.size())
			for v: Vector2 in list:
				h = Seeds.mix(h, int(v.x) * 1000 + int(v.y))
		h = Seeds.mix(h, sizes)
	return "%s t%d p%d s%d T%d c%s q%s g%08x" % [blueprint_id, tier, tray_par, par_time_s, tray_size, "".join(Array(screw_colors).map(func(c: int) -> String: return str(c))), "".join(Array(queue).map(func(c: int) -> String: return str(c))), h]


## The level in the file format from_json reads.
func to_dict() -> Dictionary:
	var d := {"format": 1, "id": id, "name": name}
	d["kind"] = blueprint_kind if kind == BLUEPRINT else KIND_NAMES[kind]
	d["board"] = [BOARD_W, BOARD_H]
	var list := []
	for p: PlankData in planks:
		var pd := p.to_dict()
		if kind != BLUEPRINT:
			var cs := []
			for s: int in p.screws:
				cs.append(screw_colors[s])
			pd["colors"] = cs
		list.append(pd)
	d["planks"] = list
	if kind == BLUEPRINT:
		return d
	d["queue"] = Array(queue)
	d["tray"] = tray_size
	d["tray_par"] = tray_par
	d["par_time"] = par_time_s
	d["line"] = line
	var hint_list := []
	for s: int in hint:
		var p := screw_plank(s)
		hint_list.append([p, s - geometry.plank_first[p]])
	d["hint"] = hint_list
	if kind != TUTORIAL:
		d["number"] = number
		d["tier"] = tier
		d["group"] = group
		d["blueprint"] = blueprint_id
		d["generator"] = generator_version
		d["band"] = band
	return d


## R3: each color's screw count is box_slots times its boxes in the queue.
static func _colors_fit(level: LevelData, errors: PackedStringArray) -> bool:
	var ok := true
	if level.screw_colors.size() != level.geometry.screw_count:
		errors.append("there must be one color per screw")
		return false
	if level.queue.is_empty():
		errors.append("the queue must have at least one box")
		ok = false
	for c: int in MAX_COLORS:
		var screws := level.screw_colors.count(c)
		var boxes := level.queue.count(c)
		if screws != boxes * Tuning.box_slots:
			errors.append("R3: color %d has %d screws and %d boxes (needs %d screws per box)" % [c, screws, boxes, Tuning.box_slots])
			ok = false
	for c: int in level.screw_colors:
		if c < 0 or c >= MAX_COLORS:
			errors.append("screw colors must be from 0 to %d" % (MAX_COLORS - 1))
			return false
	for c: int in level.queue:
		if c < 0 or c >= MAX_COLORS:
			errors.append("queue colors must be from 0 to %d" % (MAX_COLORS - 1))
			return false
	return ok


static func _read_colors(v: Variant, what: String, errors: PackedStringArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not v is Array:
		errors.append("%s must be a list of colors" % what)
		return out
	if (v as Array).size() > BoardGeometry.MAX_SCREWS:
		errors.append("%s has at most %d colors" % [what, BoardGeometry.MAX_SCREWS])
		return out
	for c: Variant in v:
		var n := _whole(c, 0, MAX_COLORS - 1, -1)
		if n < 0:
			errors.append("%s colors must be whole numbers from 0 to %d" % [what, MAX_COLORS - 1])
			return PackedInt32Array()
		out.append(n)
	return out


static func _read_hint(v: Variant, level: LevelData, errors: PackedStringArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not v is Array:
		errors.append("hint must be a list of [plank, hole]")
		return out
	if (v as Array).size() > MAX_HINT:
		errors.append("a hint has at most %d entries" % MAX_HINT)
		return out
	for item: Variant in v:
		if not item is Array or (item as Array).size() != 2:
			errors.append("hint must be a list of [plank, hole]")
			return PackedInt32Array()
		var p := _whole((item as Array)[0], 0, level.planks.size() - 1, -1)
		var h := -1
		if p >= 0:
			h = _whole((item as Array)[1], 0, level.planks[p].hole_count() - 1, -1)
		if h < 0:
			errors.append("hint names a hole that does not exist")
			return PackedInt32Array()
		out.append(level.geometry.plank_first[p] + h)
	return out


static func _whole(v: Variant, low: int, high: int, fallback: int) -> int:
	if (v is float or v is int) and float(v) == floorf(float(v)) and float(v) >= low and float(v) <= high:
		return int(v)
	return fallback


## True for lowercase letters, digits and hyphens (ids and file names).
static func is_id(text: String) -> bool:
	if text.is_empty():
		return false
	for ch: String in text:
		if not ((ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "-"):
			return false
	return true
