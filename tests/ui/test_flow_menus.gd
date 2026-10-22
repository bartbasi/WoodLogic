# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends FlowCase
## The menus, the paused level, Back, coffee, Daily, Relaxed, helpers and unlocks of the app
## flow (docs/UX.md 1.6, 1.7, 3 and 4, docs/ARCHITECTURE.md 11.4), over the fake level scene.


func _screen_menu() -> String:
	return flow.menu


func test_the_dock_tabs_replace_the_screen() -> void:
	start(4)
	for pair: Array in [["Map", "map"], ["Stats", "stats"], ["Info", "info"], ["Settings", "settings"], ["About", "about"], ["Home", "title"]]:
		tap(pair[0])
		await frames(2)
		check_eq(flow.menu, pair[1], "the %s tab" % pair[0])
		check_eq(flow.state, AppFlow.State.TITLE if pair[1] == "title" else AppFlow.State.MENU, "state after %s" % pair[0])


func test_back_on_a_menu_goes_to_the_title_and_the_title_quits() -> void:
	start(4)
	tap("Stats")
	back()
	check_eq(flow.menu, "title", "Back from Stats")
	tap("About")
	tap("License")
	check_eq(flow.menu, "license", "License")
	back()
	check_eq(flow.menu, "about", "Back from License is About")
	tap("Credits")
	back()
	check_eq(flow.menu, "about", "Back from Credits is About")
	back()
	check_eq(flow.menu, "title", "Back from About")
	back()
	check_eq(quit_calls, 1, "Back on the title closes the game")


func test_relaxed_setup_back_goes_to_the_title() -> void:
	start(9)
	tap("Relaxed")
	check_eq(flow.menu, "relaxed", "Relaxed setup")
	check(flow.screen.find_button("Play") == null, "no game row")
	back()
	check_eq(flow.menu, "title", "Back")


func test_a_paused_level_stays_alive_while_menus_show() -> void:
	await start_level_1()
	var scene := flow.level_scene
	fake().pause_requested.emit()
	check_eq(flow.state, AppFlow.State.PAUSE, "paused")
	tap("Settings")
	check_eq(flow.state, AppFlow.State.MENU, "settings shows")
	check(is_instance_valid(scene) and flow.level_scene == scene, "the level scene is kept")
	check(fake().is_paused, "and stays paused")
	tap("About")
	tap("Info")
	tap("Home")
	check_eq(flow.state, AppFlow.State.TITLE, "the title")
	check_eq(flow.screen.find_button("Back to level").note_text, "Level 1, paused", "the title offers Back to level")
	tap("Stats")
	var row := flow.screen.find_button("Back to level")
	check(row != null, "the game row reads Back to level")
	check_eq(row.note_text, "Level 1, paused", "with the note")
	tap("Back to level")
	check_eq(flow.state, AppFlow.State.LEVEL, "straight into the level")
	check(flow.screen == null, "with no Pause screen in between")
	check(not fake().is_paused, "the clock runs again")
	check_eq(fake().resumes, 1, "resumed once")
	check_eq(fake().played.size(), 1, "the same attempt, not a new one")


func test_back_from_settings_in_pause_returns_to_pause() -> void:
	await start_level_1()
	fake().pause_requested.emit()
	tap("Settings")
	tap("Map")
	back()
	check_eq(flow.state, AppFlow.State.PAUSE, "Back returns to the origin")
	back()
	check_eq(flow.state, AppFlow.State.LEVEL, "Back from Pause resumes")


func test_the_title_reached_by_a_tab_exits_on_back_even_with_a_paused_level() -> void:
	await start_level_1()
	fake().pause_requested.emit()
	tap("Settings")
	tap("Home")
	back()
	check_eq(quit_calls, 1, "Back on the title exits the app")


func test_quit_to_title_drops_the_paused_level() -> void:
	await start_level_1()
	fake().pause_requested.emit()
	tap("Quit to title")
	check_eq(flow.state, AppFlow.State.TITLE, "title")
	check(flow.level_scene == null, "the level is gone")
	check(flow.screen.find_button("Back to level") == null, "no Back to level")
	check_eq(flow.screen.find_button("Play").note_text, "Level 1", "Play starts it again")


func test_the_map_replays_a_cleared_level_and_toasts_a_locked_one() -> void:
	start(5)
	tap("Map")
	var map := flow.screen as MapScreen
	await frames(3)
	var view := map.view
	view.tap(view.center_of(8))
	check(flow.toast.is_showing(), "a toast")
	check_eq(flow.toast.text, "Clear level 6 first.", "names the level to clear")
	check_eq(flow.state, AppFlow.State.MENU, "nothing started")
	view.tap(view.center_of(3))
	check(await in_state(AppFlow.State.LEVEL), "a cleared level starts")
	check_eq(fake().played[-1].number, 3, "level 3")
	check_eq(fake().replays[-1], true, "as a replay")


func test_a_map_tap_drops_a_paused_level() -> void:
	await start_level_1()
	_win_and_next_to_level_2()
	await in_state(AppFlow.State.LEVEL)
	fake().pause_requested.emit()
	tap("Settings")
	tap("Map")
	await frames(3)
	var view := (flow.screen as MapScreen).view
	view.tap(view.center_of(1))
	check_eq(flow.state, AppFlow.State.LEVEL, "playing level 1")
	check_eq(fake().played[-1].number, 1, "level 1")
	check(not fake().is_paused, "and it is not paused")
	fake().pause_requested.emit()
	tap("Quit to title")
	check(flow.screen.find_button("Back to level") == null, "the paused level was not kept")


func _win_and_next_to_level_2() -> void:
	fake().win()
	await past_clear_delay()
	tap("Next")


func test_settings_changes_are_saved_and_applied() -> void:
	start(2)
	tap("Settings")
	var settings := flow.screen as SettingsScreen
	settings.sound_toggled.emit(false)
	check(not save_node().sound, "sound saved off")
	settings.symbols_toggled.emit(false)
	check(not save_node().symbols, "symbols saved off")
	check(not Looks.current["symbols"], "and applied to Looks")
	settings.look_changed.emit("walnut", "steel")
	check_eq(save_node().wood(), "oak", "a locked wood reads as oak")
	save_node().add_unlock("wood", "walnut")
	settings.look_changed.emit("walnut", "steel")
	check_eq(Looks.current["wood"], "walnut", "an unlocked wood is applied")
	save_node().set_sound(true)


func test_reset_asks_first_and_back_keeps_everything() -> void:
	start(3)
	tap("Settings")
	tap("Reset progress")
	check(flow.overlay is UiDialog, "the dialog")
	check((flow.overlay as UiDialog).heading_text == "Erase everything?", "its heading")
	check(not (flow.overlay as UiDialog).body_text.contains("paused"), "no sentence about a paused level")
	back()
	check(flow.overlay == null, "Back closes it")
	check_eq(save_node().next_level(), 4, "nothing erased")
	tap("Reset progress")
	tap("Keep my progress", true)
	check_eq(save_node().next_level(), 4, "Keep my progress erases nothing")


func test_reset_erases_progress_and_ends_a_paused_level() -> void:
	await start_level_1()
	_win_and_next_to_level_2()
	await in_state(AppFlow.State.LEVEL)
	fake().pause_requested.emit()
	tap("Settings")
	tap("Reset progress")
	check((flow.overlay as UiDialog).body_text.contains("The level you paused ends too."), "the extra sentence")
	tap("Erase everything", true)
	check_eq(save_node().next_level(), 1, "back to level 1")
	check_eq(save_node().highest_cleared(), 0, "nothing cleared")
	check_eq(flow.toast.text, "Progress erased.", "toast")
	check(flow.level_scene == null, "the paused level is gone")
	check_eq(flow.screen.find_button("Play").note_text, "Level 1", "the game row reads Play, Level 1")


func test_the_coffee_chip_opens_the_fixed_address() -> void:
	start(2)
	tap("Buy me a coffee")
	check_eq(opened, PackedStringArray([Links.COFFEE_URL]), "coffee opened")
	tap("Stats")
	tap("Buy me a coffee")
	check_eq(opened.size(), 2, "Stats has the chip")
	tap("About")
	check(flow.screen.find_button("Buy me a coffee") != null, "About has its block")
	tap("Buy me a coffee")
	check_eq(opened.size(), 3, "the About button opens it")


func test_no_coffee_chip_when_coffee_is_hidden() -> void:
	Links.coffee_hidden_for_tests = 1
	start(2)
	check(flow.screen.find_button("Buy me a coffee") == null, "no chip on the title")
	tap("Settings")
	check(flow.screen.find_button("Buy me a coffee") == null, "no chip on Settings")
	check(opened.is_empty(), "nothing opened")


func test_about_links_and_failures() -> void:
	start(2)
	tap("About")
	tap("Source code")
	check_eq(opened[-1], Links.SOURCE_URL, "source")
	tap("Send feedback")
	check(opened[-1].begins_with("mailto:bartbasi@gmail.com"), "feedback")
	Links.opener = func(_a: String) -> Variant: return ERR_UNAVAILABLE
	tap("Send feedback")
	check_eq(flow.toast.text, "No email app found. You can write to bartbasi@gmail.com.", "email toast")
	tap("Source code")
	check_eq(flow.toast.text, "No browser found on this phone.", "browser toast")


func test_the_level_cup_pauses_then_opens_coffee() -> void:
	await start_level_1()
	check(fake().coffee_on, "the flow told the level to show the cup")
	fake().coffee_requested.emit()
	check_eq(flow.state, AppFlow.State.PAUSE, "Pause shows first")
	check_eq(opened, PackedStringArray([Links.COFFEE_URL]), "then the page opens")
	tap("Buy me a coffee")
	check_eq(opened.size(), 2, "Pause keeps the chip")


func test_the_level_is_told_coffee_is_off() -> void:
	Links.coffee_hidden_for_tests = 1
	await start_level_1()
	check(not fake().coffee_on, "no cup")


func test_locked_daily_and_relaxed_toast_and_unlock_after_level_8() -> void:
	start(3)
	tap("Daily")
	check_eq(flow.toast.text, "Clear level 8 to open Daily.", "daily toast")
	tap("Relaxed")
	check_eq(flow.toast.text, "Clear level 8 to open Relaxed.", "relaxed toast")
	check_eq(flow.state, AppFlow.State.TITLE, "still on the title")


func test_the_daily_plays_records_a_streak_and_shows_done_today() -> void:
	start(8)
	tap("Daily")
	check(await in_state(AppFlow.State.LEVEL), "the daily starts")
	var level := fake().played[-1]
	check_eq(level.kind, LevelData.DAILY, "a daily level")
	check_eq(level.number, 20261021, "today's date")
	fake().pause_requested.emit()
	check_eq(flow.screen.level_line, "Daily", "Pause names it")
	tap("Resume")
	fake().win(30000, Vector3i(1, 1, 0))
	check_eq(flow.state, AppFlow.State.CLEAR, "clear")
	var clear := flow.screen as ClearScreen
	check_eq(clear.streak, 1, "streak 1")
	check_eq(clear.gain, 2, "two stars")
	check_eq(save_node().daily_record()["last_date"], "2026-10-21", "saved by date")
	check_eq(save_node().next_level(), 9, "the level count is untouched")
	await past_clear_delay()
	check(clear.find_button("Done") != null, "Done")
	tap("Done")
	check_eq(flow.state, AppFlow.State.TITLE, "to the title")
	check_eq(flow.screen.find_button("Daily").note_text, "Done today", "the note")


func test_relaxed_runs_through_the_level_scene_and_moves_its_stream() -> void:
	start(8)
	tap("Relaxed")
	check_eq(flow.menu, "relaxed", "setup")
	tap("Easy")
	check(await in_state(AppFlow.State.LEVEL), "a relaxed level starts")
	var level := fake().played[-1]
	check_eq(level.kind, LevelData.RELAXED, "relaxed")
	check_eq(level.band, "easy", "easy")
	check_eq(Array(fake().shown), ["undo"], "only Undo is shown")
	fake().win(1000, Vector3i.ZERO)
	check_eq(save_node().relaxed_next("easy"), 1, "stream moved on")
	check_eq(save_node().next_level(), 9, "the level count is untouched")
	await past_clear_delay()
	tap("Another")
	check(await in_state(AppFlow.State.LEVEL), "another")
	check_eq(fake().played[-1].number, 1, "the next in the stream")
	fake().win(1000, Vector3i.ZERO)
	await past_clear_delay()
	tap("Done")
	check_eq(flow.state, AppFlow.State.TITLE, "Done goes to the title")
	tap("Relaxed")
	check(flow.screen.find_button("Easy") != null, "setup again")


func test_a_relaxed_loss_shows_the_stuck_sheet_with_a_free_undo() -> void:
	start(8)
	tap("Relaxed")
	tap("Medium")
	await in_state(AppFlow.State.LEVEL)
	fake().lose()
	check_eq(flow.state, AppFlow.State.LOST, "stuck")
	check(flow.screen.find_button("Undo") != null, "Undo first")
	tap("Undo")
	check_eq(fake().used, ["undo"], "the free Undo is used")
	check_eq(flow.state, AppFlow.State.LEVEL, "play goes on")
	check_eq(save_node().helper_count("undo"), 0, "nothing taken from the save")
	check_eq(save_node().progress_copy()["stats"]["helpers_used"], 1, "but it counts in the stats")


func test_level_8_shows_the_undo_sheet_once_and_gives_two_free() -> void:
	start(7)
	tap("Play")
	check(await in_state(AppFlow.State.LEVEL), "level 8")
	check(flow.overlay is HelperSheet, "the Undo sheet shows before the first tap")
	check(fake().holds > 0, "the clock is held")
	check_eq(save_node().helper_count("undo"), 0, "nothing given yet")
	tap("Got it", true)
	check(flow.overlay == null, "closed")
	check_eq(save_node().helper_count("undo"), 2, "two free")
	check_eq(fake().highlighted, "undo", "the helper is highlighted")
	check(fake().shown.has("undo"), "the Undo button is shown")
	# Retry does not show it again, and neither does the next start.
	fake().lose()
	tap("Retry")
	check(flow.overlay == null, "never again")
	check(save_node().is_helper_met("undo"), "met")


func test_back_closes_the_helper_sheet_like_got_it() -> void:
	start(7)
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	check(flow.overlay is HelperSheet, "sheet")
	back()
	check(flow.overlay == null, "closed")
	check_eq(save_node().helper_count("undo"), 2, "Back is Got it")
	check_eq(flow.state, AppFlow.State.LEVEL, "still in the level")


func test_a_used_helper_comes_out_of_the_save_and_is_counted() -> void:
	await start_level_1()
	save_node().add_helper("undo", 2)
	fake().helper_used.emit("undo")
	check_eq(save_node().helper_count("undo"), 1, "one taken")
	check_eq(fake().counts["undo"], 1, "the level scene is told")
	check_eq(save_node().progress_copy()["stats"]["helpers_used"], 1, "counted")


func test_buying_a_helper_spends_stars_and_uses_it() -> void:
	await start_level_1()
	_give_stars(5)
	fake().helper_buy_requested.emit("undo")
	check(flow.overlay is UiDialog, "the buy dialog")
	var dialog := flow.overlay as UiDialog
	check_eq(dialog.heading_text, "Get Undo?", "heading")
	var price: int = Tuning.helpers["undo"]["price"]
	check_eq(dialog.body_text, "Undo costs %d stars. You have 5. Spend %d and use it now?" % [price, price], "body")
	tap("Get and use", true)
	check(flow.overlay == null, "closed")
	check_eq(save_node().star_bank(), 5 - price, "the price was spent")
	check_eq(fake().used, ["undo"], "used at once")
	check_eq(save_node().helper_count("undo"), 0, "the bought one was used up")


func test_not_now_and_back_buy_nothing() -> void:
	await start_level_1()
	_give_stars(5)
	fake().helper_buy_requested.emit("screwdriver")
	check(flow.overlay == null, "8 stars needed, 5 owned: no dialog")
	check_eq(flow.toast.text, "Screwdriver costs 8 stars. You have 5.", "a toast says so")
	fake().helper_buy_requested.emit("undo")
	tap("Not now", true)
	check_eq(save_node().star_bank(), 5, "nothing spent")
	fake().helper_buy_requested.emit("undo")
	back()
	check(flow.overlay == null, "Back closes it")
	check_eq(save_node().star_bank(), 5, "nothing spent")


func _give_stars(n: int) -> void:
	var level := LevelCatalog.get_level(LevelData.NUMBERED, 2, "").level
	save_node().record_win(level, 1000, Vector3i(1, 1, 1))
	save_node().add_helper("undo", 0)
	# The tutorial wins gave 3 stars; top up or trim to exactly n.
	var bank: int = save_node().star_bank()
	if bank > n:
		save_node().spend_stars(bank - n)
	else:
		var more := LevelCatalog.get_level(LevelData.NUMBERED, 3, "").level
		save_node().record_win(more, 1000, Vector3i(1, 1, 1))
		bank = save_node().star_bank()
		if bank > n:
			save_node().spend_stars(bank - n)


func test_out_of_room_offers_owned_usable_helpers_only() -> void:
	await start_level_1()
	save_node().add_helper("undo", 2)
	save_node().add_helper("screwdriver", 1)
	fake().usable = PackedStringArray(["undo", "extra_slot", "screwdriver"])
	fake().lose()
	var labels := PackedStringArray()
	var found: Array[Node] = []
	_helpers_in(flow.screen, found)
	for h: Node in found:
		labels.append((h as HelperButton).helper)
	check_eq(Array(labels), ["undo", "screwdriver"], "undo and screwdriver, not the one not owned")
	(found[0] as HelperButton).pressed.emit()
	check_eq(fake().used, ["undo"], "the helper is used")
	check_eq(flow.state, AppFlow.State.LEVEL, "play goes on")
	check(flow.screen == null, "the sheet is gone")


func _helpers_in(node: Node, found: Array[Node]) -> void:
	for child: Node in node.get_children():
		if child is HelperButton:
			found.append(child)
		_helpers_in(child, found)


func test_unlocks_are_applied_and_named_on_the_clear_screen() -> void:
	start(7)
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	tap("Got it", true)
	fake().win()
	var clear := flow.screen as ClearScreen
	check_eq(clear.unlock_notes, ["Unlocked: Daily and Relaxed"], "level 8 opens the modes")
	await past_clear_delay()
	tap("Next")
	await in_state(AppFlow.State.LEVEL)
	fake().win()
	await in_state(AppFlow.State.CLEAR)
	await past_clear_delay()
	tap("Next")
	await in_state(AppFlow.State.LEVEL)
	fake().win()
	clear = flow.screen as ClearScreen
	check_eq(clear.unlock_notes, ["Unlocked: Walnut wood"], "level 10 unlocks walnut")
	check(save_node().is_unlocked("wood", "walnut"), "saved")
	check_eq(clear.stars, Vector3i(1, 1, 1), "stars shown")


func test_a_clear_screen_reports_gain_and_replay_gain_zero() -> void:
	await start_level_1()
	fake().win(5000, Vector3i(1, 1, 1))
	check_eq((flow.screen as ClearScreen).gain, 3, "three stars gained")
	await past_clear_delay()
	tap("Replay")
	fake().win(5000, Vector3i(1, 1, 1))
	check_eq((flow.screen as ClearScreen).gain, 0, "a replay adds nothing")


func test_the_star_bank_is_passed_to_the_level() -> void:
	start(2)
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	check_eq(fake().star_bank, save_node().star_bank(), "the star bank")


func test_focus_loss_on_a_menu_saves_and_stays() -> void:
	start(3)
	tap("Stats")
	DirAccess.remove_absolute(save_node().dir + "progress.json")
	flow.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check_eq(flow.state, AppFlow.State.MENU, "stays")
	check(FileAccess.file_exists(save_node().dir + "progress.json"), "saved")


func test_the_screens_make_their_sounds() -> void:
	await start_level_1()
	var audio := tree.root.get_node("Audio")
	fake().lose()
	check_eq(audio.get("last_played"), "lose", "Out of room plays lose")
	tap("Retry")
	fake().win(5000, Vector3i(1, 1, 1))
	await frames(6)
	check_eq(audio.get("last_played"), "chime", "Level clear plays the chime")
	await frames(30)
	check_eq(audio.get("last_played"), "star", "then a star note")
