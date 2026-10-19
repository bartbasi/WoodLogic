# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelPrefetcher
extends RefCounted
## Makes levels on WorkerThreadPool so generation never blocks a frame (docs/ARCHITECTURE.md
## 4.4). The app flow owns one, calls poll() every frame, and asks for level N + 1 as soon as
## level N starts. Main thread only; the worker side touches nothing but its own job.

## One running request. The worker writes `result` once; the main thread reads it only after
## wait_for_task_completion, so no lock is needed.
class Job extends RefCounted:
	var kind: int
	var number: int
	var band: String
	var result: GeneratedLevel

	func run() -> void:
		result = LevelCatalog.get_level(kind, number, band)


## Key to WorkerThreadPool task id, for running jobs.
var _tasks := {}
## Key to Job, for running jobs.
var _jobs := {}
## Key to GeneratedLevel, for finished ones not yet taken.
var _ready := {}


## "numbered:42", "daily:20261019", "relaxed:easy:7".
static func key_for(kind: int, number: int, band: String) -> String:
	if kind == LevelData.RELAXED:
		return "relaxed:%s:%d" % [band, number]
	return "%s:%d" % [LevelData.KIND_NAMES[kind], number]


## Starts making a level unless that key is already done or running. Returns the key.
## urgent: the player is waiting for this one, so it goes on WorkerThreadPool as high
## priority, ahead of low priority jobs that have not started. A job already running keeps
## its priority; asking again with urgent while it runs changes nothing.
func request(kind: int, number: int, band: String, urgent: bool = false) -> String:
	var key := key_for(kind, number, band)
	if _ready.has(key) or _tasks.has(key):
		return key
	var job := Job.new()
	job.kind = kind
	job.number = number
	job.band = band
	_jobs[key] = job
	_tasks[key] = WorkerThreadPool.add_task(job.run, urgent, "WoodLogic level " + key)
	return key


## Collects finished jobs. Call every frame.
func poll() -> void:
	var done := PackedStringArray()
	for key: String in _tasks:
		if WorkerThreadPool.is_task_completed(_tasks[key]):
			done.append(key)
	for key: String in done:
		_collect(key)


func is_ready(key: String) -> bool:
	return _ready.has(key)


func is_running(key: String) -> bool:
	return _tasks.has(key)


## The finished level, removed from the cache; null if it is not ready yet.
func take(key: String) -> GeneratedLevel:
	if not _ready.has(key):
		return null
	var level: GeneratedLevel = _ready[key]
	_ready.erase(key)
	return level


## Waits for every running job. The app flow calls it before quitting.
func shutdown() -> void:
	var keys := PackedStringArray()
	for key: String in _tasks:
		keys.append(key)
	for key: String in keys:
		_collect(key)


func _collect(key: String) -> void:
	WorkerThreadPool.wait_for_task_completion(_tasks[key])
	var job: Job = _jobs[key]
	_tasks.erase(key)
	_jobs.erase(key)
	if job.result != null:
		_ready[key] = job.result
