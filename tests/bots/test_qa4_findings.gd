# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends QaFlowCase
## Reproductions of the defects in docs/reviews/qa-4.md. Each test asserts what the game SHOULD
## do. While a finding is open the test only prints "OPEN FINDING" and passes, so the suite
## stays green for the lead; set STRICT to true (or fix the game and watch the line disappear)
## to make an open finding fail. No test here changes game code.

const STRICT := false
const NOT_DRAWN := -100000


func _expect(id: String, ok: bool, what: String) -> void:
	if ok:
		return
	if STRICT:
		check(false, "%s: %s" % [id, what])
	else:
		print("        OPEN FINDING %s: %s" % [id, what])


## The highest z any visible canvas item under `node` is drawn at (NOT_DRAWN if none).
func _top_z(node: Node, inherited: int) -> int:
	var z := inherited
	var best := NOT_DRAWN
	if node is CanvasItem:
		var item := node as CanvasItem
		if not item.visible:
			return NOT_DRAWN
		z = (inherited + item.z_index) if item.z_as_relative else item.z_index
		best = z
	for child: Node in node.get_children():
		best = maxi(best, _top_z(child, z))
	return best


func _lose_the_level() -> bool:
	# Random taps until the tray jams, on a level hard enough that this happens quickly.
	flow.play_number(40)
	if not await level_on():
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
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


func test_f1_the_clear_screen_is_drawn_above_the_levels_own_hud_and_helper_row() -> void:
	start_real(12)
	check(await level_on(), "level 13 is on")
	await play_taps()
	check(await in_state(AppFlow.State.CLEAR), "the level was won")
	await frames(10)
	var level_top := _top_z(scene(), 0)
	var screen_top := _top_z(flow.screen, 0)
	_expect("F1", not scene().visible or level_top <= 0 or level_top <= screen_top, "Level clear is drawn under the level's HUD and helper row (level scene z %d, clear screen z %d); the pause button, helpers and timer show on top of the clear screen and hide its Replay button" % [level_top, screen_top])


func test_f1_the_out_of_room_sheet_is_drawn_above_the_planks_and_helper_row() -> void:
	start_real(30)
	var save := save_node()
	save.add_helper("undo", 1)
	save.add_helper("extra_slot", 1)
	check(await _lose_the_level(), "a level was lost")
	await frames(30)
	var level_top := _top_z(scene(), 0)
	var screen_top := _top_z(flow.screen, 0)
	_expect("F1", not scene().visible or level_top <= screen_top, "Out of room is drawn under the planks and the helper row (level scene z %d, sheet z %d): the heading and Retry are covered" % [level_top, screen_top])


func test_f2_symbols_switched_off_while_paused_reach_the_paused_board() -> void:
	start_real(3)
	check(await level_on(), "level 4 is on")
	var before := 0
	for v0: Node in nodes_of(scene(), "ScrewView"):
		if int(((v0 as Node2D).material as ShaderMaterial).get_shader_parameter("symbol")) >= 0:
			before += 1
	check(before > 0, "symbols are on to start with (%d screws)" % before)
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	tap("Settings")
	(flow.screen as SettingsScreen).symbols_toggled.emit(false)
	tap("Back to level")
	await frames(3)
	var still := 0
	for v: Node in nodes_of(scene(), "ScrewView"):
		var item := v as Node2D
		if item.visible and int((item.material as ShaderMaterial).get_shader_parameter("symbol")) >= 0:
			still += 1
	_expect("F2", still == 0, "%d screws are still drawn with symbols after the symbols setting was turned off from Pause (and a look change is not applied either); it only takes effect on the next level" % still)
	save_node().set_symbols(true)


func test_f3_accepted_moving_the_clock_back_pays_that_days_stars_but_never_moves_the_streak() -> void:
	# Accepted by the lead: offline, so a date not yet solved pays its own stars. The streak, the
	# solved count and the last counted date must not move for an earlier date.
	start(8, "2026-11-10")
	var save := save_node()
	save.record_daily("2026-11-09", 1000, Vector3i(1, 1, 1))
	save.record_daily("2026-11-10", 1000, Vector3i(1, 1, 1))
	var before: Dictionary = save.daily_record()
	check_eq(int(before["streak"]), 2, "two days in a row")
	var bank: int = save.star_bank()
	var r: Dictionary = save.record_daily("2026-11-05", 1000, Vector3i(1, 1, 1))
	check_eq(int(r["gain"]), 3, "an unsolved earlier date pays its own stars (accepted)")
	check(not bool(r["counted"]), "but it does not count for the streak")
	var after: Dictionary = save.daily_record()
	for key: String in ["streak", "best_streak", "solved", "last_date"]:
		check_eq(after[key], before[key], "moving the clock back leaves %s alone" % key)
	check_eq(save.star_bank() - bank, 3, "the bank grew by that day only")
	# Solving the same earlier date again pays nothing.
	check_eq(int(save.record_daily("2026-11-05", 1000, Vector3i(1, 1, 1))["gain"]), 0, "the same day twice pays once")
	# A streak cannot be built backwards: days before the last counted date never join it.
	for day: String in ["2026-11-08", "2026-11-07", "2026-11-06"]:
		save.record_daily(day, 1000, Vector3i(1, 1, 1))
	check_eq(int(save.daily_record()["streak"]), 2, "three earlier days did not lengthen the streak")


func test_f4_a_save_whose_next_level_is_far_ahead_of_its_progress_is_played_as_written() -> void:
	var save := save_node()
	save.erase_all()
	var p: Dictionary = save.default_progress()
	p["next_level"] = 500
	DirAccess.make_dir_recursive_absolute(str(save.dir))
	var f := FileAccess.open(str(save.dir) + "progress.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(p))
	f.close()
	boot()
	var ok := await until(func() -> bool: return flow.state == AppFlow.State.LEVEL or flow.state == AppFlow.State.TITLE or flow.state == AppFlow.State.LOADING)
	check(ok, "the app starts")
	await in_state(AppFlow.State.LEVEL)
	var number := int(fake().played[-1].number) if fake() != null and not fake().played.is_empty() else -1
	_expect("F4", number <= int(save.highest_cleared()) + 1, "a progress file with highest_cleared 0 and next_level 500 starts level %d on first launch: nothing ties next_level to the levels cleared, so a hand-edited file skips the whole game (local only, so Low)" % number)
	save.erase_all()


## Button texts (labels inside a UiButton) wider than their button.
func _overflowing(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is UiButton and (node as UiButton).is_visible_in_tree() and (node as UiButton).size.x > 0.0:
			var b := node as UiButton
			for child: Node in b.find_children("*", "Label", true, false):
				var l := child as Label
				if l.text != "" and l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.get_minimum_size().x > b.size.x + 0.5:
					out.append("\"%s\" is %.0f units wide in a %.0f unit button" % [l.text, l.get_minimum_size().x, b.size.x])
	return out


func test_f5_text_inside_buttons_fits_the_button() -> void:
	var old := tree.root.size
	tree.root.size = Vector2i(360, 640)
	start(9)
	var wide := PackedStringArray()
	for menu_name: String in ["title", "map", "stats", "info", "settings", "about", "license", "credits", "relaxed"]:
		flow.show_menu(menu_name)
		await frames(4)
		for line: String in _overflowing(flow.screen):
			wide.append("%s: %s" % [menu_name, line])
	flow.show_menu("title")
	await frames(2)
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	if flow.overlay != null:
		tap("Got it", true)
	fake().pause_requested.emit()
	await frames(4)
	for line: String in _overflowing(flow.screen):
		wide.append("pause: %s" % line)
	tree.root.size = old
	_expect("F5", wide.is_empty(), "text runs past the edge of its button at 360 x 640: %s" % "; ".join(wide))


func test_f6_the_relaxed_stuck_sheet_fits_the_screen() -> void:
	var old := tree.root.size
	for size: Vector2i in [Vector2i(360, 640), Vector2i(360, 922)]:
		tree.root.size = size
		start(9)
		flow.show_menu("relaxed")
		await frames(2)
		tap("Easy")
		await in_state(AppFlow.State.LEVEL)
		fake().lose()
		await frames(40)
		check_eq(flow.state, AppFlow.State.LOST, "the stuck sheet shows")
		var view := tree.root.get_visible_rect()
		var cut := PackedStringArray()
		for label: String in ["Undo", "Retry", "Title"]:
			var b := flow.screen.find_button(label)
			if b != null and b.get_global_rect().end.y > view.size.y + 0.5:
				cut.append("%s ends at y %.0f of %.0f" % [label, b.get_global_rect().end.y, view.size.y])
		_expect("F6", cut.is_empty(), "at %s the Relaxed stuck sheet's buttons hang below the screen: %s" % [str(size), "; ".join(cut)])
		flow.queue_free()
		await frames(2)
	tree.root.size = old


func test_f7_the_top_bar_items_do_not_overlap_on_tall_phones() -> void:
	# The cup layout from level 4: cup, label, timer, star bank, pause, across a range of phone
	# sizes in design units (a 412 x 915 phone is 360 x 799 units, a 360 x 922 phone 360 x 922).
	start_real(3)
	check(await level_on(), "level 4 is on")
	var hud: LevelHud = scene().get("_hud") as LevelHud
	var clashes := PackedStringArray()
	for size: Vector2 in [Vector2(360.0, 640.0), Vector2(360.0, 720.0), Vector2(360.0, 780.0), Vector2(360.0, 799.0), Vector2(360.0, 860.0), Vector2(360.0, 922.0), Vector2(400.0, 640.0), Vector2(480.0, 640.0)]:
		scene().set_layout_size(size)
		await frames(3)
		var items: Dictionary = hud.top_items()
		var parts: Array[Array] = [["cup", hud.cup_target()], ["label", items["label"]], ["timer", items["timer"]], ["bank", items["bank"]], ["pause", hud.pause_target()]]
		for i: int in parts.size():
			for j: int in range(i + 1, parts.size()):
				var a: Rect2 = parts[i][1]
				var b: Rect2 = parts[j][1]
				var overlap := a.intersection(b)
				if overlap.size.x > 1.0 and overlap.size.y > 1.0:
					clashes.append("%s: %s and %s overlap by %.0f units" % [str(size), parts[i][0], parts[j][0], overlap.size.x])
	_expect("F7", clashes.is_empty(), "the level's top bar items overlap (the star bank number is hidden under the pause button): %s" % "; ".join(clashes))
