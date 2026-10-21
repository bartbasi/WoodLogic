# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The screens' layout (docs/UX.md 1.1, 1.4, 1.6, 3 and 7.3) at phone, tall, folded foldable,
## tablet and opened foldable sizes, in a SubViewport so the size is exact.

## Viewport sizes in design units: base, tall, the Fold5 folded, a wide tablet, 1080 x 1200
## window, the Fold5 opened, and a wide window.
const SIZES: Array[Vector2i] = [Vector2i(360, 640), Vector2i(360, 840), Vector2i(360, 922), Vector2i(480, 640), Vector2i(533, 640), Vector2i(800, 640)]


func cleanup() -> void:
	Links.coffee_hidden_for_tests = -1
	Links.opener = Callable()
	await super.cleanup()


func _show(screen: UiScreen, size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	add_node(vp)
	screen.theme = UiTheme.build()
	vp.add_child(screen)
	return vp


func _buttons(node: Node, found: Array[UiButton]) -> void:
	for child: Node in node.get_children():
		if child is UiButton and (child as Control).visible:
			found.append(child)
		_buttons(child, found)


func _all(type_name: String, node: Node, found: Array[Node]) -> void:
	for child: Node in node.get_children():
		if child.get_script() != null and child.get_script().get_global_name() == type_name:
			found.append(child)
		_all(type_name, child, found)


func _context() -> Dictionary:
	var save := tree.root.get_node("Save")
	var progress: Dictionary = save.call("default_progress")
	progress["highest_cleared"] = 12
	progress["star_bank"] = 128
	progress["levels"] = {"1": {"stars": 3, "best_ms": 4000, "gen": 0}, "2": {"stars": 2, "best_ms": 5000, "gen": 0}}
	return {
		"next_level": 13, "paused_text": "", "version": "0.1.0", "progress": progress,
		"settings": {"sound": true, "music": false, "symbols": true, "wood": "oak", "metal": "steel", "unlocked_wood": PackedStringArray(["oak", "walnut"]), "unlocked_metal": PackedStringArray(["steel"])},
		"last_band": "medium", "daily_note": "Today's puzzle", "daily_locked": false, "relaxed_locked": false,
	}


const NAMES: Array[String] = ["pause", "clear", "clear_daily", "clear_relaxed", "lost", "lost_helpers_1", "lost_helpers_3", "lost_first", "stuck"]


func _make(screen_name: String) -> UiScreen:
	var ctx := _context()
	if MenuFactory.NAMES.has(screen_name):
		return MenuFactory.make(screen_name, ctx)
	var level := LevelCatalog.get_level(LevelData.NUMBERED, 12, "").level
	match screen_name:
		"pause":
			return PauseScreen.make("Level 12", true, false)
		"clear":
			return ClearScreen.make({"kind": LevelData.NUMBERED, "number": 12, "level": level, "stars": Vector3i(1, 1, 0), "elapsed_ms": 40000, "gain": 2, "unlocks": ["Unlocked: Walnut wood"]})
		"clear_daily":
			return ClearScreen.make({"kind": LevelData.DAILY, "number": 20261021, "level": level, "stars": Vector3i(1, 0, 0), "gain": 1, "streak": 3})
		"clear_relaxed":
			return ClearScreen.make({"kind": LevelData.RELAXED, "number": 4, "level": level})
		"lost":
			return LostScreen.make({"number": 12, "helpers": []})
		"lost_helpers_1":
			return LostScreen.make({"number": 12, "helpers": [["undo", 2]]})
		"lost_helpers_3":
			return LostScreen.make({"number": 12, "helpers": [["undo", 2], ["extra_slot", 1], ["screwdriver", 4]]})
		"lost_first":
			return LostScreen.make({"number": 1, "can_previous": false, "helpers": []})
		_:
			return LostScreen.make({"number": 12, "stuck": true})


## Every screen, built.
func _screens() -> Dictionary:
	var out := {}
	for screen_name: String in MenuFactory.NAMES + NAMES:
		out[screen_name] = _make(screen_name)
	return out


## Only the screens named: an unused screen would be an orphan node.
func _only(names: Array) -> Dictionary:
	var out := {}
	for screen_name: String in names:
		out[screen_name] = _make(screen_name)
	return out


func test_every_button_is_big_enough_and_inside_the_column() -> void:
	for size: Vector2i in SIZES:
		var screens := _screens()
		for screen_name: String in screens:
			_show(screens[screen_name], size)
	await frames(30)
	var checked := 0
	for node: Node in tree.root.get_children():
		if not node is SubViewport:
			continue
		var vp := node as SubViewport
		for child: Node in vp.get_children():
			if not child is UiScreen:
				continue
			var screen := child as UiScreen
			var where := "%s at %s" % [screen.get_script().get_global_name(), str(vp.size)]
			var buttons: Array[UiButton] = []
			_buttons(screen, buttons)
			var column_rect := Rect2(screen.column.global_position, screen.column.size)
			check(column_rect.size.x <= UiScreen.MAX_COLUMN + 0.5, where + ": the column is at most 480 wide")
			check(column_rect.size.y > 100.0, where + ": the column has room (%s)" % str(column_rect))
			for b: UiButton in buttons:
				var r := b.get_global_rect()
				checked += 1
				check(r.size.y >= 47.99, "%s: \"%s\" is %.1f tall" % [where, b.label_text, r.size.y])
				check(r.size.x >= 47.99, "%s: \"%s\" is %.1f wide" % [where, b.label_text, r.size.x])
				if screen is MenuScreen and (screen as MenuScreen).use_scroll and b.get_parent() != null and _inside_scroll(b, screen as MenuScreen):
					continue
				check(column_rect.grow(0.5).encloses(r), "%s: \"%s\" %s is inside the column %s" % [where, b.label_text, str(r), str(column_rect)])
				if b.kind == UiButton.Kind.PRIMARY:
					check(r.get_center().y >= vp.size.y / 2.0, "%s: \"%s\" %s is in the bottom half" % [where, b.label_text, str(r)])
					check(r.size.x <= UiScreen.MAX_BUTTON + 0.5, "%s: \"%s\" is at most 320 wide" % [where, b.label_text])
				if b.kind == UiButton.Kind.PRIMARY or b is DockTab:
					check(r.end.y <= vp.size.y - 8.0, "%s: \"%s\" keeps 8 units above the bottom" % [where, b.label_text])
	check(checked > 200, "buttons were checked (%d)" % checked)


func _inside_scroll(b: Control, screen: MenuScreen) -> bool:
	return screen.scroll.is_ancestor_of(b)


func test_the_dock_has_six_tabs_and_the_active_one_is_marked() -> void:
	var screens := _only(["map", "stats", "info", "settings", "about", "license", "credits", "relaxed", "title"])
	for menu_name: String in screens:
		_show(screens[menu_name], Vector2i(360, 640))
	await frames(3)
	for node: Node in tree.root.get_children():
		if node is SubViewport:
			for child: Node in node.get_children():
				if child is MenuScreen:
					var tabs: Array[Node] = []
					_all("DockTab", child, tabs)
					check_eq(tabs.size(), 6, "six tabs on %s" % (child as MenuScreen).heading)
					var active := 0
					for t: Node in tabs:
						if (t as DockTab).active:
							active += 1
							check_eq((t as DockTab).tab, (child as MenuScreen).active_tab, "the active tab")
					check_eq(active, 1, "one active tab")
					check(((tabs[0] as DockTab).custom_minimum_size.x >= 56.0) and ((tabs[0] as DockTab).custom_minimum_size.y >= 52.0), "tabs are 56 x 52")


func test_the_game_row_reads_play_or_back_to_level() -> void:
	var ctx := _context()
	var plain := MenuFactory.make("stats", ctx)
	ctx["paused_text"] = "Level 13, paused"
	var paused := MenuFactory.make("stats", ctx)
	_show(plain, Vector2i(360, 640))
	_show(paused, Vector2i(360, 640))
	await frames(3)
	check(plain.find_button("Play") != null, "Play")
	check_eq(plain.find_button("Play").note_text, "Level 13", "the note")
	check(paused.find_button("Back to level") != null, "Back to level")
	check_eq(paused.find_button("Back to level").note_text, "Level 13, paused", "the paused note")
	var title := MenuFactory.make("title", ctx)
	_show(title, Vector2i(360, 640))
	await frames(3)
	check(title.find_button("Back to level") != null, "the title's Play button says Back to level too")
	var relaxed := MenuFactory.make("relaxed", ctx)
	_show(relaxed, Vector2i(360, 640))
	await frames(3)
	check(relaxed.find_button("Play") == null and relaxed.find_button("Back to level") == null, "Relaxed setup has no game row")


func test_buttons_are_296_wide_on_a_base_phone() -> void:
	var s := MenuFactory.make("title", _context())
	_show(s, Vector2i(360, 640))
	await frames(3)
	var play := s.find_button("Play")
	check_between(play.size.x, 295.5, 296.5, "Play width")
	check_between(play.size.y, 71.5, 72.5, "Play height")
	check_between(s.find_button("Daily").size.x, 143.5, 144.5, "Daily width")


func test_the_title_has_play_daily_relaxed_the_dock_and_the_chip() -> void:
	var title := MenuFactory.make("title", _context())
	_show(title, Vector2i(360, 640))
	await frames(3)
	var buttons: Array[UiButton] = []
	_buttons(title, buttons)
	var labels := PackedStringArray()
	for b: UiButton in buttons:
		labels.append(b.label_text)
	for want: String in ["Play", "Daily", "Relaxed", "Home", "Map", "Stats", "Info", "Settings", "About", "Buy me a coffee"]:
		check(labels.has(want), "the title has %s" % want)
	check_eq(buttons.size(), 10, "and nothing else")


func test_locked_daily_and_relaxed_show_the_note() -> void:
	var ctx := _context()
	ctx["daily_locked"] = true
	ctx["relaxed_locked"] = true
	ctx["daily_note"] = "Opens after level 8"
	var title := MenuFactory.make("title", ctx)
	_show(title, Vector2i(360, 640))
	await frames(3)
	check_eq(title.find_button("Daily").note_text, "Opens after level 8", "daily note")
	check_eq(title.find_button("Relaxed").note_text, "Opens after level 8", "relaxed note")


func test_with_coffee_hidden_no_coffee_control_is_built() -> void:
	Links.coffee_hidden_for_tests = 1
	var screens := _screens()
	for screen_name: String in screens:
		_show(screens[screen_name], Vector2i(360, 640))
	await frames(5)
	for node: Node in tree.root.get_children():
		if node is SubViewport:
			var chips: Array[Node] = []
			_all("CoffeeChip", node, chips)
			check(chips.is_empty(), "no coffee chip is built")
			var buttons: Array[UiButton] = []
			_buttons(node, buttons)
			for b: UiButton in buttons:
				check(b.label_text != "Buy me a coffee", "no coffee button")
	var about: AboutScreen = screens["about"]
	var texts := PackedStringArray()
	_collect_text(about, texts)
	check(not "\n".join(texts).contains("Supporting WoodLogic"), "About leaves out the Supporting block")
	check("\n".join(texts).contains(AboutScreen.PRIVACY_NO_COFFEE), "and Privacy uses the store wording")
	check(not "\n".join(texts).contains("Buy me a coffee"), "and never names the coffee button")


func test_about_shows_the_fixed_wording_with_coffee() -> void:
	var about := MenuFactory.make("about", _context())
	_show(about, Vector2i(360, 640))
	await frames(3)
	var texts := PackedStringArray()
	_collect_text(about, texts)
	var all := "\n".join(texts)
	for want: String in [AboutScreen.SUPPORTING, AboutScreen.PRIVACY, AboutScreen.ATTRIBUTION, AboutScreen.WHAT, "Send feedback", "Source code", "Supporting WoodLogic", "License", "Credits"]:
		check(all.contains(want), "About has: " + want.left(40))
	var chips: Array[Node] = []
	_all("CoffeeChip", about, chips)
	check(chips.is_empty(), "About has no header chip")
	check(about.find_button("Buy me a coffee") != null, "About has its own coffee button")


func _collect_text(node: Node, out: PackedStringArray) -> void:
	for child: Node in node.get_children():
		if child is Label:
			out.append((child as Label).text)
		elif child is UiButton:
			out.append((child as UiButton).label_text + " " + (child as UiButton).note_text)
		_collect_text(child, out)


func test_license_and_credits_carry_the_real_text() -> void:
	var license := MenuFactory.make("license", _context())
	var credits := MenuFactory.make("credits", _context())
	_show(license, Vector2i(360, 640))
	_show(credits, Vector2i(360, 640))
	await frames(3)
	var rich: Array[RichTextLabel] = []
	_rich(license, rich)
	var license_text := ""
	for r: RichTextLabel in rich:
		license_text += r.text
	check(license_text.contains("GNU GENERAL PUBLIC LICENSE"), "the GPL text")
	check(license_text.length() > 30000, "the whole files")
	rich = []
	_rich(credits, rich)
	check(not rich.is_empty() and rich[0].text.length() > 1000, "the engine text")
	check(rich[0].text.contains("Godot"), "names Godot")


func _rich(node: Node, out: Array[RichTextLabel]) -> void:
	for child: Node in node.get_children():
		if child is RichTextLabel:
			out.append(child)
		_rich(child, out)


func test_the_clear_screens_by_kind() -> void:
	var screens := _only(["clear", "clear_daily", "clear_relaxed"])
	for screen_name: String in ["clear", "clear_daily", "clear_relaxed"]:
		_show(screens[screen_name], Vector2i(360, 640))
	await frames(3)
	var numbered: ClearScreen = screens["clear"]
	check(numbered.find_button("Next") != null and numbered.find_button("Replay") != null, "numbered: Next and Replay")
	check_eq(numbered.find_button("Next").note_text, "Level 13", "Next names the level")
	var daily: ClearScreen = screens["clear_daily"]
	check(daily.find_button("Done") != null and daily.find_button("Replay") != null, "daily: Done and Replay")
	var relaxed: ClearScreen = screens["clear_relaxed"]
	check(relaxed.find_button("Another") != null and relaxed.find_button("Done") != null, "relaxed: Another and Done")
	var texts := PackedStringArray()
	_collect_text(numbered, texts)
	var all := "\n".join(texts)
	for want: String in ["Level 12 cleared", "+2 stars", "Unlocked: Walnut wood", "Cleared", "Fast", "Clean", "Every screw is out", "Within " + UiText.seconds(LevelCatalog.get_level(LevelData.NUMBERED, 12, "").level.par_time_s)]:
		check(all.contains(want), "numbered clear has: " + want)
	texts = PackedStringArray()
	_collect_text(daily, texts)
	all = "\n".join(texts)
	check(all.contains("Daily puzzle solved") and all.contains("Streak: 3 days") and all.contains("+1 star"), "daily clear text")
	texts = PackedStringArray()
	_collect_text(relaxed, texts)
	check("\n".join(texts).contains("Nicely done"), "relaxed heading")
	check(not "\n".join(texts).contains("star"), "relaxed has no stars")


func test_the_out_of_room_sheet_by_helpers() -> void:
	var screens := _only(["lost", "lost_helpers_1", "lost_helpers_3", "stuck", "lost_first"])
	for screen_name: String in ["lost", "lost_helpers_1", "lost_helpers_3", "stuck", "lost_first"]:
		_show(screens[screen_name], Vector2i(360, 640))
	await frames(40)
	var one: LostScreen = screens["lost_helpers_1"]
	var three: LostScreen = screens["lost_helpers_3"]
	var none: LostScreen = screens["lost"]
	var heights: Array[float] = []
	for s: LostScreen in [none, one, three]:
		var helper_buttons: Array[Node] = []
		_all("HelperButton", s, helper_buttons)
		heights.append(float(helper_buttons.size()))
	check_eq(heights, [0.0, 1.0, 3.0], "helper buttons offered")
	var buttons: Array[Node] = []
	_all("HelperButton", three, buttons)
	for b: Node in buttons:
		check((b as Control).size.x >= 92.5 and (b as Control).size.y >= 47.99, "helper buttons are at least 93 x 48: %s" % str((b as Control).size))
	check(three._sheet_height() > none._sheet_height(), "the sheet is taller with helpers")
	check(none.find_button("Previous level") != null, "previous level offered")
	check(screens["lost_first"].find_button("Previous level") == null, "not on level 1")
	var stuck: LostScreen = screens["stuck"]
	check(stuck.find_button("Undo") != null and stuck.find_button("Retry") != null and stuck.find_button("Title") != null, "the stuck sheet")


func test_the_out_of_room_sheet_slides_up_and_retry_works_at_once() -> void:
	var lost := LostScreen.make({"number": 5})
	_show(lost, Vector2i(360, 640))
	var presses := [0]
	lost.retry_pressed.connect(func() -> void: presses[0] += 1)
	await frames(1)
	var retry := lost.find_button("Retry")
	check(not retry.disabled, "Retry is enabled in the first frame")
	retry.pressed.emit()
	check_eq(presses[0], 1, "Retry works while the sheet slides")
	var start_y := retry.global_position.y
	await frames(30)
	check(retry.global_position.y < start_y, "the sheet moved up")
	check(retry.get_global_rect().get_center().y > 320.0, "Retry is in the bottom half")


func test_dialogs_and_the_helper_sheet() -> void:
	var dialog := UiDialog.make("Get Undo?", "Undo costs 4 stars. You have 9. Spend 4 and use it now?", [["Get and use", UiButton.Kind.PRIMARY], ["Not now", UiButton.Kind.SECONDARY]], 1)
	var sheet := HelperSheet.make("screwdriver")
	_show(dialog, Vector2i(360, 640))
	_show(sheet, Vector2i(360, 640))
	var chosen := [-1]
	dialog.chosen.connect(func(i: int) -> void: chosen[0] = i)
	await frames(30)
	var panel_buttons: Array[UiButton] = []
	_buttons(dialog, panel_buttons)
	check_eq(panel_buttons.size(), 2, "two choices")
	check(panel_buttons[0].get_global_rect().size.x >= 270.0, "wide buttons")
	dialog.cancel()
	check_eq(chosen[0], 1, "Back is Not now")
	check(sheet.find_button("Got it") != null, "the sheet has Got it")
	check(sheet.find_button("Got it").get_global_rect().get_center().y > 400.0, "Got it is in the bottom half")


func test_text_is_plain() -> void:
	# No em dashes, no double hyphens in any label of any screen.
	var screens := _screens()
	for screen_name: String in screens:
		_show(screens[screen_name], Vector2i(360, 640))
	await frames(3)
	for node: Node in tree.root.get_children():
		if node is SubViewport:
			_check_text(node)


func _check_text(node: Node) -> void:
	for child: Node in node.get_children():
		var text := ""
		if child is RichTextLabel:
			continue
		if child is Label:
			text = (child as Label).text
		elif child is Button:
			text = (child as Button).text
		if child is UiButton:
			text += (child as UiButton).label_text + (child as UiButton).note_text
		check(not text.contains(char(0x2014)) and not text.contains("--"), "plain text: " + text)
		_check_text(child)


func test_the_title_board_is_decoration_capped_at_360_and_clear_of_play() -> void:
	for size: Vector2i in [Vector2i(360, 640), Vector2i(360, 922), Vector2i(533, 640)]:
		var title := MenuFactory.make("title", _context()) as TitleScreen
		_show(title, size)
		await frames(6)
		check(title.board != null and title.board.visible, "the board shows at %s" % str(size))
		if title.board == null:
			continue
		var play := title.find_button("Play").get_global_rect()
		var deco := title._deco
		check(deco.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the decoration takes no touches")
		check_between(play.size.x, 295.5, 320.5, "Play width at %s" % str(size))
		check_between(play.size.y, 71.5, 72.5, "Play height")
		check(title._board_size.x <= 360.0, "at most 360 wide at %s (%s)" % [str(size), str(title._board_size)])
		check(deco.get_global_rect().end.y - (title.board.global_position.y + title._board_size.y) >= 11.9, "12 units clear above Play")
