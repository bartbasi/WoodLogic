# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends FlowCase
## Cases from code review: a level started from a paused scene, settings reaching a paused
## level, a focus loss on the first-time sheet, the map's work while scrolling, and text built
## from Tuning.


func test_a_level_started_after_a_pause_and_a_tab_is_awake() -> void:
	await start_level_1()
	fake().pause_requested.emit()
	tap("Settings")
	tap("Map")
	await frames(3)
	var view := (flow.screen as MapScreen).view
	view.tap(view.center_of(1))
	check_eq(flow.state, AppFlow.State.LEVEL, "playing")
	check_eq(fake().plays_while_paused[-1], false, "the scene was woken before play()")
	check(not fake().is_paused, "and runs")
	check((flow.level_scene as CanvasItem).visible, "and is shown")


func test_the_real_level_scene_is_visible_and_playable_after_pause_tab_map() -> void:
	Links.opener = func(_a: String) -> Variant: return OK
	var save := save_node()
	save.erase_all()
	for n: int in range(1, 4):
		save.record_win(LevelCatalog.get_level(LevelData.NUMBERED, n, "").level, 9000, Vector3i(1, 1, 1))
	flow = FLOW.instantiate() as AppFlow
	flow.quit_handler = func() -> void: quit_calls += 1
	add_node(flow)
	flow.screen.find_button("Play").pressed.emit()
	check(await in_state(AppFlow.State.LEVEL), "level 4")
	await frames(5)
	flow.level_scene.emit_signal("pause_requested")
	check_eq(flow.state, AppFlow.State.PAUSE, "paused")
	tap("Settings")
	tap("Map")
	await frames(3)
	var view := (flow.screen as MapScreen).view
	view.tap(view.center_of(2))
	check(await in_state(AppFlow.State.LEVEL), "level 2 starts")
	await frames(5)
	check((flow.level_scene as CanvasItem).visible, "the level is visible")
	check_eq(flow.level_scene.get("_paused"), false, "and not paused")
	var snapshot: Dictionary = flow.level_scene.call("debug_snapshot")
	check(not snapshot.is_empty(), "and it has a board to play")


func test_settings_from_pause_reach_the_paused_level() -> void:
	await start_level_1()
	fake().pause_requested.emit()
	tap("Settings")
	var settings := flow.screen as SettingsScreen
	var before := fake().looks_refreshed
	settings.symbols_toggled.emit(false)
	check_eq(fake().looks_refreshed, before + 1, "the level scene refreshes its looks")
	save_node().add_unlock("wood", "walnut")
	settings.look_changed.emit("walnut", "steel")
	check_eq(fake().looks_refreshed, before + 2, "again for a new wood")
	save_node().set_symbols(true)


func test_a_focus_loss_keeps_the_first_time_sheet_open() -> void:
	start(7)
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	check(flow.overlay is HelperSheet, "the Undo sheet")
	flow.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(flow.overlay is HelperSheet, "still open after a focus loss")
	check_eq(flow.state, AppFlow.State.LEVEL, "no Pause over it")
	check_eq(save_node().helper_count("undo"), 0, "no free helpers given")
	check(not save_node().is_helper_met("undo"), "not met")
	fake().pause_requested.emit()
	check(flow.overlay is HelperSheet, "the pause button does not close it either")
	tap("Got it", true)
	check_eq(save_node().helper_count("undo"), 2, "Got it gives them")


func test_a_focus_loss_closes_a_buy_dialog_and_pauses() -> void:
	await start_level_1()
	for n: int in [2, 3]:
		save_node().record_win(LevelCatalog.get_level(LevelData.NUMBERED, n, "").level, 1000, Vector3i(1, 1, 1))
	fake().helper_buy_requested.emit("undo")
	check(flow.overlay is UiDialog, "the dialog")
	flow.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(flow.overlay == null, "closed")
	check_eq(flow.state, AppFlow.State.PAUSE, "paused")
	check_eq(save_node().helper_count("undo"), 0, "nothing bought")


func _map(highest: int) -> MapView:
	var vp := SubViewport.new()
	vp.size = Vector2i(360, 416)
	vp.disable_3d = true
	add_node(vp)
	var records := {}
	for n: int in range(1, highest + 1):
		records[str(n)] = {"stars": 2, "best_ms": 1, "gen": 0}
	var view := MapView.make(highest, records)
	view.theme = UiTheme.build()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(view)
	return view


func test_the_map_sets_a_node_up_only_when_it_gets_a_new_level() -> void:
	var view := _map(300)
	await frames(3)
	var base := view.setup_calls
	check(base > 0 and base <= 24, "the first view sets up about 20 nodes (%d)" % base)
	# A slow scroll by 100 units: only the levels that came into view are set up.
	var levels_before := {}
	for child: Node in view.get_children():
		if child is MapNodeView and (child as MapNodeView).visible:
			levels_before[int(child.get_meta("level"))] = true
	view._set_scroll(view.scroll - 100.0)
	var new_levels := 0
	for child: Node in view.get_children():
		if child is MapNodeView and (child as MapNodeView).visible and not levels_before.has(int(child.get_meta("level"))):
			new_levels += 1
	check_eq(view.setup_calls - base, new_levels, "one setup per newly visible level")
	check(view.setup_calls - base <= 2, "a 100 unit scroll shows at most two new levels")
	var again := view.setup_calls
	view._set_scroll(view.scroll)
	check_eq(view.setup_calls, again, "scrolling nowhere sets nothing up")
	for i: int in 40:
		view._set_scroll(view.scroll - 10.0)
	check(view.setup_calls - again <= 6, "a 400 unit scroll sets up only the new levels (%d)" % (view.setup_calls - again))


func test_text_built_from_tuning_matches_tuning() -> void:
	var h: Dictionary = Tuning.helpers
	var all := PackedStringArray()
	for group: Array in InfoScreen.groups():
		for entry: Array in group[1]:
			all.append(entry[1])
	var text := "\n".join(all)
	for helper: String in ["undo", "extra_slot", "screwdriver"]:
		var info: Dictionary = h[helper]
		check(text.contains("%s free on level %d." % [UiText.count_word(int(info["free"])), int(info["first_level"])]), "Info: free count and level of " + helper)
		var sheet := HelperSheet.texts_for(helper)
		check(str(sheet[1]).ends_with("Here are %d to get you started." % int(info["free"])), "sheet free count of " + helper)
		Tuning.helpers[helper]["free"] = 1
		check(str(HelperSheet.texts_for(helper)[1]).ends_with("Here is 1 to get you started."), "one free reads right for " + helper)
		Tuning.helpers[helper]["free"] = int(info["free"])
	check(text.contains("Undo %d, Extra slot %d, Screwdriver %d." % [int(h["undo"]["price"]), int(h["extra_slot"]["price"]), int(h["screwdriver"]["price"])]), "Info: the prices")
	check(text.contains("Opens after level %d." % Tuning.modes_open_after_level), "Info: the level Daily and Relaxed open at")
	var saved := Tuning.modes_open_after_level
	var saved_helpers: Dictionary = Tuning.helpers.duplicate(true)
	Tuning.modes_open_after_level = 11
	Tuning.helpers["undo"]["price"] = 7
	Tuning.helpers["undo"]["free"] = 3
	var changed := PackedStringArray()
	for group: Array in InfoScreen.groups():
		for entry: Array in group[1]:
			changed.append(entry[1])
	var changed_text := "\n".join(changed)
	check(changed_text.contains("Opens after level 11."), "the text follows a changed Tuning")
	check(changed_text.contains("Undo 7,"), "and the price")
	check(changed_text.contains("Three free on level"), "and the free count")
	check_eq(UiText.opens_after(), "Opens after level 11", "the title note")
	Tuning.modes_open_after_level = saved
	Tuning.helpers = saved_helpers
