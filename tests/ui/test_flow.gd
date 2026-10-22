# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The app flow (docs/ARCHITECTURE.md 10.3 and docs/UX.md 4) against a fake level scene that
## emits won and lost on demand. Uses the Save autoload, which the runner points at a
## temporary folder.

const FLOW := preload("res://src/ui/app_flow.tscn")
const FAKE_SCENE := "res://tests/ui/fake_level_scene.tscn"

var flow: AppFlow
var quit_calls := 0


func _save() -> Node:
	return tree.root.get_node("Save")


## Starts the app with the saved progress cleared (a first launch), or with level `cleared`
## already won, so Play continues at cleared + 1.
func _start(cleared: int = 0) -> void:
	var save := _save()
	save.erase_all()
	if cleared > 0:
		var level := LevelCatalog.get_level(LevelData.NUMBERED, cleared, "").level
		save.record_win(level, 9000, Vector3i(1, 1, 1))
	flow = FLOW.instantiate() as AppFlow
	flow.level_scene_path = FAKE_SCENE
	flow.quit_handler = func() -> void: quit_calls += 1
	add_node(flow)


func _until(condition: Callable, timeout_ms: int = 15000) -> bool:
	var started := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - started > timeout_ms:
			return false
		await tree.process_frame
	return true


func _in_state(s: AppFlow.State) -> bool:
	return await _until(func() -> bool: return flow.state == s)


func _fake() -> FakeLevelScene:
	return flow.level_scene as FakeLevelScene


func _tap(label: String) -> void:
	var b := flow.screen.find_button(label)
	check(b != null, "the screen has a button \"%s\"" % label)
	if b != null:
		check(not b.disabled, "\"%s\" can be tapped" % label)
		b.pressed.emit()


## Waits past the 500 ms the clear screen keeps its buttons off.
func _past_clear_delay() -> void:
	await frames(40)


func _file(name: String) -> String:
	return FileAccess.get_file_as_string(_save().dir + name)


func test_a_first_launch_goes_straight_to_level_1() -> void:
	_start()
	check(await _in_state(AppFlow.State.LEVEL), "reaches the level")
	check(flow.screen == null, "no title or other screen")
	check_eq(_fake().played.size(), 1, "one level played")
	check_eq(_fake().played[0].number, 1, "level 1")
	check_eq(_fake().replays[0], false, "not a replay")


func test_a_later_launch_shows_the_title_and_play_continues() -> void:
	_start(4)
	check_eq(flow.state, AppFlow.State.TITLE, "title first")
	var play := flow.screen.find_button("Play")
	check_eq(play.note_text, "Level 5", "Play says where it continues")
	check(play.custom_minimum_size.y >= 72.0, "Play is a big button")
	play.pressed.emit()
	check(await _in_state(AppFlow.State.LEVEL), "reaches the level")
	check_eq(_fake().played[0].number, 5, "level 5")
	check_eq(_fake().replays[0], false, "continuing is not a replay")


func test_win_then_next_plays_level_2_and_saves() -> void:
	_start()
	await _in_state(AppFlow.State.LEVEL)
	_fake().win(12000, Vector3i(1, 1, 0))
	check_eq(flow.state, AppFlow.State.CLEAR, "the clear screen shows")
	# Saved at the moment of the clear (UX 3.4).
	var saved: Dictionary = JSON.parse_string(_file("progress.json"))
	check_eq(saved["next_level"], 2.0, "next_level saved")
	check_eq(saved["highest_cleared"], 1.0, "highest_cleared saved")
	check_eq(saved["star_bank"], 2.0, "stars saved")
	check_eq(_save().next_level(), 2, "next_level")
	# The buttons wait 500 ms.
	var next := flow.screen.find_button("Next")
	check(next.disabled, "Next is not tappable at once")
	await _past_clear_delay()
	check(not next.disabled, "Next is tappable after 500 ms")
	check_eq(next.note_text, "Level 2", "Next names the level")
	next.pressed.emit()
	check(await _in_state(AppFlow.State.LEVEL), "level 2 starts")
	check_eq(_fake().played.size(), 2, "two levels played")
	check_eq(_fake().played[1].number, 2, "level 2")
	check(flow.screen == null, "the clear screen is gone")


func test_replay_plays_the_same_level_again() -> void:
	_start()
	await _in_state(AppFlow.State.LEVEL)
	_fake().win()
	await _past_clear_delay()
	_tap("Replay")
	check_eq(flow.state, AppFlow.State.LEVEL, "playing again")
	check_eq(_fake().played.size(), 2, "played twice")
	check(_fake().played[0] == _fake().played[1], "the same LevelData")
	check_eq(_fake().replays[1], true, "marked as a replay")
	check_eq(_save().next_level(), 2, "next_level is not moved by a replay")


func test_a_generated_level_is_played_and_the_next_one_is_saved_ahead() -> void:
	_start(8)
	flow.screen.find_button("Play").pressed.emit()
	check(await _in_state(AppFlow.State.LEVEL), "level 9 starts")
	var level := _fake().played[0]
	check_eq(level.number, 9, "level 9")
	check_eq(level.kind, LevelData.NUMBERED, "a generated level")
	# Level 10 is made while 9 is played, and written for the next launch.
	var arrived := await _until(func() -> bool: return FileAccess.file_exists(_save().dir + "next_level.json") and _file("next_level.json").contains("numbered:9"))
	check(arrived, "next_level.json holds the Play level")
	_fake().win()
	var key := LevelPrefetcher.key_for(LevelData.NUMBERED, 10, "")
	var ahead := await _until(func() -> bool: return _save().read_next_level(key, Generator.GENERATOR_VERSION) != null)
	check(ahead, "level 10 is saved once it arrives")
	await _past_clear_delay()
	_tap("Next")
	check(await _in_state(AppFlow.State.LEVEL), "level 10 starts")
	check_eq(_fake().played[1].number, 10, "level 10")


func test_the_saved_next_level_is_played_without_generating() -> void:
	_start(11)
	# Level 12 as the last run left it.
	var level := LevelCatalog.get_level(LevelData.NUMBERED, 12, "").level
	_save().write_next_level("numbered:12", level)
	flow.queue_free()
	await frames(2)
	flow = FLOW.instantiate() as AppFlow
	flow.level_scene_path = FAKE_SCENE
	flow.quit_handler = func() -> void: quit_calls += 1
	add_node(flow)
	check_eq(flow.state, AppFlow.State.TITLE, "title")
	flow.screen.find_button("Play").pressed.emit()
	# The level came from the file (after its check), not from the generator.
	check(await _in_state(AppFlow.State.LEVEL), "playing")
	check_eq(JSON.stringify(_fake().played[0].to_dict()), JSON.stringify(level.to_dict()), "the saved level")


func test_a_saved_level_for_another_key_is_ignored() -> void:
	_start(11)
	var wrong := LevelCatalog.get_level(LevelData.NUMBERED, 20, "").level
	_save().write_next_level("numbered:12", wrong)
	flow.queue_free()
	await frames(2)
	flow = FLOW.instantiate() as AppFlow
	flow.level_scene_path = FAKE_SCENE
	flow.quit_handler = func() -> void: quit_calls += 1
	add_node(flow)
	flow.screen.find_button("Play").pressed.emit()
	check(await _in_state(AppFlow.State.LEVEL), "level 12 is generated")
	check_eq(_fake().played[0].number, 12, "level 12, not 20")


func test_loss_then_retry_replays_the_same_level() -> void:
	_start()
	await _in_state(AppFlow.State.LEVEL)
	_fake().lose()
	check_eq(flow.state, AppFlow.State.LOST, "out of room shows")
	check(flow.screen.find_button("Retry") != null, "Retry")
	_tap("Retry")
	check_eq(flow.state, AppFlow.State.LEVEL, "back in the level")
	check_eq(_fake().retries, 1, "the scene was asked to retry")
	check_eq(_fake().played.size(), 1, "same level, not a new one")
	check(flow.screen == null, "the sheet is gone")
	# A second loss works the same way.
	_fake().lose()
	check_eq(flow.state, AppFlow.State.LOST, "out of room again")


func test_previous_level_goes_to_n_minus_1_and_not_on_level_1() -> void:
	_start()
	await _in_state(AppFlow.State.LEVEL)
	_fake().lose()
	check(flow.screen.find_button("Previous level") == null, "not offered on level 1")
	check(flow.screen.find_button("Title") != null, "Title is")
	_tap("Retry")
	_fake().win()
	await _past_clear_delay()
	_tap("Next")
	await _in_state(AppFlow.State.LEVEL)
	check_eq(_fake().played[-1].number, 2, "on level 2")
	_fake().lose()
	check(flow.screen.find_button("Previous level") != null, "offered on level 2")
	_tap("Previous level")
	check(await _in_state(AppFlow.State.LEVEL), "level 1 again")
	check_eq(_fake().played[-1].number, 1, "level 1")
	check(_fake().played[-1] == _fake().played[0], "the LevelData was kept, not made again")
	check_eq(_fake().replays[-1], true, "a replay")
	check_eq(_save().next_level(), 2, "Play still goes to level 2")


func test_previous_level_is_generated_when_it_is_not_in_hand() -> void:
	_start(11)
	flow.screen.find_button("Play").pressed.emit()
	await _in_state(AppFlow.State.LEVEL)
	_fake().lose()
	_tap("Previous level")
	check(await _in_state(AppFlow.State.LEVEL), "level 11 starts")
	check_eq(_fake().played[-1].number, 11, "level 11")


func test_back_on_the_title_quits() -> void:
	_start(2)
	check_eq(flow.state, AppFlow.State.TITLE, "title")
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check_eq(quit_calls, 1, "Back on the title closes the game")


func test_back_in_the_level_opens_pause_and_back_again_resumes() -> void:
	_start()
	await _in_state(AppFlow.State.LEVEL)
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check_eq(flow.state, AppFlow.State.PAUSE, "pause")
	check(_fake().is_paused, "the level is paused")
	check_eq(quit_calls, 0, "the game is not closed")
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check_eq(flow.state, AppFlow.State.LEVEL, "Back on pause resumes")
	check(not _fake().is_paused, "the level runs again")
	check_eq(_fake().resumes, 1, "resumed once")


func test_the_level_gets_back_first() -> void:
	_start()
	await _in_state(AppFlow.State.LEVEL)
	_fake().back_handled = true
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check_eq(flow.state, AppFlow.State.LEVEL, "the level handled it")
	check_eq(_fake().pauses, 0, "no pause")


func test_back_on_clear_and_out_of_room_goes_to_the_title() -> void:
	_start()
	await _in_state(AppFlow.State.LEVEL)
	_fake().win()
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check_eq(flow.state, AppFlow.State.TITLE, "clear to title")
	check_eq(_save().next_level(), 2, "the clear was saved")
	check_eq(flow.screen.find_button("Play").note_text, "Level 2", "Play continues at 2")
	flow.screen.find_button("Play").pressed.emit()
	await _in_state(AppFlow.State.LEVEL)
	_fake().lose()
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check_eq(flow.state, AppFlow.State.TITLE, "out of room to title")
	check_eq(quit_calls, 0, "never closed")


func test_pause_screen_buttons() -> void:
	_start()
	await _in_state(AppFlow.State.LEVEL)
	_fake().pause_requested.emit()
	check_eq(flow.state, AppFlow.State.PAUSE, "pause")
	check_eq(_fake().pauses, 1, "the level was paused")
	for label: String in ["Resume", "Retry", "Sound: On", "Music: On", "Quit to title"]:
		check(flow.screen.find_button(label) != null, "Pause has \"%s\"" % label)
	_tap("Sound: On")
	check(flow.screen.find_button("Sound: Off") != null, "the label changes at once")
	check(not _save().sound, "sound is saved off")
	_tap("Sound: Off")
	check(_save().sound, "sound is back on")
	_tap("Retry")
	check_eq(flow.state, AppFlow.State.LEVEL, "retry returns to the level")
	check_eq(_fake().retries, 1, "retried")
	check(not _fake().is_paused, "and runs")
	_fake().pause_requested.emit()
	_tap("Quit to title")
	check_eq(flow.state, AppFlow.State.TITLE, "title")
	check(flow.level_scene == null, "the level is gone")
	# Play starts the same level again, from the beginning.
	flow.screen.find_button("Play").pressed.emit()
	check_eq(flow.state, AppFlow.State.LEVEL, "playing")
	check_eq(_fake().played[0].number, 1, "level 1 again")
	check_eq(_fake().played.size(), 1, "on a fresh scene")


func test_focus_loss_saves_and_pauses() -> void:
	_start()
	await _in_state(AppFlow.State.LEVEL)
	DirAccess.remove_absolute(_save().dir + "progress.json")
	DirAccess.remove_absolute(_save().dir + "settings.json")
	flow.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check_eq(flow.state, AppFlow.State.PAUSE, "paused")
	check(_fake().is_paused, "the level is paused")
	check(FileAccess.file_exists(_save().dir + "progress.json"), "progress saved")
	check(FileAccess.file_exists(_save().dir + "settings.json"), "settings saved")
	# Losing focus again, or leaving through the system, changes nothing more.
	flow.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check_eq(flow.state, AppFlow.State.PAUSE, "still paused")
	check_eq(_fake().pauses, 1, "paused once")


func test_leaving_on_the_clear_screen_saves_and_stays() -> void:
	_start()
	await _in_state(AppFlow.State.LEVEL)
	_fake().win()
	DirAccess.remove_absolute(_save().dir + "progress.json")
	flow.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check_eq(flow.state, AppFlow.State.CLEAR, "stays on the clear screen")
	check(FileAccess.file_exists(_save().dir + "progress.json"), "progress saved")


func test_a_missing_level_scene_shows_a_plain_message() -> void:
	_save().erase_all()
	flow = FLOW.instantiate() as AppFlow
	flow.level_scene_path = "res://tests/ui/does_not_exist.tscn"
	add_node(flow)
	await _until(func() -> bool: return flow.state == AppFlow.State.ERROR, 5000)
	check_eq(flow.state, AppFlow.State.ERROR, "the error screen")


func test_play_back_play_while_the_level_is_still_being_made() -> void:
	_start(11)
	_save().set_next_level_for_tests(150)
	flow.queue_free()
	await frames(2)
	flow = FLOW.instantiate() as AppFlow
	flow.level_scene_path = FAKE_SCENE
	flow.quit_handler = func() -> void: quit_calls += 1
	add_node(flow)
	flow.screen.find_button("Play").pressed.emit()
	var waited := flow.state == AppFlow.State.LOADING
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check_eq(flow.state, AppFlow.State.TITLE, "Back leaves the loading screen")
	flow.screen.find_button("Play").pressed.emit()
	check(await _in_state(AppFlow.State.LEVEL), "the level starts (it was still loading: %s)" % str(waited))
	check_eq(_fake().played[0].number, 150, "level 150")


func test_a_loss_during_pause_is_shown_on_resume() -> void:
	_start()
	await _in_state(AppFlow.State.LEVEL)
	_fake().pause_requested.emit()
	check_eq(flow.state, AppFlow.State.PAUSE, "paused")
	_fake().lose()
	check_eq(flow.state, AppFlow.State.PAUSE, "the pause screen stays")
	_tap("Resume")
	check_eq(flow.state, AppFlow.State.LOST, "Out of room shows on resume")


func test_a_win_during_pause_shows_level_clear() -> void:
	_start()
	await _in_state(AppFlow.State.LEVEL)
	_fake().pause_requested.emit()
	_fake().win()
	check_eq(flow.state, AppFlow.State.CLEAR, "Level clear shows")
	check_eq(_save().next_level(), 2, "and the win is saved")


func test_retry_from_pause_forgets_a_loss_that_arrived_while_paused() -> void:
	_start()
	await _in_state(AppFlow.State.LEVEL)
	_fake().pause_requested.emit()
	_fake().lose()
	_tap("Retry")
	check_eq(flow.state, AppFlow.State.LEVEL, "playing again")
	_fake().pause_requested.emit()
	_tap("Resume")
	check_eq(flow.state, AppFlow.State.LEVEL, "no stale loss")


func test_a_level_that_finishes_on_the_title_is_kept_for_play() -> void:
	_start(11)
	_save().set_next_level_for_tests(150)
	flow.queue_free()
	await frames(2)
	flow = FLOW.instantiate() as AppFlow
	flow.level_scene_path = FAKE_SCENE
	flow.quit_handler = func() -> void: quit_calls += 1
	add_node(flow)
	flow.screen.find_button("Play").pressed.emit()
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check_eq(flow.state, AppFlow.State.TITLE, "back on the title")
	var arrived := await _until(func() -> bool: return flow.call("_known", LevelData.NUMBERED, 150, "") != null)
	check(arrived, "the level finishes while the title is up and is kept")
	flow.screen.find_button("Play").pressed.emit()
	check_eq(flow.state, AppFlow.State.LEVEL, "Play starts it at once, with no new wait")
	check_eq(_fake().played[0].number, 150, "level 150")
