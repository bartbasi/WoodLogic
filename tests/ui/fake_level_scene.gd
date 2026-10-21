# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name FakeLevelScene
extends Control
## A small stand-in for the level scene (ARCHITECTURE section 6) for the app flow tests. It
## records what the flow asks and emits won and lost on demand.

signal won(result: FakeLevelResult)
signal lost(level: LevelData)
signal pause_requested
signal helper_used(helper: String)
signal helper_buy_requested(helper: String)
signal first_action
signal coffee_requested

var played: Array[LevelData] = []
var replays: Array[bool] = []
var retries := 0
var pauses := 0
var resumes := 0
var is_paused := false
## For each play(): was the scene still paused when it was asked to play? (A level started on a
## paused scene would be frozen.)
var plays_while_paused: Array[bool] = []
var looks_refreshed := 0
var back_handled := false
var coffee_on := false
var star_bank := 0
var counts: Dictionary = {}
var shown := PackedStringArray()
var highlighted := ""
var used: Array[String] = []
var holds := 0
var usable := PackedStringArray()


func play(level: LevelData, replay: bool) -> void:
	played.append(level)
	replays.append(replay)
	plays_while_paused.append(is_paused)


func retry() -> void:
	retries += 1
	is_paused = false


func pause() -> void:
	if is_paused:
		return
	pauses += 1
	is_paused = true


func resume() -> void:
	resumes += 1
	is_paused = false


func hold_clock(on: bool) -> void:
	holds += 1 if on else 0


func set_coffee(on: bool) -> void:
	coffee_on = on


func handle_back() -> bool:
	return back_handled


func set_star_bank(stars: int) -> void:
	star_bank = stars


func set_helpers(new_counts: Dictionary, new_shown: PackedStringArray) -> void:
	counts = new_counts
	shown = new_shown


func highlight_helper(helper: String) -> void:
	highlighted = helper


## Like the real scene: using a helper takes effect and says so.
func use_helper(helper: String) -> void:
	used.append(helper)
	helper_used.emit(helper)


func usable_after_loss() -> PackedStringArray:
	return usable


func set_instant(_on: bool) -> void:
	pass


func debug_snapshot() -> Dictionary:
	return {}


## Test helpers: the player wins or loses the level last played.
func win(ms: int = 12000, stars: Vector3i = Vector3i(1, 1, 1)) -> void:
	var r := FakeLevelResult.new()
	r.level = played[-1]
	r.elapsed_ms = ms
	r.stars = stars
	won.emit(r)


func lose() -> void:
	lost.emit(played[-1])


func refresh_looks() -> void:
	looks_refreshed += 1
