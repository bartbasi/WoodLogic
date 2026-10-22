# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Phase 5: the tray changes size by level (docs/UX.md 3.2.2). The layout and the picture at 3, 4,
## 5 and 6 slots, Extra slot growing a tray, the warning at one free slot, the shrink line and the
## tray closing, and that a pause or a new play() leaves nothing of either behind.

const Kit := preload("res://tests/level/kit.gd")
const Levels := preload("res://tests/level/levels.gd")
const NOTE := "The tray is smaller now. Every slot counts."
## UX 3.2.2: frame width and slot left edges at the base phone, for a 360 wide content rect.
const TABLE := {
	3: [160.0, [108.0, 158.0, 208.0]],
	4: [210.0, [83.0, 133.0, 183.0, 233.0]],
	5: [260.0, [58.0, 108.0, 158.0, 208.0, 258.0]],
	6: [310.0, [33.0, 83.0, 133.0, 183.0, 233.0, 283.0]],
}
## name, window pixels, dp per design unit, as in capture.gd
const SIZES := [
	["phone-360x640", Vector2i(360, 640), 1.0],
	["phone-412x915", Vector2i(412, 915), 1.0],
	["small-320x568", Vector2i(320, 568), 1.0],
	["tablet-1200x1920", Vector2i(1200, 1920), 2.14],
	["foldable-split", Vector2i(1680, 1440), 1.25],
]

var _scene: LevelScene
var _spy: Spy


## Stands in for the Audio autoload and writes down every effect asked for, in order.
class Spy extends Node:
	var log: Array[String] = []

	func play(effect: String, _pitch: float = 1.0, _volume_db: float = 0.0) -> void:
		log.append(effect)


## The cascade level (twelve loose discs, no open box for the first six) with this many tray slots.
func _cascade(slots: int) -> LevelData:
	var level := Levels.cascade_level()
	level.tray_size = slots
	return level


func _make(level: LevelData, instant: bool) -> LevelScene:
	_scene = Kit.make_scene(self, level, instant)
	_spy = add_node(Spy.new()) as Spy
	_scene.set("_audio", _spy)
	_scene.set_helpers({"undo": 3, "extra_slot": 3, "screwdriver": 3}, PackedStringArray(["undo", "extra_slot", "screwdriver"]))
	return _scene


## A scene laid out the way a window of `pixels` at `dpu` is (capture.gd does the same).
func _scene_at(level: LevelData, pixels: Vector2i, dpu: float, instant: bool = true) -> LevelScene:
	var scale := minf(pixels.x / 360.0, pixels.y / 640.0)
	var units := Vector2(pixels) / scale
	var scene := (load(Kit.SCENE) as PackedScene).instantiate() as LevelScene
	scene.dp_per_unit = dpu
	add_node(scene)
	scene.set_layout_size(Vector2(roundi(units.x), roundi(units.y)))
	scene.set_instant(instant)
	scene.play(level, false)
	return scene


func _content(pixels: Vector2i) -> Rect2:
	var scale := minf(pixels.x / 360.0, pixels.y / 640.0)
	var units := Vector2(pixels) / scale
	return Rect2(0.0, 24.0, roundf(units.x), roundf(units.y) - 40.0)


func _snap(scene: LevelScene) -> Dictionary:
	return scene.debug_snapshot()


func _problems(scene: LevelScene) -> String:
	return "; ".join(Kit.mismatches(scene))


# == layout ==

func test_the_frame_and_slots_match_the_table_at_the_base_phone() -> void:
	var l := LevelLayout.compute(Rect2(0.0, 24.0, 360.0, 600.0), 1.0)
	for slots: int in TABLE:
		var want: Array = TABLE[slots]
		var frame := l.tray_frame(slots)
		check_between(frame.size.x, want[0], want[0], "%d slots: frame width" % slots)
		check_between(frame.size.y, 52.0, 52.0, "%d slots: frame height" % slots)
		check_between(frame.get_center().x, 180.0, 180.0, "%d slots: the frame is centered" % slots)
		check_between(frame.position.x, 180.0 - float(want[0]) * 0.5, 180.0 - float(want[0]) * 0.5, "%d slots: frame left edge" % slots)
		var lefts: Array = want[1]
		for i: int in slots:
			var center := l.tray_slot_center(i, slots)
			check_between(center.x - 22.0, float(lefts[i]), float(lefts[i]), "%d slots: slot %d left edge" % [slots, i])
			check_between(center.y, l.tray_bar.get_center().y, l.tray_bar.get_center().y, "%d slots: slot %d on the frame's middle" % [slots, i])


func test_extra_slot_rows_of_the_table_are_the_same_frames() -> void:
	# 4 plus Extra slot is the 5 row, 3 plus Extra slot is the 4 row (UX 3.2.2): the frame depends
	# only on how many slots there are.
	var l := LevelLayout.compute(Rect2(0.0, 24.0, 360.0, 600.0), 1.0)
	check_eq(l.tray_frame(5).size.x, LevelLayout.tray_width(5), "five is five however it came about")
	check_between(l.tray_frame(4).size.x - l.tray_frame(3).size.x, 50.0, 50.0, "each extra slot widens the frame by 50")
	check_between(l.tray_frame(6).size.x - l.tray_frame(5).size.x, 50.0, 50.0, "also the sixth")


func test_every_tray_size_fits_its_column_at_every_screen_shape() -> void:
	for entry: Array in SIZES:
		var pixels: Vector2i = entry[1]
		var l := LevelLayout.compute(_content(pixels), entry[2])
		for slots: int in range(3, 8):
			var frame := l.tray_frame(slots)
			var name := "%s, %d slots" % [entry[0], slots]
			var column := l.rail if l.split else l.content
			check(frame.position.x >= column.position.x - 0.01 and frame.end.x <= column.end.x + 0.01, "%s: the frame %s is inside its column %s" % [name, str(frame), str(column)])
			check(frame.position.y >= l.tray_bar.position.y - 0.01 and frame.end.y <= l.tray_bar.end.y + 0.01, "%s: the frame is inside the tray bar" % name)
			check_between(frame.get_center().x, l.tray_center.x, l.tray_center.x, "%s: centered" % name)
			if slots <= 6:
				check_between(l.tray_scale(slots), l.box_scale, l.box_scale, "%s: up to six slots are never shrunk" % name)
			# Slots never overlap: their centers are 50 units apart at the tray's scale, the hollows 38.
			var gap := l.tray_slot_center(1, slots).x - l.tray_slot_center(0, slots).x
			check(gap >= 38.0 * l.tray_scale(slots), "%s: neighbouring slots %.1f apart" % [name, gap])
			var first := l.tray_slot_center(0, slots).x - 22.0 * l.tray_scale(slots)
			var last := l.tray_slot_center(slots - 1, slots).x + 22.0 * l.tray_scale(slots)
			check(first >= frame.position.x and last <= frame.end.x, "%s: the slots are inside the frame" % name)


func test_the_scene_draws_the_frame_where_the_layout_puts_it() -> void:
	for entry: Array in SIZES:
		for slots: int in [3, 4, 5, 6]:
			var scene := _scene_at(_cascade(slots), entry[1], entry[2])
			var problems := _problems(scene)
			check(problems.is_empty(), "%s, %d slots: %s" % [entry[0], slots, problems])
			check_eq(_snap(scene)["tray_slots"], slots, "%s: the tray has the level's %d slots" % [entry[0], slots])
			scene.queue_free()


func test_the_slots_follow_the_levels_own_size() -> void:
	# Nothing assumes 5: whatever the level says is what is built, and Retry gives it back.
	for slots: int in [3, 4, 5, 6]:
		var scene := _make(_cascade(slots), true)
		check_eq(_snap(scene)["tray_slots"], slots, "%d slots at the start" % slots)
		check_eq(scene.get_state().tray().size(), slots, "the model agrees")
		scene.use_helper("extra_slot")
		check_eq(_snap(scene)["tray_slots"], slots + 1, "%d slots after Extra slot" % slots)
		scene.retry()
		check_eq(_snap(scene)["tray_slots"], slots, "Retry gives back %d" % slots)
		check_eq(_problems(scene), "", "the picture after Retry")
		scene.queue_free()


func test_a_tap_on_the_tray_does_nothing() -> void:
	var scene := _make(_cascade(3), true)
	scene.tap_screw(0)
	var before := _snap(scene)
	var l := scene.get_layout()
	for slot: int in 3:
		scene.tap_at(l.tray_slot_center(slot, 3))
	var after := _snap(scene)
	check_eq(after["tray"], before["tray"], "the tray is as it was")
	check_eq(after["screws"], before["screws"], "no screw moved")
	check_eq(scene.get_state().tray_uses(), 1, "no tray use")


# == the warning ==

func test_the_warning_shows_at_one_free_slot_of_three() -> void:
	var scene := _make(_cascade(3), true)
	check(not _snap(scene)["tray_warning"], "no warning with three free")
	scene.tap_screw(0)
	check(not _snap(scene)["tray_warning"], "no warning with two free")
	check_eq(_snap(scene)["tray_ticks"], 0, "and no tick")
	scene.tap_screw(1)
	check(_snap(scene)["tray_warning"], "the warning at one free slot")
	check_eq(_snap(scene)["tray_ticks"], 1, "with one tick")
	scene.tap_screw(2)
	check(not _snap(scene)["tray_warning"], "full is not the warning (the full look takes over)")
	check_eq(_snap(scene)["tray_ticks"], 1, "and no second tick")
	check_eq(_problems(scene), "", "the picture agrees: %s" % _problems(scene))


func test_the_warning_clears_when_a_screw_leaves_or_a_slot_comes() -> void:
	var scene := _make(_cascade(3), true)
	scene.tap_screw(0)
	scene.tap_screw(1)
	check(_snap(scene)["tray_warning"], "the warning")
	scene.use_helper("extra_slot")
	check(not _snap(scene)["tray_warning"], "Extra slot makes it two free and the warning clears")
	check_eq(_snap(scene)["tray_ticks"], 1, "without a sound")
	var other := _make(_cascade(3), true)
	other.tap_screw(0)
	other.tap_screw(1)
	other.use_helper("undo")
	check(not _snap(other)["tray_warning"], "taking a screw back clears it too")


func test_the_tick_plays_at_most_once_every_two_seconds() -> void:
	var scene := _make(_cascade(3), true)
	scene.tap_screw(0)
	scene.tap_screw(1)
	check_eq(_snap(scene)["tray_ticks"], 1, "the first tick")
	scene.use_helper("undo")
	scene.tap_screw(1)
	check(_snap(scene)["tray_warning"], "the warning is back")
	check_eq(_snap(scene)["tray_ticks"], 1, "but no new tick inside two seconds")
	scene.use_helper("undo")
	scene.debug_step(2.1)
	scene.tap_screw(1)
	check_eq(_snap(scene)["tray_ticks"], 2, "after two seconds it ticks again")


func test_extra_slot_from_a_full_tray_enters_the_warning_with_a_tick() -> void:
	var scene := _make(_cascade(3), true)
	for s: int in [0, 1, 2]:
		scene.tap_screw(s)
	scene.debug_step(2.1)
	check_eq(_snap(scene)["tray_ticks"], 1, "one tick so far")
	scene.use_helper("extra_slot")
	check(_snap(scene)["tray_warning"], "a full tray plus a slot is one free slot")
	check_eq(_snap(scene)["tray_ticks"], 2, "the state was entered, so it ticks")


func test_the_warning_tick_in_the_air_plays_when_the_screw_lands() -> void:
	var scene := _make(_cascade(3), false)
	scene.debug_step(1.0)
	scene.tap_screw(0)
	scene.debug_step(1.0)
	scene.tap_screw(1)
	_spy.log.clear()
	check(_snap(scene)["tray_warning"], "the warning shows at the tap")
	check_eq(_snap(scene)["tray_ticks"], 0, "the tick waits for the landing")
	scene.debug_step(1.0)
	check_eq(_spy.log.count("tick"), 1, "one tick at the landing: %s" % str(_spy.log))


# == Extra slot ==

func test_extra_slot_takes_a_tray_from_three_slots_to_four() -> void:
	var scene := _make(_cascade(3), true)
	scene.tap_screw(0)
	scene.tap_screw(1)
	scene.use_helper("extra_slot")
	var snap := _snap(scene)
	check_eq(snap["tray_slots"], 4, "four slots")
	var frame: Rect2 = snap["tray_view_frame"]
	check_between(frame.size.x, 210.0, 210.0, "the frame is 210 wide (UX 3.2.2)")
	check_between(frame.get_center().x, scene.get_layout().tray_center.x, scene.get_layout().tray_center.x, "and still centered")
	var l := scene.get_layout()
	var lefts: Array = TABLE[4][1]
	var centers: Array = snap["slot_centers"]
	for i: int in 4:
		var scene_x := l.gu_to_scene(centers[i] as Vector2).x
		check_between(scene_x - 22.0 - l.content.position.x, float(lefts[i]), float(lefts[i]), "slot %d left edge in the four slot row" % i)
	check_eq(_problems(scene), "", "the screws sit in the slots the model says: %s" % _problems(scene))
	# The new slot takes a screw like any other.
	scene.tap_screw(2)
	scene.tap_screw(3)
	check_eq(scene.get_state().tray().count(-1), 0, "all four slots fill")
	check_eq(_problems(scene), "", "the picture with four screws: %s" % _problems(scene))


func test_extra_slot_grows_the_frame_in_250_ms_and_leaves_no_second_frame() -> void:
	var scene := _make(_cascade(3), false)
	scene.debug_step(1.0)
	var root: Node2D = scene.get("_box_root")
	var kids := root.get_child_count()
	scene.tap_screw(0)
	scene.debug_step(0.7)
	scene.use_helper("extra_slot")
	check(_snap(scene)["swap"], "the old frame is fading out")
	check_eq(root.get_child_count(), kids + 1, "it is a view of its own")
	scene.debug_step(0.12)
	var alpha: float = _snap(scene)["tray_alpha"]
	check(alpha > 0.0 and alpha < 1.0, "the new frame is half in: %.2f" % alpha)
	scene.debug_step(0.3)
	check(not _snap(scene)["swap"], "done")
	check_eq(root.get_child_count(), kids, "the old frame is gone")
	check_eq(_snap(scene)["tray_alpha"], 1.0, "the new frame is fully there")
	check_eq(_problems(scene), "", "the picture agrees: %s" % _problems(scene))


func test_extra_slot_then_a_quick_tap_lands_in_the_new_geometry() -> void:
	var scene := _make(_cascade(3), false)
	scene.debug_step(1.0)
	scene.tap_screw(0)
	scene.tap_screw(1)
	scene.use_helper("extra_slot")
	scene.tap_screw(2)
	check_eq(Kit.mismatches(scene, false).size(), 0, "beliefs agree in the air: %s" % "; ".join(Kit.mismatches(scene, false)))
	scene.debug_step(2.0)
	check_eq(_problems(scene), "", "settled: %s" % _problems(scene))


func test_undo_keeps_the_extra_slot_and_the_size() -> void:
	var scene := _make(_cascade(3), true)
	scene.tap_screw(0)
	scene.use_helper("extra_slot")
	scene.use_helper("undo")
	check_eq(_snap(scene)["tray_slots"], 4, "the Extra slot stays open after an Undo (R27)")
	check_eq(_problems(scene), "", "the picture: %s" % _problems(scene))


# == the shrink line ==

func test_the_shrink_line_sits_in_the_helper_bar_with_a_steady_outline() -> void:
	var scene := _make(_cascade(4), false)
	var hud: LevelHud = scene.get("_hud")
	var undo_at := hud.target_of("undo").get_center()
	check_eq(hud.hit(undo_at), "undo", "the helper buttons are there")
	scene.show_tray_note(NOTE)
	scene.debug_step(0.3)
	check_eq(_snap(scene)["note"], "", "it waits for the board to settle")
	scene.debug_step(0.5)
	check_eq(_snap(scene)["note"], NOTE, "then it shows, word for word")
	scene.debug_step(0.3)
	var snap := _snap(scene)
	check_between(snap["note_alpha"], 0.999, 1.0, "fully in")
	var l := scene.get_layout()
	var rect: Rect2 = snap["note_rect"]
	check_between(rect.size.x, 336.0, 336.0, "the plaque is 336 wide")
	check_between(rect.size.y, 48.0, 48.0, "and 48 tall")
	check(rect.get_center().distance_to(l.helper_bar.get_center()) < 0.01, "in the helper bar's place")
	check(snap["note_frame"] == snap["tray_frame"], "the outline goes round the tray frame")
	check_eq(hud.hit(undo_at), "", "the helper buttons are not there to press")
	check(not scene.debug_snapshot()["clock_running"], "it does not start the clock")
	check_eq(_snap(scene)["tray_slots"], 4, "and the tray is untouched")


func test_the_shrink_line_stays_2_5_seconds_and_goes_at_the_first_action_after() -> void:
	var scene := _make(_cascade(4), true)
	var hud: LevelHud = scene.get("_hud")
	scene.show_tray_note(NOTE)
	check_eq(_snap(scene)["note"], NOTE, "in an instant scene it shows at once")
	scene.debug_step(2.0)
	scene.tap_screw(0)
	check_eq(_snap(scene)["note"], NOTE, "an action at 2 seconds does not take it away yet")
	scene.debug_step(0.4)
	check_eq(_snap(scene)["note"], NOTE, "still there at 2.4")
	scene.debug_step(0.2)
	check_eq(_snap(scene)["note"], "", "it goes at 2.5, as an action had come")
	check_eq(hud.hit(hud.target_of("undo").get_center()), "undo", "the buttons are back")
	# The other way round: nobody acts before 2.5, then the first action takes it away at once.
	var again := _make(_cascade(4), true)
	again.show_tray_note(NOTE)
	again.debug_step(3.0)
	check_eq(_snap(again)["note"], NOTE, "with no action it stays past 2.5")
	again.tap_screw(0)
	check_eq(_snap(again)["note"], "", "the first action after 2.5 seconds takes it away")


func test_the_shrink_line_goes_by_itself_at_six_seconds() -> void:
	var scene := _make(_cascade(4), false)
	scene.show_tray_note(NOTE)
	scene.debug_step(5.0)
	check_eq(_snap(scene)["note"], NOTE, "still there at five seconds (it began at 0.45)")
	scene.debug_step(1.7)
	check_eq(_snap(scene)["note"], "", "gone by six seconds after it began")
	check_eq(_snap(scene)["note_alpha"], 0.0, "faded out")
	check_eq(_snap(scene)["helpers"].size(), 3, "the helper buttons are back")


func test_the_shrink_line_fades_over_150_ms_each_way() -> void:
	var scene := _make(_cascade(4), false)
	scene.show_tray_note(NOTE)
	scene.debug_step(0.5)
	var alpha: float = _snap(scene)["note_alpha"]
	check(alpha > 0.0 and alpha < 1.0, "fading in: %.2f" % alpha)
	scene.debug_step(0.2)
	check_eq(_snap(scene)["note_alpha"], 1.0, "in")
	scene.debug_step(2.5)
	scene.tap_screw(0)
	scene.debug_step(0.05)
	alpha = _snap(scene)["note_alpha"]
	check(alpha > 0.0 and alpha < 1.0, "fading out: %.2f" % alpha)
	scene.debug_step(0.2)
	check_eq(_snap(scene)["note_alpha"], 0.0, "out")


func test_a_refused_or_covered_tap_is_not_an_action_for_the_line() -> void:
	var scene := _make(Levels.swing_level(), true)
	scene.show_tray_note(NOTE)
	scene.debug_step(3.0)
	scene.tap_screw(1)
	scene.tap_screw(Levels.SWING_COVERED)
	check_eq(_snap(scene)["note"], "", "the first tap was accepted and took it away")
	var covered := _make(Levels.swing_level(), true)
	covered.tap_screw(1)
	covered.show_tray_note(NOTE)
	covered.debug_step(3.0)
	covered.tap_screw(Levels.SWING_COVERED)
	check_eq(_snap(covered)["note"], NOTE, "a tap on a covered screw does not")


func test_a_pause_holds_the_line_and_a_new_play_removes_it() -> void:
	var scene := _make(_cascade(4), true)
	scene.show_tray_note(NOTE)
	scene.debug_step(1.0)
	scene.pause()
	scene.debug_step(10.0)
	scene.resume()
	check_eq(_snap(scene)["note"], NOTE, "the paused seconds did not count")
	scene.debug_step(1.4)
	check_eq(_snap(scene)["note"], NOTE, "2.4 seconds shown")
	scene.play(_cascade(4), false)
	var snap := _snap(scene)
	check_eq(snap["note"], "", "a new play() has no line")
	check_eq(snap["note_alpha"], 0.0, "and none of it left")
	check_eq(scene.get("_hud").hit(scene.get("_hud").target_of("undo").get_center()), "undo", "the buttons are back")
	scene.debug_step(10.0)
	check_eq(_snap(scene)["note"], "", "and it does not come back")
	# A line that is still fading in when play() comes.
	var live := _make(_cascade(4), false)
	live.show_tray_note(NOTE)
	live.debug_step(0.5)
	live.play(_cascade(4), false)
	check_eq(_snap(live)["note_alpha"], 0.0, "no half faded line after a new play()")
	live.debug_step(10.0)
	check_eq(_snap(live)["note"], "", "and none later")


func test_the_line_wraps_and_stays_inside_the_plaque() -> void:
	# At every size the plaque is inside the helper bar's column and 48 units tall at f.
	for entry: Array in SIZES:
		var scene := _scene_at(_cascade(4), entry[1], entry[2])
		var l := scene.get_layout()
		scene.show_tray_note(NOTE)
		var rect: Rect2 = _snap(scene)["note_rect"]
		check(rect.position.x >= l.helper_bar.position.x - 0.01 and rect.end.x <= l.helper_bar.end.x + 0.01, "%s: the plaque is inside the helper bar" % entry[0])
		check_between(rect.size.y, 48.0 * l.f - 0.01, 48.0 * l.f + 0.01, "%s: 48 tall at f" % entry[0])
		check(rect.size.x >= minf(336.0 * l.f, l.helper_bar.size.x - 24.0) - 0.01, "%s: as wide as the tutorial lines" % entry[0])
		scene.queue_free()


# == the tray closing ==

func test_the_closing_shows_the_old_tray_then_closes_with_a_knock() -> void:
	var scene := _make(_cascade(4), false)
	var root: Node2D = scene.get("_box_root")
	var kids := root.get_child_count()
	scene.play_tray_closing()
	var snap := _snap(scene)
	check(snap["swap"], "the closing is under way")
	check_eq(root.get_child_count(), kids + 1, "the old, five slot frame is in the scene")
	check_eq(snap["tray_alpha"], 0.0, "the real tray waits")
	check_eq(snap["tray_slots"], 4, "the rules see four slots from the start")
	_spy.log.clear()
	scene.debug_step(0.3)
	check_eq(_snap(scene)["tray_alpha"], 0.0, "it waits for the board to settle")
	check(not _spy.log.has("knock_dull"), "and has not knocked")
	scene.debug_step(0.3)
	var mid: float = _snap(scene)["tray_alpha"]
	check(mid > 0.0 and mid < 1.0, "sliding in: %.2f" % mid)
	var drawn: Rect2 = _snap(scene)["tray_view_frame"]
	check(drawn.get_center().x < scene.get_layout().tray_center.x, "from the left of the middle")
	scene.debug_step(0.5)
	check(not _snap(scene)["swap"], "done")
	check_eq(root.get_child_count(), kids, "the old frame is gone")
	check(_spy.log.has("knock_dull"), "the dull wood knock: %s" % str(_spy.log))
	check_eq(_problems(scene), "", "the tray is at its own size and centered: %s" % _problems(scene))
	check_between((_snap(scene)["tray_view_frame"] as Rect2).size.x, 210.0, 210.0, "a 210 wide frame")


func test_the_closing_works_from_four_to_three_and_five_to_four() -> void:
	for slots: int in [3, 4]:
		var scene := _make(_cascade(slots), false)
		scene.play_tray_closing()
		scene.debug_step(1.5)
		check(not _snap(scene)["swap"], "%d slots: done" % slots)
		check_eq(_problems(scene), "", "%d slots: %s" % [slots, _problems(scene)])
		scene.queue_free()


func test_a_tap_during_the_closing_ends_it_at_once_and_quietly() -> void:
	var scene := _make(_cascade(4), false)
	scene.play_tray_closing()
	scene.debug_step(0.2)
	_spy.log.clear()
	scene.tap_screw(0)
	check(not _snap(scene)["swap"], "the closing is over")
	check_eq(_snap(scene)["tray_alpha"], 1.0, "the tray is there")
	check(not _spy.log.has("knock_dull"), "with no knock: %s" % str(_spy.log))
	scene.debug_step(2.0)
	check_eq(_problems(scene), "", "the screw landed in the tray's own slot: %s" % _problems(scene))


func test_a_pause_during_the_closing_ends_it() -> void:
	var scene := _make(_cascade(4), false)
	var root: Node2D = scene.get("_box_root")
	var kids := root.get_child_count()
	scene.play_tray_closing()
	scene.debug_step(0.6)
	scene.pause()
	check(not _snap(scene)["swap"], "ended by the pause")
	check_eq(root.get_child_count(), kids, "nothing left behind")
	scene.resume()
	scene.debug_step(1.0)
	check_eq(_problems(scene), "", "after the pause: %s" % _problems(scene))


func test_a_new_play_during_the_closing_leaves_nothing_behind() -> void:
	var scene := _make(_cascade(4), false)
	var root: Node2D = scene.get("_box_root")
	var fresh := root.get_child_count()
	scene.play_tray_closing()
	scene.debug_step(0.6)
	scene.play(_cascade(3), false)
	check(not _snap(scene)["swap"], "no closing under way")
	check_eq(root.get_child_count(), fresh, "no old frame in the scene")
	check_eq(_snap(scene)["tray_alpha"], 1.0, "the new tray is fully there")
	check_eq(_snap(scene)["tray_slots"], 3, "at the new level's size")
	scene.debug_step(2.0)
	check_eq(_problems(scene), "", "and stays right: %s" % _problems(scene))
	# And the closing that was cut off does not knock later.
	_spy.log.clear()
	scene.debug_step(2.0)
	check(not _spy.log.has("knock_dull"), "no late knock")


func test_closing_and_line_together_end_cleanly() -> void:
	# Level 12 arrives by Next: the closing and the line are both asked right after play().
	var scene := _make(_cascade(4), false)
	scene.play_tray_closing()
	scene.show_tray_note(NOTE)
	scene.debug_step(0.9)
	check_eq(_snap(scene)["note"], NOTE, "the line shows")
	scene.debug_step(0.5)
	check(not _snap(scene)["swap"], "the closing is done")
	scene.debug_step(6.0)
	var snap := _snap(scene)
	check_eq(snap["note"], "", "the line is gone")
	check_eq(snap["busy"], 0, "nothing is still moving")
	check_eq(_problems(scene), "", "the picture: %s" % _problems(scene))


func test_the_closing_in_an_instant_scene_changes_nothing() -> void:
	var scene := _make(_cascade(4), true)
	scene.play_tray_closing()
	check(not _snap(scene)["swap"], "nothing to animate")
	check_eq(_problems(scene), "", "the tray is at its own size: %s" % _problems(scene))


func test_the_new_methods_before_a_level_are_harmless() -> void:
	var scene := (load(Kit.SCENE) as PackedScene).instantiate() as LevelScene
	add_node(scene)
	scene.play_tray_closing()
	scene.show_tray_note(NOTE)
	check(scene.get_state() == null, "still no level")


# == the picture follows the model at every tray size ==

func test_stored_levels_played_at_every_tray_size_agree_with_the_model() -> void:
	var checked := 0
	for slots: int in [3, 4, 5, 6]:
		for tier: int in [4, 7, 10]:
			for g: GeneratedLevel in LevelCatalog.fallback[tier - 1].slice(0, 2):
				var errors := PackedStringArray()
				var level := g.level.with_colors(g.level.screw_colors, g.level.queue, errors, {"tray": slots})
				check(level != null and errors.is_empty(), "a copy with %d slots: %s" % [slots, "; ".join(errors)])
				if level == null:
					continue
				for with_extra: bool in [false, true]:
					var game := Kit.random_game(level, slots * 10 + tier)
					var scene := Kit.make_scene(self, level, true)
					_check_game(scene, game["taps"], with_extra, "%d slots, %s%s" % [slots, g.level.id, ", Extra slot" if with_extra else ""])
					checked += 1
					scene.queue_free()
					await frames(1)
	check(checked >= 48, "played %d games" % checked)


func _check_game(scene: LevelScene, taps: PackedInt32Array, with_extra: bool, what: String) -> void:
	var problems := Kit.mismatches(scene)
	check(problems.is_empty(), "%s at the start: %s" % [what, "; ".join(problems)])
	for i: int in taps.size():
		if with_extra and i == 2:
			scene.use_helper("extra_slot")
		scene.tap_screw(taps[i])
		problems = Kit.mismatches(scene)
		check(problems.is_empty(), "%s after tap %d: %s" % [what, i, "; ".join(problems)])
		if not problems.is_empty():
			return
	check_eq(_snap(scene)["tray_slots"], scene.get_state().tray().size(), "%s: the tray size at the end" % what)


func test_the_same_games_with_animation_on_end_in_step() -> void:
	# A quick player (a tap every other frame) on 3, 4 and 5 slot trays, Extra slot in the middle.
	for slots: int in [3, 4, 5]:
		var g: GeneratedLevel = LevelCatalog.fallback[6][0]
		var errors := PackedStringArray()
		var level := g.level.with_colors(g.level.screw_colors, g.level.queue, errors, {"tray": slots})
		var game := Kit.random_game(level, 7 + slots)
		var scene := Kit.make_scene(self, level, false)
		var taps: PackedInt32Array = game["taps"]
		for i: int in taps.size():
			if i == 3:
				scene.use_helper("extra_slot")
			scene.tap_screw(taps[i])
			var problems := Kit.mismatches(scene, false)
			check(problems.is_empty(), "%d slots, tap %d: %s" % [slots, i, "; ".join(problems)])
			await frames(2)
		await Kit.settle(self, scene)
		await frames(30)
		var settled := Kit.mismatches(scene)
		check(settled.is_empty(), "%d slots settled: %s" % [slots, "; ".join(settled)])
		scene.queue_free()
		await frames(1)
