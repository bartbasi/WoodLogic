# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends QaFlowCase
## Phase 5 on the app flow, with the real data and the real level scene where the picture
## matters (GDD 12 item 22b and 22c, docs/UX.md 3.2.2 and 3.13.4): the tray of each level, the
## shrink line once only, the tray closing only on Next, the gifts at levels 50 and 100 once only.
## tests/ui/test_flow_tray.gd covers the same ideas with made up gift levels over the fake
## scene; these use levels 50 and 100 as they ship, and the real scene.

const NOTE := "The tray is smaller now. Every slot counts."
const GIFT_50 := "A gift for reaching level 50: 2 Undos and 1 Extra slot."
const GIFT_100 := "A gift for reaching level 100: 2 Undos and 1 Extra slot."
const GIFT_BOTH := "A gift for reaching level 50 and level 100: 4 Undos and 2 Extra slots."


## Marks every helper met with none given, so no first-time sheet or free helper gets in the way.
func _helpers_met() -> void:
	for h: String in ["undo", "extra_slot", "screwdriver"]:
		save_node().mark_helper_met(h, 0)


## Taps Play and plays on past any sheet until a level is on the fake scene.
func _play_from_title() -> void:
	tap("Play")
	check(await in_state(AppFlow.State.LEVEL), "a level starts")
	while flow.overlay != null:
		tap("Got it", true)


func _win_and_wait() -> void:
	fake().win()
	await past_clear_delay()


func _gifts() -> Array[String]:
	return (flow.screen as ClearScreen).gift_notes


func test_acc_22c_the_gift_at_level_50_comes_once_with_the_clear_of_level_49() -> void:
	start(48)
	_helpers_met()
	await _play_from_title()
	check_eq(fake().played[-1].number, 49, "level 49")
	var undo_before: int = save_node().helper_count("undo")
	var extra_before: int = save_node().helper_count("extra_slot")
	await _win_and_wait()
	check_eq(_gifts(), [GIFT_50], "the plaque on the clear screen of level 49")
	check_eq(save_node().helper_count("undo") - undo_before, 2, "2 Undos")
	check_eq(save_node().helper_count("extra_slot") - extra_before, 1, "1 Extra slot")
	check_eq(save_node().helper_count("screwdriver"), 0, "no Screwdriver")
	check_eq(Array(save_node().gifts_given()), [50], "recorded")
	check(flow.screen.find_button("Next") != null and not flow.screen.find_button("Next").disabled, "Next is still one tap")
	# Level 50 itself, and a replay of 49: nothing more.
	tap("Next")
	check(await in_state(AppFlow.State.LEVEL), "level 50")
	await _win_and_wait()
	check(_gifts().is_empty(), "no second gift on level 50")
	tap("Replay")
	await in_state(AppFlow.State.LEVEL)
	await _win_and_wait()
	check(_gifts().is_empty(), "nor on a replay")
	check_eq(save_node().helper_count("undo") - undo_before, 2, "still 2 Undos")
	# A restart reads the same record and gives nothing.
	save_node().load_all()
	check_eq(Array(save_node().gifts_given()), [50], "the record survives a restart")
	check_eq(save_node().helper_count("extra_slot") - extra_before, 1, "and so do the helpers")


func test_acc_22c_the_gift_at_level_100_comes_once_after_the_first_was_given() -> void:
	start(98)
	save_node().grant_gift(50, {"undo": 2, "extra_slot": 1})
	_helpers_met()
	await _play_from_title()
	check_eq(fake().played[-1].number, 99, "level 99")
	var undo_before: int = save_node().helper_count("undo")
	await _win_and_wait()
	check_eq(_gifts(), [GIFT_100], "only the second gift")
	check_eq(save_node().helper_count("undo") - undo_before, 2, "2 Undos")
	check_eq(Array(save_node().gifts_given()), [50, 100], "both recorded")
	tap("Next")
	await in_state(AppFlow.State.LEVEL)
	await _win_and_wait()
	check(_gifts().is_empty(), "nothing at level 100 itself")


func test_acc_22c_a_save_already_past_50_gets_its_gift_on_the_next_clear_and_only_once() -> void:
	start(60)
	_helpers_met()
	await _play_from_title()
	var undo_before: int = save_node().helper_count("undo")
	await _win_and_wait()
	check_eq(_gifts(), [GIFT_50], "the gift it missed, not the one for 100")
	check_eq(save_node().helper_count("undo") - undo_before, 2, "2 Undos")
	tap("Next")
	await in_state(AppFlow.State.LEVEL)
	await _win_and_wait()
	check(_gifts().is_empty(), "never again")
	# And one past both gets both, as one note with the sum.
	start(120)
	_helpers_met()
	await _play_from_title()
	var undo_120: int = save_node().helper_count("undo")
	await _win_and_wait()
	check_eq(_gifts(), [GIFT_BOTH], "one note with the sum")
	check_eq(save_node().helper_count("undo") - undo_120, 4, "4 Undos")
	check_eq(save_node().helper_count("extra_slot"), 2, "2 Extra slots")
	check_eq(Array(save_node().gifts_given()), [50, 100], "both recorded")


func test_acc_22c_no_gift_for_the_daily_or_relaxed_even_when_one_is_due() -> void:
	start(60, "2026-10-22")
	_helpers_met()
	flow.play_daily()
	check(await in_state(AppFlow.State.LEVEL), "the daily")
	while flow.overlay != null:
		tap("Got it", true)
	await _win_and_wait()
	check(_gifts().is_empty(), "no gift after a Daily")
	check_eq(save_node().helper_count("undo"), 0, "no Undo")
	check_eq(Array(save_node().gifts_given()), [], "nothing recorded")
	flow.quit_to_title()
	flow.play_relaxed("easy")
	await in_state(AppFlow.State.LEVEL)
	fake().win(1000, Vector3i.ZERO)
	check(_gifts().is_empty(), "no gift after Relaxed")
	check_eq(Array(save_node().gifts_given()), [], "still nothing recorded")
	check_eq(save_node().helper_count("undo"), 0, "still no Undo")


func test_acc_22c_a_progress_reset_gives_the_gifts_and_the_shrink_line_their_turn_again() -> void:
	start(60)
	_helpers_met()
	save_node().grant_gift(50, {"undo": 2, "extra_slot": 1})
	save_node().mark_tray_note_shown()
	check(save_node().tray_note_shown(), "the line is marked shown")
	tap("Settings")
	tap("Reset progress")
	tap("Erase everything", true)
	check_eq(Array(save_node().gifts_given()), [], "the gift flags are cleared")
	check(not save_node().tray_note_shown(), "and the shrink line flag")
	check_eq(save_node().helper_count("undo"), 0, "and the helpers")


# == the tray on the real scene ==

## Waits for the level scene to be showing a level (without instant mode, so the closing and
## the line play), then watches `frames` frames: what the shrink line said, whether the tray
## closing ran, and how many slots the tray has.
func _arrive(frames_to_watch: int = 240) -> Dictionary:
	var ok := await until(func() -> bool: return flow.state == AppFlow.State.LEVEL and scene() != null, 8000)
	var seen := {"ok": ok, "note": "", "swap": false, "slots": -1, "clock": false}
	if not ok:
		return seen
	for i: int in frames_to_watch:
		var snap := scene().debug_snapshot()
		if str(snap["note"]) != "":
			seen["note"] = snap["note"]
		if bool(snap["swap"]):
			seen["swap"] = true
		seen["slots"] = int(snap["tray_slots"])
		seen["clock"] = bool(seen["clock"]) or bool(snap["clock_running"])
		await tree.process_frame
	return seen


## Wins the level on the real scene (instant, so it is quick) and presses Next.
func _win_real_and_next() -> void:
	scene().set_instant(true)
	await play_taps()
	check(await in_state(AppFlow.State.CLEAR), "the level was won")
	await past_clear_delay()
	scene().set_instant(false)
	tap("Next")


func test_acc_22b_the_real_tray_has_the_slots_of_its_level_and_extra_slot_adds_one() -> void:
	for pair: Array in [[8, 5], [10, 5], [11, 5], [12, 4], [14, 4], [20, 4], [21, 3], [24, 3], [49, 3]]:
		start_real(int(pair[0]) - 1)
		flow.play_number(int(pair[0]))
		var seen := await _arrive(5)
		check(bool(seen["ok"]), "level %d starts" % pair[0])
		check_eq(scene().get_level().number, int(pair[0]), "it is level %d" % pair[0])
		check_eq(int(seen["slots"]), int(pair[1]), "level %d: the drawn tray" % pair[0])
		check_eq(scene().get_state().tray().size(), int(pair[1]), "level %d: the rules' tray" % pair[0])
		flow.queue_free()
		await frames(2)
	# Extra slot is one more, for that try only.
	start_real(23)
	flow.play_number(24)
	await _arrive(3)
	scene().set_instant(true)
	scene().use_helper("extra_slot")
	await frames(3)
	check_eq(scene().get_state().tray().size(), 4, "level 24: 3 slots and the Extra slot")
	check_eq(int(scene().debug_snapshot()["tray_slots"]), 4, "drawn too")
	scene().retry()
	await frames(3)
	check_eq(scene().get_state().tray().size(), 3, "Retry gives the level's 3 slots back")
	flow.queue_free()
	await frames(2)
	# The Daily has 3, Relaxed 5, whatever the player's level.
	start_real(15)
	flow.play_daily()
	var daily := await _arrive(5)
	check_eq(int(daily["slots"]), 3, "the Daily has 3 slots")
	flow.quit_to_title()
	flow.play_relaxed("hard")
	var relaxed := await _arrive(5)
	check_eq(int(relaxed["slots"]), 5, "Relaxed has 5 slots")
	check_eq(scene().get_state().tray().size(), 5, "and the rules agree")


func test_the_shrink_line_shows_once_at_level_12_and_the_tray_closes_on_next_from_11() -> void:
	start_real(10)
	flow.play_number(11)
	var at_11 := await _arrive(60)
	check_eq(int(at_11["slots"]), 5, "level 11: 5 slots")
	check_eq(str(at_11["note"]), "", "level 11: no line")
	check(not bool(at_11["swap"]), "level 11: no closing")
	await _win_real_and_next()
	var at_12 := await _arrive(240)
	check_eq(scene().get_level().number, 12, "Next plays level 12")
	check_eq(int(at_12["slots"]), 4, "level 12: 4 slots")
	check(bool(at_12["swap"]), "the tray closed on arrival by Next")
	check_eq(str(at_12["note"]), NOTE, "the line, word for word")
	check(not bool(at_12["clock"]), "the line and the closing did not start the clock")
	check(save_node().tray_note_shown(), "marked shown")
	# Level 13: the same tray, so neither.
	await _win_real_and_next()
	var at_13 := await _arrive(240)
	check_eq(scene().get_level().number, 13, "level 13")
	check_eq(int(at_13["slots"]), 4, "level 13: 4 slots")
	check_eq(str(at_13["note"]), "", "no line again")
	check(not bool(at_13["swap"]), "no closing at the same size")


func test_the_closing_runs_from_20_to_21_and_21_has_no_line() -> void:
	start_real(19)
	save_node().mark_tray_note_shown()
	flow.play_number(20)
	var at_20 := await _arrive(30)
	check_eq(int(at_20["slots"]), 4, "level 20: 4 slots")
	await _win_real_and_next()
	var at_21 := await _arrive(240)
	check_eq(scene().get_level().number, 21, "level 21")
	check_eq(int(at_21["slots"]), 3, "level 21: 3 slots")
	check(bool(at_21["swap"]), "the tray closes by one more slot")
	check_eq(str(at_21["note"]), "", "and no line (GDD 6.8: no line at 21)")


func test_the_closing_never_runs_from_the_title_the_map_retry_a_replay_or_a_mode() -> void:
	# Level 12 from the title: the line, no closing.
	start_real(11)
	tap("Play")
	var from_title := await _arrive(240)
	check_eq(scene().get_level().number, 12, "Play starts level 12")
	check_eq(str(from_title["note"]), NOTE, "the line shows on the first smaller level")
	check(not bool(from_title["swap"]), "no closing from the title")
	# Retry: neither.
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	tap("Retry")
	var after_retry := await _arrive(120)
	check_eq(str(after_retry["note"]), "", "no line on Retry")
	check(not bool(after_retry["swap"]), "no closing on Retry")
	# A replay from the map of level 11 then Next to the replay of 12: neither, since 12 is cleared
	# once the player has been through it. Save a progress past 12 to make both replays.
	flow.quit_to_title()
	save_node().record_win(LevelCatalog.get_level(LevelData.NUMBERED, 12, "").level, 9000, Vector3i(1, 1, 1))
	save_node().record_win(LevelCatalog.get_level(LevelData.NUMBERED, 13, "").level, 9000, Vector3i(1, 1, 1))
	flow.play_number(11)
	await _arrive(5)
	check(flow.state == AppFlow.State.LEVEL, "a replay of 11")
	await _win_real_and_next()
	var replay_12 := await _arrive(240)
	check_eq(scene().get_level().number, 12, "Next from the replay of 11")
	check(not bool(replay_12["swap"]), "no closing on a replay")
	check_eq(str(replay_12["note"]), "", "no line on a replay")
	# From the map to level 21 (a replay or the next level): the tray simply appears.
	flow.quit_to_title()
	flow.play_number(21)
	var to_21 := await _arrive(120)
	check_eq(int(to_21["slots"]), 3, "level 21 straight from the map or title")
	check(not bool(to_21["swap"]), "no closing without Next")
	flow.quit_to_title()
	flow.play_daily()
	var daily := await _arrive(120)
	check(not bool(daily["swap"]) and str(daily["note"]) == "", "nothing in the Daily")
	flow.quit_to_title()
	flow.play_relaxed("easy")
	var relaxed := await _arrive(120)
	check(not bool(relaxed["swap"]) and str(relaxed["note"]) == "", "nothing in Relaxed")


func test_a_player_who_arrives_first_at_a_later_smaller_tray_still_gets_the_line_once() -> void:
	# A save from before the tray shrank has cleared level 30 and never seen the line. The first
	# numbered level it plays that is a new level gets the line, once (the code says "the first
	# numbered level whose tray is smaller than the start"), never on a replay.
	start_real(29)
	check(not save_node().tray_note_shown(), "the line has not been shown")
	tap("Play")
	var first := await _arrive(240)
	check_eq(scene().get_level().number, 30, "level 30")
	check_eq(str(first["note"]), NOTE, "the line shows at the first new level, even a late one")
	check(not bool(first["swap"]), "and no closing from the title")
	await _win_real_and_next()
	var second := await _arrive(240)
	check_eq(str(second["note"]), "", "never again")


func test_ux_3_14_the_info_lines_for_the_tray_prices_and_gifts_are_the_uxs_words() -> void:
	var texts := PackedStringArray()
	for group: Array in InfoScreen.groups():
		for entry: Array in group[1]:
			texts.append(str(entry[1]))
	var all := "\n".join(texts)
	var ux := FileAccess.get_file_as_string("res://docs/UX.md").replace("\n", " ").replace("\r", " ")
	while ux.contains("  "):
		ux = ux.replace("  ", " ")
	for line: String in [
			"The tray starts with 5 slots. It shrinks to 4 from level 12 and to 3 from level 21.",
			"Out of a helper? Tap it in a level to buy one with stars: Undo 3, Extra slot 5, Screwdriver 8.",
			"Reach level 50 and level 100 for a gift each time: 2 Undos and 1 Extra slot.",
			"Undo. Takes back your last move. Two free on level 8.",
			"Extra slot. Adds one more tray slot, once per try. Two free on level 15.",
			"Screwdriver. Removes any one screw, even a covered one, to where a tap would send it. Two free on level 25."]:
		check(ux.contains(line), "UX 3.14 has the line: %s" % line)
		check(all.contains(line), "the Info screen shows it: %s" % line)


func test_ux_3_2_2_the_tray_frame_is_the_size_ux_gives_for_each_slot_count_and_nothing_else_moves() -> void:
	start_real(24)
	flow.play_number(25)
	check(await level_on(), "level 25 is on")
	scene().set_layout_size(Vector2(360.0, 640.0))
	await frames(3)
	var layout := scene().get_layout()
	# UX 3.2.2: frame widths and x ranges for a 360 wide column, slot left edges.
	var table: Array = [[3, 160.0, 100.0, [108.0, 158.0, 208.0]], [4, 210.0, 75.0, [83.0, 133.0, 183.0, 233.0]], [5, 260.0, 50.0, [58.0, 108.0, 158.0, 208.0, 258.0]], [6, 310.0, 25.0, [33.0, 83.0, 133.0, 183.0, 233.0, 283.0]]]
	for row: Array in table:
		var slots: int = row[0]
		var frame := layout.tray_frame(slots)
		check_eq(snappedf(frame.size.x, 0.01), float(row[1]), "%d slots: the frame is %d wide" % [slots, int(row[1])])
		check_eq(snappedf(frame.position.x, 0.01), float(row[2]), "%d slots: the frame starts at x %d" % [slots, int(row[2])])
		check_eq(snappedf(frame.size.y, 0.01), 52.0, "%d slots: 52 tall" % slots)
		var edges: Array = row[3]
		for i: int in slots:
			var left := layout.tray_slot_center(i, slots).x - 22.0
			check_eq(snappedf(left, 0.01), float(edges[i]), "%d slots: slot %d left edge" % [slots, i])
	# The boxes, the board and the helper bar do not move with the tray's size: compare a 5, a 4
	# and a 3 slot level.
	var rects := {}
	for n: int in [10, 14, 30]:
		flow.play_number(n)
		await until(func() -> bool: return flow.state == AppFlow.State.LEVEL and scene().get_level().number == n, 5000)
		scene().set_layout_size(Vector2(360.0, 640.0))
		await frames(2)
		var l := scene().get_layout()
		rects[n] = [l.boxes_bar, l.helper_bar, l.panel, l.top_bar]
	check_eq(rects[10], rects[14], "the boxes, helper bar, board and top bar are the same at 5 and 4 slots")
	check_eq(rects[14], rects[30], "and at 3 slots")


func _write_progress(changes: Dictionary) -> void:
	var save := save_node()
	save.erase_all()
	var p: Dictionary = save.default_progress()
	p.merge(changes, true)
	DirAccess.make_dir_recursive_absolute(str(save.dir))
	var f := FileAccess.open(str(save.dir) + "progress.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(p))
	f.close()


func test_edited_gift_and_shrink_line_flags_are_cleaned_and_the_game_still_plays() -> void:
	var forty: Array = []
	for i: int in 40:
		forty.append(i + 1)
	var cases: Array[Dictionary] = [
		{"gifts_given": [50, "x", -1, 1e12, 50, 100, null, 2.5], "tray_note_shown": "yes"},
		{"gifts_given": forty, "tray_note_shown": 1},
		{"gifts_given": "all", "tray_note_shown": null},
		{"gifts_given": {"50": true}, "tray_note_shown": [true]},
		{"gifts_given": [], "tray_note_shown": true, "highest_cleared": 70, "next_level": 71},
	]
	for i: int in cases.size():
		var c: Dictionary = cases[i]
		_write_progress(c)
		boot()
		check(await until(func() -> bool: return flow.state == AppFlow.State.TITLE or flow.state == AppFlow.State.LEVEL), "case %d: the app starts" % i)
		var given := Array(save_node().gifts_given())
		for level: Variant in given:
			check(int(level) >= 1 and int(level) <= Save.MAX_LEVEL, "case %d: a recorded gift level %s is a real level" % [i, str(level)])
		check(given.size() <= 32, "case %d: at most 32 gift records (%d)" % [i, given.size()])
		check(typeof(save_node().tray_note_shown()) == TYPE_BOOL, "case %d: the shrink line flag is a bool" % i)
		flow.queue_free()
		await frames(2)
	save_node().erase_all()
