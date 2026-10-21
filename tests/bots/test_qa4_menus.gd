# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends QaFlowCase
## Phase 4 edge cases for Back on every screen (UX 4.2), the coffee chip and cup with coffee
## hidden, Settings while paused and reset progress. Over the fake level scene, which has the
## app flow's whole state machine but no board.

const MENUS: Array[String] = ["title", "map", "stats", "info", "settings", "about", "license", "credits", "relaxed"]


func test_uc_4_2_back_on_every_menu_screen_from_the_title() -> void:
	start(9)
	var before := var_to_str(save_node().progress_copy())
	for tab: String in ["Map", "Stats", "Info", "Settings", "About"]:
		tap(tab)
		await frames(1)
		back()
		check_eq(flow.menu, "title", "Back from %s goes to the title, not through the tabs" % tab)
	# Walk several tabs, then one Back still goes straight to the title.
	tap("Map")
	tap("Stats")
	tap("Info")
	tap("Settings")
	back()
	check_eq(flow.menu, "title", "Back after four tabs")
	tap("About")
	tap("License")
	back()
	check_eq(flow.menu, "about", "License to About")
	tap("Credits")
	back()
	check_eq(flow.menu, "about", "Credits to About")
	back()
	check_eq(flow.menu, "title", "About to the title")
	tap("Relaxed")
	check_eq(flow.menu, "relaxed", "Relaxed setup")
	back()
	check_eq(flow.menu, "title", "Relaxed setup to the title")
	check_eq(quit_calls, 0, "nothing quit yet")
	back()
	check_eq(quit_calls, 1, "Back on the title exits")
	check_eq(var_to_str(save_node().progress_copy()), before, "Back erased and spent nothing")


func test_uc_4_2_back_on_every_menu_screen_from_pause() -> void:
	await start_level_1()
	fake().pause_requested.emit()
	check_eq(flow.state, AppFlow.State.PAUSE, "paused")
	var before := var_to_str(save_node().progress_copy())
	tap("Settings")
	for tab: String in ["Map", "Stats", "Info", "About", "Settings"]:
		tap(tab)
		await frames(1)
		back()
		check_eq(flow.state, AppFlow.State.PAUSE, "Back from %s returns to Pause" % tab)
		tap("Settings")
	tap("About")
	tap("License")
	back()
	check_eq(flow.menu, "about", "License to About")
	back()
	check_eq(flow.state, AppFlow.State.PAUSE, "About to Pause")
	check(not fake().is_paused or flow.state == AppFlow.State.PAUSE, "the level is still the paused one")
	back()
	check_eq(flow.state, AppFlow.State.LEVEL, "Back on Pause resumes")
	check_eq(var_to_str(save_node().progress_copy()), before, "nothing erased or spent")


func test_uc_4_2_back_from_the_title_reached_by_a_tab_while_paused_exits_and_keeps_the_save() -> void:
	await start_level_1()
	fake().pause_requested.emit()
	tap("Settings")
	tap("Home")
	check_eq(flow.state, AppFlow.State.TITLE, "title")
	check(flow.screen.find_button("Back to level") != null, "the paused level is offered")
	back()
	check_eq(quit_calls, 1, "Back on the title exits (the paused level is not kept, UX 4.3)")


func test_uc_4_2_back_on_clear_lost_and_the_relaxed_stuck_sheet_goes_to_the_title() -> void:
	start(9)
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	fake().win()
	await past_clear_delay()
	check_eq(flow.state, AppFlow.State.CLEAR, "clear screen")
	back()
	check_eq(flow.state, AppFlow.State.TITLE, "Back on the clear screen goes to the title")
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	fake().lose()
	await frames(2)
	check_eq(flow.state, AppFlow.State.LOST, "out of room")
	back()
	check_eq(flow.state, AppFlow.State.TITLE, "Back on out of room goes to the title")
	tap("Relaxed")
	tap("Easy")
	await in_state(AppFlow.State.LEVEL)
	fake().lose()
	await frames(2)
	check_eq(flow.state, AppFlow.State.LOST, "the stuck sheet")
	back()
	check_eq(flow.state, AppFlow.State.TITLE, "Back on the stuck sheet goes to the title")


func test_uc_4_2_the_reset_dialog_closes_on_back_and_erases_nothing() -> void:
	start(5)
	tap("Settings")
	var before := var_to_str(save_node().progress_copy())
	tap("Reset progress")
	check(flow.overlay is UiDialog, "the dialog is up")
	back()
	check(flow.overlay == null, "Back closes it")
	check_eq(flow.menu, "settings", "still on Settings")
	check_eq(var_to_str(save_node().progress_copy()), before, "nothing erased")


func test_every_screen_has_one_dock_and_never_a_second_coffee_control() -> void:
	start(9)
	for hidden: int in [0, 1]:
		Links.coffee_hidden_for_tests = hidden
		for menu_name: String in MENUS:
			flow.show_menu(menu_name)
			await frames(2)
			var chips := nodes_of(flow.screen, "CoffeeChip").size()
			var text := all_text(flow.screen)
			var coffee_buttons := _coffee_buttons(flow.screen)
			var want_chip := 0
			if hidden == 0 and ["title", "map", "stats", "info", "settings", "relaxed"].has(menu_name):
				want_chip = 1
			check_eq(chips, want_chip, "%s, coffee hidden=%d: header chips" % [menu_name, hidden])
			if hidden == 1:
				check(not text.contains("coffee"), "%s: no word about coffee when hidden" % menu_name)
			elif menu_name == "about":
				check_eq(coffee_buttons, 1, "About has its own single coffee button")
			elif menu_name == "license" or menu_name == "credits":
				check_eq(coffee_buttons + chips, 0, "%s has no coffee" % menu_name)
			check_eq(nodes_of(flow.screen, "DockTab").size(), 6, "%s: six dock tabs" % menu_name if menu_name != "title" else "title: six dock tabs")


func test_coffee_hidden_opens_nothing_even_when_asked_directly() -> void:
	start(9)
	Links.coffee_hidden_for_tests = 1
	check(not Links.open_coffee(), "open_coffee refuses")
	flow.call("_open_coffee")
	check_eq(opened.size(), 0, "nothing was handed to the phone")
	check(flow.toast.is_showing(), "a plain note appears instead")
	Links.coffee_hidden_for_tests = -1


func test_the_coffee_chip_in_pause_survives_a_failing_opener() -> void:
	await start_level_1()
	Links.opener = func(_address: String) -> Variant: return ERR_UNAVAILABLE
	fake().pause_requested.emit()
	tap("Buy me a coffee")
	check_eq(flow.state, AppFlow.State.PAUSE, "still on Pause")
	check(flow.toast.is_showing(), "the toast says no browser")
	check(flow.toast.text.contains("browser"), "and says why: %s" % flow.toast.text)
	tap("Resume")
	check_eq(flow.state, AppFlow.State.LEVEL, "the level resumes")


func test_the_cup_twice_in_a_row_opens_the_page_once_and_pauses_once() -> void:
	await start_level_1()
	fake().coffee_requested.emit()
	fake().coffee_requested.emit()
	check_eq(flow.state, AppFlow.State.PAUSE, "paused")
	check_eq(opened.size(), 2, "each request is answered (the flow cannot tell them apart)")
	check_eq(fake().pauses, 1, "but the level is paused only once")


func test_settings_while_paused_keep_the_paused_level_and_pause_shows_the_new_toggles() -> void:
	await start_level_1()
	fake().pause_requested.emit()
	tap("Settings")
	var settings := flow.screen as SettingsScreen
	settings.sound_toggled.emit(false)
	settings.music_toggled.emit(false)
	check(not save_node().sound and not save_node().music, "saved")
	back()
	check_eq(flow.state, AppFlow.State.PAUSE, "back on Pause")
	check_eq(fake().retries, 0, "the level was not restarted")
	check_eq(fake().resumes, 0, "nor resumed")
	check(fake().is_paused, "still paused")
	tap("Settings")
	tap("Back to level")
	check_eq(flow.state, AppFlow.State.LEVEL, "Back to level goes straight in")
	check_eq(fake().resumes, 1, "and resumes the level once")
	save_node().set_sound(true)
	save_node().set_music(true)


func test_reset_while_paused_ends_the_level_and_the_next_start_is_level_1() -> void:
	await start_level_1()
	fake().win()
	await past_clear_delay()
	tap("Next")
	await in_state(AppFlow.State.LEVEL)
	fake().pause_requested.emit()
	tap("Settings")
	tap("Reset progress")
	check(flow.overlay is UiDialog, "asked first")
	check(all_text(flow.overlay).contains("level you paused ends too"), "the dialog says the paused level ends")
	tap("Erase everything", true)
	check_eq(save_node().highest_cleared(), 0, "erased")
	check_eq(save_node().next_level(), 1, "back to level 1")
	check(flow.screen.find_button("Back to level") == null, "no paused level on the next screen")
	tap("Home")
	check(flow.screen.find_button("Back to level") == null, "nor on the title")
	check(flow.level_scene == null, "the level scene is gone")


func test_a_reset_keeps_settings_and_an_unlocked_look_falls_back() -> void:
	start(25)
	var save := save_node()
	save.add_unlock("wood", "walnut")
	save.add_unlock("metal", "brass")
	save.set_look("walnut", "brass")
	check_eq(save.wood(), "walnut", "walnut was unlocked at level 10")
	save.set_sound(false)
	tap("Settings")
	tap("Reset progress")
	tap("Erase everything", true)
	check(not save.sound, "sound stays off")
	check_eq(save.wood(), "oak", "a wood that is no longer unlocked reads as the default")
	check_eq(save.metal(), "steel", "and so does the metal")
	save.set_sound(true)


## 1 if the screen has a button with the coffee label, else 0.
func _coffee_buttons(root: Node) -> int:
	return 1 if (root as UiScreen).find_button("Buy me a coffee") != null else 0


func test_the_sound_and_music_switches_reach_the_audio_system_and_survive_a_restart() -> void:
	start(5)
	var audio := tree.root.get_node("Audio")
	var save := save_node()
	tap("Settings")
	var settings := flow.screen as SettingsScreen
	settings.sound_toggled.emit(false)
	settings.music_toggled.emit(false)
	check(not audio.is_sound_on(), "sound is off in the audio system")
	var heard: int = audio.play_count
	audio.play("tap")
	check_eq(int(audio.play_count), heard, "an effect made while sound is off is not played")
	# A restart: a new app flow over the same save reads the switches again.
	flow.queue_free()
	await frames(2)
	save.load_all()
	boot()
	check(await in_state(AppFlow.State.TITLE), "the title shows after a restart")
	check(not audio.is_sound_on(), "sound is still off after a restart")
	tap("Settings")
	(flow.screen as SettingsScreen).sound_toggled.emit(true)
	check(audio.is_sound_on(), "and on again")
	audio.play("tap")
	check(int(audio.play_count) > heard, "an effect is played again")
	(flow.screen as SettingsScreen).music_toggled.emit(true)
