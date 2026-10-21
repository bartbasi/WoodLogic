# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The views offer the contract's setup arguments and methods (docs/ARCHITECTURE.md 7 and
## 11.1) and run without errors. Headless runs draw nothing, so the look itself is checked on
## the screenshots tools/art makes.

## A bar 30 by 8 grid units with rounded ends, two holes, as the logic would hand it over.
static func _bar_outline() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := -PI / 2.0 + PI * i / 16.0
		pts.append(Vector2(30, 4) + Vector2(cos(a), sin(a)) * 4.0)
	for i in 17:
		var a := PI / 2.0 + PI * i / 16.0
		pts.append(Vector2(4, 4) + Vector2(cos(a), sin(a)) * 4.0)
	return pts


func test_plank_view_sets_up_wiggles_and_bakes() -> void:
	var v := PlankView.new()
	v.setup(_bar_outline(), PackedVector2Array(), 1, PackedVector2Array([Vector2(6, 4), Vector2(28, 4)]), 42)
	add_node(v)
	v.wiggle()
	v.set_shadow(0.5)
	v.bake()
	await frames(4)
	check(v.is_baked(), "baked after a couple of frames")
	v.rotation = 0.4
	v.setup(_bar_outline(), PackedVector2Array(), 0, PackedVector2Array(), 7)
	await frames(2)
	check(true, "no errors")


func test_ring_plank_and_board_panel() -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 64:
		var a := TAU * i / 64.0
		outer.append(Vector2(20, 20) + Vector2(cos(a), sin(a)) * 12.0)
		inner.append(Vector2(20, 20) + Vector2(cos(a), sin(a)) * 6.0)
	var ring := PlankView.new()
	ring.setup(outer, inner, 2, PackedVector2Array(), 3)
	add_node(ring)
	ring.bake()
	var board := BoardView.new()
	add_node(board)
	var panels: Array[Rect2] = [Rect2(8, 176, 344, 360), Rect2(8, 0, 344, 160)]
	board.setup(Vector2(360, 640), panels)
	board.bake()
	await frames(4)
	check(true, "no errors")


func test_simplify_keeps_a_circle_close_and_small() -> void:
	var circle := PackedVector2Array()
	for i in 128:
		var a := TAU * i / 128.0
		circle.append(Vector2(cos(a), sin(a)) * 160.0)
	var out := PlankView.simplify(circle, PlankView.OUTLINE_TOLERANCE, PlankView.MAX_OUTER)
	check(out.size() <= PlankView.MAX_OUTER, "fits the shader's array")
	check(out.size() < 128, "drops points it doesn't need")
	for i in out.size():
		var mid := (out[i] + out[(i + 1) % out.size()]) * 0.5
		check_between(mid.length(), 160.0 - 1.0, 160.0, "chord stays within a unit of the circle")


func test_screw_view_sizes_and_states() -> void:
	for size: int in [ScrewView.BOARD, ScrewView.WELL, ScrewView.TRAY]:
		var v := ScrewView.new()
		v.setup(3, size)
		add_node(v)
		check_eq(v.radius() * 2.0, ScrewView.DIAMETERS[size], "diameter")
		v.set_turn(45.0)
		v.set_lift(0.5)
		v.set_covered(true)
		check(v.is_covered(), "covered")
		v.set_bright(true)
		check(v.is_bright(), "bright in Screwdriver mode")
		v.set_bright(false)
	await frames(12)
	Looks.current["symbols"] = false
	var off := ScrewView.new()
	off.setup(0, ScrewView.BOARD)
	Looks.current["symbols"] = true
	off.free()


func test_box_view_open_preview_and_close() -> void:
	var box := BoxView.new()
	box.setup(4, false)
	add_node(box)
	box.set_count(2)
	box.set_lid(0.5)
	box.close()
	var preview := BoxView.new()
	preview.setup(8, true)
	add_node(preview)
	check_eq(BoxView.well_center(1), Vector2(46, 20), "the middle well, per UX 3.2.2")
	await frames(16)
	box.setup(4, false)
	check(true, "no errors")


func test_tray_view_states_and_geometry() -> void:
	var tray := TrayView.new()
	tray.setup(5)
	add_node(tray)
	tray.set_filled(PackedByteArray([1, 1, 1, 1, 0]))
	tray.set_warning(true)
	tray.set_full(false)
	await frames(3)
	tray.setup(6)
	tray.set_full(true)
	check_eq(TrayView.width(5), 260.0, "five slots are 260 wide (UX 2)")
	check_eq(TrayView.width(6), 310.0, "six slots are 310 wide (UX 2)")
	check_eq(TrayView.slot_x(0, 5), -100.0, "the first slot's center")
	await frames(2)


func test_clear_effects_play_and_skip_emit_finished() -> void:
	var fx := ClearEffects.new()
	var stars: Array[Vector2] = [Vector2(84, 180), Vector2(180, 180), Vector2(276, 180)]
	var earned: Array[bool] = [true, false, true]
	fx.setup(Rect2(0, 0, 360, 640), stars, earned)
	add_node(fx)
	var done := [0]
	fx.finished.connect(func() -> void: done[0] += 1)
	fx.play()
	check(fx.is_playing(), "playing")
	await frames(110)
	check_eq(done[0], 1, "finished once after 1.6 s")
	fx.play()
	fx.skip()
	check_eq(done[0], 2, "skip finishes at once")
	check(not fx.is_playing(), "stopped")


func test_map_nodes_and_trail() -> void:
	for state: int in [MapNodeView.CLEARED, MapNodeView.NEXT, MapNodeView.LOCKED]:
		for big: bool in [false, true]:
			var v := MapNodeView.new()
			v.setup(123, state, 2, big)
			add_node(v)
			check(v.diameter() >= 48.0, "a node is at least a 48 unit target")
	var next := MapNodeView.new()
	next.setup(5, MapNodeView.NEXT, 0, false)
	check_eq(next.diameter(), 80.0, "the next level is 80 across")
	next.set_pressed(true)
	next.free()
	var trail := TrailCanvas.new()
	add_node(trail)
	await frames(2)
	check(trail.drawn, "the trail drew")


class TrailCanvas extends Node2D:
	var drawn := false

	func _draw() -> void:
		MapTrail.draw_segment(self, Vector2(180, 600), Vector2(276, 512), true)
		MapTrail.draw_segment(self, Vector2(276, 512), Vector2(180, 424), false)
		MapTrail.draw_fade(self, Rect2(0, 0, 360, 64), Tokens.PEGBOARD)
		drawn = true


func test_a_cached_view_freed_mid_cache_logs_nothing() -> void:
	# Freed at every point of the settle and capture frames, and once taken out of the tree.
	for wait in 5:
		var box := BoxView.new()
		box.setup(1, false)
		tree.root.add_child(box)
		await frames(wait)
		box.free()
		await frames(4)
	var tray := TrayView.new()
	tray.setup(5)
	tree.root.add_child(tray)
	await frames(3)
	tree.root.remove_child(tray)
	await frames(4)
	tray.free()
	await frames(2)
	check(true, "no errors")


func test_a_cached_view_settles_into_its_cache() -> void:
	var node := MapNodeView.new()
	node.setup(7, MapNodeView.CLEARED, 3, false)
	add_node(node)
	await frames(8)
	check(node.is_cached(), "cached once still")
	node.set_pressed(true)
	check(not node.is_cached(), "drawn live again after a change")


func test_a_plank_freed_mid_bake_logs_nothing() -> void:
	for wait in 4:
		var v := PlankView.new()
		v.setup(_bar_outline(), PackedVector2Array(), 1, PackedVector2Array(), 9)
		tree.root.add_child(v)
		v.bake()
		await frames(wait)
		v.free()
		await frames(4)
	check(true, "no errors")


func test_title_board_fills_each_title_size_and_bakes() -> void:
	for size: Vector2 in [Vector2(312, 196), Vector2(312, 430), Vector2(360, 212), Vector2(312, 120)]:
		var board := TitleBoard.new()
		board.setup(size)
		add_node(board)
		board.bake()
		await frames(8)
		check(board.is_baked(), "baked at %s" % size)
		Looks.current["wood"] = "ebony"
		board.setup(size)
		board.bake()
		Looks.current["wood"] = "oak"
		await frames(3)
	var gone := TitleBoard.new()
	gone.setup(Vector2(312, 196))
	tree.root.add_child(gone)
	gone.bake()
	await frames(2)
	gone.free()
	await frames(4)
	check(true, "no errors")
