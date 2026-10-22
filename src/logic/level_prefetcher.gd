# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelPrefetcher
extends RefCounted
## Makes levels on WorkerThreadPool so generation never blocks a frame (docs/ARCHITECTURE.md
## 4.4). The app flow owns one, calls poll() every frame, and asks for level N + 1 as soon as
## level N starts. Main thread only; the worker side touches nothing but its own job.
##
## For each key:
## - request() on a new key queues one task, high priority if urgent, else low.
## - request() with urgent on a key that is queued at low priority and has not started promotes
##   it: a second task, high priority, for the same job. Whichever task starts first makes the
##   level; the other finds it taken and returns at once, so the level is made once.
## - request() on a key that is running, finished or ready changes nothing (a running job keeps
##   its priority; WorkerThreadPool can't change it). Nothing ever demotes a key.
## - poll() moves a finished job's level to the ready ones; take() hands it out once.
## - shutdown() stops every job not yet collected (GenerationStop), waits for their tasks (each
##   returns within a few milliseconds) and throws their results away. Levels already ready
##   stay ready. The prefetcher works as new afterwards.
##
## A Job lives as long as any of its tasks: a method Callable such as job.run does not keep its
## object alive, so every task runs a lambda that holds the job, and the prefetcher keeps
## [task id, job] for a task it has not waited for yet (_leftover).

## One level being made. run() may be called by two tasks (see request); the first claims the
## job and makes the level, the second returns at once. The worker writes result once, under
## the mutex; the main thread reads it only after is_finished() says so.
class Job extends RefCounted:
	var kind: int
	var number: int
	var band: String
	var result: GeneratedLevel
	var stop := GenerationStop.new()
	## A high priority task was queued for it (urgent from the start, or promoted).
	var high := false
	var _mutex := Mutex.new()
	var _claimed := false
	var _finished := false

	func run() -> void:
		_mutex.lock()
		var mine := not _claimed
		_claimed = true
		_mutex.unlock()
		if not mine:
			return
		var made := LevelCatalog.get_level(kind, number, band, stop)
		_mutex.lock()
		result = made
		_finished = true
		_mutex.unlock()

	## A task has started making the level.
	func is_started() -> bool:
		_mutex.lock()
		var started := _claimed
		_mutex.unlock()
		return started

	## The level is made (result is set).
	func is_finished() -> bool:
		_mutex.lock()
		var done := _finished
		_mutex.unlock()
		return done


## Key to Job, for jobs not yet collected.
var _jobs := {}
## Key to its WorkerThreadPool task ids (one, or two once promoted).
var _tasks := {}
## [task id, Job] for tasks of collected jobs that had not finished yet (a promoted job's other
## task, or the making task in the moment after it set the result): waited for once done.
var _leftover: Array[Array] = []
## Key to GeneratedLevel, for finished ones not yet taken.
var _ready := {}


## "numbered:42", "daily:20261019", "relaxed:easy:7".
static func key_for(kind: int, number: int, band: String) -> String:
	if kind == LevelData.RELAXED:
		return "relaxed:%s:%d" % [band, number]
	return "%s:%d" % [LevelData.KIND_NAMES[kind], number]


## Starts making a level unless that key is already ready or running, and promotes a queued key
## when urgent (see the top). Returns the key. urgent: the player is waiting for this one, so it
## goes on WorkerThreadPool as high priority, ahead of low priority jobs that have not started.
func request(kind: int, number: int, band: String, urgent: bool = false) -> String:
	var key := key_for(kind, number, band)
	if _ready.has(key):
		return key
	if _jobs.has(key):
		var queued: Job = _jobs[key]
		if urgent and not queued.high and not queued.is_started():
			queued.high = true
			var ids: PackedInt64Array = _tasks[key]
			ids.append(_add_task(queued, true, key))
			_tasks[key] = ids
		return key
	var job := Job.new()
	job.kind = kind
	job.number = number
	job.band = band
	job.high = urgent
	_jobs[key] = job
	_tasks[key] = PackedInt64Array([_add_task(job, urgent, key)])
	return key


## Queues a task that runs the job. The lambda holds the job, so it outlives the task even once
## the prefetcher lets go of it.
func _add_task(job: Job, high: bool, key: String) -> int:
	return WorkerThreadPool.add_task(func() -> void: job.run(), high, "WoodLogic level " + key)


## Collects finished jobs. Call every frame. Never waits on a task that is still running.
func poll() -> void:
	var done := PackedStringArray()
	for key: String in _jobs:
		if (_jobs[key] as Job).is_finished():
			done.append(key)
	for key: String in done:
		_collect(key)
	var still: Array[Array] = []
	for pair: Array in _leftover:
		if WorkerThreadPool.is_task_completed(pair[0]):
			WorkerThreadPool.wait_for_task_completion(pair[0])
		else:
			still.append(pair)
	_leftover = still


func is_ready(key: String) -> bool:
	return _ready.has(key)


## Asked for and not collected yet (queued or being made).
func is_running(key: String) -> bool:
	return _jobs.has(key)


## The finished level, removed from the cache; null if it is not ready yet.
func take(key: String) -> GeneratedLevel:
	if not _ready.has(key):
		return null
	var level: GeneratedLevel = _ready[key]
	_ready.erase(key)
	return level


## Stops every job not yet collected, waits for its tasks and for every leftover task, and throws
## the stopped results away (see the top). The app flow calls it before quitting; it returns
## within a few milliseconds even in the middle of a long generation (a leftover task returns
## at once when it runs, so it waits only for whatever else the pool is running ahead of it).
func shutdown() -> void:
	for key: String in _jobs:
		(_jobs[key] as Job).stop.request()
	for key: String in _tasks:
		for id: int in (_tasks[key] as PackedInt64Array):
			WorkerThreadPool.wait_for_task_completion(id)
	for pair: Array in _leftover:
		WorkerThreadPool.wait_for_task_completion(pair[0])
	_jobs.clear()
	_tasks.clear()
	_leftover = []


## A finished job: its level to the ready ones (unless stopped), its tasks waited for or left
## for poll() when one has not finished yet (a promoted job's other task).
func _collect(key: String) -> void:
	var job: Job = _jobs[key]
	for id: int in (_tasks[key] as PackedInt64Array):
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
		else:
			_leftover.append([id, job])
	_jobs.erase(key)
	_tasks.erase(key)
	if job.result != null and not job.result.stopped:
		_ready[key] = job.result
