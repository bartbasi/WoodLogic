# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelAnim
extends RefCounted
## One timed motion, run by the level scene's frame loop. It waits `delay` seconds, then runs
## for `duration`. `finish()` jumps to the end (the test mode), `cancel()` drops it where it is
## (another motion took over). Motions only show what the logic already decided.

var delay := 0.0
var duration := 0.0
var done := false
## Called once, after the final frame has been applied (not after a cancel).
var on_done := Callable()
var _t := 0.0
var _started := false


## Advances by dt seconds. True once it is finished.
func step(dt: float) -> bool:
	if done:
		return true
	_t += dt
	var local := _t - delay
	if local < 0.0:
		return false
	if not _started:
		_started = true
		_begin()
	if local >= duration:
		_apply(duration)
		_end()
		return true
	_apply(local)
	return false


## Jumps to the end and finishes.
func finish() -> void:
	if done:
		return
	if not _started:
		_started = true
		_begin()
	_apply(duration)
	_end()


## Stops where it is, without calling on_done.
func cancel() -> void:
	done = true
	on_done = Callable()
	_release()


## Seconds until it is over.
func remaining() -> float:
	return 0.0 if done else maxf(0.0, delay + duration - _t)


func _end() -> void:
	done = true
	if on_done.is_valid():
		on_done.call()
	on_done = Callable()
	_release()


## Lets go of what the motion holds on to (slots, callbacks), so no reference cycle keeps a
## finished motion and its slot alive.
func _release() -> void:
	pass


func _begin() -> void:
	pass


func _apply(_local: float) -> void:
	pass


static func out_cubic(x: float) -> float:
	var y := 1.0 - x
	return 1.0 - y * y * y


static func in_cubic(x: float) -> float:
	return x * x * x


static func in_quad(x: float) -> float:
	return x * x


static func out_quad(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


static func in_out_sine(x: float) -> float:
	return 0.5 - 0.5 * cos(PI * x)


## Overshoots by about 8 percent and settles.
static func out_back(x: float) -> float:
	var s := 1.5
	var y := x - 1.0
	return 1.0 + (s + 1.0) * y * y * y + s * y * y
