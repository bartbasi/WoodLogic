# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The progress map (docs/UX.md 3.6): positions from the level number, a pool of about 20
## recycled nodes, taps turned into levels by arithmetic, opening centered on the next level.


func _view(highest: int, size: Vector2i = Vector2i(360, 416)) -> MapView:
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	add_node(vp)
	vp.add_child(Control.new())
	var records := {}
	for n: int in range(1, mini(highest, 400) + 1):
		records[str(n)] = {"stars": 1 + n % 3, "best_ms": 1000, "gen": 0}
	var view := MapView.make(highest, records)
	view.theme = UiTheme.build()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(view)
	return view


func test_the_zigzag_lanes_and_spacing() -> void:
	var xs: Array[float] = []
	for n: int in range(1, 9):
		xs.append(MapMath.lane_x(n, 180.0))
	check_eq(xs, [180.0, 276.0, 180.0, 84.0, 180.0, 276.0, 180.0, 84.0], "lane x for levels 1 to 8")
	check_eq(MapMath.node_y(1, 0, 400.0) - MapMath.node_y(2, 0, 400.0), 88.0, "88 between centers")
	for n: int in range(1, 40):
		var a := Vector2(MapMath.lane_x(n, 180.0), MapMath.node_y(n, 50, 400.0))
		var b := Vector2(MapMath.lane_x(n + 1, 180.0), MapMath.node_y(n + 1, 50, 400.0))
		check(a.distance_to(b) >= 88.0, "nodes are never closer than 88")
		var c := Vector2(MapMath.lane_x(n + 2, 180.0), MapMath.node_y(n + 2, 50, 400.0))
		check(a.distance_to(c) >= 130.0 - 0.01 or absf(a.x - c.x) < 1.0 and a.distance_to(c) >= 176.0 - 0.01, "two apart are at least 130 apart")


func test_states_sizes_and_hard_levels() -> void:
	check_eq(MapMath.state_of(3, 5), MapMath.CLEARED, "cleared")
	check_eq(MapMath.state_of(6, 5), MapMath.NEXT, "next")
	check_eq(MapMath.state_of(7, 5), MapMath.LOCKED, "locked")
	check_eq(MapMath.top_level(5), 10, "four locked past the next")
	check_eq(MapMath.node_size(6, 5), 80.0, "next is 80")
	check_eq(MapMath.node_size(3, 5), 64.0, "cleared is 64")
	check_eq(MapMath.node_size(10, 12), 72.0, "a hard level is 72")
	check_eq(MapMath.node_size(15, 12), 64.0, "level 15 is next or locked: 64")
	check_eq(MapMath.node_size(9, 12), 64.0, "level 9 is not hard")
	check(MapMath.is_hard(10) and MapMath.is_hard(15) and not MapMath.is_hard(5) and not MapMath.is_hard(11), "every 5th from 10")


func test_a_tap_becomes_a_level_by_arithmetic() -> void:
	var body := 416.0
	for n: int in [1, 2, 7, 33, 150, 999]:
		var highest := maxi(0, n - 1)
		var x := MapMath.lane_x(n, 180.0)
		var y := MapMath.node_y(n, highest, body)
		check_eq(MapMath.level_at(x, y, 180.0, highest, body), n, "the center of level %d" % n)
		check_eq(MapMath.level_at(x + 20.0, y - 20.0, 180.0, highest, body), n, "inside the badge of %d" % n)
		check_eq(MapMath.level_at(x + 120.0, y, 180.0, highest, body), 0, "beside the badge of %d" % n)
	check_eq(MapMath.level_at(180.0, 100000.0, 180.0, 5, body), 0, "far below level 1")


func test_it_opens_centered_on_the_next_level() -> void:
	for highest: int in [0, 4, 150]:
		var view := _view(highest)
		await frames(3)
		var next_center := view.center_of(highest + 1)
		check_between(next_center.y, view.size.y / 2.0 - 1.0, view.size.y / 2.0 + 1.0, "the next node at the middle (highest %d)" % highest)


func test_the_pool_stays_small_at_any_level_count() -> void:
	var view := _view(1000, Vector2i(360, 922))
	await frames(3)
	check(view.pool_size() <= 24, "about 20 node views (%d)" % view.pool_size())
	check(view.pool_size() >= 8, "and enough to cover the view (%d)" % view.pool_size())
	var small := _view(2)
	await frames(3)
	check(small.pool_size() <= 12, "fewer when few levels exist (%d)" % small.pool_size())
	view.scroll_to_next()
	await frames(40)
	check(view.pool_size() <= 24, "scrolling does not grow the pool (%d)" % view.pool_size())


func test_taps_choose_cleared_and_next_and_nudge_locked() -> void:
	var view := _view(12)
	await frames(3)
	var chosen := []
	var locked := []
	view.level_chosen.connect(func(n: int) -> void: chosen.append(n))
	view.locked_tapped.connect(func(n: int) -> void: locked.append(n))
	view.tap(view.center_of(13))
	view.tap(view.center_of(11))
	view.tap(view.center_of(15))
	check_eq(chosen, [13, 11], "the next and a cleared level start")
	check_eq(locked, [13], "a locked tap names the level to clear")
	view.tap(Vector2(2.0, 2.0))
	check_eq(chosen.size(), 2, "a tap on empty trail does nothing")


func test_nodes_are_the_designers_views_and_labels_read_right() -> void:
	var view := _view(12)
	await frames(3)
	var shown := 0
	for child: Node in view.get_children():
		if child is MapNodeView and (child as MapNodeView).visible:
			shown += 1
	check(shown >= 8, "node views are in use (%d)" % shown)
	check_eq(MapMath.label_of(13, 12, 0), "Level 13, next", "the next node")
	check_eq(MapMath.label_of(14, 12, 0), "Level 14, locked", "a locked node")
	check_eq(MapMath.label_of(5, 12, 1), "Level 5, 1 star", "one star")
	check_eq(MapMath.label_of(5, 12, 3), "Level 5, 3 stars", "three stars")
	var next_node := view._node_for(13)
	check(next_node != null and next_node.diameter() == 80.0, "the next node is 80 across")
	var hard := view._node_for(10)
	check(hard != null and hard.diameter() == 72.0, "a hard cleared level is 72 across")


func test_the_go_to_level_chip_shows_only_when_the_next_node_is_far() -> void:
	var view := _view(150, Vector2i(360, 416))
	await frames(3)
	check(not view._goto.visible, "hidden when the next level is in view")
	view._set_scroll(view._max_scroll())
	await frames(2)
	check(view._goto.visible, "shown when it is far away")
	check_eq(view._goto.label_text, "Go to level 151", "named")
	view.scroll_to_next()
	await frames(40)
	check(not view._goto.visible, "gone after the scroll")


func test_a_drag_scrolls_and_a_short_touch_is_a_tap() -> void:
	var view := _view(30)
	await frames(3)
	var start := view.scroll
	view._begin_touch(Vector2(180.0, 200.0))
	view._move_touch(Vector2(180.0, 260.0))
	view._move_touch(Vector2(180.0, 320.0))
	check(view.scroll < start, "dragging down shows higher...lower levels, the scroll moved: %f to %f" % [start, view.scroll])
	var chosen := []
	view.level_chosen.connect(func(n: int) -> void: chosen.append(n))
	view._end_touch(Vector2(180.0, 320.0))
	check(chosen.is_empty(), "a drag is not a tap")
	var center := view.center_of(31)
	view._begin_touch(center)
	view._end_touch(center)
	check_eq(chosen, [31], "a short touch is a tap")
