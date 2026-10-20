# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelClock
extends RefCounted
## The level's clock (GDD S6, UX 3.2.2). It starts at the first action, stops while paused or
## held (a sheet or a dialog), and stops for good at the win and at a loss. It never reads the
## time itself: the caller passes in a millisecond count, so tests can drive it.

var started := false
var finished := false
var _paused := false
var _held := false
var _accumulated := 0
var _since := 0


func reset() -> void:
	started = false
	finished = false
	_paused = false
	_held = false
	_accumulated = 0
	_since = 0


## Starts the clock. True if this call started it (the first action).
func start(now_ms: int) -> bool:
	if started:
		return false
	started = true
	_since = now_ms
	return true


func is_running() -> bool:
	return started and not finished and not _paused and not _held


func elapsed_ms(now_ms: int) -> int:
	if is_running():
		return _accumulated + maxi(0, now_ms - _since)
	return _accumulated


func set_paused(on: bool, now_ms: int) -> void:
	_commit(now_ms)
	_paused = on


func set_held(on: bool, now_ms: int) -> void:
	_commit(now_ms)
	_held = on


## Stops for good (a win or a loss).
func stop(now_ms: int) -> void:
	_commit(now_ms)
	finished = true


## A loss was cleared: the clock goes on from where it stopped (GDD R37).
func resume_after_stop(now_ms: int) -> void:
	_commit(now_ms)
	finished = false
	_since = now_ms


func _commit(now_ms: int) -> void:
	if is_running():
		_accumulated += maxi(0, now_ms - _since)
	_since = now_ms
