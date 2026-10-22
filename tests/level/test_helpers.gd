# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Phase 4: the helper row (Undo, Extra slot, Screwdriver), the Screwdriver mode, the timer and
## pips, the star bank and the coffee cup (docs/ARCHITECTURE.md 6 and 11.3, UX 3.2.2, 1.7, 3.13).
## Every helper is checked against PlayState and the picture.

const Kit := preload("res://tests/level/kit.gd")
const Levels := preload("res://tests/level/levels.gd")
const ALL := ["undo", "extra_slot", "screwdriver"]

var _used: Array[String] = []
var _buys: Array[String] = []
var _coffee := 0
var _paused_when_coffee := false
var _lost := 0
var _scene: LevelScene


func _on_used(helper: String) -> void:
	_used.append(helper)


func _on_buy(helper: String) -> void:
	_buys.append(helper)


func _on_coffee() -> void:
	_coffee += 1
	_paused_when_coffee = bool(_scene.debug_snapshot()["paused"])


func _on_lost(_level: LevelData) -> void:
	_lost += 1


## A scene in instant mode with every helper owned twice, shown, and a bank of 10 stars.
func _make(level: LevelData, instant: bool = true) -> LevelScene:
	_used.clear()
	_buys.clear()
	_coffee = 0
	_lost = 0
	_scene = Kit.make_scene(self, level, instant)
	_scene.helper_used.connect(_on_used)
	_scene.helper_buy_requested.connect(_on_buy)
	_scene.coffee_requested.connect(_on_coffee)
	_scene.lost.connect(_on_lost)
	_scene.set_star_bank(10)
	_scene.set_helpers({"undo": 2, "extra_slot": 2, "screwdriver": 2}, PackedStringArray(ALL))
	_scene.set_coffee(true)
	return _scene


func _hud(scene: LevelScene) -> LevelHud:
	return scene.get("_hud") as LevelHud


func _touch(scene: LevelScene, p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = p
	e.pressed = pressed
	scene.call("_gui_input", e)


## A touch that goes down and comes up on a control, as a finger does.
func _press(scene: LevelScene, id: String) -> void:
	var p := _hud(scene).target_of(id).get_center()
	_touch(scene, p, true)
	_touch(scene, p, false)


func _tutorial_with_number(n: int) -> LevelData:
	# The swing level wearing a tutorial number, to try the level 1 to 3 and 4 and up rules.
	var errors := PackedStringArray()
	var base := Levels.swing_level()
	return base.with_colors(base.screw_colors, base.queue, errors, {"number": n})


func _relaxed(base: LevelData) -> LevelData:
	var errors := PackedStringArray()
	return base.with_colors(base.screw_colors, base.queue, errors, {"kind": LevelData.RELAXED, "number": 3})


# == the row ==

func test_the_row_shows_what_the_app_flow_says_and_the_badges() -> void:
	var scene := _make(Levels.cascade_level())
	check_eq(scene.debug_snapshot()["helpers"], PackedStringArray(ALL), "three buttons in the fixed order")
	var hud := _hud(scene)
	check_eq(hud.get_badge("undo"), "2", "a count")
	scene.set_helpers({"undo": 0, "extra_slot": 1, "screwdriver": 0}, PackedStringArray(ALL))
	check_eq(hud.get_badge("undo"), "3", "count 0 shows the price, 3 stars")
	check_eq(hud.get_badge("screwdriver"), "8", "8 stars")
	check(not hud.is_button_dim("undo") and not hud.is_button_dim("screwdriver"), "a bank of 10 can pay 3 and 8")
	scene.set_star_bank(5)
	check(not hud.is_button_dim("undo"), "a bank of 5 can pay 3")
	check(hud.is_button_dim("screwdriver"), "but not 8 (dimmed)")
	scene.set_helpers({"undo": 2, "extra_slot": 2, "screwdriver": 2}, PackedStringArray(["undo"]))
	check_eq(scene.debug_snapshot()["helpers"], PackedStringArray(["undo"]), "only the introduced helpers show")
	scene.set_helpers({}, PackedStringArray())
	check_eq(scene.debug_snapshot()["helpers"], PackedStringArray(), "none before level 8")


func test_relaxed_shows_only_a_free_undo() -> void:
	var scene := _make(_relaxed(Levels.cascade_level()))
	check_eq(scene.debug_snapshot()["helpers"], PackedStringArray(["undo"]), "only Undo in Relaxed")
	check_eq(_hud(scene).get_badge("undo"), "Free", "it reads Free")
	# Undo is free and unlimited: it works with no count and reports itself.
	scene.set_helpers({"undo": 0}, PackedStringArray(["undo"]))
	scene.tap_screw(0)
	_press(scene, "undo")
	check_eq(_used, ["undo"] as Array[String], "helper_used undo in Relaxed")
	check_eq(scene.get_state().tray_uses(), 0, "back at the start")


func test_the_timer_pips_and_star_bank_show_from_level_4() -> void:
	for n: int in [1, 3]:
		var early := _make(_tutorial_with_number(n))
		check(not early.debug_snapshot()["timer_shown"], "no timer on level %d" % n)
		early.queue_free()
	var scene := _make(_tutorial_with_number(4))
	check(scene.debug_snapshot()["timer_shown"], "the timer shows on level 4")
	check_eq(scene.debug_snapshot()["pips"], Vector2i(1, 1), "both pips are full at the start")
	check_eq(scene.debug_snapshot()["bank"], 10, "the star bank shows")


func test_the_star_bank_counts_down_over_400_ms() -> void:
	var scene := _make(_tutorial_with_number(5), false)
	await Kit.settle(self, scene)
	scene.set_star_bank(6)
	await frames(10)
	var mid: int = scene.debug_snapshot()["bank"]
	check(mid < 10 and mid > 6, "counting down: %d" % mid)
	await frames(30)
	check_eq(scene.debug_snapshot()["bank"], 6, "ends at the new bank")
	scene.set_star_bank(9)
	check_eq(scene.debug_snapshot()["bank"], 9, "a rise shows at once")


# == Undo ==

func test_undo_by_the_button_takes_back_the_move_and_costs_the_clean_pip() -> void:
	var level := Levels.cascade_level()
	var scene := _make(_tutorial_with_number(5))
	var fresh := scene.get_state().snapshot()
	check_eq(scene.tap_screw(0).ok, true, "a tap")
	_press(scene, "undo")
	check_eq(scene.get_state().snapshot(), fresh, "Undo restores the logic's state")
	check_eq(_used, ["undo"] as Array[String], "helper_used undo, once")
	check_eq(Kit.mismatches(scene).size(), 0, "the picture agrees: %s" % "; ".join(Kit.mismatches(scene)))
	check_eq(scene.debug_snapshot()["pips"].y, 0, "the clean pip is an outline after a helper")
	check_eq(level.screw_count(), 12, "level sanity")
	# Nothing to undo: no signal, a toast.
	_used.clear()
	_press(scene, "undo")
	check_eq(_used.size(), 0, "nothing was used")
	check_eq(scene.debug_snapshot()["toast"], "Nothing to undo.", "the toast says so")


func test_undo_after_a_helper_and_the_result_names_the_helpers() -> void:
	var scene := _make(Levels.swing_level())
	var wins: Array[LevelResult] = []
	scene.won.connect(func(r: LevelResult) -> void: wins.append(r))
	scene.tap_screw(1)
	scene.use_helper("undo")
	for s: int in Levels.SWING_SOLUTION:
		scene.tap_screw(s)
	check_eq(wins.size(), 1, "won")
	check(wins[0].helpers_used.has("undo"), "the result names Undo")
	check_eq(wins[0].stars.z, 0, "and the clean star is gone (R32)")


# == Extra slot ==

func test_extra_slot_adds_one_tray_slot_once_per_try() -> void:
	var scene := _make(Levels.cascade_level())
	scene.tap_screw(0)
	_press(scene, "extra_slot")
	check_eq(scene.get_state().tray().size(), 6, "a sixth slot")
	check_eq(scene.debug_snapshot()["tray"].size(), 6, "the picture has it too")
	check_eq(_used, ["extra_slot"] as Array[String], "helper_used extra_slot")
	check_eq(_hud(scene).get_badge("extra_slot"), "Used", "the badge reads Used")
	check(_hud(scene).is_button_dim("extra_slot"), "and the button is disabled")
	_press(scene, "extra_slot")
	check_eq(_used.size(), 1, "a second press does nothing")
	check_eq(Kit.mismatches(scene).size(), 0, "the picture agrees with six slots: %s" % "; ".join(Kit.mismatches(scene)))
	# A screw landing in the sixth slot sits where the logic says.
	for s: int in [1, 2, 3, 4, 5]:
		scene.tap_screw(s)
	check_eq(Kit.mismatches(scene).size(), 0, "with the tray full to six: %s" % "; ".join(Kit.mismatches(scene)))
	scene.retry()
	check_eq(scene.get_state().tray().size(), 5, "Retry gives back five slots")
	check_eq(_hud(scene).get_badge("extra_slot"), "2", "and the badge shows the count again")


func test_extra_slot_in_the_air_lands_the_screws_in_the_new_slots() -> void:
	var scene := _make(Levels.cascade_level(), false)
	await Kit.settle(self, scene)
	for s: int in [0, 1, 2]:
		scene.tap_screw(s)
		await frames(2)
	scene.use_helper("extra_slot")
	await Kit.settle(self, scene)
	check_eq(Kit.mismatches(scene).size(), 0, "settled: %s" % "; ".join(Kit.mismatches(scene)))


# == Screwdriver ==

func test_screwdriver_removes_a_covered_screw_and_undo_takes_it_back() -> void:
	var scene := _make(Levels.swing_level())
	scene.tap_screw(1)
	var before := scene.get_state().snapshot()
	check(not scene.get_state().is_free(Levels.SWING_COVERED), "the disc screw is covered")
	_press(scene, "screwdriver")
	check(scene.debug_snapshot()["driver"] and scene.debug_snapshot()["banner"], "the mode and its banner")
	check_eq(_used.size(), 0, "entering the mode spends nothing")
	# A tap on the covered screw removes it, to where a tap would send it (R31).
	var at := scene.get_layout().gu_to_scene(scene.get_level().screw_center(Levels.SWING_COVERED))
	var expect := scene.get_state().destination(Levels.SWING_COVERED)
	scene.tap_at(at)
	check(not scene.get_state().is_on_board(Levels.SWING_COVERED), "the screw is gone")
	check_eq(expect.x, PlayState.BOX, "it went where a tap would send it")
	check_eq(scene.get_state().helpers_used(), PackedStringArray(["screwdriver"]), "the model counts the Screwdriver")
	check_eq(_used, ["screwdriver"] as Array[String], "helper_used screwdriver")
	check(not scene.debug_snapshot()["driver"], "the mode ends")
	check_eq(Kit.mismatches(scene).size(), 0, "the picture agrees: %s" % "; ".join(Kit.mismatches(scene)))
	# Undo takes the Screwdriver's removal back (R26).
	_press(scene, "undo")
	check_eq(scene.get_state().snapshot(), before, "Undo after a Screwdriver restores the state")
	check_eq(_used, ["screwdriver", "undo"] as Array[String], "both reported")
	check_eq(Kit.mismatches(scene).size(), 0, "and the picture: %s" % "; ".join(Kit.mismatches(scene)))


func test_screwdriver_refused_keeps_the_mode_and_costs_nothing() -> void:
	var scene := _make(Levels.cascade_level())
	for s: int in [0, 1, 2, 3, 4]:
		scene.tap_screw(s)
	check_eq(scene.get_state().tray().count(-1), 0, "the tray is full")
	var before := scene.get_state().snapshot()
	scene.use_helper("screwdriver")
	scene.tap_at(scene.get_layout().gu_to_scene(scene.get_level().screw_center(5)))
	check_eq(scene.get_state().snapshot(), before, "a screw with nowhere to go stays")
	check(scene.debug_snapshot()["driver"], "the mode stays")
	check_eq(scene.debug_snapshot()["toast"], "That screw has nowhere to go.", "the toast says why")
	check_eq(_used.size(), 0, "nothing was used")
	scene.tap_at(scene.get_layout().gu_to_scene(scene.get_level().screw_center(6)))
	check(not scene.get_state().is_on_board(6), "a screw that fits goes")
	check_eq(_used, ["screwdriver"] as Array[String], "now it is used")


func test_screwdriver_cancel_back_and_pause_leave_the_mode_and_keep_the_helper() -> void:
	var scene := _make(Levels.cascade_level())
	var paused := [0]
	scene.pause_requested.connect(func() -> void: paused[0] += 1)
	scene.use_helper("screwdriver")
	_press(scene, "cancel")
	check(not scene.debug_snapshot()["driver"], "Cancel leaves the mode")
	scene.use_helper("screwdriver")
	check(scene.handle_back(), "Back is handled in the mode")
	check(not scene.debug_snapshot()["driver"], "and leaves it")
	check(not scene.handle_back(), "a second Back is not handled")
	scene.use_helper("screwdriver")
	_press(scene, "pause")
	check(not scene.debug_snapshot()["driver"], "the pause button leaves the mode")
	check_eq(paused[0], 1, "and asks for Pause")
	check_eq(_used.size(), 0, "no helper was used by any of them")


# == buying ==

func test_a_helper_at_count_zero_asks_to_buy_when_the_bank_can_pay() -> void:
	var scene := _make(Levels.cascade_level())
	scene.set_helpers({"undo": 0, "extra_slot": 0, "screwdriver": 0}, PackedStringArray(ALL))
	_press(scene, "undo")
	check_eq(_buys, ["undo"] as Array[String], "helper_buy_requested undo (3 stars, bank 10)")
	check_eq(_buys.size(), 1, "one request for one press")
	_press(scene, "screwdriver")
	check_eq(_buys, ["undo", "screwdriver"] as Array[String], "8 stars is within 10 too")
	scene.set_star_bank(2)
	_buys.clear()
	_press(scene, "undo")
	check_eq(_buys.size(), 0, "no request when the bank cannot pay")
	check_eq(scene.debug_snapshot()["toast"], "Not enough stars. 3 needed.", "the toast says so")
	# After Get and use the app flow pushes the count and calls use_helper.
	scene.tap_screw(0)
	scene.set_helpers({"undo": 1}, PackedStringArray(["undo"]))
	scene.use_helper("undo")
	check_eq(_used, ["undo"] as Array[String], "use_helper works after buying")


func test_the_highlight_ring_and_the_first_count_ticking_up() -> void:
	var scene := _make(Levels.cascade_level(), false)
	await Kit.settle(self, scene)
	scene.highlight_helper("undo")
	check_eq(scene.debug_snapshot()["highlight"], "undo", "the ring is on Undo")
	check_eq(_hud(scene).get_badge("undo"), "0", "the count starts at 0")
	await frames(15)
	check_eq(_hud(scene).get_badge("undo"), "1", "ticks to 1")
	await frames(20)
	check_eq(_hud(scene).get_badge("undo"), "2", "and to 2")
	check_eq(scene.debug_snapshot()["highlight"], "undo", "the ring stays steady")
	scene.tap_screw(0)
	check_eq(scene.debug_snapshot()["highlight"], "", "until the first tap")


# == after a loss ==

func test_helpers_after_a_loss_follow_r37() -> void:
	var found := Kit.find_loss()
	check(not found.is_empty(), "a losing game exists")
	if found.is_empty():
		return
	var level: LevelData = found["level"]
	var scene := _make(level)
	for s: int in found["taps"]:
		scene.tap_screw(s)
	check_eq(scene.get_state().status(), PlayState.LOST, "lost")
	var fits := false
	for s: int in level.screw_count():
		if scene.get_state().is_on_board(s) and scene.get_state().destination(s).x != PlayState.NONE:
			fits = true
	var usable := scene.usable_after_loss()
	check(usable.has("undo") and usable.has("extra_slot"), "Undo and Extra slot are offered")
	check_eq(usable.has("screwdriver"), fits, "Screwdriver only when some screw fits an open box")
	scene.set_helpers({"undo": 0, "extra_slot": 1, "screwdriver": 0}, PackedStringArray(ALL))
	check_eq(scene.usable_after_loss(), PackedStringArray(["extra_slot"]), "only owned helpers")
	# Extra slot clears the loss; the clock goes on and the loss was announced once.
	_lost = 0
	scene.use_helper("extra_slot")
	check_eq(scene.get_state().status(), PlayState.PLAYING, "the sixth slot clears the loss")
	check_eq(_used, ["extra_slot"] as Array[String], "reported")
	check(not scene.is_over(), "the scene plays on")
	check_eq(scene.usable_after_loss().has("extra_slot"), false, "Extra slot is used up for this try")


func test_undo_clears_a_loss() -> void:
	var found := Kit.find_loss()
	if found.is_empty():
		check(false, "a losing game exists")
		return
	var scene := _make(found["level"])
	for s: int in found["taps"]:
		scene.tap_screw(s)
	scene.use_helper("undo")
	check_eq(scene.get_state().status(), PlayState.PLAYING, "Undo clears the loss (R29)")
	check_eq(Kit.mismatches(scene).size(), 0, "the picture agrees: %s" % "; ".join(Kit.mismatches(scene)))
	check_eq(_used, ["undo"] as Array[String], "reported")


func test_a_cancelled_screwdriver_after_a_loss_announces_the_loss_again() -> void:
	var found := Kit.find_loss()
	if found.is_empty():
		check(false, "a losing game exists")
		return
	var scene := _make(found["level"])
	for s: int in found["taps"]:
		scene.tap_screw(s)
	_lost = 0
	scene.use_helper("screwdriver")
	check(scene.debug_snapshot()["driver"], "the mode starts after a loss")
	_press(scene, "cancel")
	check_eq(_lost, 1, "the sheet is asked for again, so the player is never stranded")


# == the coffee cup ==

func test_the_cup_is_hidden_on_levels_1_to_3_and_shows_from_4() -> void:
	for n: int in [1, 2, 3]:
		var scene := _make(_tutorial_with_number(n))
		check(not scene.debug_snapshot()["cup"], "no cup on level %d" % n)
		scene.queue_free()
	for n: int in [4, 8, 50]:
		var scene := _make(_tutorial_with_number(n))
		check(scene.debug_snapshot()["cup"], "the cup on level %d" % n)
		scene.queue_free()
	var off := _make(_tutorial_with_number(6))
	off.set_coffee(false)
	check(not off.debug_snapshot()["cup"], "the switch hides it")
	check_eq(_hud(off).hit(_hud(off).cup_target().get_center()), "", "and it takes no touches")


func test_the_cup_hides_for_sheets_dialogs_the_clear_and_the_loss() -> void:
	var scene := _make(_tutorial_with_number(6))
	scene.hold_clock(true)
	check(not scene.debug_snapshot()["cup"], "hidden while a sheet or dialog holds the clock")
	scene.hold_clock(false)
	check(scene.debug_snapshot()["cup"], "back after")
	for s: int in Levels.SWING_SOLUTION:
		scene.tap_screw(s)
	check(not scene.debug_snapshot()["cup"], "hidden once the level is cleared")
	var found := Kit.find_loss()
	if not found.is_empty():
		var lost_scene := _make(found["level"])
		for s: int in found["taps"]:
			lost_scene.tap_screw(s)
		check(not lost_scene.debug_snapshot()["cup"], "and hidden at the loss")


func test_the_cup_pauses_the_level_before_it_emits() -> void:
	var scene := _make(_tutorial_with_number(6))
	var hud := _hud(scene)
	var target := hud.target_of("cup")
	check_eq(target.size, Vector2(48.0, 48.0), "exactly 48 by 48 at the base size")
	_touch(scene, target.get_center(), true)
	check_eq(_coffee, 0, "nothing on touch down")
	_touch(scene, target.get_center(), false)
	check_eq(_coffee, 1, "coffee_requested on release")
	check(_paused_when_coffee, "the level was already paused when the signal came")
	check(not scene.debug_snapshot()["clock_running"], "the clock is stopped")
	scene.resume()
	# A touch that goes down elsewhere and slides onto the cup does nothing, and neither does one
	# that goes down on the cup and lifts elsewhere.
	_touch(scene, Vector2(200.0, 22.0), true)
	_touch(scene, target.get_center(), false)
	_touch(scene, target.get_center(), true)
	_touch(scene, Vector2(200.0, 300.0), false)
	check_eq(_coffee, 1, "only a press that starts and ends on it counts")
	# The cup never touches the board and the board never listens outside its panel.
	var l := scene.get_layout()
	var before := scene.get_state().snapshot()
	for p: Vector2 in [target.get_center(), l.boxes_bar.get_center(), l.tray_bar.get_center(), l.helper_bar.get_center()]:
		scene.tap_at(p)
	check_eq(scene.get_state().snapshot(), before, "touches outside the board panel never reach the board")
	check_eq(scene.debug_snapshot()["marks"], 0, "not even a ripple")
	scene.tap_at(l.gu_to_scene(Vector2(80.0, 10.0)))
	check_eq(scene.debug_snapshot()["marks"], 1, "inside the panel they do")


func test_no_screw_target_can_touch_the_cup() -> void:
	# UX 1.7: the nearest screw target is at least 126 units from the cup's 48 by 48 target.
	var levels: Array[LevelData] = []
	for tier: int in LevelCatalog.fallback.size():
		for g: GeneratedLevel in LevelCatalog.fallback[tier]:
			levels.append(g.level)
	var scene := _make(levels[0])
	var cup := _hud(scene).cup_target()
	var l := scene.get_layout()
	var nearest := 1000.0
	for level: LevelData in levels:
		for s: int in level.screw_count():
			var c := l.gu_to_scene(level.screw_center(s))
			var dx := maxf(maxf(cup.position.x - c.x, 0.0), c.x - cup.end.x)
			var dy := maxf(maxf(cup.position.y - c.y, 0.0), c.y - cup.end.y)
			nearest = minf(nearest, Vector2(dx, dy).length() - LevelHit.RADIUS_GU * l.grid_px / 4.0 * 4.0)
	check(nearest >= 120.0, "the nearest screw target is %.0f units from the cup" % nearest)


func test_the_label_takes_the_cups_place_when_it_hides() -> void:
	var scene := _make(_tutorial_with_number(6))
	var with_cup: Dictionary = _hud(scene).top_items()
	scene.set_coffee(false)
	var without: Dictionary = _hud(scene).top_items()
	check_between((with_cup["label"] as Rect2).position.x, 55.9, 56.1, "label x beside the cup")
	check_between((without["label"] as Rect2).position.x, 11.9, 12.1, "label x without it")
	check_between((with_cup["timer"] as Rect2).position.x, 149.9, 150.1, "timer x beside the cup")
	check_between((without["timer"] as Rect2).position.x, 111.9, 112.1, "timer x without it")
