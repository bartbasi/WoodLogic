# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name GenerationStop
extends RefCounted
## Asks one level being made on a worker thread to give up (docs/ARCHITECTURE.md 4.4). The
## main thread calls request(); Generator.make checks it between tries and the solver's search
## every CHECK_EVERY states it expands, so a stopped make returns within a few milliseconds. A
## stopped make hands out no level (GeneratedLevel.stopped). One per request, never shared or
## static, so stopping one level never touches another and nothing needs resetting. A make that
## is never stopped is exactly the make without one: the checks change no choice.

## How many states the solver expands between checks.
const CHECK_EVERY := 1024

var _mutex := Mutex.new()
var _requested := false


## Asks the level to stop. Any thread; it stays asked.
func request() -> void:
	_mutex.lock()
	_requested = true
	_mutex.unlock()


func is_requested() -> bool:
	_mutex.lock()
	var asked := _requested
	_mutex.unlock()
	return asked
