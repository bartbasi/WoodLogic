# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends Control
## The phone timing run (docs/ARCHITECTURE.md 10.4). Only the "Android timing" build runs it,
## in place of the game. It checks that the phone makes the same levels as the PC (the golden
## fingerprints), then times levels 1 to 200 and ten dailies the way the game makes them, on a
## background thread, plus the boot's sound building and reading a saved next level. The
## table shows on screen, goes to the log, and is saved to user://timing.txt.

const GOLDEN := "res://tests/logic/golden_levels.json"
const OUT := "user://timing.txt"
const LAST_LEVEL := 200
const DAILIES: Array[int] = [20261020, 20261021, 20261022, 20261023, 20261024, 20261025, 20261026, 20261027, 20261028, 20261029]

var _text := ""
var _label := Label.new()
var _scroll := ScrollContainer.new()
var _thread := Thread.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = Color(0.1, 0.09, 0.08)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 12
	_scroll.offset_top = 24
	_scroll.offset_right = -12
	_scroll.offset_bottom = -24
	add_child(_scroll)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(320, 0)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.82))
	_scroll.add_child(_label)
	_say("WoodLogic timing, %s" % ProjectSettings.get_setting("application/config/version"))
	_say("Phone: %s, %s, %d cores, %s %s" % [OS.get_model_name(), OS.get_processor_name(), OS.get_processor_count(), OS.get_name(), OS.get_version()])
	_say("Engine %s, generator version %d" % [Engine.get_version_info()["string"], Generator.GENERATOR_VERSION])
	var started := Time.get_ticks_msec()
	if not LevelCatalog.load_all():
		_say("FAILED: the game data did not load.")
		_finish()
		return
	_say("Game data loaded in %d ms." % (Time.get_ticks_msec() - started))
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		_say("Sounds built in %.0f ms at startup (target: under 50)." % (float(audio.get("build_seconds")) * 1000.0))
	_thread.start(_work)


func _exit_tree() -> void:
	if _thread.is_started():
		_thread.wait_to_finish()


## Runs on the background thread. Everything it reports goes through call_deferred.
func _work() -> void:
	_check_golden()
	var rows: Array[Dictionary] = []
	for n: int in range(1, LAST_LEVEL + 1):
		rows.append(_time(LevelData.NUMBERED, n))
		if n % 20 == 0:
			_say.call_deferred("Timed levels 1 to %d." % n)
	var dailies: Array[Dictionary] = []
	for day: int in DAILIES:
		dailies.append(_time(LevelData.DAILY, day))
	var read_ms := _time_saved_level_read()
	_report.call_deferred(rows, dailies, read_ms)


## How long reading a saved next level takes (the app flow does this on the main thread at
## boot, 10.3): the last level, written out and read back ten times.
func _time_saved_level_read() -> float:
	var level := LevelCatalog.get_level(LevelData.NUMBERED, LAST_LEVEL, "").level
	var text := JSON.stringify(level.to_dict())
	var started := Time.get_ticks_usec()
	for i: int in 10:
		var errors := PackedStringArray()
		LevelData.from_dict(JSON.parse_string(text) as Dictionary, errors)
	return (Time.get_ticks_usec() - started) / 10000.0


func _check_golden() -> void:
	var d: Variant = JSON.parse_string(LevelCatalog.read_text(GOLDEN))
	if not d is Dictionary:
		_say.call_deferred("FAILED: the golden file did not read.")
		return
	var version := int((d as Dictionary).get("generator_version", 0))
	if version != Generator.GENERATOR_VERSION:
		_say.call_deferred("FAILED: the golden file is for generator version %d." % version)
		return
	var levels: Array = (d as Dictionary).get("levels", [])
	var same := 0
	var differ := PackedStringArray()
	for item: Variant in levels:
		var key: String = (item as Dictionary)["key"]
		var parts := key.split(":")
		var g: GeneratedLevel
		match parts[0]:
			"numbered":
				g = LevelCatalog.get_level(LevelData.NUMBERED, parts[1].to_int(), "")
			"daily":
				g = LevelCatalog.get_level(LevelData.DAILY, parts[1].to_int(), "")
			"relaxed":
				g = LevelCatalog.get_level(LevelData.RELAXED, parts[2].to_int(), parts[1])
		var got := g.level.fingerprint() if g != null and g.level != null else "none"
		if got == (item as Dictionary)["fingerprint"]:
			same += 1
		else:
			differ.append(key)
	if differ.is_empty():
		_say.call_deferred("Golden levels: all %d match the PC." % same)
	else:
		_say.call_deferred("FAILED: %d of %d golden levels differ from the PC: %s" % [differ.size(), levels.size(), ", ".join(differ)])


func _time(kind: int, number: int) -> Dictionary:
	var started := Time.get_ticks_usec()
	var g := LevelCatalog.get_level(kind, number, "")
	var ms := (Time.get_ticks_usec() - started) / 1000.0
	return {"kind": kind, "number": number, "tier": g.level.tier, "ms": ms, "fell_back": g.fell_back}


func _report(rows: Array[Dictionary], dailies: Array[Dictionary], read_ms: float) -> void:
	_say("")
	_say("Time to make one level, in ms (the player waits on this only if it isn't ready yet)")
	_say("tier  levels  median     95%   worst  fallbacks")
	var by_tier := {}
	for row: Dictionary in rows:
		var t: int = row["tier"]
		if not by_tier.has(t):
			by_tier[t] = [] as Array[Dictionary]
		(by_tier[t] as Array[Dictionary]).append(row)
	var tiers: Array = by_tier.keys()
	tiers.sort()
	for t: int in tiers:
		# Tier 0 is the tutorial levels, which are stored, not made.
		_say(_line(" tut" if t == 0 else "%4d" % t, by_tier[t]))
	_say(_line(" all", rows))
	_say(_line("days", dailies))
	_say("")
	_say("Reading a saved next level: %.1f ms." % read_ms)
	var slow: Array[Dictionary] = rows.duplicate()
	slow.append_array(dailies)
	slow.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["ms"]) > float(b["ms"]))
	_say("")
	_say("Slowest five:")
	for row: Dictionary in slow.slice(0, 5):
		var what := "level %d" % row["number"] if row["kind"] == LevelData.NUMBERED else "daily %d" % row["number"]
		_say("  %s (tier %d): %.0f ms%s" % [what, row["tier"], row["ms"], ", fell back" if row["fell_back"] else ""])
	_finish()


func _line(name: String, rows: Array[Dictionary]) -> String:
	var times: Array[float] = []
	var fallbacks := 0
	for row: Dictionary in rows:
		times.append(float(row["ms"]))
		fallbacks += 1 if row["fell_back"] else 0
	times.sort()
	var median := times[times.size() / 2]
	var p95 := times[mini(times.size() - 1, int(ceil(times.size() * 0.95)) - 1)]
	return "%s  %6d  %6.0f  %6.0f  %6.0f  %9d" % [name, rows.size(), median, p95, times[-1], fallbacks]


func _say(line: String) -> void:
	print(line)
	_text += line + "\n"
	_label.text = _text


func _finish() -> void:
	_say("")
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		_say("Done, but %s could not be written." % OUT)
		return
	f.store_string(_text)
	f.close()
	_say("Done. Saved to %s." % ProjectSettings.globalize_path(OUT))
