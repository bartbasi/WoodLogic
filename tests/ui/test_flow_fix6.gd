# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends FlowCase
## Phase 6 fixes: the prefetch order and its job limit, the saved next level checked before it
## is played, the Home tab, the clear screen notes and the gift count-up.

var _saved_gifts: Array[Dictionary] = []
var _gifts_swapped := false


func cleanup() -> void:
	if _gifts_swapped:
		Tuning.gifts = _saved_gifts
	await super.cleanup()


func test_the_daily_and_relaxed_levels_wait_for_the_play_level_and_the_one_after() -> void:
	start(10)
	var n: int = save_node().next_level()
	check(not flow.get("_modes_queued"), "nothing but the Play level and N + 1 at boot")
	var low: Array = flow.get("_low_queue")
	var kinds := []
	for entry: Array in low:
		kinds.append(entry[0])
	check(not kinds.has(LevelData.DAILY) and not kinds.has(LevelData.RELAXED), "no daily or relaxed job queued at boot")
	check(await until(func() -> bool: return flow.get("_modes_queued")), "they are queued later")
	check(flow.call("_known", LevelData.NUMBERED, n, "") != null, "the Play level is in hand by then")
	check(flow.call("_known", LevelData.NUMBERED, n + 1, "") != null, "and so is level N + 1")


func test_a_relaxed_level_makes_the_next_one_ahead() -> void:
	start(8)
	tap("Relaxed")
	tap("Easy")
	check(await in_state(AppFlow.State.LEVEL), "a relaxed level")
	var index: int = fake().played[-1].number
	var key := LevelPrefetcher.key_for(LevelData.RELAXED, index + 1, "easy")
	var queued: bool = false
	for entry: Array in flow.get("_low_queue"):
		queued = queued or (entry[0] == LevelData.RELAXED and entry[1] == index + 1 and entry[2] == "easy")
	var asked: bool = (flow.get("_low_keys") as Array).has(key) or flow.call("_known", LevelData.RELAXED, index + 1, "easy") != null
	check(queued or asked, "the band's next level is asked for")
	check(await until(func() -> bool: return flow.call("_known", LevelData.RELAXED, index + 1, "easy") != null), "and arrives")
	fake().win(1000, Vector3i.ZERO)
	await past_clear_delay()
	tap("Another")
	check_eq(flow.state, AppFlow.State.LEVEL, "Another is at once, with no One moment")


func test_previous_level_and_the_daily_are_made_ahead_with_few_jobs() -> void:
	start(10)
	tap("Play")
	check(await in_state(AppFlow.State.LEVEL), "level 11")
	var most := 0
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 30000:
		most = maxi(most, (flow.get("_low_keys") as Array).size())
		OS.delay_msec(2)
		await tree.process_frame
		if flow.call("_known", LevelData.NUMBERED, 10, "") != null and flow.call("_known", LevelData.DAILY, 20261021, "") != null and flow.call("_known", LevelData.NUMBERED, 12, "") != null:
			break
	check(most <= AppFlow.MAX_LOW_JOBS, "at most %d low jobs at once (%d)" % [AppFlow.MAX_LOW_JOBS, most])
	check(flow.call("_known", LevelData.NUMBERED, 10, "") != null, "Previous level is ready")
	check(flow.call("_known", LevelData.NUMBERED, 12, "") != null, "Next is ready")
	check(flow.call("_known", LevelData.DAILY, 20261021, "") != null, "today's Daily is ready")
	check((flow.get("_spare") as Array).size() <= AppFlow.MAX_SPARE, "the spare levels are capped")


func test_tapping_the_active_home_tab_on_the_title_is_harmless() -> void:
	start(4)
	check_eq(flow.menu, "title", "title")
	tap("Home")
	await frames(2)
	check_eq(flow.menu, "title", "still the title")
	tap("Map")
	tap("Map")
	check_eq(flow.menu, "map", "the active Map tab scrolls, not an error")


func test_a_tampered_saved_next_level_is_thrown_away() -> void:
	start(19)
	flow.queue_free()
	await frames(2)
	var level := LevelCatalog.get_level(LevelData.NUMBERED, 20, "").level
	level.tray_size = 1
	check(save_node().write_next_level("numbered:20", level), "the file is written")
	boot()
	check(flow.get("_current") == null, "the tampered level is not used")
	check(save_node().read_next_level("numbered:20", Generator.GENERATOR_VERSION) == null, "and the file is removed")


func test_an_unsolvable_saved_next_level_is_thrown_away() -> void:
	start(19)
	flow.queue_free()
	await frames(2)
	var level := LevelCatalog.get_level(LevelData.NUMBERED, 20, "").level
	var d := level.to_dict()
	# A queue that never matches the screws can not be solved.
	d["queue"] = [7, 7, 7, 7, 7, 7]
	d["key"] = "numbered:20"
	var f := FileAccess.open(save_node().dir + "next_level.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	boot()
	check(flow.get("_current") == null, "nothing unsolved is played")


## A level 20 file written for the next boot (after the first flow is gone, so it can not
## write its own over it).
func _boot_with_file(level: LevelData, number: int = 19) -> void:
	start(number)
	flow.queue_free()
	await frames(2)
	check(save_node().write_next_level("numbered:%d" % (number + 1), level), "the file is written")
	boot()


func test_a_good_saved_next_level_passes_the_check_and_plays_without_generating() -> void:
	var level := LevelCatalog.get_level(LevelData.NUMBERED, 20, "").level
	await _boot_with_file(level)
	check_eq(flow.state, AppFlow.State.TITLE, "the title shows at once, before the check is done")
	check(await until(func() -> bool: return flow.get("_check") == null), "the check finishes")
	var used: LevelData = flow.get("_current")
	check(used != null, "a solved, matching level is used")
	if used != null:
		check_eq(JSON.stringify(used.to_dict()), JSON.stringify(level.to_dict()), "the same level")
	check((flow.get("_low_queue") as Array).size() + (flow.get("_low_keys") as Array).size() > 0 or flow.call("_known", LevelData.NUMBERED, 21, "") != null, "N + 1 is asked for after the verdict")
	tap("Play")
	check_eq(flow.state, AppFlow.State.LEVEL, "Play starts it at once")
	check(fake().played[-1] == used, "the saved level itself")


func test_a_saved_level_that_fails_the_check_is_made_instead() -> void:
	# A tray par below what the level needs: the file reads fine but the check rejects it.
	var level: LevelData = null
	for n: int in range(30, 60):
		level = LevelCatalog.get_level(LevelData.NUMBERED, n, "").level
		var tier := Tuning.tier_for_level(n)
		var found := Solver.search_only(level, Generator.MAX_STATES[tier - 1], true, Generator.acceptance_cap(tier))
		if found.fewest_tray_uses >= 1:
			break
	var number := level.number
	var d := level.to_dict()
	d["tray_par"] = 0
	d["key"] = "numbered:%d" % number
	start(number - 1)
	flow.queue_free()
	await frames(2)
	var f := FileAccess.open(save_node().dir + "next_level.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	boot()
	check(await until(func() -> bool: return flow.get("_check") == null), "the check finishes")
	check(flow.get("_current") == null, "the rejected level is not used")
	tap("Play")
	check(await in_state(AppFlow.State.LEVEL), "the level is made and plays")
	check_eq(fake().played[-1].number, number, "the right level")
	check_eq(fake().played[-1].tray_par, level.tray_par, "the generator's own tray par, not the file's")


func test_play_tapped_while_the_check_runs_waits_for_it() -> void:
	var level := LevelCatalog.get_level(LevelData.NUMBERED, 20, "").level
	await _boot_with_file(level)
	# No frame has passed since the boot: the worker is still at it, or has just finished.
	tap("Play")
	check(flow.state == AppFlow.State.LOADING or flow.state == AppFlow.State.LEVEL, "One moment, or already playing")
	check(await in_state(AppFlow.State.LEVEL), "then the level starts")
	check_eq(JSON.stringify(fake().played[-1].to_dict()), JSON.stringify(level.to_dict()), "it is the saved level, not a new one")


func test_quitting_while_the_check_runs_does_not_wait_for_it() -> void:
	var level := LevelCatalog.get_level(LevelData.NUMBERED, 20, "").level
	await _boot_with_file(level)
	var check_object: SavedLevelCheck = flow.get("_check")
	check(check_object != null, "the check is running or just done")
	var started := Time.get_ticks_msec()
	flow.quit()
	check_eq(quit_calls, 1, "quit went through")
	check(Time.get_ticks_msec() - started < 1500, "and did not wait long")
	check(check_object.stop.is_requested(), "the search was asked to stop")
	check(flow.get("_check") == null, "nothing is left running")


func _show_clear(info: Dictionary, size: Vector2i) -> ClearScreen:
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	add_node(vp)
	var screen := ClearScreen.make(info)
	screen.theme = UiTheme.build()
	vp.add_child(screen)
	return screen


func test_three_clear_notes_keep_next_and_replay_on_the_screen() -> void:
	var level := LevelCatalog.get_level(LevelData.NUMBERED, 49, "").level
	for size: Vector2i in [Vector2i(360, 640), Vector2i(360, 922), Vector2i(533, 640)]:
		var screen := _show_clear({"kind": LevelData.NUMBERED, "number": 49, "level": level, "stars": Vector3i(1, 1, 1), "elapsed_ms": 9000, "gain": 3,
			"unlocks": ["Unlocked: Daily and Relaxed", "Unlocked: Maple wood"], "gifts": ["A gift for reaching level 50: 2 Undos and 1 Extra slot."]}, size)
		await frames(5)
		for label: String in ["Next", "Replay"]:
			var r := screen.find_button(label).get_global_rect()
			check(r.end.y <= float(size.y) - 8.0 and r.position.y > 0.0, "%s is on the %s screen (%s)" % [label, str(size), str(r)])
		check(screen.find_button("Next").get_global_rect().position.y > screen.find_button("Replay").get_global_rect().position.y - 100.0, "Next is above Replay")


func test_the_gift_count_up_is_told_the_counts_from_before() -> void:
	var list: Array[Dictionary] = [{"level": 3, "undo": 2, "extra_slot": 1, "screwdriver": 0}]
	_saved_gifts = Tuning.gifts.duplicate()
	_gifts_swapped = true
	Tuning.gifts = list
	start(2)
	save_node().add_helper("undo", 1)
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	check(fake().gift_counts_before.is_empty(), "no count-up on a level without a gift")
	fake().win()
	await past_clear_delay()
	tap("Next")
	check(await in_state(AppFlow.State.LEVEL), "the next level")
	check_eq(fake().gift_counts_before.size(), 1, "told once, right after play()")
	check_eq(fake().gift_counts_before[0]["undo"], 1, "with the Undo count from before the gift")
	check_eq(fake().gift_counts_before[0]["extra_slot"], 0, "and the Extra slot count")
	check_eq(fake().counts["undo"], 3, "the scene has the counts after the gift")
	fake().win()
	await past_clear_delay()
	tap("Next")
	await in_state(AppFlow.State.LEVEL)
	check_eq(fake().gift_counts_before.size(), 1, "not again on the level after")


func test_the_saved_level_check_is_quick_and_does_not_reject_real_levels() -> void:
	var worst := 0
	var total := 0
	var count := 0
	var rejected := PackedInt32Array()
	for n: int in range(9, 401, 7):
		var level := LevelCatalog.get_level(LevelData.NUMBERED, n, "").level
		var started := Time.get_ticks_msec()
		var ok := AppFlow.saved_level_solves(level, Tuning.tier_for_level(n))
		var ms := Time.get_ticks_msec() - started
		worst = maxi(worst, ms)
		total += ms
		count += 1
		if not ok:
			rejected.append(n)
	print("        saved level check over %d levels from 9 to 400: average %d ms, worst %d ms" % [count, total / count, worst])
	check(rejected.is_empty(), "a generated level is never rejected: %s" % str(rejected))
