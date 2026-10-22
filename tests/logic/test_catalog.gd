# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## LevelCatalog and LevelPrefetcher (docs/ARCHITECTURE.md 3 and 4.4).

const TEMP_DIR := "user://test_catalog_files"

## Set while a test has replaced LevelCatalog's fallback levels; cleanup() reloads them.
var _fallback_replaced := false


func test_load_all_reads_tuning_blueprints_tutorials_and_fallbacks() -> void:
	check(LevelCatalog.load_all(), "loads cleanly")
	check(LevelCatalog.is_loaded(), "loaded")
	check_eq(LevelCatalog.blueprints.size(), LevelCatalog.json_files(LevelCatalog.BLUEPRINT_DIR).size(), "every blueprint file")
	for i: int in range(1, LevelCatalog.blueprints.size()):
		check(LevelCatalog.blueprints[i - 1].id < LevelCatalog.blueprints[i].id, "blueprints sorted by id")
	check_eq(LevelCatalog.tutorials.size(), Tuning.tutorial_levels, "every tutorial level")
	check_eq(LevelCatalog.fallback.size(), Tuning.tiers.size(), "a fallback list per tier")
	check_eq(LevelCatalog.relaxed_fallback.size(), Tuning.tiers.size(), "and a Relaxed one")
	check(not (LevelCatalog.numbered_schedule[2] as PackedInt32Array).is_empty(), "a schedule for the numbered levels")
	check(LevelCatalog.load_all(), "a second call does nothing and is fine")


func test_suits_need_screws_layers_and_enough_cover_for_tray_tiers() -> void:
	LevelCatalog.load_all()
	var robot := LevelCatalog.blueprint_index("robot")
	var bricks := LevelCatalog.blueprint_index("bricks")
	check(not LevelCatalog.suits[3].has(robot), "robot (nothing covered) does not suit tier 4, which needs the tray")
	check(LevelCatalog.suits[4].has(bricks), "bricks (12 covered) suits tier 5")
	for t: int in Tuning.tiers.size():
		check(LevelCatalog.suits[t].size() > Tuning.recent_blueprints_excluded, "tier %d has more blueprints than G7 looks back (%d)" % [t + 1, LevelCatalog.suits[t].size()])


func test_get_level_serves_the_tutorial_for_levels_1_to_8() -> void:
	LevelCatalog.load_all()
	for n: int in range(1, Tuning.tutorial_levels + 1):
		var g := LevelCatalog.get_level(LevelData.NUMBERED, n, "")
		check(g.level == LevelCatalog.tutorials[n - 1], "level %d is tutorial %d" % [n, n])
		check(g.solve.solved and g.solve.complete and g.solve.fewest_tray_uses == 0, "tutorial %d solved" % n)
	var g9 := LevelCatalog.get_level(LevelData.NUMBERED, 9, "")
	check(g9.level.kind == LevelData.NUMBERED and g9.level.number == 9, "level 9 is generated")


func test_json_files_lists_json_and_remapped_json_sorted() -> void:
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	for name: String in ["b.json", "a.json.remap", "c.txt", "b.json.remap"]:
		var f := FileAccess.open(TEMP_DIR.path_join(name), FileAccess.WRITE)
		f.store_string("{}")
		f.close()
	check_eq(LevelCatalog.json_files(TEMP_DIR), PackedStringArray([TEMP_DIR.path_join("a.json"), TEMP_DIR.path_join("b.json")]), "a.json (from a.json.remap) and b.json, once each")
	check_eq(LevelCatalog.json_files("user://no_such_folder"), PackedStringArray(), "a missing folder lists nothing")
	for name: String in DirAccess.get_files_at(TEMP_DIR):
		DirAccess.remove_absolute(TEMP_DIR.path_join(name))
	DirAccess.remove_absolute(TEMP_DIR)


func test_a_broken_fallback_file_makes_loading_fail() -> void:
	LevelCatalog.load_all()
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	var good := FileAccess.get_file_as_string(LevelCatalog.FALLBACK_DIR.path_join("tier-01.json"))
	for pair: Array in [["tier-01.json", good], ["tier-02.json", "{ broken"]]:
		var f := FileAccess.open(TEMP_DIR.path_join(pair[0]), FileAccess.WRITE)
		f.store_string(pair[1])
		f.close()
	var errors := PackedStringArray()
	_fallback_replaced = true
	var ok := LevelCatalog.read_fallback(TEMP_DIR, errors)
	check(not ok and errors.size() == 1 and errors[0].contains("tier-02.json"), "a broken fallback file is reported: %s" % "; ".join(errors))
	check(LevelCatalog.fallback[0].size() > 0, "the good file still loads")
	check(LevelCatalog.reload_fallback(), "the shipped fallback files load again")
	_fallback_replaced = false
	for name: String in DirAccess.get_files_at(TEMP_DIR):
		DirAccess.remove_absolute(TEMP_DIR.path_join(name))
	DirAccess.remove_absolute(TEMP_DIR)


func test_relaxed_files_load_into_the_relaxed_pool() -> void:
	# relaxed-<t>.json files hold levels made with Relaxed's tray (Generator.stored_pool); they
	# load beside the tier's own, never into it.
	LevelCatalog.load_all()
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	for name: String in ["tier-07.json", "relaxed-07.json"]:
		var f := FileAccess.open(TEMP_DIR.path_join(name), FileAccess.WRITE)
		f.store_string(FileAccess.get_file_as_string(LevelCatalog.FALLBACK_DIR.path_join(name)))
		f.close()
	var errors := PackedStringArray()
	_fallback_replaced = true
	check(LevelCatalog.read_fallback(TEMP_DIR, errors), "both load: %s" % "; ".join(errors))
	var own: Array = LevelCatalog.fallback[6]
	var relaxed: Array = LevelCatalog.relaxed_fallback[6]
	check(not own.is_empty() and not relaxed.is_empty(), "tier 7 has both")
	for g: GeneratedLevel in own:
		check_eq(g.level.tray_size, Tuning.tier(7).tray, "%s: the tier's tray in the tier's pool" % g.level.id)
	for g: GeneratedLevel in relaxed:
		check_eq(g.level.tray_size, Tuning.relaxed_tray, "%s: Relaxed's tray in the Relaxed pool" % g.level.id)
	var others := 0
	for t: int in Tuning.tiers.size():
		if t != 6:
			others += LevelCatalog.fallback[t].size() + LevelCatalog.relaxed_fallback[t].size()
	check_eq(others, 0, "nothing else")
	check(LevelCatalog.reload_fallback(), "the shipped fallback files load again")
	_fallback_replaced = false
	for name: String in DirAccess.get_files_at(TEMP_DIR):
		DirAccess.remove_absolute(TEMP_DIR.path_join(name))
	DirAccess.remove_absolute(TEMP_DIR)


func test_fallback_file_reader_rejects_bad_files() -> void:
	var errors := PackedStringArray()
	check(LevelCatalog.parse_fallback("{", errors).is_empty() and not errors.is_empty(), "not JSON")
	errors.clear()
	check(LevelCatalog.parse_fallback('{"format": 1, "tier": 1, "levels": [{"level": {}}]}', errors).is_empty() and not errors.is_empty(), "no solve")
	errors.clear()
	var good := FileAccess.get_file_as_string(LevelCatalog.FALLBACK_DIR.path_join("tier-01.json"))
	check(LevelCatalog.parse_fallback(good.replace('"tier": 1,', '"tier": 2,'), errors).is_empty() and not errors.is_empty(), "levels of another tier than the file's")
	errors.clear()
	check(not LevelCatalog.parse_fallback(good, errors).is_empty() and errors.is_empty(), "the shipped file reads")


func test_prefetcher_makes_levels_on_worker_threads() -> void:
	LevelCatalog.load_all()
	var p := LevelPrefetcher.new()
	var key := p.request(LevelData.NUMBERED, 12, "")
	check_eq(key, "numbered:12", "the key")
	check_eq(p.request(LevelData.NUMBERED, 12, ""), key, "asking again is the same request")
	var daily := p.request(LevelData.DAILY, 20261019, "")
	var relaxed := p.request(LevelData.RELAXED, 7, "easy")
	check_eq([daily, relaxed], ["daily:20261019", "relaxed:easy:7"], "keys")
	var started := Time.get_ticks_msec()
	while not (p.is_ready(key) and p.is_ready(daily) and p.is_ready(relaxed)) and Time.get_ticks_msec() - started < 60000:
		p.poll()
		await tree.process_frame
	check(p.is_ready(key) and p.is_ready(daily) and p.is_ready(relaxed), "all three ready")
	var g := p.take(key)
	check(g != null and g.level.fingerprint() == LevelCatalog.get_level(LevelData.NUMBERED, 12, "").level.fingerprint(), "the same level as asking directly")
	check(p.take(key) == null, "taken once")
	check(not p.is_ready(key), "no longer ready")
	p.shutdown()


func test_prefetcher_an_urgent_request_promotes_a_queued_key() -> void:
	# Twelve slow levels at low priority, then a quick one behind them, then the quick one again
	# as urgent: it is promoted, so it is ready long before the slow ones are all done. (Without
	# the promotion it would wait for most of them: low priority tasks get only part of the
	# pool's threads.)
	LevelCatalog.load_all()
	var p := LevelPrefetcher.new()
	var slow: Array[String] = []
	for n: int in range(100, 112):
		slow.append(p.request(LevelData.NUMBERED, n, ""))
	var quick := p.request(LevelData.RELAXED, 3, "easy")
	check(p.is_running(quick), "queued")
	check_eq(p.request(LevelData.RELAXED, 3, "easy", true), quick, "the urgent request names the same key")
	check_eq(p.request(LevelData.RELAXED, 3, "easy", true), quick, "asking again changes nothing")
	var started := Time.get_ticks_msec()
	while not p.is_ready(quick) and Time.get_ticks_msec() - started < 60000:
		p.poll()
		await tree.process_frame
	check(p.is_ready(quick), "the promoted level is ready")
	var slow_ready := 0
	for key: String in slow:
		slow_ready += 1 if p.is_ready(key) else 0
	check(slow_ready < slow.size(), "before the slow levels queued ahead of it (%d of %d ready)" % [slow_ready, slow.size()])
	var g := p.take(quick)
	check(g != null and g.level.fingerprint() == LevelCatalog.get_level(LevelData.RELAXED, 3, "easy").level.fingerprint(), "the same level as asking directly")
	p.shutdown()


func test_prefetcher_job_makes_its_level_once() -> void:
	# A promoted job has two tasks; the second to start finds the job taken and returns.
	LevelCatalog.load_all()
	var job := LevelPrefetcher.Job.new()
	job.kind = LevelData.RELAXED
	job.number = 3
	job.band = "easy"
	check(not job.is_started() and not job.is_finished(), "not started")
	job.run()
	var first := job.result
	check(job.is_started() and job.is_finished() and first != null and first.level != null, "made")
	job.run()
	check(job.result == first, "a second run makes nothing")


func test_prefetcher_keeps_a_promoted_job_alive_until_its_other_task_has_run() -> void:
	# Code review 6: a promoted job's low priority task can still be queued after poll() has
	# collected the job. The job must live until that task has run (a method Callable alone does
	# not keep it), then go. Busy low priority tasks of our own hold the twin in the queue.
	LevelCatalog.load_all()
	for round: int in 2:
		var blockers := _block_low_priority_threads()
		var p := LevelPrefetcher.new()
		var key := p.request(LevelData.NUMBERED, 3, "")
		var ref: WeakRef = weakref(p.get("_jobs")[key])
		p.request(LevelData.NUMBERED, 3, "", true)
		var started := Time.get_ticks_msec()
		while not p.is_ready(key) and Time.get_ticks_msec() - started < 10000:
			p.poll()
			await tree.process_frame
		check(p.is_ready(key) and not p.is_running(key), "round %d: the promoted level is ready and collected" % round)
		check_eq((p.get("_leftover") as Array).size(), 1, "round %d: its other task is still queued" % round)
		check(ref.get_ref() != null, "round %d: so the job is still alive" % round)
		if round == 0:
			# Waited for by poll() once it has run.
			for id: int in blockers:
				WorkerThreadPool.wait_for_task_completion(id)
			started = Time.get_ticks_msec()
			while not (p.get("_leftover") as Array).is_empty() and Time.get_ticks_msec() - started < 10000:
				p.poll()
				await tree.process_frame
			check((p.get("_leftover") as Array).is_empty(), "poll() waits for it once it has run")
		else:
			# Waited for by shutdown(), cleanly.
			p.shutdown()
			check((p.get("_leftover") as Array).is_empty() and p.is_ready(key), "shutdown() waits for it and keeps the ready level")
			for id: int in blockers:
				WorkerThreadPool.wait_for_task_completion(id)
		check(ref.get_ref() == null, "round %d: then the job is freed" % round)
		check(p.take(key).level == LevelCatalog.tutorials[2], "round %d: the level is tutorial 3" % round)


## Low priority tasks that keep the pool's low priority threads busy for a while, so a low
## priority task queued after them waits.
func _block_low_priority_threads() -> Array[int]:
	var ids: Array[int] = []
	for i: int in 2 * OS.get_processor_count():
		ids.append(WorkerThreadPool.add_task(func() -> void: OS.delay_msec(150), false, "test blocker"))
	return ids


func test_prefetcher_shutdown_stops_running_jobs_and_drops_them() -> void:
	LevelCatalog.load_all()
	var p := LevelPrefetcher.new()
	var done := p.request(LevelData.NUMBERED, 12, "")
	var started := Time.get_ticks_msec()
	while not p.is_ready(done) and Time.get_ticks_msec() - started < 60000:
		p.poll()
		await tree.process_frame
	check(p.is_ready(done), "a level made before shutdown")
	# Slow levels (tiers 7 to 10, seconds each on a phone), urgent and not, given time to start.
	var keys: Array[String] = []
	for n: int in range(150, 156):
		keys.append(p.request(LevelData.NUMBERED, n, "", n % 2 == 0))
	keys.append(p.request(LevelData.RELAXED, 0, "hard", true))
	await frames(3)
	started = Time.get_ticks_msec()
	p.shutdown()
	var waited := Time.get_ticks_msec() - started
	check(waited < 1000, "shutdown stops the generations instead of waiting for them (%d ms)" % waited)
	for key: String in keys:
		check(not p.is_ready(key) and not p.is_running(key), "%s is dropped" % key)
	check(p.is_ready(done), "a level already made stays ready")
	# The prefetcher works as new afterwards, and makes the same levels.
	var again := p.request(LevelData.NUMBERED, 150, "", true)
	started = Time.get_ticks_msec()
	while not p.is_ready(again) and Time.get_ticks_msec() - started < 60000:
		p.poll()
		await tree.process_frame
	var g := p.take(again)
	check(g != null and not g.stopped and g.level.fingerprint() == LevelCatalog.get_level(LevelData.NUMBERED, 150, "").level.fingerprint(), "a later request makes the same level as asking directly")
	p.shutdown()


func test_a_stopped_make_hands_out_no_level() -> void:
	LevelCatalog.load_all()
	var stop := GenerationStop.new()
	check(not stop.is_requested(), "not asked yet")
	var kept := Generator.make(LevelData.NUMBERED, 150, "", stop)
	check(not kept.stopped and kept.level != null, "a stop never asked changes nothing")
	check_eq(kept.level.fingerprint(), Generator.make(LevelData.NUMBERED, 150, "").level.fingerprint(), "the same level as without one")
	stop.request()
	check(stop.is_requested(), "asked")
	var g := Generator.make(LevelData.NUMBERED, 150, "", stop)
	check(g.stopped and g.level == null and g.solve == null and not g.fell_back and g.attempts == 0, "stopped at once, no level and no fallback")
	var t := LevelCatalog.get_level(LevelData.NUMBERED, 3, "", stop)
	check(t.stopped and t.level == null, "a tutorial level asked to stop comes back stopped too")
	# A big search (level 129 with 7 slots and no safe move rule takes over 100000 states).
	var level := Generator.with_tray(LevelCatalog.get_level(LevelData.NUMBERED, 129, "").level, 7)
	var full := Solver.search_only(level, 1000000, false)
	var r := Solver.search_only(level, 1000000, false, -1, stop)
	check(full.complete and not r.complete and r.states * 4 < full.states, "a search asked to stop ends early (%d of %d states)" % [r.states, full.states])


func test_a_make_stopped_from_another_thread_ends_quickly() -> void:
	# The stop is asked while the worker is busy (or, on a fast machine, after it is done: then
	# the level is whole).
	LevelCatalog.load_all()
	var stop := GenerationStop.new()
	var thread := Thread.new()
	thread.start(func() -> GeneratedLevel: return Generator.make(LevelData.NUMBERED, 152, "", stop))
	await frames(2)
	var started := Time.get_ticks_msec()
	stop.request()
	var g: GeneratedLevel = thread.wait_to_finish()
	var waited := Time.get_ticks_msec() - started
	check(waited < 1000, "it ends soon after the stop (%d ms)" % waited)
	check(g.stopped == (g.level == null), "stopped exactly when it has no level")
	if not g.stopped:
		check_eq(g.level.fingerprint(), Generator.make(LevelData.NUMBERED, 152, "").level.fingerprint(), "a whole level is the usual one")


func cleanup() -> void:
	if _fallback_replaced:
		LevelCatalog.reload_fallback()
		_fallback_replaced = false
	for name: String in DirAccess.get_files_at(TEMP_DIR) if DirAccess.dir_exists_absolute(TEMP_DIR) else PackedStringArray():
		DirAccess.remove_absolute(TEMP_DIR.path_join(name))
	DirAccess.remove_absolute(TEMP_DIR)
	await super()
