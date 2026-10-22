# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name SavedLevelCheck
extends RefCounted
## Solves the level read from next_level.json again on a worker thread, so the title shows at
## once (a hard level takes about half a second on a PC, several times that on a phone). The
## worker only reads the level and runs the solver: it never touches Save or any node. The task
## holds this object in a lambda, so it lives until the task is done even if the app flow lets
## go of it, and the main thread waits for the task before it lets go (finish) or at quit
## (cancel, then finish: the search stops within a few milliseconds).

var level: LevelData
var tier := 1
var number := 0
var stop := GenerationStop.new()
## Read on the main thread only after is_done().
var passed := false
var _task := -1


func start() -> void:
	_task = WorkerThreadPool.add_task(func() -> void: _run(), true, "WoodLogic saved level check")


func _run() -> void:
	passed = AppFlow.saved_level_solves(level, tier, stop)


## True once the worker has finished (never waits).
func is_done() -> bool:
	return _task >= 0 and WorkerThreadPool.is_task_completed(_task)


## Waits for the task (it is done or about to be) so nothing still runs.
func finish() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## Asks the search to stop, then waits. For quitting.
func cancel() -> void:
	stop.request()
	finish()
