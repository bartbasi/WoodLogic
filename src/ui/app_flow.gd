# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name AppFlow
extends Control
## The app: which screen shows, which level is on, and what is saved (docs/ARCHITECTURE.md
## 6 and 10.3, docs/UX.md 4). It talks to the level scene only through ARCHITECTURE section 6.
##
## Phase 3 screens: Title, the level, Pause, Level clear and Out of room. The first launch
## skips the title. Levels come from LevelPrefetcher, polled every frame: the level the
## player waits on is urgent, level N + 1 is asked for as soon as N starts, and the current
## and previous LevelData are kept for Retry and Previous level.

enum State { BOOT, ERROR, TITLE, LOADING, LEVEL, PAUSE, CLEAR, LOST }

const LEVEL_SCENE := "res://src/level/level_scene.tscn"
const NUMBERED := LevelData.NUMBERED

## Tests point this at a small fake level scene.
var level_scene_path := LEVEL_SCENE
## Tests replace this so a Back press on the title doesn't end the test run.
var quit_handler := Callable()

var state: State = State.BOOT
var level_scene: Node
var screen: UiScreen

var _prefetch := LevelPrefetcher.new()
var _current: LevelData
var _previous: LevelData
## Level N + 1 once it has arrived, so Next is one tap.
var _next_ready: LevelData
var _ahead_key := ""
var _wanted_key := ""
var _abandoned: Array[String] = []
var _wanted_number := 0
var _lost_while_paused := false
var _wanted_replay := false
var _replay := false
var _file_key := ""
var _shut_down := false


func _ready() -> void:
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boot()


func _exit_tree() -> void:
	_prefetch.shutdown()


# boot

func _boot() -> void:
	if not LevelCatalog.load_all():
		_show_error()
		return
	Save.load_all()
	Audio.set_sound(Save.sound)
	Audio.set_music(Save.music)
	var n := Save.next_level()
	# A level saved by the last run is played without generating it (ARCHITECTURE 10.3).
	var saved := Save.read_next_level(LevelPrefetcher.key_for(NUMBERED, n, ""), Generator.GENERATOR_VERSION)
	if saved != null:
		_current = saved
		_file_key = "numbered:%d" % n
	if Save.highest_cleared() == 0:
		# First launch (or after a reset): straight into the level, no title (UX 5.1).
		play_number(n)
	else:
		# Ask for the Play level while the title is up.
		if _known(n) == null:
			_request(n, true)
		show_title()


func _show_error() -> void:
	state = State.ERROR
	var s := UiScreen.new()
	s.fade_in = false
	_set_screen(s)
	var label := s.plaque("WoodLogic could not start", "HeadingLabel")
	s.column.add_child(s.spacer())
	s.column.add_child(label)
	s.column.add_child(s.spacer())


# every frame

func _process(_delta: float) -> void:
	_prefetch.poll()
	# Requests nobody wants any more are collected once they finish, so they don't pile up.
	for key: String in _abandoned.duplicate():
		if key == _wanted_key or key == _ahead_key:
			_abandoned.erase(key)
		elif _prefetch.is_ready(key):
			_prefetch.take(key)
			_abandoned.erase(key)
	if _ahead_key != "" and _prefetch.is_ready(_ahead_key):
		var got := _prefetch.take(_ahead_key)
		_ahead_key = ""
		if got != null and got.level != null:
			_next_ready = got.level
			_sync_next_file()
	if state == State.LOADING:
		# The level may have arrived as the one ahead, or be the one asked for urgently.
		var in_hand := _known(_wanted_number)
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


func _title_key_ready() -> bool:
	return _prefetch.is_ready(LevelPrefetcher.key_for(NUMBERED, Save.next_level(), ""))


# screens

func _set_screen(s: UiScreen) -> void:
	_clear_screen()
	screen = s
	add_child(s)


func _clear_screen() -> void:
	if screen != null:
		screen.queue_free()
		screen = null


## Stops wanting a requested level; it is taken and dropped when it finishes.
## Only a request still running needs this; a finished one was already taken or is wanted.
func _abandon(key: String) -> void:
	if key != "" and _prefetch.is_running(key) and not _abandoned.has(key):
		_abandoned.append(key)


## Asks the prefetcher for numbered level n. A key asked for is wanted again, so it leaves
## the abandoned list.
func _request(n: int, urgent: bool) -> String:
	var key := _prefetch.request(NUMBERED, n, "", urgent)
	_abandoned.erase(key)
	return key


func show_title() -> void:
	_lost_while_paused = false
	if state == State.LOADING:
		# The Play button asks for this level next, so a finishing level is kept for it.
		if _wanted_key != LevelPrefetcher.key_for(NUMBERED, Save.next_level(), ""):
			_abandon(_wanted_key)
		_wanted_key = ""
	_free_level_scene()
	state = State.TITLE
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var s := TitleScreen.make(Save.next_level(), version)
	s.play_pressed.connect(func() -> void: play_number(Save.next_level()))
	_set_screen(s)


func _show_loading() -> void:
	state = State.LOADING
	var s := UiScreen.new()
	s.fade_in = false
	_set_screen(s)
	s.column.add_child(s.spacer())
	s.column.add_child(s.plaque("One moment", "HeadingLabel"))
	s.column.add_child(s.spacer())


func _show_pause() -> void:
	state = State.PAUSE
	level_scene.call("pause")
	var s := PauseScreen.make(_current.number, Save.sound, Save.music)
	s.resume_pressed.connect(_resume)
	s.retry_pressed.connect(_retry_from_pause)
	s.quit_pressed.connect(show_title)
	s.sound_toggled.connect(func(on: bool) -> void:
		Save.set_sound(on)
		Audio.set_sound(on))
	s.music_toggled.connect(func(on: bool) -> void:
		Save.set_music(on)
		Audio.set_music(on))
	_set_screen(s)


func _show_clear() -> void:
	state = State.CLEAR
	var s := ClearScreen.make(_current.number)
	s.next_pressed.connect(func() -> void: play_number(_current.number + 1))
	s.replay_pressed.connect(_replay_level)
	_set_screen(s)


func _show_lost() -> void:
	state = State.LOST
	var s := LostScreen.make(_current.number)
	s.retry_pressed.connect(_retry_from_lost)
	s.previous_pressed.connect(func() -> void: play_number(_current.number - 1))
	s.title_pressed.connect(show_title)
	_set_screen(s)


# levels

## The LevelData for level n if it is in hand (current, previous or the one just ahead).
func _known(n: int) -> LevelData:
	for level: LevelData in [_current, _previous, _next_ready]:
		if level != null and level.number == n and (level.kind == NUMBERED or level.kind == LevelData.TUTORIAL):
			return level
	return null


## Puts a newly arrived level in hand without starting it (the Play level made during the
## title). It never replaces the current level of a running game.
func _remember(level: LevelData) -> void:
	if _current == null:
		_current = level
	else:
		_next_ready = level
	_sync_next_file()


## Starts numbered level n. Retry and Previous level reuse the LevelData in hand; others come
## from the prefetcher, or wait for it with a plain "One moment" screen.
func play_number(n: int) -> void:
	n = clampi(n, 1, Save.MAX_LEVEL)
	var replay := n < Save.next_level()
	var level := _known(n)
	if level != null:
		_begin(level, replay)
		return
	var key := LevelPrefetcher.key_for(NUMBERED, n, "")
	_abandoned.erase(key)
	if _prefetch.is_ready(key):
		var made := _prefetch.take(key)
		if made != null and made.level != null:
			_begin(made.level, replay)
			return
	_wanted_key = _request(n, true)
	_wanted_replay = replay
	_wanted_number = n
	_show_loading()


func _begin(level: LevelData, replay: bool) -> void:
	if level != _current:
		_previous = _current
		_current = level
	if level == _next_ready:
		_next_ready = null
	_replay = replay
	_lost_while_paused = false
	if not _ensure_level_scene():
		return
	_clear_screen()
	state = State.LEVEL
	level_scene.call("play", level, replay)
	# Level N + 1 is made while the player plays N.
	var ahead := level.number + 1
	if _known(ahead) == null and ahead <= Save.MAX_LEVEL:
		var key := _request(ahead, false)
		if _ahead_key != "" and _ahead_key != key:
			_abandon(_ahead_key)
		_ahead_key = key
	_sync_next_file()


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
	add_child(level_scene)
	move_child(level_scene, 0)
	return true


func _free_level_scene() -> void:
	if level_scene != null and is_instance_valid(level_scene):
		level_scene.queue_free()
	level_scene = null


func _on_won(result: Object) -> void:
	if state != State.LEVEL and state != State.PAUSE:
		return
	var level: LevelData = result.get("level")
	var elapsed: int = result.get("elapsed_ms")
	var stars: Vector3i = result.get("stars")
	if level == null:
		level = _current
	Save.record_win(level, elapsed, stars)
	_sync_next_file()
	_show_clear()


func _on_lost(_level: LevelData) -> void:
	if state == State.PAUSE:
		# The loss is kept and shown when the player resumes.
		_lost_while_paused = true
		return
	if state != State.LEVEL:
		return
	_show_lost()


func _on_pause_requested() -> void:
	if state == State.LEVEL:
		_show_pause()


func _resume() -> void:
	if state != State.PAUSE:
		return
	_clear_screen()
	state = State.LEVEL
	level_scene.call("resume")
	if _lost_while_paused:
		_lost_while_paused = false
		_show_lost()


## Retry from Pause. The scene is paused, so it is resumed first; its retry then restarts the
## level with the clock waiting for the first action.
func _retry_from_pause() -> void:
	_lost_while_paused = false
	_clear_screen()
	state = State.LEVEL
	level_scene.call("resume")
	level_scene.call("retry")


func _retry_from_lost() -> void:
	_clear_screen()
	state = State.LEVEL
	level_scene.call("retry")


func _replay_level() -> void:
	_begin(_current, true)


## Keeps next_level.json holding the level Play will start at (the saved next level): when
## the level for Save.next_level() is in hand and was generated, it is written once.
func _sync_next_file() -> void:
	var n := Save.next_level()
	var level := _known(n)
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
	if state == State.LEVEL:
		_show_pause()
	Save.save_all()


## The Android back button and gesture, as UX 4.2 says.
func handle_back() -> void:
	match state:
		State.TITLE:
			quit()
		State.LEVEL:
			if not bool(level_scene.call("handle_back")):
				_show_pause()
		State.PAUSE:
			_resume()
		State.CLEAR, State.LOST, State.LOADING, State.ERROR:
			show_title()
		_:
			pass


func quit() -> void:
	if _shut_down:
		return
	_shut_down = true
	Save.save_all()
	_prefetch.shutdown()
	if quit_handler.is_valid():
		quit_handler.call()
	else:
		get_tree().quit()
