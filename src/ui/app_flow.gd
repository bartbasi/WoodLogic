# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name AppFlow
extends Control
## The app: which screen shows, which level is on, and what is saved (docs/ARCHITECTURE.md 6,
## 8 and 11.4, docs/UX.md 4). It talks to the level scene only through ARCHITECTURE section 6.
##
## Screens: the menus (Title, Map, Stats, Info, Settings, About, License, Credits, Relaxed
## setup) share one frame and one nav dock; the level; Pause; Level clear; Out of room; the
## helper sheet and the dialogs. A paused level stays alive, hidden, while menus show, and
## "Back to level" goes straight into it. Levels come from LevelPrefetcher, polled every frame:
## the level the player waits on is urgent, level N + 1 is asked for as soon as N starts, and
## the current and previous LevelData are kept for Retry and Previous level.

enum State { BOOT, ERROR, TITLE, MENU, LOADING, LEVEL, PAUSE, CLEAR, LOST }

const LEVEL_SCENE := "res://src/level/level_scene.tscn"
const NUMBERED := LevelData.NUMBERED
## The canvas layer of everything drawn over the level (the level scene is on layer 0).
const UI_LAYER := 10
## At most this many low priority level jobs run at once, so the worker threads stay free for
## the level the player is waiting on.
const MAX_LOW_JOBS := 3
const MAX_SPARE := 8
const HELPER_ORDER: Array[String] = ["undo", "extra_slot", "screwdriver"]

## Tests point this at a small fake level scene.
var level_scene_path := LEVEL_SCENE
## Tests replace this so a Back press on the title does not end the test run.
var quit_handler := Callable()
## Tests set "YYYY-MM-DD" to fix today's date for the Daily.
var today_override := ""

var state: State = State.BOOT
var level_scene: Node
## The full screen or sheet now showing (menu, Pause, Level clear, Out of room, loading).
var screen: UiScreen
## A helper sheet or a dialog on top of `screen` or the level.
var overlay: UiScreen
## The menu on screen when state is TITLE or MENU: "title", "map", "stats" and so on.
var menu := ""
var toast: Toast
var _ui_layer: CanvasLayer

var _prefetch := LevelPrefetcher.new()
var _current: LevelData
var _previous: LevelData
## Levels made ahead (N + 1, N - 1, the Daily, the next Relaxed level), so Next and Previous
## level are one tap. At most MAX_SPARE are kept.
var _spare: Array[LevelData] = []
## Levels asked for ahead of time, low priority: waiting to be requested, and requested.
var _low_queue: Array[Array] = []
var _low_keys: Array[String] = []
var _modes_queued := false
## The helper counts from before a gift, until the next level shows them counting up.
var _gift_before: Dictionary = {}
## The saved next level being solved again on a worker thread; null once decided.
var _check: SavedLevelCheck
var _wanted_key := ""
var _abandoned: Array[String] = []
var _wanted_kind := NUMBERED
var _wanted_number := 0
var _wanted_band := ""
var _wanted_replay := false
## A level is paused in memory: the player went to Pause and from there to the menus.
var _paused_level := false
var _lost_while_paused := false
var _replay := false
var _file_key := ""
var _shut_down := false
var _helper_sheet_for := ""
## The tray size of the level the player just cleared, set when Next is tapped, so the next
## level can close its tray if it is smaller. 0 when the level did not come from Next.
var _arrival_tray := 0


func _ready() -> void:
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Every screen shown over the level lives on its own canvas layer above it, so nothing
	# inside the level scene (its HUD, planks, any z index) can ever draw over a screen.
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = UI_LAYER
	add_child(_ui_layer)
	toast = Toast.new()
	toast.theme = theme
	toast.z_index = 1100
	_ui_layer.add_child(toast)
	_boot()


func _exit_tree() -> void:
	if _check != null:
		_check.cancel()
	_prefetch.shutdown()


# boot

func _boot() -> void:
	if not LevelCatalog.load_all():
		_show_error()
		return
	Save.load_all()
	_apply_settings()
	var n := Save.next_level()
	# A level saved by the last run is played without generating it, once it has been solved
	# again (on a worker thread, so the title shows at once) and checked against the rules
	# (ARCHITECTURE 10.3). Until that is decided nothing else is asked for.
	var saved := Save.read_next_level(LevelPrefetcher.key_for(NUMBERED, n, ""), Generator.GENERATOR_VERSION)
	if saved != null:
		var tier := _saved_level_tier(saved, n)
		if tier > 0 and Save.highest_cleared() > 0:
			_check = SavedLevelCheck.new()
			_check.level = saved
			_check.tier = tier
			_check.number = n
			_check.start()
		else:
			Save.clear_next_level()
	if Save.highest_cleared() == 0:
		# First launch (or after a reset): straight into the level, no title (UX 5.1).
		play_number(n)
		return
	if _check == null:
		_after_check(n)
	show_menu("title")


## The check has decided (or there was nothing to check): ask for the Play level if it is
## not in hand, urgent, then N + 1 behind it. Today's daily and the next Relaxed levels wait
## until both are in hand (see _queue_modes).
func _after_check(n: int) -> void:
	if _known(NUMBERED, n, "") == null:
		var key := _request(NUMBERED, n, "", true)
		if state == State.LOADING and _wanted_kind == NUMBERED and _wanted_number == n:
			_wanted_key = key
	_queue_low(NUMBERED, n + 1, "")


## Takes the worker's verdict once it has finished (never waits for it).
func _poll_check() -> void:
	if _check == null or not _check.is_done():
		return
	var check := _check
	_check = null
	check.finish()
	if check.passed:
		_current = check.level
		_file_key = "numbered:%d" % check.number
	else:
		Save.clear_next_level()
	_after_check(check.number)


## The tier of a level read from the file if it fits the rules for that number (the number,
## the kind, the tier and the tray), else 0. The solving part runs on a worker thread.
func _saved_level_tier(level: LevelData, n: int) -> int:
	if level.number != n or level.kind != NUMBERED:
		return 0
	var tier := Tuning.tier_for_level(n)
	if level.tier != tier or level.tray_size != Tuning.tier(tier).tray:
		return 0
	return tier


## The generator's own acceptance search (the tier's state budget and the generator's own cap on
## tray uses), not the full solve with the novice and trap playouts. The tray par must
## not be below the fewest tray uses found. `stop` ends the search early (quitting); a stopped
## search is not complete, so it fails. Safe on a worker thread: it only reads.
static func saved_level_solves(level: LevelData, tier: int, stop: GenerationStop = null) -> bool:
	var result := Solver.search_only(level, Generator.MAX_STATES[tier - 1], true, Generator.acceptance_cap(tier), stop)
	if not result.solved or not result.complete:
		return false
	return level.tray_par >= result.fewest_tray_uses


func _show_error() -> void:
	state = State.ERROR
	var s := UiScreen.new()
	s.fade_in = false
	_set_screen(s)
	s.column.add_child(s.spacer())
	s.column.add_child(s.plaque("WoodLogic could not start", "HeadingLabel"))
	s.column.add_child(s.spacer())


## Sound and music from the settings; the looks wait for the renderers' Looks.
func _apply_settings() -> void:
	Audio.set_sound(Save.sound)
	Audio.set_music(Save.music)
	_apply_looks()


## Looks.current from the settings (ARCHITECTURE 7). A wood or metal that is not unlocked
## reads as the default.
func _apply_looks() -> void:
	Looks.current = {"wood": Save.wood(), "metal": Save.metal(), "symbols": Save.symbols}
	# A level that is alive (paused behind the menus) draws itself again in the new looks.
	if level_scene != null and is_instance_valid(level_scene):
		level_scene.call("refresh_looks")


# every frame

func _process(_delta: float) -> void:
	_prefetch.poll()
	# Requests nobody wants any more are collected once they finish, so they do not pile up.
	for key: String in _abandoned.duplicate():
		if key == _wanted_key:
			_abandoned.erase(key)
		elif _prefetch.is_ready(key):
			_prefetch.take(key)
			_abandoned.erase(key)
	_poll_check()
	_pump_low()
	if state == State.LOADING:
		# The level may have arrived as the one ahead, or be the one asked for urgently.
		var in_hand := _known(_wanted_kind, _wanted_number, _wanted_band)
		if in_hand != null:
			_abandon(_wanted_key)
			_wanted_key = ""
			_begin(in_hand, _wanted_replay)
		elif _prefetch.is_ready(_wanted_key):
			var made := _prefetch.take(_wanted_key)
			_wanted_key = ""
			if made == null or made.level == null:
				_show_error()
				return
			_begin(made.level, _wanted_replay)
	elif state == State.TITLE and _title_key_ready():
		# The Play level arrived while the title was up: keep it for the tap on Play.
		var made := _prefetch.take(LevelPrefetcher.key_for(NUMBERED, Save.next_level(), ""))
		if made != null and made.level != null:
			_remember(made.level)
	if not _modes_queued and (state == State.TITLE or state == State.LEVEL):
		_queue_modes()


## Asks for a level ahead of time at low priority, behind the ones already asked for.
func _queue_low(kind: int, number: int, band: String) -> void:
	if number < 0 or (kind == NUMBERED and (number < 1 or number > Save.MAX_LEVEL)):
		return
	if _known(kind, number, band) != null:
		return
	var key := LevelPrefetcher.key_for(kind, number, band)
	if _low_keys.has(key) or _prefetch.is_ready(key) or _prefetch.is_running(key):
		return
	for entry: Array in _low_queue:
		if entry[0] == kind and entry[1] == number and entry[2] == band:
			return
	_low_queue.append([kind, number, band])


## Starts queued low jobs while fewer than MAX_LOW_JOBS run, and puts finished ones in hand.
func _pump_low() -> void:
	for key: String in _low_keys.duplicate():
		if _prefetch.is_ready(key) and key != _wanted_key:
			var got := _prefetch.take(key)
			_low_keys.erase(key)
			if got != null and got.level != null:
				_add_spare(got.level)
		elif not _prefetch.is_running(key) and not _prefetch.is_ready(key):
			_low_keys.erase(key)
	while _low_keys.size() < MAX_LOW_JOBS and not _low_queue.is_empty():
		var entry: Array = _low_queue.pop_front()
		if _known(entry[0], entry[1], entry[2]) == null:
			_low_keys.append(_request(entry[0], entry[1], entry[2], false))


func _add_spare(level: LevelData) -> void:
	_spare.append(level)
	while _spare.size() > MAX_SPARE:
		_spare.pop_front()
	_sync_next_file()


## Today's Daily and each Relaxed band's next level are made once the Play level and N + 1 are
## in hand, never ahead of them.
func _queue_modes() -> void:
	var n := Save.next_level()
	if _known(NUMBERED, n, "") == null or _known(NUMBERED, n + 1, "") == null:
		return
	_modes_queued = true
	if not _modes_open():
		return
	_queue_low(LevelData.DAILY, _today_number(), "")
	for band: String in Tuning.BANDS:
		_queue_low(LevelData.RELAXED, Save.relaxed_next(band), band)


func _title_key_ready() -> bool:
	return _prefetch.is_ready(LevelPrefetcher.key_for(NUMBERED, Save.next_level(), ""))


# screens

func _set_screen(s: UiScreen) -> void:
	_clear_screen()
	screen = s
	s.theme = theme
	_ui_layer.add_child(s)
	_ui_layer.move_child(toast, -1)


func _clear_screen() -> void:
	if screen != null:
		screen.queue_free()
		screen = null


func _set_overlay(s: UiScreen) -> void:
	_clear_overlay()
	overlay = s
	s.theme = theme
	_ui_layer.add_child(s)
	_ui_layer.move_child(toast, -1)


func _clear_overlay() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null


func show_toast(text: String) -> void:
	toast.show_text(text)


## Shows a menu screen by name (MenuFactory.NAMES). The dock's tabs replace the screen, so
## they never add history; a paused level stays alive underneath.
func show_menu(menu_name: String) -> void:
	# A menu is no arrival by Next.
	_arrival_tray = 0
	_clear_overlay()
	_set_level_visible(false)
	menu = menu_name
	state = State.TITLE if menu_name == "title" else State.MENU
	var s := MenuFactory.make(menu_name, _menu_context())
	if s == null:
		return
	s.tab_pressed.connect(_on_tab)
	s.game_pressed.connect(_on_game_row)
	s.coffee_pressed.connect(_on_coffee)
	_wire_menu(menu_name, s)
	_set_screen(s)


func _menu_context() -> Dictionary:
	var date := _today_text()
	return {
		"next_level": Save.next_level(),
		"paused_text": _paused_text(),
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"progress": Save.progress_copy(),
		"settings": {
			"sound": Save.sound, "music": Save.music, "symbols": Save.symbols,
			"wood": Save.wood(), "metal": Save.metal(),
			"unlocked_wood": Save.unlocked_ids("wood"), "unlocked_metal": Save.unlocked_ids("metal"),
		},
		"last_band": Save.relaxed_last_band(),
		"daily_note": "Done today" if Save.daily_done(date) else "Today's puzzle",
		"daily_locked": not _modes_open(),
		"relaxed_locked": not _modes_open(),
	}


## Connects the signals only some menus have.
func _wire_menu(menu_name: String, s: MenuScreen) -> void:
	match menu_name:
		"title":
			var t := s as TitleScreen
			t.play_pressed.connect(_on_game_row)
			t.daily_pressed.connect(_on_daily)
			t.relaxed_pressed.connect(_on_relaxed)
		"map":
			var m := s as MapScreen
			m.level_chosen.connect(_on_map_level)
			m.locked_tapped.connect(func(n: int) -> void:
				Audio.play("knock_dull")
				show_toast("Clear level %d first." % n))
		"settings":
			var st := s as SettingsScreen
			st.sound_toggled.connect(func(on: bool) -> void:
				Save.set_sound(on)
				Audio.set_sound(on))
			st.music_toggled.connect(func(on: bool) -> void:
				Save.set_music(on)
				Audio.set_music(on))
			st.symbols_toggled.connect(func(on: bool) -> void:
				Save.set_symbols(on)
				_apply_looks())
			st.look_changed.connect(func(wood: String, metal: String) -> void:
				Save.set_look(wood, metal)
				_apply_looks())
			st.reset_requested.connect(_ask_reset)
		"about":
			var a := s as AboutScreen
			a.feedback_pressed.connect(func() -> void:
				if not Links.open_feedback():
					show_toast("No email app found. You can write to bartbasi@gmail.com."))
			a.source_pressed.connect(func() -> void:
				if not Links.open_source():
					show_toast("No browser found on this phone."))
			a.license_pressed.connect(show_menu.bind("license"))
			a.credits_pressed.connect(show_menu.bind("credits"))
		"relaxed":
			(s as RelaxedScreen).band_pressed.connect(play_relaxed)


func _on_tab(tab: String) -> void:
	var target: String = MenuFactory.TAB_SCREENS.get(tab, "")
	if target != "":
		show_menu(target)


func _on_coffee() -> void:
	_open_coffee()


func _open_coffee() -> void:
	if not Links.open_coffee():
		show_toast("No browser found on this phone.")


## "Play", or "Back to level" when a level is paused.
func _on_game_row() -> void:
	if _paused_level:
		_back_to_level()
	else:
		play_number(Save.next_level())


func _on_map_level(n: int) -> void:
	play_number(n)


func _modes_open() -> bool:
	return Save.highest_cleared() >= Tuning.modes_open_after_level


func _on_daily() -> void:
	if not _modes_open():
		UiScreen.shake((screen as TitleScreen).daily_button)
		Audio.play("knock_dull")
		show_toast("Clear level %d to open Daily." % Tuning.modes_open_after_level)
		return
	play_daily()


func _on_relaxed() -> void:
	if not _modes_open():
		UiScreen.shake((screen as TitleScreen).relaxed_button)
		Audio.play("knock_dull")
		show_toast("Clear level %d to open Relaxed." % Tuning.modes_open_after_level)
		return
	show_menu("relaxed")


func _show_loading() -> void:
	state = State.LOADING
	_set_level_visible(false)
	var s := UiScreen.new()
	s.fade_in = false
	_set_screen(s)
	s.column.add_child(s.spacer())
	s.column.add_child(s.plaque("One moment", "HeadingLabel"))
	s.column.add_child(s.spacer())


## The line under "Paused" and on the game row: "Level 7", "Daily" or "Relaxed, Easy".
func _level_label() -> String:
	if _current == null:
		return "Level %d" % Save.next_level()
	match _current.kind:
		LevelData.DAILY:
			return "Daily"
		LevelData.RELAXED:
			return "Relaxed, %s" % _current.band.capitalize()
		_:
			return "Level %d" % _current.number


func _paused_text() -> String:
	if not _paused_level or _current == null:
		return ""
	match _current.kind:
		LevelData.DAILY:
			return "Daily, paused"
		LevelData.RELAXED:
			return "Relaxed, paused"
		_:
			return "Level %d, paused" % _current.number


func _show_pause() -> void:
	_clear_overlay()
	state = State.PAUSE
	_paused_level = true
	_set_level_visible(true)
	level_scene.call("pause")
	var s := PauseScreen.make(_level_label(), Save.sound, Save.music)
	s.resume_pressed.connect(_resume)
	s.retry_pressed.connect(_retry_from_pause)
	s.quit_pressed.connect(quit_to_title)
	s.settings_pressed.connect(show_menu.bind("settings"))
	s.coffee_pressed.connect(_open_coffee)
	s.sound_toggled.connect(func(on: bool) -> void:
		Save.set_sound(on)
		Audio.set_sound(on))
	s.music_toggled.connect(func(on: bool) -> void:
		Save.set_music(on)
		Audio.set_music(on))
	_set_screen(s)
	_set_level_visible(false)


func _show_clear(info: Dictionary) -> void:
	state = State.CLEAR
	var s := ClearScreen.make(info)
	var kind := int(info.get("kind", NUMBERED))
	s.next_pressed.connect(_clear_primary.bind(kind))
	s.replay_pressed.connect(_clear_secondary.bind(kind))
	_set_screen(s)


## The big button of Level clear: Next, Done (daily) or Another (Relaxed).
func _clear_primary(kind: int) -> void:
	match kind:
		LevelData.DAILY:
			quit_to_title()
		LevelData.RELAXED:
			play_relaxed(_current.band)
		_:
			_arrival_tray = _current.tray_size
			play_number(_current.number + 1)


## The second button: Replay, or Done on a Relaxed clear.
func _clear_secondary(kind: int) -> void:
	if kind == LevelData.RELAXED:
		quit_to_title()
	else:
		_begin(_current, true)


func _show_lost() -> void:
	state = State.LOST
	var options := {"number": _current.number, "can_previous": false, "stuck": _current.kind == LevelData.RELAXED, "helpers": []}
	if _current.kind == NUMBERED or _current.kind == LevelData.TUTORIAL:
		options["can_previous"] = _current.number > 1
	if _current.kind != LevelData.RELAXED:
		options["helpers"] = _lost_helpers()
	var s := LostScreen.make(options)
	s.retry_pressed.connect(_retry_from_lost)
	s.previous_pressed.connect(func() -> void: play_number(_current.number - 1))
	s.title_pressed.connect(quit_to_title)
	s.helper_pressed.connect(_use_helper_after_loss)
	_set_screen(s)


## [[helper, count], ...] the player owns and can use after this loss, in the fixed order.
func _lost_helpers() -> Array:
	var usable: PackedStringArray = PackedStringArray()
	if level_scene != null:
		usable = level_scene.call("usable_after_loss")
	var out := []
	for h: String in HELPER_ORDER:
		if usable.has(h) and Save.helper_count(h) > 0:
			out.append([h, Save.helper_count(h)])
	return out


func _use_helper_after_loss(helper: String) -> void:
	_clear_screen()
	state = State.LEVEL
	level_scene.call("use_helper", helper)


# levels

func _today() -> Dictionary:
	if today_override != "":
		return {"year": int(today_override.substr(0, 4)), "month": int(today_override.substr(5, 2)), "day": int(today_override.substr(8, 2))}
	return Time.get_date_dict_from_system()


func _today_number() -> int:
	var d := _today()
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])


func _today_text() -> String:
	return _date_text(_today_number())


## 20261019 as "2026-10-19".
@warning_ignore("integer_division")
static func _date_text(number: int) -> String:
	return "%04d-%02d-%02d" % [number / 10000, (number / 100) % 100, number % 100]


static func _matches(level: LevelData, kind: int, number: int, band: String) -> bool:
	if level == null or level.number != number:
		return false
	if kind == NUMBERED:
		return level.kind == NUMBERED or level.kind == LevelData.TUTORIAL
	return level.kind == kind and level.band == band


## The LevelData for a level if it is in hand (current, previous or the one just ahead).
func _known(kind: int, number: int, band: String) -> LevelData:
	for level: LevelData in [_current, _previous]:
		if _matches(level, kind, number, band):
			return level
	for level: LevelData in _spare:
		if _matches(level, kind, number, band):
			return level
	return null


## Puts a newly arrived level in hand without starting it (the Play level made during the
## title). It never replaces the current level of a running game.
func _remember(level: LevelData) -> void:
	if _current == null:
		_current = level
		_sync_next_file()
	else:
		_add_spare(level)


## Asks the prefetcher for a level. A key asked for is wanted again, so it leaves the
## abandoned list.
func _request(kind: int, number: int, band: String, urgent: bool) -> String:
	var key := _prefetch.request(kind, number, band, urgent)
	_abandoned.erase(key)
	return key


## Stops wanting a requested level; it is taken and dropped when it finishes. Only a request
## still running needs this; a finished one was already taken or is wanted.
func _abandon(key: String) -> void:
	if key != "" and _prefetch.is_running(key) and not _abandoned.has(key):
		_abandoned.append(key)


## Starts numbered level n. Retry and Previous level reuse the LevelData in hand; others come
## from the prefetcher, or wait for it with a plain "One moment" screen.
func play_number(n: int) -> void:
	n = clampi(n, 1, Save.MAX_LEVEL)
	_play(NUMBERED, n, "", n < Save.next_level())


## Today's daily (UX 3.1). A solved daily can be played again for more stars.
func play_daily() -> void:
	_play(LevelData.DAILY, _today_number(), "", false)


## The next Relaxed level of a band ("easy", "medium" or "hard").
func play_relaxed(band: String) -> void:
	_play(LevelData.RELAXED, Save.relaxed_next(band), band, false)


func _play(kind: int, number: int, band: String, replay: bool) -> void:
	if _check != null and kind == NUMBERED and number == _check.number and _known(kind, number, band) == null:
		# The saved level is still being checked: wait for the verdict (it either plays the
		# saved level or asks for it to be made).
		_wanted_key = ""
		_wanted_kind = kind
		_wanted_number = number
		_wanted_band = band
		_wanted_replay = replay
		_show_loading()
		return
	var level := _known(kind, number, band)
	if level != null:
		_begin(level, replay)
		return
	var key := LevelPrefetcher.key_for(kind, number, band)
	_abandoned.erase(key)
	if _prefetch.is_ready(key):
		var made := _prefetch.take(key)
		if made != null and made.level != null:
			_begin(made.level, replay)
			return
	_wanted_key = _request(kind, number, band, true)
	_wanted_kind = kind
	_wanted_number = number
	_wanted_band = band
	_wanted_replay = replay
	_show_loading()


func _begin(level: LevelData, replay: bool) -> void:
	if level != _current:
		_previous = _current
		_current = level
	_spare.erase(level)
	_replay = replay
	_lost_while_paused = false
	var was_paused := _paused_level
	_paused_level = false
	_clear_overlay()
	if not _ensure_level_scene():
		return
	_clear_screen()
	state = State.LEVEL
	_set_level_visible(true)
	if was_paused:
		# A different level starts on a scene that was left paused: wake it first.
		level_scene.call("resume")
	level_scene.call("play", level, replay)
	_configure_level_scene(level)
	_queue_ahead(level)
	_sync_next_file()
	if not _gift_before.is_empty():
		level_scene.call("show_helper_gift", _gift_before)
		_gift_before = {}
	_tray_moments(level, replay)
	_maybe_helper_sheet(level)


## The smaller tray (UX 3.2.2): the closing animation when the player arrives by Next and
## the tray is smaller than the one just played, and the one-time line on the first numbered
## level whose tray is smaller than the starting size. Never on Retry (it does not come
## here), a replay, the Daily or Relaxed.
func _tray_moments(level: LevelData, replay: bool) -> void:
	var came_from := _arrival_tray
	_arrival_tray = 0
	if level.kind != NUMBERED and level.kind != LevelData.TUTORIAL:
		return
	# The tray the board really has (a stored level can differ from the schedule).
	var tray := level.tray_size
	if came_from > 0 and tray < came_from and not replay:
		level_scene.call("play_tray_closing")
	if not replay and level.kind == NUMBERED and tray < Tuning.tray_size and not Save.tray_note_shown():
		Save.mark_tray_note_shown()
		level_scene.call("show_tray_note", "The tray is smaller now. Every slot counts.")


## What is worth having ready while this level is played, all at low priority and in this
## order: N + 1 (Next), N - 1 (Previous level) and today's Daily; for a Relaxed level, the
## band's next level (Another).
func _queue_ahead(level: LevelData) -> void:
	if level.kind == LevelData.RELAXED:
		_queue_low(LevelData.RELAXED, level.number + 1, level.band)
		return
	if level.kind == NUMBERED or level.kind == LevelData.TUTORIAL:
		_queue_low(NUMBERED, level.number + 1, "")
		_queue_low(NUMBERED, level.number - 1, "")
	if _modes_open():
		_queue_low(LevelData.DAILY, _today_number(), "")


func _ensure_level_scene() -> bool:
	if level_scene != null and is_instance_valid(level_scene):
		return true
	var packed: PackedScene = null
	if ResourceLoader.exists(level_scene_path):
		packed = load(level_scene_path) as PackedScene
	if packed == null:
		push_warning("AppFlow: no level scene at " + level_scene_path)
		_show_error()
		return false
	level_scene = packed.instantiate()
	level_scene.connect("won", _on_won)
	level_scene.connect("lost", _on_lost)
	level_scene.connect("pause_requested", _on_pause_requested)
	# The level scene contract (ARCHITECTURE 6 and 11.3): every signal is connected, none is
	# optional, so a rename on the level side fails loudly.
	level_scene.connect("helper_used", _on_helper_used)
	level_scene.connect("helper_buy_requested", _on_buy_requested)
	level_scene.connect("coffee_requested", _on_coffee_requested)
	add_child(level_scene)
	move_child(level_scene, 0)
	return true


func _free_level_scene() -> void:
	if level_scene != null and is_instance_valid(level_scene):
		level_scene.queue_free()
	level_scene = null


func _set_level_visible(on: bool) -> void:
	if level_scene != null and is_instance_valid(level_scene) and level_scene is CanvasItem:
		(level_scene as CanvasItem).visible = on


## What the level scene needs to know when a level starts: the coffee cup, the star bank and
## the helper bar.
func _configure_level_scene(_level: LevelData) -> void:
	level_scene.call("set_coffee", Links.coffee_visible())
	level_scene.call("set_star_bank", Save.star_bank())
	_push_helpers()


## Tells the level scene the helper counts and which buttons to show: those whose first-time
## explanation was shown (none before level 8), and only Undo in Relaxed.
func _push_helpers() -> void:
	if level_scene == null or _current == null:
		return
	var shown := PackedStringArray()
	if _current.kind == LevelData.RELAXED:
		shown.append("undo")
	else:
		for h: String in HELPER_ORDER:
			if Save.is_helper_met(h):
				shown.append(h)
	level_scene.call("set_helpers", Save.helper_counts(), shown)
	level_scene.call("set_star_bank", Save.star_bank())


# helpers: the first-time sheet, using, buying

## Shows the explanation of the first helper this level introduces and the player has not met
## (UX 3.13.1), before the first tap. The clock is held while it is open.
func _maybe_helper_sheet(level: LevelData) -> void:
	if level.kind != NUMBERED and level.kind != LevelData.TUTORIAL:
		return
	for h: String in HELPER_ORDER:
		var info: Dictionary = Tuning.helpers[h]
		if level.number >= int(info["first_level"]) and not Save.is_helper_met(h):
			_show_helper_sheet(h)
			return


func _show_helper_sheet(helper: String) -> void:
	_helper_sheet_for = helper
	level_scene.call("hold_clock", true)
	var sheet := HelperSheet.make(helper)
	sheet.got_it.connect(_helper_sheet_done)
	_set_overlay(sheet)


func _helper_sheet_done() -> void:
	var helper := _helper_sheet_for
	_helper_sheet_for = ""
	_clear_overlay()
	level_scene.call("hold_clock", false)
	if helper != "":
		Save.mark_helper_met(helper, int(Tuning.helpers[helper]["free"]))
		_push_helpers()
		level_scene.call("highlight_helper", helper)
	if _current != null:
		_maybe_helper_sheet(_current)


func _on_helper_used(helper: String) -> void:
	# Relaxed: Undo is free and unlimited, but it still counts in the stats (GDD 6.6). One
	# write either way.
	Save.helper_used(helper, _current != null and _current.kind != LevelData.RELAXED)
	_push_helpers()


func _on_buy_requested(helper: String) -> void:
	if _current == null or _current.kind == LevelData.RELAXED or not Tuning.helpers.has(helper):
		return
	var price := int(Tuning.helpers[helper]["price"])
	var bank := Save.star_bank()
	if bank < price:
		show_toast("%s costs %d stars. You have %d." % [HelperButton.NAMES.get(helper, helper), price, bank])
		return
	var helper_name: String = HelperButton.NAMES.get(helper, helper)
	level_scene.call("hold_clock", true)
	Audio.play("tick")
	var dialog := UiDialog.make("Get %s?" % helper_name, "%s costs %d stars. You have %d. Spend %d and use it now?" % [helper_name, price, bank, price], [["Get and use", UiButton.Kind.PRIMARY], ["Not now", UiButton.Kind.SECONDARY]], 1)
	dialog.chosen.connect(func(i: int) -> void:
		_clear_overlay()
		level_scene.call("hold_clock", false)
		# The stars and the helper go in one write: a kill in between loses nothing.
		if i == 0 and Save.buy_helper(helper, price):
			_push_helpers()
			level_scene.call("use_helper", helper))
	_set_overlay(dialog)


func _on_coffee_requested() -> void:
	# The scene has paused itself; Pause shows in the same frame, then the page opens.
	if state == State.LEVEL:
		_show_pause()
	_open_coffee()


# wins and losses

func _on_won(result: Object) -> void:
	if state != State.LEVEL and state != State.PAUSE:
		return
	var level: LevelData = result.get("level")
	var elapsed: int = result.get("elapsed_ms")
	var stars: Vector3i = result.get("stars")
	if level == null:
		level = _current
	_clear_overlay()
	_paused_level = false
	var info := {"kind": level.kind, "number": level.number, "level": level, "stars": stars, "elapsed_ms": elapsed, "gain": 0, "streak": 0, "unlocks": []}
	var highest_before := Save.highest_cleared()
	var counts_before := Save.helper_counts()
	match level.kind:
		LevelData.DAILY:
			var r := Save.record_daily(_date_text(level.number), elapsed, stars, level.group)
			info["gain"] = r["gain"]
			info["streak"] = r["streak"]
		LevelData.RELAXED:
			Save.record_relaxed(level.band)
		_:
			info["gain"] = Save.record_win(level, elapsed, stars)
			info["gifts"] = _grant_gifts()
			if not (info["gifts"] as Array).is_empty():
				# The next level shows the helper badges counting up from these (UX 3.13.4).
				_gift_before = counts_before
	info["unlocks"] = _apply_unlocks(highest_before)
	_sync_next_file()
	_show_clear(info)


## Gives every gift the player's next level has reached and not yet received (UX 3.13.4). The
## helpers are saved with the record of the gift before anything is shown, so a gift is given
## exactly once even if the app dies at once; a save already past a gift's level gets it on
## its next clear. Returns the plaque lines (one, with the sum, if two are due).
func _grant_gifts() -> Array[String]:
	var next := Save.next_level()
	var levels := []
	var sum := {}
	for g: Dictionary in Tuning.gifts:
		var at := int(g["level"])
		if at > next or Save.is_gift_given(at):
			continue
		if Save.grant_gift(at, g):
			levels.append(at)
			for h: String in HELPER_ORDER:
				sum[h] = int(sum.get(h, 0)) + int(g.get(h, 0))
	var notes: Array[String] = []
	if not levels.is_empty():
		notes.append("A gift for reaching %s: %s." % [UiText.gift_levels(levels), UiText.gift_helpers(sum)])
	return notes


## Applies the unlocks this clear passed and returns their notes (UX 3.4).
func _apply_unlocks(highest_before: int) -> Array[String]:
	var notes: Array[String] = []
	var highest := Save.highest_cleared()
	var best_streak := int(Save.daily_record()["best_streak"])
	if highest_before < Tuning.modes_open_after_level and highest >= Tuning.modes_open_after_level:
		notes.append("Unlocked: Daily and Relaxed")
	for u: Dictionary in Tuning.unlocks:
		var kind := str(u["what"])
		var id := str(u["id"])
		var reached := false
		if u.has("best_streak"):
			reached = best_streak >= int(u["best_streak"])
		else:
			reached = highest >= int(u.get("level", 0))
		if reached and Save.add_unlock(kind, id):
			notes.append("Unlocked: %s %s" % [id.capitalize(), kind])
	return notes


func _on_lost(_level: LevelData) -> void:
	if state == State.PAUSE:
		# The loss is kept and shown when the player resumes.
		_lost_while_paused = true
		return
	if state != State.LEVEL:
		return
	_clear_overlay()
	_show_lost()


func _on_pause_requested() -> void:
	if state == State.LEVEL and not overlay is HelperSheet:
		_cancel_overlay()
		_show_pause()


## Leaves Pause and shows the level; the clock starts again if it had started.
func _resume() -> void:
	if state != State.PAUSE:
		return
	_back_into_level()
	if _lost_while_paused:
		_lost_while_paused = false
		_show_lost()


## The game row's "Back to level": straight into the paused level with no Pause screen.
func _back_to_level() -> void:
	if level_scene == null or not is_instance_valid(level_scene):
		_paused_level = false
		play_number(Save.next_level())
		return
	_back_into_level()
	if _lost_while_paused:
		_lost_while_paused = false
		_show_lost()


func _back_into_level() -> void:
	_clear_overlay()
	_clear_screen()
	_paused_level = false
	state = State.LEVEL
	_set_level_visible(true)
	level_scene.call("resume")


## Retry from Pause. The scene is paused, so it is resumed first; its retry then restarts the
## level with the clock waiting for the first action.
func _retry_from_pause() -> void:
	_lost_while_paused = false
	_back_into_level()
	level_scene.call("retry")


func _retry_from_lost() -> void:
	_clear_screen()
	state = State.LEVEL
	level_scene.call("retry")


## Quit to title (and every other way out of a level to the title): the level is dropped, and
## Play starts it again from the beginning (UX 4.3).
func quit_to_title() -> void:
	_arrival_tray = 0
	_lost_while_paused = false
	_paused_level = false
	_clear_overlay()
	if state == State.LOADING:
		if _wanted_key != LevelPrefetcher.key_for(NUMBERED, Save.next_level(), ""):
			_abandon(_wanted_key)
		_wanted_key = ""
	_free_level_scene()
	show_menu("title")


# resetting progress

func _ask_reset() -> void:
	var body := "This erases your levels, stars, helpers, streaks and stats on this phone. It cannot be undone. Your settings stay as they are."
	if _paused_level:
		body += " The level you paused ends too."
	var dialog := UiDialog.make("Erase everything?", body, [["Keep my progress", UiButton.Kind.PRIMARY], ["Erase everything", UiButton.Kind.DANGER]], 0)
	dialog.chosen.connect(func(i: int) -> void:
		_clear_overlay()
		if i == 1:
			_erase_progress())
	_set_overlay(dialog)


func _erase_progress() -> void:
	Save.reset_progress()
	_paused_level = false
	_free_level_scene()
	_current = null
	_previous = null
	_spare.clear()
	_low_queue.clear()
	_file_key = ""
	show_menu("settings")
	show_toast("Progress erased.")


## Keeps next_level.json holding the level Play will start at (the saved next level): when
## the level for Save.next_level() is in hand and was generated, it is written once.
func _sync_next_file() -> void:
	var n := Save.next_level()
	var level := _known(NUMBERED, n, "")
	if level == null or level.kind != NUMBERED:
		return
	var key := LevelPrefetcher.key_for(NUMBERED, n, "")
	if key == _file_key:
		return
	if Save.write_next_level(key, level):
		_file_key = key


# Back and the lifecycle

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			handle_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			_on_leave()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		handle_back()
		get_viewport().set_input_as_handled()


## Losing focus or going to the background: write everything, and cover the board (UX 4.3).
func _on_leave() -> void:
	if state == State.BOOT or state == State.ERROR:
		return
	if state == State.LEVEL and not overlay is HelperSheet:
		# A helper sheet stays open (the clock is already held): pulling down the notification
		# shade must not count as "Got it". A buy dialog just closes.
		_cancel_overlay()
		_show_pause()
	Save.save_all()


## Closes a helper sheet or dialog the way Back does ("Got it", "Not now", "Keep my
## progress"). True if there was one.
func _cancel_overlay() -> bool:
	if overlay == null:
		return false
	if overlay is HelperSheet:
		_helper_sheet_done()
	elif overlay is UiDialog:
		(overlay as UiDialog).cancel()
	else:
		_clear_overlay()
	return true


## The Android back button and gesture, as UX 4.2 says.
func handle_back() -> void:
	if _cancel_overlay():
		return
	match state:
		State.TITLE:
			quit()
		State.MENU:
			_back_from_menu()
		State.LEVEL:
			if not bool(level_scene.call("handle_back")):
				_show_pause()
		State.PAUSE:
			_resume()
		State.CLEAR, State.LOST, State.LOADING, State.ERROR:
			quit_to_title()
		_:
			pass


## Back on a menu goes to its origin: About from License or Credits, the title from Relaxed
## setup, otherwise Pause if the player came from Pause, otherwise the title.
func _back_from_menu() -> void:
	match menu:
		"license", "credits":
			show_menu("about")
		"relaxed":
			show_menu("title")
		_:
			if _paused_level:
				_show_pause()
			else:
				show_menu("title")


func quit() -> void:
	if _shut_down:
		return
	_shut_down = true
	Save.save_all()
	if _check != null:
		_check.cancel()
		_check = null
	_prefetch.shutdown()
	if quit_handler.is_valid():
		quit_handler.call()
	else:
		get_tree().quit()
