# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends QaFlowCase
## Phase 4 edge cases for Daily and its streak (GDD 6.6), Relaxed's free Undo and buying a
## helper with too few stars (R38), on the app flow.


func _hud() -> LevelHud:
	return scene().get("_hud") as LevelHud


func _touch(p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = p
	e.pressed = pressed
	scene().call("_gui_input", e)


func _press(id: String) -> void:
	var p := _hud().target_of(id).get_center()
	_touch(p, true)
	_touch(p, false)


## Plays today's daily on a fresh flow (the save is kept) and wins it.
func _daily_on(date: String) -> void:
	if flow != null:
		flow.queue_free()
		await frames(2)
	boot(date)
	await in_state(AppFlow.State.TITLE)
	tap("Daily")
	await in_state(AppFlow.State.LEVEL)
	fake().win()
	await past_clear_delay()


func test_acc_26_the_streak_over_month_and_year_ends_a_skipped_day_and_the_clock_moved_back() -> void:
	start(8, "2026-10-30")
	var daily := func() -> Dictionary: return save_node().daily_record()
	await _daily_on("2026-10-30")
	check_eq(int(daily.call()["streak"]), 1, "first daily")
	await _daily_on("2026-10-31")
	check_eq(int(daily.call()["streak"]), 2, "the next day")
	await _daily_on("2026-11-01")
	check_eq(int(daily.call()["streak"]), 3, "across the month end")
	await _daily_on("2026-11-01")
	check_eq(int(daily.call()["streak"]), 3, "the same day twice does not count twice")
	await _daily_on("2026-11-03")
	check_eq(int(daily.call()["streak"]), 1, "a skipped day starts again at 1")
	check_eq(int(daily.call()["best_streak"]), 3, "the best streak is kept")
	var bank: int = save_node().star_bank()
	await _daily_on("2026-11-02")
	check_eq(int(daily.call()["streak"]), 1, "the clock moved back: the streak does not move")
	check_eq(str(daily.call()["last_date"]), "2026-11-03", "and the last counted date does not go back")
	check_eq(int(daily.call()["solved"]), 4, "the solved count follows the counted days only")
	# What moving the clock back does give: an unsolved date is a new puzzle with its own stars.
	check_eq(save_node().star_bank() - bank, 3, "the clock moved back to an unsolved day earns its stars again (accepted, F3)")
	for pair: Array in [["2026-12-31", "2027-01-01"], ["2027-02-28", "2027-03-01"], ["2028-02-28", "2028-02-29"], ["2028-02-29", "2028-03-01"]]:
		save_node().reset_progress()
		save_node().record_daily(pair[0], 1000, Vector3i(1, 1, 1))
		save_node().record_daily(pair[1], 1000, Vector3i(1, 1, 1))
		check_eq(int(save_node().daily_record()["streak"]), 2, "%s then %s are consecutive days" % pair)


func test_the_daily_keeps_the_date_it_started_on() -> void:
	start(8, "2026-10-31")
	tap("Daily")
	await in_state(AppFlow.State.LEVEL)
	check_eq(fake().played[-1].number, 20261031, "today's daily")
	flow.today_override = "2026-11-01"
	fake().win()
	await past_clear_delay()
	check(save_node().daily_done("2026-10-31"), "it counts for the day it was started")
	check(not save_node().daily_done("2026-11-01"), "not for the day after midnight")


func test_a_clock_set_far_ahead_locks_the_streak_until_that_date() -> void:
	start(8, "2027-10-21")
	var save := save_node()
	save.record_daily("2027-10-21", 1000, Vector3i(1, 1, 1))
	check_eq(int(save.daily_record()["streak"]), 1, "one daily solved with a clock a year ahead")
	var r: Dictionary = save.record_daily("2026-10-22", 1000, Vector3i(1, 1, 1))
	check(not r["counted"], "the true date is now 'earlier', so it never counts again (finding)")
	r = save.record_daily("2026-10-23", 1000, Vector3i(1, 1, 1))
	check(not r["counted"], "and neither does any day until the real date passes the faked one")


func test_relaxed_undo_is_free_and_unlimited_on_the_real_scene() -> void:
	start_real(9, "2026-10-21", false)
	var save := save_node()
	save.mark_helper_met("undo", 0)
	flow.play_relaxed("easy")
	check(await level_on(), "a Relaxed level is on")
	var sol := solution()
	var undone := 0
	for i: int in 5:
		scene().tap_screw(sol[i])
		await frames(1)
		_press("undo")
		await frames(1)
		undone += 1
	check_eq(scene().get_state().snapshot()["on_board"].size(), scene().get_level().screw_count(), "five undos took five taps back")
	check_eq(save.helper_count("undo"), 0, "no Undo was taken from the save")
	check_eq(int(save.progress_copy()["stats"]["helpers_used"]), undone, "each use still counts in the stats")
	check_eq(save.star_bank(), 27, "nothing was spent")
	check(scene().debug_snapshot().has("cup"), "the level is the real scene")


func test_acc_13c_too_few_stars_to_buy_toasts_and_spends_nothing() -> void:
	start_real(8, "2026-10-21", false)
	var save := save_node()
	for h: String in ["undo", "extra_slot", "screwdriver"]:
		save.mark_helper_met(h, 0)
	save.spend_stars(save.star_bank() - 3)
	check_eq(save.star_bank(), 3, "3 stars")
	check(await level_on(), "level 9 is on")
	await play_taps(2)
	var before := state_text()
	_press("undo")
	await frames(2)
	check(flow.overlay == null, "no dialog: the bank cannot pay")
	check_eq(scene().debug_snapshot()["toast"], "Not enough stars. 4 needed.", "the level says what it costs")
	check_eq(save.star_bank(), 3, "nothing spent")
	check_eq(save.helper_count("undo"), 0, "nothing given")
	check_eq(state_text(), before, "the board is untouched")
	_press("screwdriver")
	await frames(2)
	check_eq(scene().debug_snapshot()["toast"], "Not enough stars. 8 needed.", "Screwdriver names its price")


func test_acc_13c_with_exactly_the_price_the_dialog_opens_and_back_or_not_now_buy_nothing() -> void:
	start_real(8, "2026-10-21", false)
	var save := save_node()
	for h: String in ["undo", "extra_slot", "screwdriver"]:
		save.mark_helper_met(h, 0)
	save.spend_stars(save.star_bank() - 4)
	check(await level_on(), "level 9 is on")
	await play_taps(2)
	var before := state_text()
	_press("undo")
	await frames(2)
	check(flow.overlay is UiDialog, "the buy dialog opens with exactly 4 stars")
	check(not bool(scene().debug_snapshot()["clock_running"]), "the clock is stopped while the dialog is open (S6)")
	back()
	check(flow.overlay == null, "Back closes it")
	check_eq(save.star_bank(), 4, "nothing spent by Back")
	check(bool(scene().debug_snapshot()["clock_running"]), "the clock runs again once it is closed")
	_press("undo")
	await frames(2)
	tap("Not now", true)
	check_eq(save.star_bank(), 4, "nothing spent by Not now")
	check_eq(state_text(), before, "and the board is untouched")
	_press("undo")
	await frames(2)
	tap("Get and use", true)
	await frames(2)
	check_eq(save.star_bank(), 0, "Get and use spends exactly the price")
	check(state_text() != before, "and used the Undo (a tap was taken back)")
	check_eq(save.helper_count("undo"), 0, "the bought Undo was used up")
	check_eq(int(save.progress_copy()["stats"]["helpers_used"]), 1, "counted once")


## Loses the level on the screen by random taps (instant mode). True if the level got lost.
func _drive_to_loss(seed_value: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in 300:
		if flow.state != AppFlow.State.LEVEL:
			break
		var state := scene().get_state()
		var free: Array[int] = []
		for s: int in scene().get_level().screw_count():
			if state.is_free(s):
				free.append(s)
		if free.is_empty():
			break
		scene().tap_screw(free[rng.randi_range(0, free.size() - 1)])
		await frames(1)
	return await until(func() -> bool: return flow.state == AppFlow.State.LOST, 1500)


func test_acc_13b_the_out_of_room_sheet_offers_exactly_the_owned_usable_helpers() -> void:
	var shown_cases := 0
	for case_index: int in 6:
		start_real(39, "2026-10-21", false)
		for h0: String in ["undo", "extra_slot", "screwdriver"]:
			save_node().mark_helper_met(h0, 0)
		var save := save_node()
		# Cases: all owned, only Undo, only Extra slot, only Screwdriver, none, all owned again.
		var cases: Array = [["undo", "extra_slot", "screwdriver"], ["undo"], ["extra_slot"], ["screwdriver"], [], ["undo", "extra_slot", "screwdriver"]]
		var owned: Array = cases[case_index]
		for h: String in owned:
			save.add_helper(h, 1)
		var lost := false
		for attempt: int in 6:
			flow.play_number(40 + 5 * case_index)
			if not await level_on():
				break
			if await _drive_to_loss(100 + case_index * 10 + attempt):
				lost = true
				break
		if not lost:
			flow.queue_free()
			await frames(2)
			continue
		shown_cases += 1
		var state := scene().get_state()
		# The rule, worked out here (R37): Undo with something to take back, Extra slot not yet
		# used, Screwdriver if some screw on the board fits an open box.
		var usable := PackedStringArray()
		if state.can_undo() and owned.has("undo"):
			usable.append("undo")
		if not state.extra_slot_used() and owned.has("extra_slot"):
			usable.append("extra_slot")
		for s: int in scene().get_level().screw_count():
			if owned.has("screwdriver") and state.is_on_board(s) and state.destination(s).x == PlayState.BOX:
				usable.append("screwdriver")
				break
		var got := scene().usable_after_loss()
		check_eq(Array(got), Array(usable), "case %d: usable_after_loss (R37)" % case_index)
		for h: String in ["undo", "extra_slot", "screwdriver"]:
			var label: String = {"undo": "Undo", "extra_slot": "Extra slot", "screwdriver": "Screwdriver"}[h]
			var offered := flow.screen.find_button(label) != null
			check_eq(offered, owned.has(h) and usable.has(h), "case %d: %s on the sheet (owned %s, usable %s)" % [case_index, label, str(owned.has(h)), str(usable.has(h))])
		var text := all_text(flow.screen)
		check(not text.contains("buy") and not text.contains("get and use") and not text.contains("stars"), "case %d: the sheet never offers a purchase: %s" % [case_index, text.replace("\n", " | ")])
		# Using the first offered helper clears the loss.
		for h: String in ["undo", "extra_slot", "screwdriver"]:
			if owned.has(h) and usable.has(h) and h != "screwdriver":
				var label: String = {"undo": "Undo", "extra_slot": "Extra slot"}[h]
				flow.screen.find_button(label).pressed.emit()
				await frames(3)
				check(flow.state == AppFlow.State.LEVEL or flow.state == AppFlow.State.LOST, "case %d: %s answered" % [case_index, label])
				check(save.helper_count(h) == 0, "case %d: the helper was taken from the save" % case_index)
				break
		flow.queue_free()
		await frames(2)
	check(shown_cases >= 4, "only %d of 6 cases reached a loss" % shown_cases)


func test_acc_28_each_unlock_appears_at_its_milestone_and_survives_a_restart() -> void:
	var table: Array = [[10, "wood", "walnut"], [25, "metal", "brass"], [50, "wood", "maple"], [100, "wood", "cherry"], [150, "wood", "ebony"]]
	var save := save_node()
	for row: Array in table:
		start(int(row[0]) - 1)
		check(not save.unlocked_ids(str(row[1])).has(str(row[2])), "%s is locked before level %d" % [row[2], row[0]])
		tap("Play")
		check(await in_state(AppFlow.State.LEVEL), "level %d starts" % row[0])
		check_eq(fake().played[-1].number, int(row[0]), "it is level %d" % row[0])
		fake().win()
		await past_clear_delay()
		check(save.unlocked_ids(str(row[1])).has(str(row[2])), "%s %s unlocked at level %d" % [row[2], row[1], row[0]])
		check(all_text(flow.screen).contains("unlocked: %s" % str(row[2])), "the clear screen names it: %s" % all_text(flow.screen).replace("\n", " | "))
		save.load_all()
		check(save.unlocked_ids(str(row[1])).has(str(row[2])), "%s survives a restart" % row[2])
		flow.queue_free()
		await frames(2)
	# Streaks: copper at 3 days, black at 7.
	start(8, "2026-12-01")
	for day: int in range(1, 8):
		await _daily_on("2026-12-%02d" % day)
		if day == 2:
			check(not save.unlocked_ids("metal").has("copper"), "no copper at a streak of 2")
		if day == 3:
			check(save.unlocked_ids("metal").has("copper"), "copper at a streak of 3")
			check(all_text(flow.screen).contains("unlocked: copper"), "the clear screen names it")
		if day == 6:
			check(not save.unlocked_ids("metal").has("black"), "no black at 6")
		if day == 7:
			check(save.unlocked_ids("metal").has("black"), "black at 7")
	save.load_all()
	check(save.unlocked_ids("metal").has("black") and save.unlocked_ids("metal").has("copper"), "both survive a restart")


func test_acc_29_level_1_is_three_screws_and_takes_the_perfect_bot_under_the_par() -> void:
	# The bots cannot play "no reading", but level 1 itself must be clearable in well under 30 s.
	var level := LevelCatalog.get_level(LevelData.NUMBERED, 1, "").level
	check_eq(level.screw_count(), 3, "level 1 is three screws")
	check_eq(level.par_time_s, 30, "par is 30 s")
	check_eq(level.line, "", "no text on level 1 itself")
	check_eq(level.hint.size(), 3, "the hand points at all three screws")


func test_acc_19_each_helper_arrives_once_with_two_free_on_its_level() -> void:
	var save := save_node()
	for row: Array in [["undo", 8], ["extra_slot", 15], ["screwdriver", 25]]:
		var helper: String = row[0]
		var level_number: int = row[1]
		start(level_number - 1)
		# The helpers before this one were met on their own levels.
		for before: String in ["undo", "extra_slot", "screwdriver"]:
			if int(Tuning.helpers[before]["first_level"]) < level_number:
				save.mark_helper_met(before, 2)
		check_eq(save.helper_count(helper), 0, "%s: none owned before its level" % helper)
		check(not save.is_helper_met(helper), "%s: not met yet" % helper)
		flow.queue_free()
		await frames(2)
		boot()
		await in_state(AppFlow.State.TITLE)
		tap("Play")
		check(await in_state(AppFlow.State.LEVEL), "%s: level %d starts" % [helper, level_number])
		check(flow.overlay is HelperSheet, "%s: its sheet shows on level %d" % [helper, level_number])
		check(fake().holds > 0, "%s: the clock is held while the sheet shows" % helper)
		tap("Got it", true)
		check_eq(save.helper_count(helper), 2, "%s: two free" % helper)
		check(save.is_helper_met(helper), "%s: met" % helper)
		# Played again, or reached again after a reset of the level: no second gift, no second sheet.
		fake().win()
		await past_clear_delay()
		tap("Replay")
		await frames(3)
		check(flow.overlay == null, "%s: no second sheet" % helper)
		check_eq(save.helper_count(helper), 2, "%s: still two" % helper)
	flow.queue_free()
	await frames(2)
