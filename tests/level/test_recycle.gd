# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Phase 6: box views are recycled (each is a CachedDrawing with a render target of its own), and
## the helper badges count up to a gift (UX 3.13.4).

const Kit := preload("res://tests/level/kit.gd")
const Levels := preload("res://tests/level/levels.gd")
const ALL := ["undo", "extra_slot", "screwdriver"]

var _scene: LevelScene
var _spy: Spy


## Stands in for the Audio autoload and writes down every effect asked for, in order.
class Spy extends Node:
	var log: Array[String] = []

	func play(effect: String, _pitch: float = 1.0, _volume_db: float = 0.0) -> void:
		log.append(effect)


func _make(level: LevelData, instant: bool) -> LevelScene:
	_scene = Kit.make_scene(self, level, instant)
	_spy = add_node(Spy.new()) as Spy
	_scene.set("_audio", _spy)
	return _scene


## Every BoxView under a node, and the render targets (SubViewports) they own.
func _count_boxes(node: Node, out: Dictionary) -> void:
	for child: Node in node.get_children():
		if child is BoxView:
			out["boxes"] = int(out["boxes"]) + 1
			for inner: Node in child.get_children():
				if inner is SubViewport:
					out["targets"] = int(out["targets"]) + 1
		_count_boxes(child, out)


func _boxes_in(scene: LevelScene) -> Dictionary:
	var out := {"boxes": 0, "targets": 0}
	_count_boxes(scene, out)
	return out


func _nodes_in(node: Node) -> int:
	var n := 1
	for child: Node in node.get_children():
		n += _nodes_in(child)
	return n


## Whether each box and preview view is drawn as the model says (color, count, shown, opaque).
func _look_problems(scene: LevelScene) -> String:
	var out := PackedStringArray()
	var state := scene.get_state()
	var views: Array = scene.get("_box_views")
	for pos: int in views.size():
		var want := state.open_box(pos).x
		var view: Node2D = views[pos]
		if want < 0:
			if view != null:
				out.append("box %d is drawn but is closed" % pos)
			continue
		if view == null:
			out.append("box %d is missing" % pos)
			continue
		if int(view.get("_color")) != posmod(want, Palette.count()):
			out.append("box %d has color %d, expected %d" % [pos, view.get("_color"), want])
		if bool(view.get("_preview")):
			out.append("box %d is drawn as a preview" % pos)
		if not view.visible or view.modulate.a < 0.999:
			out.append("box %d is not fully shown" % pos)
		var inside := 0
		for s: int in state.box_screws(pos):
			if s >= 0:
				inside += 1
		if int(view.get("_count")) != inside:
			out.append("box %d counts %d screws, holds %d" % [pos, view.get("_count"), inside])
	var previews: Array = scene.get("_preview_views")
	var want_previews := state.preview()
	if previews.size() != want_previews.size():
		out.append("%d previews drawn, %d wanted" % [previews.size(), want_previews.size()])
	else:
		for k: int in previews.size():
			var view: Node2D = previews[k]
			if int(view.get("_color")) != posmod(want_previews[k], Palette.count()) or not bool(view.get("_preview")):
				out.append("preview %d is drawn wrong" % k)
			if not view.visible or view.modulate.a < 0.999:
				out.append("preview %d is not fully shown" % k)
	return "; ".join(out)


func _play_through(scene: LevelScene, solution: PackedInt32Array, level: LevelData) -> void:
	for s: int in solution:
		var r := scene.tap_screw(s)
		check(r.ok, "%s: tap %d accepted" % [level.id, s])
		var problems := Kit.mismatches(scene, false)
		check(problems.is_empty(), "%s after tap %d: %s" % [level.id, s, "; ".join(problems)])
		await frames(2)
	await Kit.settle(self, scene)
	await frames(30)


func test_box_views_and_render_targets_stay_flat_over_a_long_level() -> void:
	var scene := _make(Levels.cascade_level(), false)
	await Kit.settle(self, scene)
	var most := 0
	for s: int in Levels.CASCADE_SOLUTION:
		scene.tap_screw(s)
		await frames(3)
		var counts := _boxes_in(scene)
		most = maxi(most, int(counts["boxes"]))
		check(int(counts["targets"]) <= int(counts["boxes"]), "one render target at most per box view")
	await Kit.settle(self, scene)
	await frames(30)
	check(most <= 6, "at most six box views at once on a four box level, saw %d" % most)
	check_eq(Kit.mismatches(scene).size(), 0, "the picture agrees: %s" % "; ".join(Kit.mismatches(scene)))
	check_eq(_look_problems(scene), "", "the boxes are drawn as the model says")
	check(int(scene.debug_snapshot()["boxes_made"]) <= 6, "the level made %d box views" % scene.debug_snapshot()["boxes_made"])


func test_many_levels_in_one_scene_make_no_new_box_views_after_the_first_few() -> void:
	var scene := _make(Levels.cascade_level(), false)
	await Kit.settle(self, scene)
	var made_after_two := -1
	var targets_after_two := -1
	var most_boxes := 0
	var made_log: Array[int] = []
	for i: int in 10:
		var n := Kit.level_of_tier([4, 5, 6][i % 3], 12 + i)
		var g := Kit.numbered(n)
		scene.play(g.level, false)
		await frames(1)
		await _play_through(scene, g.solve.solution, g.level)
		check_eq(_look_problems(scene), "", "level %d: the boxes after the level" % n)
		var counts := _boxes_in(scene)
		most_boxes = maxi(most_boxes, int(counts["boxes"]))
		made_log.append(int(scene.debug_snapshot()["boxes_made"]))
		if i == 1:
			made_after_two = int(scene.debug_snapshot()["boxes_made"])
			targets_after_two = int(counts["targets"])
	var snap := scene.debug_snapshot()
	check(int(snap["boxes_made"]) <= made_after_two + 3, "views made grew from %d to %d over eight more levels" % [made_after_two, snap["boxes_made"]])
	check(made_log[9] - made_log[4] <= 1, "no steady churn over the last five levels: %s" % str(made_log))
	check(int(snap["boxes_made"]) <= LevelScene.BOX_POOL_MAX + 2, "never more than the pool and a few: %s" % str(made_log))
	check(most_boxes <= LevelScene.BOX_POOL_MAX + 6, "box views in the scene stayed small: %d" % most_boxes)
	check(int(_boxes_in(scene)["targets"]) <= targets_after_two + 3, "render targets stayed flat: %d after two levels, %d at the end" % [targets_after_two, _boxes_in(scene)["targets"]])
	check(int(snap["box_pool"]) <= LevelScene.BOX_POOL_MAX, "the pool is capped")


func test_the_node_count_of_the_scene_is_flat_from_level_to_level() -> void:
	var scene := _make(Levels.cascade_level(), true)
	var sizes: Array[int] = []
	for i: int in 8:
		scene.play(Levels.cascade_level(), false)
		for s: int in Levels.CASCADE_SOLUTION:
			scene.tap_screw(s)
		await frames(3)
		sizes.append(_nodes_in(scene))
	check_eq(scene.get_state().status(), PlayState.WON, "the level was won")
	# The pool fills during the first levels; after that the count stays put.
	for i: int in range(3, sizes.size()):
		check(sizes[i] <= sizes[2] + 2, "level %d has %d nodes, level 3 had %d" % [i + 1, sizes[i], sizes[2]])


func test_a_recycled_box_is_reset_in_every_way() -> void:
	# Close a box with screws in it, then wait for the pool to hand the view out again.
	var scene := _make(Levels.cascade_level(), false)
	await Kit.settle(self, scene)
	for s: int in [0, 1, 2, 3, 4, 6, 7, 8]:
		scene.tap_screw(s)
		await frames(2)
	await Kit.settle(self, scene)
	await frames(60)
	check(int(scene.debug_snapshot()["box_pool"]) >= 0, "a pool exists")
	check_eq(_look_problems(scene), "", "after a box closed and the next arrived: %s" % _look_problems(scene))
	scene.retry()
	await frames(2)
	check_eq(_look_problems(scene), "", "after Retry")
	check_eq(Kit.mismatches(scene, false).size(), 0, "and the picture agrees")


func test_undo_after_a_close_still_agrees_with_recycled_views() -> void:
	var scene := _make(Levels.cascade_level(), false)
	await Kit.settle(self, scene)
	for s: int in [0, 1, 2, 3, 4, 6, 7, 8]:
		scene.tap_screw(s)
		await frames(2)
	await Kit.settle(self, scene)
	for i: int in 3:
		scene.debug_undo()
		await frames(2)
	await Kit.settle(self, scene)
	await frames(60)
	check_eq(Kit.mismatches(scene).size(), 0, "the picture: %s" % "; ".join(Kit.mismatches(scene)))
	check_eq(_look_problems(scene), "", "the boxes: %s" % _look_problems(scene))


# == the gift count ==

func _hud(scene: LevelScene) -> LevelHud:
	return scene.get("_hud") as LevelHud


func _gift_scene(instant: bool = false) -> LevelScene:
	var scene := _make(Levels.cascade_level(), instant)
	scene.set_helpers({"undo": 4, "extra_slot": 1, "screwdriver": 0}, PackedStringArray(["undo", "extra_slot"]))
	return scene


func test_the_badges_show_the_old_counts_and_count_up_once() -> void:
	var scene := _gift_scene()
	await frames(2)
	_spy.log.clear()
	scene.show_helper_gift({"undo": 2, "extra_slot": 0})
	var hud := _hud(scene)
	check_eq(hud.get_badge("undo"), "2", "Undo starts at the old count")
	check_eq(hud.get_badge("extra_slot"), "0", "Extra slot starts at 0")
	check(scene.debug_snapshot()["gift"], "the count is under way")
	scene.debug_step(0.25)
	check_eq(hud.get_badge("undo"), "3", "one step after 200 ms")
	check_eq(hud.get_badge("extra_slot"), "1", "Extra slot reached its count")
	scene.debug_step(0.2)
	check_eq(hud.get_badge("undo"), "4", "and the last step")
	check(not scene.debug_snapshot()["gift"], "done")
	check_eq(_spy.log.count("tick"), 3, "one soft tick per step: %s" % str(_spy.log))
	scene.debug_step(2.0)
	check_eq(hud.get_badge("undo"), "4", "it stays there")
	check_eq(_spy.log.count("tick"), 3, "and ticks no more")


func test_a_helper_that_is_not_shown_or_did_not_go_up_does_not_count() -> void:
	var scene := _gift_scene()
	scene.show_helper_gift({"undo": 4, "extra_slot": 1, "screwdriver": 0})
	check(not scene.debug_snapshot()["gift"], "nothing went up: no count")
	var other := _gift_scene()
	other.set_helpers({"undo": 3, "extra_slot": 1, "screwdriver": 5}, PackedStringArray(["undo", "extra_slot"]))
	other.show_helper_gift({"undo": 3, "extra_slot": 1, "screwdriver": 0})
	check(not other.debug_snapshot()["gift"], "the Screwdriver is not shown, so it does not count")
	check_eq(_hud(other).get_badge("undo"), "3", "Undo shows its count")


func test_an_instant_scene_shows_the_counts_at_once() -> void:
	var scene := _gift_scene(true)
	scene.show_helper_gift({"undo": 2, "extra_slot": 0})
	check_eq(_hud(scene).get_badge("undo"), "4", "the new count at once")
	check(not scene.debug_snapshot()["gift"], "nothing to wait for")


func test_a_pause_ends_the_gift_count_quietly() -> void:
	var scene := _gift_scene()
	await frames(2)
	scene.show_helper_gift({"undo": 2, "extra_slot": 0})
	scene.debug_step(0.25)
	_spy.log.clear()
	scene.pause()
	check_eq(_hud(scene).get_badge("undo"), "4", "the real count after the pause")
	check_eq(_hud(scene).get_badge("extra_slot"), "1", "for both")
	check(not scene.debug_snapshot()["gift"], "no count left")
	check(not _spy.log.has("tick"), "with no sound: %s" % str(_spy.log))
	scene.resume()
	scene.debug_step(1.0)
	check_eq(_hud(scene).get_badge("undo"), "4", "and it does not start again")
	check_eq(scene.debug_snapshot()["busy"], 0, "nothing is moving")


func test_a_new_play_drops_the_gift_count() -> void:
	var scene := _gift_scene()
	await frames(2)
	scene.show_helper_gift({"undo": 2, "extra_slot": 0})
	scene.debug_step(0.25)
	scene.play(Levels.cascade_level(), false)
	check(not scene.debug_snapshot()["gift"], "no count under way")
	check_eq(_hud(scene).get_badge("undo"), "4", "the badge shows the count the helpers have")
	scene.debug_step(1.0)
	check_eq(_hud(scene).get_badge("undo"), "4", "and keeps it")
	check_eq(_hud(scene).get_badge("extra_slot"), "1", "for both")


func test_a_helper_tap_ends_the_count_and_uses_a_real_count() -> void:
	var scene := _gift_scene()
	await frames(2)
	var used: Array[String] = []
	scene.helper_used.connect(func(h: String) -> void: used.append(h))
	scene.tap_screw(0)
	scene.show_helper_gift({"undo": 2, "extra_slot": 0})
	scene.debug_step(0.1)
	var hud := _hud(scene)
	var p := hud.target_of("undo").get_center()
	var down := InputEventScreenTouch.new()
	down.position = p
	down.pressed = true
	scene.call("_gui_input", down)
	var up := InputEventScreenTouch.new()
	up.position = p
	up.pressed = false
	scene.call("_gui_input", up)
	check_eq(used, ["undo"] as Array[String], "the tap used Undo")
	check(not scene.debug_snapshot()["gift"], "the count ended")
	check_eq(hud.get_badge("undo"), "4", "the badge shows the real count")
	scene.debug_step(1.0)
	check_eq(hud.get_badge("undo"), "4", "and no step comes later")
	# The same by use_helper.
	var other := _gift_scene()
	await frames(2)
	other.tap_screw(0)
	other.show_helper_gift({"undo": 2, "extra_slot": 0})
	other.use_helper("undo")
	check(not other.debug_snapshot()["gift"], "use_helper ends it too")
