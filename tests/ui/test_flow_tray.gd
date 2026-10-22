# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends FlowCase
## The smaller tray (the shrink line, the closing), the gifts and the text built from the data
## (docs/UX.md 3.2.2, 3.4, 3.13.4, 3.14).

const NOTE := "The tray is smaller now. Every slot counts."

var _saved_gifts: Array[Dictionary] = []
var _gifts_swapped := false


func cleanup() -> void:
	if _gifts_swapped:
		Tuning.gifts = _saved_gifts
	await super.cleanup()


func _use_gifts(list: Array[Dictionary]) -> void:
	if not _gifts_swapped:
		_saved_gifts = Tuning.gifts.duplicate()
	_gifts_swapped = true
	Tuning.gifts = list


func _two_gifts() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"level": 3, "undo": 2, "extra_slot": 1, "screwdriver": 0},
		{"level": 5, "undo": 2, "extra_slot": 1, "screwdriver": 0},
	]
	return out


## The first numbered level whose tray is smaller than the start (12 on the normal data).
func _first_smaller() -> int:
	var steps := UiText.tray_steps()
	return int(steps[0][1]) if not steps.is_empty() else 0


func _restart() -> void:
	flow.queue_free()
	await frames(2)
	boot()


func test_the_data_has_a_smaller_tray_step() -> void:
	var steps := UiText.tray_steps()
	check(not steps.is_empty(), "the tray gets smaller somewhere")
	check_eq(UiText.tray_for(1), Tuning.tray_size, "the tutorial keeps the starting size")
	check(UiText.tray_for(_first_smaller()) < Tuning.tray_size, "from the first step it is smaller")


func test_the_shrink_line_shows_once_on_the_first_smaller_level() -> void:
	var first := _first_smaller()
	start()
	save_node().set_next_level_for_tests(first)
	await _restart()
	tap("Play")
	check(await in_state(AppFlow.State.LEVEL), "the level starts")
	check_eq(fake().played[-1].number, first, "level %d" % first)
	check_eq(fake().tray_notes, [NOTE], "the line, word for word")
	check(save_node().tray_note_shown(), "marked shown")
	check_eq(fake().tray_closings, 0, "no closing from the title")
	# Quit and play again: never again.
	if flow.overlay != null:
		back()
	fake().pause_requested.emit()
	tap("Quit to title")
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	check_eq(fake().tray_notes.size(), 0, "a fresh scene was not told again")
	# Retry never shows it.
	fake().lose()
	tap("Retry")
	check_eq(fake().tray_notes.size(), 0, "not on Retry")


func test_the_shrink_line_is_not_for_replays_daily_or_relaxed() -> void:
	var first := _first_smaller()
	start(8)
	save_node().set_next_level_for_tests(first + 2)
	await _restart()
	tap("Map")
	await frames(3)
	var view := (flow.screen as MapScreen).view
	view.tap(view.center_of(first))
	check(await in_state(AppFlow.State.LEVEL), "a replay of the first smaller level")
	check_eq(fake().replays[-1], true, "it is a replay")
	check(fake().tray_notes.is_empty(), "no line on a replay")
	check(not save_node().tray_note_shown(), "and not marked")
	flow.play_daily()
	check(await in_state(AppFlow.State.LEVEL), "the daily")
	check(fake().tray_notes.is_empty(), "no line in the daily")
	flow.play_relaxed("hard")
	check(await in_state(AppFlow.State.LEVEL), "relaxed")
	check(fake().tray_notes.is_empty(), "no line in Relaxed")
	check_eq(fake().tray_closings, 0, "and no closing")


func test_the_tray_closes_when_next_arrives_at_a_smaller_tray() -> void:
	var first := _first_smaller()
	start()
	save_node().set_next_level_for_tests(first - 1)
	await _restart()
	tap("Play")
	check(await in_state(AppFlow.State.LEVEL), "the level before")
	check_eq(fake().tray_closings, 0, "no closing at the old size")
	while flow.overlay != null:
		back()
	fake().win()
	await past_clear_delay()
	tap("Next")
	check(await in_state(AppFlow.State.LEVEL), "level %d" % first)
	check_eq(fake().tray_closings, 1, "the tray closes on arrival by Next")
	check_eq(fake().tray_notes, [NOTE], "and the line shows too")


func test_a_gift_is_given_once_and_shown_on_the_clear_screen() -> void:
	_use_gifts(_two_gifts())
	start(2)
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	check_eq(save_node().helper_count("extra_slot"), 0, "nothing yet")
	fake().win()
	var clear := flow.screen as ClearScreen
	check_eq(clear.gift_notes, ["A gift for reaching level 3: 2 Undos and 1 Extra slot."], "the plaque")
	check_eq(save_node().helper_count("undo"), 2, "two Undos")
	check_eq(save_node().helper_count("extra_slot"), 1, "one Extra slot")
	check_eq(Array(save_node().gifts_given()), [3], "recorded")
	await past_clear_delay()
	check(clear.find_button("Next") != null and not clear.find_button("Next").disabled, "Next is still one tap")
	tap("Next")
	await in_state(AppFlow.State.LEVEL)
	fake().win()
	check_eq((flow.screen as ClearScreen).gift_notes, ["A gift for reaching level 5: 2 Undos and 1 Extra slot."], "the next gift")
	check_eq(save_node().helper_count("undo"), 4, "added again")
	await past_clear_delay()
	tap("Replay")
	fake().win()
	check((flow.screen as ClearScreen).gift_notes.is_empty(), "never repeated")
	check_eq(save_node().helper_count("undo"), 4, "nothing more")


func test_both_gifts_due_at_once_show_one_note_with_the_sum() -> void:
	_use_gifts(_two_gifts())
	start(6)
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	fake().win()
	check_eq((flow.screen as ClearScreen).gift_notes, ["A gift for reaching level 3 and level 5: 4 Undos and 2 Extra slots."], "one note")
	check_eq(save_node().helper_count("undo"), 4, "both given")
	check_eq(Array(save_node().gifts_given()), [3, 5], "both recorded")


func test_a_kill_between_the_grant_and_the_plaque_gives_it_once() -> void:
	_use_gifts(_two_gifts())
	start(2)
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	fake().win()
	# The app dies here: nothing but the saved files remain.
	flow.queue_free()
	await frames(2)
	save_node().load_all()
	check_eq(save_node().helper_count("undo"), 2, "the grant was saved first")
	check(save_node().is_gift_given(3), "and its record")
	boot()
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	fake().win()
	var notes: Array[String] = (flow.screen as ClearScreen).gift_notes
	check(notes.size() == 1 and notes[0].contains("level 5") and not notes[0].contains("level 3"), "only the next gift comes: %s" % str(notes))
	check_eq(save_node().helper_count("undo"), 4, "each granted exactly once")


func test_no_gift_in_relaxed() -> void:
	_use_gifts(_two_gifts())
	start(8)
	tap("Relaxed")
	tap("Easy")
	await in_state(AppFlow.State.LEVEL)
	fake().win(1000, Vector3i.ZERO)
	check((flow.screen as ClearScreen).gift_notes.is_empty(), "no gift in Relaxed")
	check_eq(save_node().helper_count("undo"), 0, "no helpers")


func test_info_text_comes_from_the_data() -> void:
	var texts := PackedStringArray()
	for group: Array in InfoScreen.groups():
		for entry: Array in group[1]:
			texts.append(entry[1])
	var all := "\n".join(texts)
	check(all.contains(UiText.tray_line()), "the tray line")
	check(UiText.tray_line().begins_with("The tray starts with %d slots." % Tuning.tray_size), "starts from the data")
	for step: Array in UiText.tray_steps():
		check(UiText.tray_line().contains("%d from level %d" % [step[0], step[1]]), "step %s" % str(step))
	_use_gifts(_two_gifts())
	check_eq(UiText.gift_info_line(), "Reach level 3 and level 5 for a gift each time: 2 Undos and 1 Extra slot.", "the gift line")
	var undo: Dictionary = Tuning.helpers["undo"]
	check(all.contains("Undo %d," % int(undo["price"])), "the price comes from Tuning")
	Tuning.gifts = []
	check_eq(UiText.gift_info_line(), "", "no gifts, no line")


## A level handed out with a tray of its own, as a stored level from another tier's pool can.
func _level_with_tray(number: int, tray: int) -> LevelData:
	var level := LevelCatalog.get_level(LevelData.NUMBERED, number, "").level
	level.tray_size = tray
	return level


func test_the_line_and_the_closing_follow_the_real_tray_not_the_schedule() -> void:
	var first := _first_smaller()
	start()
	# The schedule says smaller, but this board really has the full tray: no line, no closing.
	flow.set("_arrival_tray", Tuning.tray_size)
	flow.call("_begin", _level_with_tray(first, Tuning.tray_size), false)
	check(fake().tray_notes.is_empty(), "no line on a board with the full tray")
	check_eq(fake().tray_closings, 0, "no closing to a size the board does not have")
	check(not save_node().tray_note_shown(), "and not marked")
	# A board that really is smaller gets both.
	flow.set("_arrival_tray", Tuning.tray_size)
	flow.call("_begin", _level_with_tray(first, Tuning.tray_size - 1), false)
	check_eq(fake().tray_notes, [NOTE], "the line on a really smaller tray")
	check_eq(fake().tray_closings, 1, "and the closing")


func test_leaving_without_a_next_level_forgets_the_arrival() -> void:
	start(3)
	flow.set("_arrival_tray", Tuning.tray_size)
	flow.quit_to_title()
	check_eq(flow.get("_arrival_tray"), 0, "quit to title forgets it")
	flow.set("_arrival_tray", Tuning.tray_size)
	flow.show_menu("stats")
	check_eq(flow.get("_arrival_tray"), 0, "a menu forgets it")
	tap("Home")
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	check_eq(fake().tray_closings, 0, "the next Play is not an arrival by Next")
