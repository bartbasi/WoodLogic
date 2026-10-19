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
## geometry (both read-only). The caller fills in the other play fields before handing it on.
## Returns null and adds to errors if the colors break R3.
func with_colors(colors: PackedInt32Array, box_queue: PackedInt32Array, errors: PackedStringArray) -> LevelData:
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
	if not _colors_fit(level, errors):
		return null
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
		allowed.append_array(["queue", "tray_par", "par_time", "line", "hint"])
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
	if not (id_value is String and _is_id(id_value)):
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
	level.tray_par = PlankData.read_int(d, "tray_par", 0, 100, "level", errors)
	level.par_time_s = PlankData.read_int(d, "par_time", 1, 3600, "level", errors)
	var line_value: Variant = d.get("line", "")
	if line_value is String:
		level.line = line_value
	else:
		errors.append("line must be text")
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


static func _is_id(text: String) -> bool:
	if text.is_empty():
		return false
	for ch: String in text:
		if not ((ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "-"):
			return false
	return true
