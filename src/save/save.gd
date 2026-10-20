# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends Node
## The Save autoload (docs/ARCHITECTURE.md 3.4, 8 and 10.3): progress and settings on the
## phone, as JSON in `dir`. Files are written safely (a temporary file, then a rename) and
## read with a type and range check on every field. A missing file means defaults. A file
## that is not valid, or has a field of the wrong type or range, is kept once as `<name>.bad`
## and the bad parts fall back to defaults. Nothing from a file is ever decoded as an object:
## only JSON.parse is used, so a hostile file can at worst reset itself.
##
## Nothing is read before the app flow calls load_all(), and nothing is written before that
## either, so an early call can never overwrite the player's real files with defaults.

## Something worth keeping changed: a setting.
signal settings_changed
## Something worth keeping changed: the progress (a level result, a reset, a new level).
signal progress_changed

const FORMAT := 1
const PROGRESS_FILE := "progress.json"
const SETTINGS_FILE := "settings.json"
const NEXT_LEVEL_FILE := "next_level.json"

## Largest file read at all. A real progress file is far smaller.
const MAX_FILE_BYTES := 4_000_000
const MAX_LEVEL_FILE_BYTES := 1_000_000
const MAX_LEVEL := 1_000_000
const MAX_COUNT := 1_000_000_000
const MAX_TOTAL_MS := 1_000_000_000_000_000
## A day of play time is more than any level takes.
const MAX_MS := 86_400_000
const MAX_GEN := 1_000_000
const MAX_LEVEL_RECORDS := 100_000
const MAX_DAYS := 4_000
const MAX_HELPERS := 9_999

const GROUPS: Array[String] = ["easy", "medium", "hard", "expert"]
const BANDS: Array[String] = ["easy", "medium", "hard"]
const HELPERS: Array[String] = ["undo", "extra_slot", "screwdriver"]
const DEFAULT_WOOD := "oak"
const DEFAULT_METAL := "steel"

## Where the files live. The test runner points it at user://test_<process id>/ before
## load_all(), so tests never touch the player's real saves.
var dir := "user://"

## The settings (docs/ARCHITECTURE.md 3.4). Change them with the set_ functions.
var sound := true
var music := true
var symbols := true
var wood_id := DEFAULT_WOOD
var metal_id := DEFAULT_METAL

## What the last load_all() found wrong, one line each (for tests and the log).
var problems := PackedStringArray()

var _progress: Dictionary = {}
var _loaded := false
var _found_problem := false


func _init() -> void:
	_progress = default_progress()


# loading and saving

## Reads progress.json and settings.json from dir. Only the app flow's boot calls it (and
## tests, which may call it again to start over from the files).
func load_all() -> void:
	problems = PackedStringArray()
	_progress = _load_file(PROGRESS_FILE, true)
	_apply_settings(_load_file(SETTINGS_FILE, false))
	_loaded = true
	progress_changed.emit()
	settings_changed.emit()


## Writes both files. The app flow calls it on pause and focus loss.
func save_all() -> void:
	save_progress()
	save_settings()


func save_progress() -> bool:
	if not _loaded:
		return false
	return _write_json(PROGRESS_FILE, _progress)


func save_settings() -> bool:
	if not _loaded:
		return false
	return _write_json(SETTINGS_FILE, settings_dict())


## Forgets everything, in memory and on disk (the files, their .bad copies and the saved next
## level). For tests now and Settings' "Erase everything" later.
func erase_all() -> void:
	for file_name: String in [PROGRESS_FILE, SETTINGS_FILE, NEXT_LEVEL_FILE]:
		for suffix: String in ["", ".bad", ".tmp"]:
			var path := _path(file_name + suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	_progress = default_progress()
	sound = true
	music = true
	symbols = true
	wood_id = DEFAULT_WOOD
	metal_id = DEFAULT_METAL
	_loaded = true
	progress_changed.emit()
	settings_changed.emit()


func default_progress() -> Dictionary:
	var time := {}
	for group: String in GROUPS:
		time[group] = {"n": 0, "total_ms": 0, "best_ms": 0}
	return {
		"format": FORMAT,
		"next_level": 1,
		"highest_cleared": 0,
		"star_bank": 0,
		"stars_earned": 0,
		"levels": {},
		"helpers": {"undo": 0, "extra_slot": 0, "screwdriver": 0},
		"helpers_met": [],
		"daily": {"last_date": "", "streak": 0, "best_streak": 0, "solved": 0, "days": {}},
		"relaxed": {"next": {"easy": 0, "medium": 0, "hard": 0}, "last_band": ""},
		"stats": {"cleared": 0, "three_star": 0, "helpers_used": 0, "time": time},
		"unlocked": {"wood": [DEFAULT_WOOD], "metal": [DEFAULT_METAL]},
	}


func settings_dict() -> Dictionary:
	return {"format": FORMAT, "sound": sound, "music": music, "symbols": symbols, "wood": wood_id, "metal": metal_id}


# progress

func next_level() -> int:
	return _progress["next_level"]


## The next level to play, kept by hand (tests, and screens that move the player on).
func set_next_level(n: int) -> void:
	_progress["next_level"] = clampi(n, 1, MAX_LEVEL)
	save_progress()
	progress_changed.emit()


func highest_cleared() -> int:
	return _progress["highest_cleared"]


func star_bank() -> int:
	return _progress["star_bank"]


func stars_earned() -> int:
	return _progress["stars_earned"]


## The record of a level, {"stars": 0..3, "best_ms": int, "gen": int}, or {} if never cleared.
func level_record(n: int) -> Dictionary:
	var levels: Dictionary = _progress["levels"]
	var rec: Dictionary = levels.get(str(n), {})
	return rec.duplicate()


## A deep copy of all the progress, for Stats and tests.
func progress_copy() -> Dictionary:
	return _progress.duplicate(true)


## Records a win of a numbered level (tutorial levels are numbered levels 1 to 8): the level
## record, the star bank, the next level, the highest cleared and the stats, then writes the
## file. `stars` is the LevelResult's Vector3i (cleared, fast, clean). Stars only ever add
## (GDD S5): a record keeps the best. Returns the stars gained over the old record.
func record_win(level: LevelData, elapsed_ms: int, stars: Vector3i) -> int:
	if level == null or (level.kind != LevelData.NUMBERED and level.kind != LevelData.TUTORIAL):
		return 0
	var n := level.number
	if n < 1 or n > MAX_LEVEL:
		return 0
	var total := clampi(stars.x + stars.y + stars.z, 0, 3)
	var ms := clampi(elapsed_ms, 1, MAX_MS)
	var levels: Dictionary = _progress["levels"]
	var key := str(n)
	var had := levels.has(key)
	var old: Dictionary = levels.get(key, {"stars": 0, "best_ms": 0, "gen": 0})
	var old_stars: int = old["stars"]
	var old_best: int = old["best_ms"]
	var gain := maxi(0, total - old_stars)
	levels[key] = {
		"stars": maxi(total, old_stars),
		"best_ms": ms if old_best <= 0 else mini(old_best, ms),
		"gen": clampi(level.generator_version, 0, MAX_GEN),
	}
	_progress["star_bank"] = mini(MAX_COUNT, int(_progress["star_bank"]) + gain)
	_progress["stars_earned"] = mini(MAX_COUNT, int(_progress["stars_earned"]) + gain)
	var stats: Dictionary = _progress["stats"]
	if not had:
		stats["cleared"] = mini(MAX_COUNT, int(stats["cleared"]) + 1)
	if total == 3 and old_stars < 3:
		stats["three_star"] = mini(MAX_COUNT, int(stats["three_star"]) + 1)
	if GROUPS.has(level.group):
		var time: Dictionary = stats["time"]
		var g: Dictionary = time[level.group]
		g["n"] = mini(MAX_COUNT, int(g["n"]) + 1)
		g["total_ms"] = mini(MAX_TOTAL_MS, int(g["total_ms"]) + ms)
		g["best_ms"] = ms if int(g["best_ms"]) <= 0 else mini(int(g["best_ms"]), ms)
	_progress["highest_cleared"] = maxi(int(_progress["highest_cleared"]), n)
	if n >= int(_progress["next_level"]):
		_progress["next_level"] = mini(n + 1, MAX_LEVEL)
	save_progress()
	progress_changed.emit()
	return gain


# settings

func set_sound(on: bool) -> void:
	sound = on
	_settings_changed()


func set_music(on: bool) -> void:
	music = on
	_settings_changed()


func set_symbols(on: bool) -> void:
	symbols = on
	_settings_changed()


## Picks a wood and a metal. An id that is not a plain lowercase name is ignored.
func set_look(wood: String, metal: String) -> void:
	if _is_id(wood):
		wood_id = wood
	if _is_id(metal):
		metal_id = metal
	_settings_changed()


## The wood in use: the chosen one if it is unlocked, otherwise the default (3.4).
func wood() -> String:
	return wood_id if is_unlocked("wood", wood_id) else DEFAULT_WOOD


func metal() -> String:
	return metal_id if is_unlocked("metal", metal_id) else DEFAULT_METAL


func is_unlocked(kind: String, id: String) -> bool:
	var unlocked: Dictionary = _progress["unlocked"]
	var list: Array = unlocked.get(kind, [])
	return list.has(id)


func _settings_changed() -> void:
	save_settings()
	settings_changed.emit()


# the saved next level

## Writes the stored-level format of one level plus "key" (for example "numbered:42") to
## next_level.json, so the next launch can play it without generating it.
func write_next_level(key: String, level: LevelData) -> bool:
	if level == null or key.length() > 64:
		return false
	var d := level.to_dict()
	d["key"] = key
	return _write_json(NEXT_LEVEL_FILE, d)


## The level in next_level.json if it is the one asked for, otherwise null. Anything odd
## (a missing or broken file, another key, another generator version, a level that does not
## read cleanly) means null, and the caller generates the level as usual.
func read_next_level(key: String, generator_version: int) -> LevelData:
	var path := _path(NEXT_LEVEL_FILE)
	if not FileAccess.file_exists(path):
		return null
	var text := _read_text(path, MAX_LEVEL_FILE_BYTES)
	if text == "":
		return null
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return null
	var d: Dictionary = (json.data as Dictionary).duplicate()
	var file_key: Variant = d.get("key")
	if not file_key is String or file_key != key:
		return null
	d.erase("key")
	var errors := PackedStringArray()
	var level := LevelData.from_dict(d, errors)
	if level == null or not errors.is_empty():
		return null
	if level.kind != LevelData.NUMBERED or level.generator_version != generator_version:
		return null
	if key != "numbered:%d" % level.number:
		return null
	return level


func clear_next_level() -> void:
	var path := _path(NEXT_LEVEL_FILE)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# files

func _path(file_name: String) -> String:
	return dir.path_join(file_name)


## Returns the file's text, or "" if it can't be read or is too large.
func _read_text(path: String, limit: int) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	if f.get_length() > limit:
		return ""
	return f.get_as_text()


## A temporary file, then a rename, so a crash in the middle never leaves half a save.
func _write_json(file_name: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var path := _path(file_name)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save: could not write " + tmp)
		return false
	var stored := f.store_string(JSON.stringify(data, "\t"))
	var write_error := f.get_error()
	f.close()
	if not stored or write_error != OK:
		# A cut short write (storage full): never rename it over the good file.
		DirAccess.remove_absolute(tmp)
		push_warning("Save: could not finish writing " + tmp)
		return false
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("Save: could not rename " + tmp)
		return false
	return true


## Reads one save file and returns clean data: progress when `is_progress`, otherwise the
## settings as a dictionary. A missing file is defaults. A bad one is kept as <name>.bad.
func _load_file(file_name: String, is_progress: bool) -> Dictionary:
	_found_problem = false
	var path := _path(file_name)
	var clean := default_progress() if is_progress else settings_dict_defaults()
	if not FileAccess.file_exists(path):
		return clean
	var text := _read_text(path, MAX_FILE_BYTES)
	var json := JSON.new()
	if text == "" or json.parse(text) != OK or not json.data is Dictionary:
		_keep_bad(file_name, "not valid JSON, too large or not an object")
		return clean
	var raw: Dictionary = json.data
	clean = _clean_progress(raw) if is_progress else _clean_settings(raw)
	if _found_problem:
		# The good fields go straight back, so a crash now loses nothing, but only once the
		# original is safe as .bad.
		if _keep_bad(file_name, "some fields had the wrong type or range"):
			_write_json(file_name, clean)
	return clean


func settings_dict_defaults() -> Dictionary:
	return {"format": FORMAT, "sound": true, "music": true, "symbols": true, "wood": DEFAULT_WOOD, "metal": DEFAULT_METAL}


func _keep_bad(file_name: String, why: String) -> bool:
	problems.append("%s: %s" % [file_name, why])
	var path := _path(file_name)
	var bad := path + ".bad"
	if FileAccess.file_exists(bad):
		DirAccess.remove_absolute(bad)
	return DirAccess.rename_absolute(path, bad) == OK


func _problem(what: String) -> void:
	_found_problem = true
	if problems.size() < 20:
		problems.append(what)


# checking fields

## A whole number in low..high, or the fallback (and a problem noted). JSON numbers arrive as
## floats, so a float with a fraction, an infinity or a value out of range is refused.
func _whole(v: Variant, low: int, high: int, fallback: int, what: String) -> int:
	if v is int or v is float:
		var f := float(v)
		if is_finite(f) and floorf(f) == f and f >= float(low) and f <= float(high):
			return int(f)
	_problem("%s must be a whole number from %d to %d" % [what, low, high])
	return fallback


## Like _whole, but a field that is simply missing is quietly the fallback (an older save).
func _whole_in(d: Dictionary, key: String, low: int, high: int, fallback: int, what: String) -> int:
	if not d.has(key):
		return fallback
	return _whole(d[key], low, high, fallback, what + "." + key)


func _dict_in(d: Dictionary, key: String, what: String) -> Dictionary:
	if not d.has(key):
		return {}
	if d[key] is Dictionary:
		return d[key]
	_problem("%s.%s must be an object" % [what, key])
	return {}


func _is_id(s: Variant) -> bool:
	if not s is String:
		return false
	var text: String = s
	if text.length() < 1 or text.length() > 24:
		return false
	for i: int in text.length():
		var c := text.unicode_at(i)
		var ok := (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95
		if not ok:
			return false
	return true


## "YYYY-MM-DD" with a plausible month and day.
func _is_date(s: Variant) -> bool:
	if not s is String:
		return false
	var text: String = s
	if text.length() != 10 or text[4] != "-" or text[7] != "-":
		return false
	for i: int in 10:
		if i == 4 or i == 7:
			continue
		var c := text.unicode_at(i)
		if c < 48 or c > 57:
			return false
	var month := text.substr(5, 2).to_int()
	var day := text.substr(8, 2).to_int()
	return month >= 1 and month <= 12 and day >= 1 and day <= 31


func _is_digits(s: String) -> bool:
	if s.length() < 1 or s.length() > 7:
		return false
	for i: int in s.length():
		var c := s.unicode_at(i)
		if c < 48 or c > 57:
			return false
	return s[0] != "0"


func _clean_progress(raw: Dictionary) -> Dictionary:
	var out := default_progress()
	# Older saves (format 0 or none) have the same fields as format 1; missing fields are
	# defaults. A format this build does not know is read as far as its fields are understood.
	if raw.has("format"):
		_whole(raw["format"], 0, 1_000_000, FORMAT, "format")
	out["next_level"] = _whole_in(raw, "next_level", 1, MAX_LEVEL, 1, "progress")
	out["highest_cleared"] = _whole_in(raw, "highest_cleared", 0, MAX_LEVEL, 0, "progress")
	out["star_bank"] = _whole_in(raw, "star_bank", 0, MAX_COUNT, 0, "progress")
	out["stars_earned"] = _whole_in(raw, "stars_earned", 0, MAX_COUNT, 0, "progress")
	out["levels"] = _clean_levels(_dict_in(raw, "levels", "progress"))
	var helpers_raw := _dict_in(raw, "helpers", "progress")
	var helpers: Dictionary = out["helpers"]
	for h: String in HELPERS:
		helpers[h] = _whole_in(helpers_raw, h, 0, MAX_HELPERS, 0, "helpers")
	out["helpers_met"] = _clean_name_list(raw.get("helpers_met", []), HELPERS, "helpers_met")
	out["daily"] = _clean_daily(_dict_in(raw, "daily", "progress"))
	out["relaxed"] = _clean_relaxed(_dict_in(raw, "relaxed", "progress"))
	out["stats"] = _clean_stats(_dict_in(raw, "stats", "progress"))
	out["unlocked"] = _clean_unlocked(_dict_in(raw, "unlocked", "progress"))
	return out


func _clean_levels(raw: Dictionary) -> Dictionary:
	var out := {}
	for key: Variant in raw:
		if out.size() >= MAX_LEVEL_RECORDS:
			_problem("levels has too many records")
			break
		if not key is String or not _is_digits(key) or int(key) > MAX_LEVEL:
			_problem("levels has a bad key")
			continue
		var rec: Variant = raw[key]
		if not rec is Dictionary:
			_problem("levels.%s must be an object" % key)
			continue
		var r: Dictionary = rec
		out[key] = {
			"stars": _whole_in(r, "stars", 0, 3, 0, "levels." + key),
			"best_ms": _whole_in(r, "best_ms", 0, MAX_MS, 0, "levels." + key),
			"gen": _whole_in(r, "gen", 0, MAX_GEN, 0, "levels." + key),
		}
	return out


func _clean_name_list(raw: Variant, allowed: Array[String], what: String) -> Array:
	var out := []
	if not raw is Array:
		_problem(what + " must be a list")
		return out
	for item: Variant in raw:
		if item is String and allowed.has(item):
			if not out.has(item):
				out.append(item)
		else:
			_problem(what + " has an unknown entry")
	return out


func _clean_daily(raw: Dictionary) -> Dictionary:
	var out: Dictionary = default_progress()["daily"]
	if raw.has("last_date"):
		if raw["last_date"] is String and (raw["last_date"] == "" or _is_date(raw["last_date"])):
			out["last_date"] = raw["last_date"]
		else:
			_problem("daily.last_date must be empty or YYYY-MM-DD")
	out["streak"] = _whole_in(raw, "streak", 0, MAX_COUNT, 0, "daily")
	out["best_streak"] = _whole_in(raw, "best_streak", 0, MAX_COUNT, 0, "daily")
	out["solved"] = _whole_in(raw, "solved", 0, MAX_COUNT, 0, "daily")
	var days_raw := _dict_in(raw, "days", "daily")
	var days: Dictionary = out["days"]
	for key: Variant in days_raw:
		if days.size() >= MAX_DAYS:
			_problem("daily.days has too many records")
			break
		if not _is_date(key) or not days_raw[key] is Dictionary:
			_problem("daily.days has a bad entry")
			continue
		var r: Dictionary = days_raw[key]
		days[key] = {
			"stars": _whole_in(r, "stars", 0, 3, 0, "daily.days"),
			"best_ms": _whole_in(r, "best_ms", 0, MAX_MS, 0, "daily.days"),
		}
	return out


func _clean_relaxed(raw: Dictionary) -> Dictionary:
	var out: Dictionary = default_progress()["relaxed"]
	var next_raw := _dict_in(raw, "next", "relaxed")
	var next: Dictionary = out["next"]
	for band: String in BANDS:
		next[band] = _whole_in(next_raw, band, 0, MAX_COUNT, 0, "relaxed.next")
	if raw.has("last_band"):
		if raw["last_band"] is String and (raw["last_band"] == "" or BANDS.has(raw["last_band"])):
			out["last_band"] = raw["last_band"]
		else:
			_problem("relaxed.last_band must be empty, easy, medium or hard")
	return out


func _clean_stats(raw: Dictionary) -> Dictionary:
	var out: Dictionary = default_progress()["stats"]
	out["cleared"] = _whole_in(raw, "cleared", 0, MAX_COUNT, 0, "stats")
	out["three_star"] = _whole_in(raw, "three_star", 0, MAX_COUNT, 0, "stats")
	out["helpers_used"] = _whole_in(raw, "helpers_used", 0, MAX_COUNT, 0, "stats")
	var time_raw := _dict_in(raw, "time", "stats")
	var time: Dictionary = out["time"]
	for group: String in GROUPS:
		var g_raw := _dict_in(time_raw, group, "stats.time")
		time[group] = {
			"n": _whole_in(g_raw, "n", 0, MAX_COUNT, 0, "stats.time"),
			"total_ms": _whole_in(g_raw, "total_ms", 0, MAX_TOTAL_MS, 0, "stats.time"),
			"best_ms": _whole_in(g_raw, "best_ms", 0, MAX_MS, 0, "stats.time"),
		}
	return out


func _clean_unlocked(raw: Dictionary) -> Dictionary:
	var out: Dictionary = default_progress()["unlocked"]
	for kind: String in ["wood", "metal"]:
		if not raw.has(kind):
			continue
		var list: Variant = raw[kind]
		if not list is Array:
			_problem("unlocked.%s must be a list" % kind)
			continue
		var clean: Array = out[kind]
		for item: Variant in list:
			if clean.size() >= 32:
				break
			if _is_id(item):
				if not clean.has(item):
					clean.append(item)
			else:
				_problem("unlocked.%s has a bad entry" % kind)
	return out


func _clean_settings(raw: Dictionary) -> Dictionary:
	var out := settings_dict_defaults()
	for key: String in ["sound", "music", "symbols"]:
		if raw.has(key):
			if raw[key] is bool:
				out[key] = raw[key]
			else:
				_problem("settings.%s must be true or false" % key)
	for key: String in ["wood", "metal"]:
		if raw.has(key):
			if _is_id(raw[key]):
				out[key] = raw[key]
			else:
				_problem("settings.%s must be a plain lowercase name" % key)
	return out


func _apply_settings(clean: Dictionary) -> void:
	sound = clean["sound"]
	music = clean["music"]
	symbols = clean["symbols"]
	wood_id = clean["wood"]
	metal_id = clean["metal"]
