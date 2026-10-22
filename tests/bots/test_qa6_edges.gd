# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends QaFlowCase
## Phase 6 edge cases: the shrunken tray with Undo and Extra slot at the moment of the loss, the
## gifts after a reset, the app killed between a write and its rename, and the app closed while
## a level is still being made.

## 3 slot levels (21 and up) that random play loses quickly.
const LEVELS: Array[int] = [25, 30, 40, 45, 55, 60, 75, 100, 105, 150]


func _entry(n: int) -> BotEntry:
	var g := LevelCatalog.get_level(LevelData.NUMBERED, n, "")
	var entry := BotEntry.new()
	entry.level = g.level
	entry.solve = g.solve
	entry.label = "level %d" % n
	return entry


## Random taps until the tray jams. Null if the level was won first (it tries 20 seeds).
func _lost_session(entry: BotEntry, seed_base: int) -> BotSession:
	for attempt: int in 20:
		var session := BotSession.start(entry.level, false)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_base * 100 + attempt
		var guard := 0
		while session.state.status() == PlayState.PLAYING and guard < 200:
			guard += 1
			var free := Bot.free_screws(session)
			if free.is_empty():
				break
			session.tap(free[rng.randi_range(0, free.size() - 1)])
		if session.state.status() == PlayState.LOST:
			return session
	return null


func test_the_loss_moment_on_a_3_slot_tray_with_undo_and_extra_slot() -> void:
	var reached := 0
	for n: int in LEVELS:
		var entry := _entry(n)
		check_eq(entry.level.tray_size, 3, "%s: 3 slots" % entry.label)
		var session := _lost_session(entry, n)
		if session == null:
			continue
		reached += 1
		var state := session.state
		check_eq(state.tray().size(), 3, "%s: the tray is 3 slots at the loss" % entry.label)
		check(not state.tray().has(-1), "%s: and full" % entry.label)
		# Extra slot opens a 4th slot: the loss is cleared, and the new slot is empty.
		var r := session.extra_slot()
		check(r.ok, "%s: Extra slot works at a loss" % entry.label)
		check_eq(state.status(), PlayState.PLAYING, "%s: the loss is cleared" % entry.label)
		check_eq(state.tray().size(), 4, "%s: 4 slots" % entry.label)
		check_eq(state.tray()[3], -1, "%s: the new slot is empty" % entry.label)
		check_eq(r.kinds(), PackedInt32Array([LogicEvent.TRAY_EXTENDED, LogicEvent.RESUMED]), "%s: EXTENDED then RESUMED" % entry.label)
		check_eq(session.extra_slot().reason, TapResult.ALREADY_USED, "%s: not twice" % entry.label)
		# Undo takes a tap back and keeps the 4th slot (R27); the helpers used are named once each.
		var undone := session.undo()
		check(undone.ok, "%s: Undo works after Extra slot" % entry.label)
		check_eq(state.tray().size(), 4, "%s: undo does not take the slot back" % entry.label)
		check_eq(Array(state.helpers_used()), ["extra_slot", "undo"], "%s: helpers used" % entry.label)
		# Play on until it ends either way; the session checks every rule on the way.
		var rng := RandomNumberGenerator.new()
		rng.seed = n
		var guard := 0
		while state.status() == PlayState.PLAYING and guard < 100:
			guard += 1
			var free := Bot.free_screws(session)
			if free.is_empty():
				break
			session.tap(free[rng.randi_range(0, free.size() - 1)])
		check(state.status() != PlayState.PLAYING, "%s: it ended" % entry.label)
		if state.status() == PlayState.LOST:
			# Lost again with 4 full slots: Undo still works, Extra slot is spent, a Screwdriver
			# removal is refused unless some screw fits.
			check_eq(session.extra_slot().reason, TapResult.ALREADY_USED, "%s: the Extra slot is spent" % entry.label)
			var before := state.tray().size()
			var again := session.undo()
			check(again.ok, "%s: Undo from the second loss" % entry.label)
			check_eq(state.tray().size(), before, "%s: the 4 slots stay" % entry.label)
		check_eq(session.violation_count, 0, "%s: %s" % [entry.label, str(Array(session.violations))])
		# Retry is a new attempt: 3 slots, nothing used.
		var fresh := PlayState.start(entry.level)
		check_eq(fresh.tray().size(), 3, "%s: Retry gives 3 slots" % entry.label)
		check(not fresh.extra_slot_used() and fresh.helpers_used().is_empty(), "%s: and no helper used" % entry.label)
	check(reached >= 6, "%d of %d levels reached a loss" % [reached, LEVELS.size()])


func test_a_reset_gives_the_gifts_their_turn_again_without_doubling_them() -> void:
	start(48)
	for h: String in ["undo", "extra_slot", "screwdriver"]:
		save_node().mark_helper_met(h, 0)
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	fake().win()
	await past_clear_delay()
	check_eq(save_node().helper_count("undo"), 2, "the first gift: 2 Undos")
	check_eq(save_node().helper_count("extra_slot"), 1, "and 1 Extra slot")
	flow.quit_to_title()
	await frames(2)
	tap("Settings")
	tap("Reset progress")
	tap("Erase everything", true)
	check_eq(save_node().helper_count("undo"), 0, "the reset took the Undos")
	check_eq(Array(save_node().gifts_given()), [], "and the record of the gift")
	# The same walk again: the same gift, once, not on top of the old one.
	flow.queue_free()
	await frames(2)
	start(48)
	for h2: String in ["undo", "extra_slot", "screwdriver"]:
		save_node().mark_helper_met(h2, 0)
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	fake().win()
	await past_clear_delay()
	check_eq(save_node().helper_count("undo"), 2, "after a reset the gift is 2 Undos again, not 4")
	check_eq(save_node().helper_count("extra_slot"), 1, "and 1 Extra slot, not 2")
	check_eq(Array(save_node().gifts_given()), [50], "recorded once")
	save_node().erase_all()


func test_a_write_that_was_killed_before_its_rename_leaves_the_old_save_in_charge() -> void:
	var save := save_node()
	save.erase_all()
	DirAccess.make_dir_recursive_absolute(str(save.dir))
	var p: Dictionary = save.default_progress()
	p["highest_cleared"] = 12
	p["next_level"] = 13
	var good := FileAccess.open(str(save.dir) + "progress.json", FileAccess.WRITE)
	good.store_string(JSON.stringify(p))
	good.close()
	# The newer write died half way: a temporary file with the start of a different save.
	for tmp_name: String in ["progress.json.tmp", "settings.json.tmp", "next_level.json.tmp"]:
		var tmp := FileAccess.open(str(save.dir) + tmp_name, FileAccess.WRITE)
		tmp.store_string("{\"format\": 1, \"highest_cleared\": 99, \"next_le")
		tmp.close()
	save.load_all()
	check_eq(save.highest_cleared(), 12, "the complete file is the one read")
	check_eq(PackedStringArray(save.problems).size(), 0, "no problem is reported for a leftover temporary file")
	save.save_progress()
	check_eq(save.highest_cleared(), 12, "and the next save goes on from it")
	var after: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(save.dir) + "progress.json"))
	check(after is Dictionary and int((after as Dictionary)["highest_cleared"]) == 12, "the file written next is whole")
	save.erase_all()


func test_closing_the_app_while_a_level_is_still_being_made_leaves_a_clean_start() -> void:
	start(20)
	flow.play_number(300)
	check_eq(flow.state, AppFlow.State.LOADING, "a deep level is being made")
	# The app is closed here (the tree frees the flow; its prefetcher waits for the worker).
	flow.queue_free()
	await frames(3)
	boot()
	check(await until(func() -> bool: return flow.state == AppFlow.State.TITLE), "the next start shows the title")
	check_eq(save_node().highest_cleared(), 20, "progress is as it was")
	tap("Play")
	check(await in_state(AppFlow.State.LEVEL), "Play starts level 21")
	check_eq(fake().played[-1].number, 21, "level 21")
	save_node().erase_all()
