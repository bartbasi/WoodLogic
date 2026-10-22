# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends QaFlowCase
## Phase 4 edge cases around the new parts, over the real level scene where the board matters:
## the paused level kept alive through the dock, Back on every screen (UX 4.2), the coffee
## cup and chip, locked map nodes, Settings while paused, reset, buying with too few stars.

const Kit := preload("res://tests/level/kit.gd")


func test_acc_13e_a_paused_real_level_is_untouched_by_a_tour_of_every_menu() -> void:
	start_real(3)
	check(await level_on(), "level 4 is on")
	await play_taps(4)
	var before := state_text()
	var tray_before := scene().get_state().tray()
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check_eq(flow.state, AppFlow.State.PAUSE, "Back pauses")
	tap("Settings")
	var started := Time.get_ticks_msec()
	for tab: String in ["Map", "Stats", "Info", "About", "Settings", "Home", "Map", "About"]:
		tap(tab)
		await frames(2)
	tap("License")
	check_eq(flow.menu, "license", "License")
	back()
	tap("Credits")
	back()
	tap("Home")
	check_eq(flow.state, AppFlow.State.TITLE, "on the title")
	check(not scene().visible, "the level is hidden while menus show")
	check(flow.screen.find_button("Back to level") != null, "the Play button now reads Back to level")
	await wait_ms(1500 - (Time.get_ticks_msec() - started))
	tap("Back to level")
	check_eq(flow.state, AppFlow.State.LEVEL, "straight back into the level")
	check(scene().visible, "the board is showing")
	check_eq(state_text(), before, "the rule state is exactly as it was")
	check_eq(scene().get_state().tray(), tray_before, "the tray is as it was")
	check_eq(Kit.mismatches(scene()).size(), 0, "the picture matches the model")
	# Finish: the 1.5 s spent in menus must not be in the time.
	await play_taps()
	check(await in_state(AppFlow.State.CLEAR), "the level was won")
	var best := int(save_node().level_record(4).get("best_ms", -1))
	check(best >= 0 and best < 1200, "the recorded time %d ms leaves out the time spent in menus" % best)


func test_acc_13e_quit_or_another_level_restarts_the_paused_one_next_time() -> void:
	start_real(3)
	check(await level_on(), "level 4 is on")
	await play_taps(3)
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	tap("Quit to title")
	check(flow.screen.find_button("Back to level") == null, "the paused level is gone")
	tap("Play")
	check(await level_on(), "Play starts level 4 again")
	check_eq(scene().get_state().tray_uses(), 0, "from the beginning")
	check_eq(scene().get_state().snapshot()["on_board"].size(), scene().get_level().screw_count(), "every screw is back on the board")
	# Starting another level from the map drops a paused one too.
	await play_taps(2)
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	tap("Settings")
	tap("Map")
	await frames(3)
	var view := (flow.screen as MapScreen).view
	view.tap(view.center_of(2))
	check(await level_on(), "level 2 starts")
	check_eq(scene().get_level().number, 2, "it is level 2")
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	tap("Quit to title")
	check(flow.screen.find_button("Back to level") == null, "nothing is kept")


func test_a_locked_map_node_leaves_the_paused_level_alone() -> void:
	start_real(3)
	check(await level_on(), "level 4 is on")
	await play_taps(2)
	var before := state_text()
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	tap("Settings")
	tap("Map")
	await frames(3)
	var map := flow.screen as MapScreen
	var view := map.view
	# Hammer every locked node, and between nodes, and a cleared node's neighbor.
	for n: int in [6, 7, 8, 5, 6, 6, 6, 8]:
		view.tap(view.center_of(n))
	view.tap(view.center_of(5) + Vector2(150.0, 0.0))
	view.tap(Vector2(-50.0, -50.0))
	view.tap(Vector2(10000.0, 10000.0))
	check_eq(flow.state, AppFlow.State.MENU, "still on the map")
	check_eq(flow.toast.text, "Clear level 4 first.", "the toast names the level to clear")
	tap("Back to level")
	check_eq(flow.state, AppFlow.State.LEVEL, "the paused level is still there")
	check_eq(state_text(), before, "and untouched")
	# Tapping the next node while its level is paused restarts it (a different attempt).
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	tap("Settings")
	tap("Map")
	await frames(3)
	view = (flow.screen as MapScreen).view
	view.tap(view.center_of(4))
	check(await level_on(), "the next node starts level 4")
	check_eq(scene().get_state().tray_uses(), 0, "afresh")


func test_acc_13d_the_map_on_a_huge_save_stays_small_and_taps_work() -> void:
	var save := save_node()
	save.erase_all()
	var p: Dictionary = save.default_progress()
	p["highest_cleared"] = 250000
	p["next_level"] = 250001
	DirAccess.make_dir_recursive_absolute(str(save.dir))
	var f := FileAccess.open(str(save.dir) + "progress.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(p))
	f.close()
	boot()
	await in_state(AppFlow.State.TITLE)
	tap("Map")
	await frames(3)
	var view := (flow.screen as MapScreen).view
	check(view.pool_size() <= 30, "the node pool is %d" % view.pool_size())
	view.tap(view.center_of(250005))
	check_eq(flow.toast.text, "Clear level 250001 first.", "a locked node far up")
	view.tap(view.center_of(250000))
	check(await in_state(AppFlow.State.LEVEL), "a cleared node far up replays")
	check_eq(fake().played[-1].number, 250000, "level 250000")


func test_settings_changed_while_paused_show_when_the_player_goes_back_to_the_level() -> void:
	start_real(3)
	check(await level_on(), "level 4 is on")
	var views := nodes_of(scene(), "ScrewView")
	check(views.size() > 0, "the board has screw views")
	var symbols_on := 0
	for v: Node in views:
		if int(((v as Node2D).material as ShaderMaterial).get_shader_parameter("symbol")) >= 0:
			symbols_on += 1
	check(symbols_on > 0, "symbols are on to start with")
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	tap("Settings")
	var settings := flow.screen as SettingsScreen
	settings.symbols_toggled.emit(false)
	check(not Looks.symbols_on(), "Looks says symbols are off")
	tap("Back to level")
	await frames(3)
	var still := 0
	for v: Node in nodes_of(scene(), "ScrewView"):
		if (v as Node2D).visible and int(((v as Node2D).material as ShaderMaterial).get_shader_parameter("symbol")) >= 0:
			still += 1
	check_eq(still, 0, "screws still drawn with symbols after switching them off and going back to the level")


func test_acc_13a_a_killed_app_comes_back_to_the_same_level_from_the_beginning() -> void:
	start_real(5)
	check(await level_on(), "level 6 is on")
	await play_taps(5)
	var level := scene().get_level()
	# The app loses focus (saved), then is killed: no quit, no Save call of ours.
	flow.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check_eq(flow.state, AppFlow.State.PAUSE, "focus loss pauses")
	var progress_text := FileAccess.get_file_as_string(str(save_node().dir) + "progress.json")
	for word: String in ["tray", "boxes", "on_board", "screws", "snapshot", "plank"]:
		check(not progress_text.contains(word), "the save holds no board state (found \"%s\")" % word)
	flow.queue_free()
	await frames(3)
	boot()
	check(await in_state(AppFlow.State.TITLE), "the title shows after the restart")
	check_eq(save_node().next_level(), 6, "Play continues at level 6")
	tap("Play")
	check(await in_state(AppFlow.State.LEVEL), "level 6 starts")
	check_eq(fake().played[-1].number, 6, "the same level")
	check_eq(var_to_str(fake().played[-1].to_dict()), var_to_str(level.to_dict()), "the same board, colors and queue")
	check_eq(fake().played[-1].screw_count(), level.screw_count(), "from the beginning")


func test_an_older_save_with_few_fields_is_migrated_and_plays() -> void:
	var save := save_node()
	save.erase_all()
	DirAccess.make_dir_recursive_absolute(str(save.dir))
	var f := FileAccess.open(str(save.dir) + "progress.json", FileAccess.WRITE)
	f.store_string("{\"next_level\": 12, \"highest_cleared\": 11, \"levels\": {\"1\": {\"stars\": 3, \"best_ms\": 20000}, \"11\": {\"stars\": 2, \"best_ms\": 90000}}, \"star_bank\": 21}")
	f.close()
	boot()
	check(await in_state(AppFlow.State.TITLE), "the title shows")
	check_eq(save.highest_cleared(), 11, "levels cleared are kept")
	check_eq(save.star_bank(), 21, "the star bank is kept")
	check_eq(int(save.level_record(11)["stars"]), 2, "a level record is kept")
	check_eq(save.helper_count("undo"), 0, "new fields start at zero")
	tap("Map")
	await frames(3)
	check_eq(flow.menu, "map", "the map opens")
	tap("Stats")
	check_eq(flow.menu, "stats", "Stats opens")
	tap("Play")
	check(await in_state(AppFlow.State.LEVEL), "Play starts level 12")
	check_eq(fake().played[-1].number, 12, "level 12")


func test_the_cup_shows_from_level_4_and_never_when_coffee_is_hidden() -> void:
	for pair: Array in [[0, 0, false], [2, 0, false], [3, 0, true], [3, 1, false], [20, 0, true], [20, 1, false]]:
		Links.coffee_hidden_for_tests = pair[1]
		start_real(pair[0])
		check(await level_on(), "level %d is on" % (int(pair[0]) + 1))
		check_eq(bool(scene().debug_snapshot()["cup"]), pair[2], "level %d, coffee hidden=%d: the cup" % [int(pair[0]) + 1, pair[1]])
		flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		var text := all_text(flow.screen)
		if int(pair[1]) == 1:
			check(not text.contains("coffee"), "Pause says nothing about coffee when it is hidden")
		else:
			check_eq(nodes_of(flow.screen, "CoffeeChip").size(), 1, "Pause keeps its coffee chip")
		flow.queue_free()
		await frames(2)
	Links.coffee_hidden_for_tests = -1


func test_acc_13_retry_gives_an_identical_level_and_resets_clock_tray_helpers_and_extra_slot() -> void:
	start_real(14)
	check(await level_on(), "level 15 is on")
	var level := scene().get_level()
	var before := var_to_str(level.to_dict())
	await play_taps(3)
	var hud: LevelHud = scene().get("_hud") as LevelHud
	var p := hud.target_of("extra_slot").get_center()
	for pressed: bool in [true, false]:
		var e := InputEventScreenTouch.new()
		e.position = p
		e.pressed = pressed
		scene().call("_gui_input", e)
	check(scene().get_state().extra_slot_used(), "Extra slot was used")
	check_eq(scene().get_state().tray().size(), 5, "four slots and the Extra slot (levels 12 to 20 have a 4 slot tray)")
	check(bool(scene().debug_snapshot()["clock_running"]), "the clock is running")
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	tap("Retry")
	await frames(3)
	check_eq(flow.state, AppFlow.State.LEVEL, "playing again")
	check_eq(var_to_str(scene().get_level().to_dict()), before, "the identical level")
	var state := scene().get_state()
	check_eq(state.tray().size(), 4, "the level's normal four slots")
	check_eq(state.tray_uses(), 0, "tray uses reset")
	check(not state.extra_slot_used(), "Extra slot is available again")
	check_eq(state.helpers_used().size(), 0, "helpers used reset")
	check(not bool(scene().debug_snapshot()["clock_running"]), "the clock waits for the first action")
	check_eq(save_node().helper_count("extra_slot"), 1, "the spent Extra slot stays spent (2 free, 1 used)")


func test_uc_4_2_back_in_screwdriver_mode_leaves_the_mode_and_keeps_the_helper() -> void:
	start_real(24)
	check(await level_on(), "level 25 is on")
	var hud: LevelHud = scene().get("_hud") as LevelHud
	var p := hud.target_of("screwdriver").get_center()
	for pressed: bool in [true, false]:
		var e := InputEventScreenTouch.new()
		e.position = p
		e.pressed = pressed
		scene().call("_gui_input", e)
	check(bool(scene().get("_driver")), "the Screwdriver mode is on")
	back()
	check_eq(flow.state, AppFlow.State.LEVEL, "Back leaves the mode and does not pause")
	check(not bool(scene().get("_driver")), "the mode is off")
	check_eq(save_node().helper_count("screwdriver"), 2, "the helper was kept")
	back()
	check_eq(flow.state, AppFlow.State.PAUSE, "the next Back pauses")


func test_ux_4_4_speed_targets_play_next_and_retry_on_this_pc() -> void:
	# The title asks for the Play level while it shows; give the worker a moment, as a player
	# reading the title does, then time Play to a level on the screen.
	start_real(12)
	await wait_ms(1500)
	var started := Time.get_ticks_msec()
	tap("Play")
	var on := await until(func() -> bool: return flow.state == AppFlow.State.LEVEL, 5000)
	var play_ms := Time.get_ticks_msec() - started
	check(on, "Play starts a level")
	# Next from the clear screen: the level after is made while the player plays.
	scene().set_instant(true)
	await wait_ms(1500)
	await play_taps()
	check(await in_state(AppFlow.State.CLEAR), "cleared")
	await past_clear_delay()
	started = Time.get_ticks_msec()
	tap("Next")
	await until(func() -> bool: return flow.state == AppFlow.State.LEVEL, 5000)
	var next_ms := Time.get_ticks_msec() - started
	check_eq(scene().get_level().number, 14, "Next plays level 14")
	# Retry from pause.
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	started = Time.get_ticks_msec()
	tap("Retry")
	var retry_ms := Time.get_ticks_msec() - started
	check_eq(flow.state, AppFlow.State.LEVEL, "Retry is playing at once")
	print("        speed on this PC (headless, a prefetched level): Play to level %d ms, Next to level %d ms, Retry %d ms" % [play_ms, next_ms, retry_ms])
	check(play_ms < 1000, "Play to the first tappable screw is under one second (UX 4.4): %d ms" % play_ms)
	check(next_ms < 1000, "Next is under one second: %d ms" % next_ms)
	check(retry_ms < 400, "Retry is playable within 400 ms: %d ms" % retry_ms)


func test_fun_2_every_tap_answers_within_100_ms_with_animation_on() -> void:
	start_real(14)
	check(await level_on(), "level 15 is on")
	scene().set_instant(false)
	var sol := solution()
	var worst := 0
	var total := 0
	for s: int in sol:
		var started := Time.get_ticks_usec()
		scene().tap_screw(s)
		var took := Time.get_ticks_usec() - started
		worst = maxi(worst, took)
		total += took
		await frames(2)
	@warning_ignore("integer_division")
	print("        tap_screw with animation on: mean %.2f ms, worst %.2f ms over %d taps" % [total / 1000.0 / sol.size(), worst / 1000.0, sol.size()])
	check(worst < 100000, "the slowest tap took %.1f ms (the answer, with its motion and sound, starts within 100 ms)" % (worst / 1000.0))
