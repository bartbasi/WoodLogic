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

var played: Array[LevelData] = []
var replays: Array[bool] = []
var retries := 0
var pauses := 0
var resumes := 0
var is_paused := false
var back_handled := false


func play(level: LevelData, replay: bool) -> void:
	played.append(level)
	replays.append(replay)
	is_paused = false


func retry() -> void:
	retries += 1
	is_paused = false


func pause() -> void:
	pauses += 1
	is_paused = true


func resume() -> void:
	resumes += 1
	is_paused = false


func hold_clock(_on: bool) -> void:
	pass


func handle_back() -> bool:
	return back_handled


func set_star_bank(_stars: int) -> void:
	pass


func set_helpers(_counts: Dictionary, _shown: PackedStringArray) -> void:
	pass


func highlight_helper(_helper: String) -> void:
	pass


func use_helper(_helper: String) -> void:
	pass


func usable_after_loss() -> PackedStringArray:
	return PackedStringArray()


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
