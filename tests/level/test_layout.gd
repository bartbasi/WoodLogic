# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The level screen's layout against the worked examples in docs/UX.md 3.2.1 and 3.2.1a.


func _layout(width: float, height: float, dpu: float, top: float = 24.0, bottom: float = 16.0) -> LevelLayout:
	return LevelLayout.compute(Rect2(0.0, top, width, height - top - bottom), dpu)


func test_base_phone_is_the_reference_layout() -> void:
	var l := _layout(360.0, 640.0, 1.0)
	check(not l.split, "base phone is stacked")
	check_between(l.b, 1.0, 1.0, "board scale on the base phone")
	check_between(l.f, 1.0, 1.0, "furniture scale on the base phone")
	check_eq(l.top_bar.size.y, 44.0, "top bar height")
	check_eq(l.boxes_bar.size.y, 64.0, "boxes row height")
	check_eq(l.tray_bar.size.y, 52.0, "tray height")
	check_eq(l.panel.size.y, 360.0, "board panel height")
	check_eq(l.helper_bar.size.y, 56.0, "helper bar height")
	check_eq(l.helper_bar.end.y, 640.0 - 16.0, "the helper bar ends at the bottom inset")
	# UX 3.2.2: open boxes at x 12 and 112, previews at 216 and 286, in a 360 wide row.
	check_between(l.open_pos[0].x, 12.0, 12.0, "first open box x")
	check_between(l.open_pos[1].x, 112.0, 112.0, "second open box x")
	check_between(l.preview_pos[0].x, 216.0, 216.0, "first preview x")
	check_between(l.preview_pos[1].x, 286.0, 286.0, "second preview x")
	# The core is 344 wide, centered in the 344 wide panel at x 8 .. 352.
	check_between(l.core_origin.x, 8.0, 8.0, "core x")


func test_tall_phone_keeps_b_and_grows_the_bars() -> void:
	var l := _layout(360.0, 800.0, 1.0)
	check(not l.split, "tall phone is stacked")
	check_between(l.b, 1.0, 1.0, "board scale on a tall phone")
	check_between(l.f, 1.167, 1.167, "furniture scale on a tall phone")
	check_between(l.panel.size.y, 479.5, 480.5, "board panel height on a tall phone")
	# The core sits centered in the taller panel: 60 units of back board above and below.
	check_between(l.core_origin.y - l.panel.position.y, 59.5, 60.5, "back board above the core")


func test_tablet_scales_the_board_up() -> void:
	var l := _layout(400.0, 640.0, 2.14, 12.0, 8.0)
	check(not l.split, "10 inch tablet is stacked")
	check_between(l.b, 1.1, 1.13, "board scale on a 400 x 640 tablet")
	check_between(l.f, 0.88, 0.94, "furniture scale on a 400 x 640 tablet")
	var wide := _layout(480.0, 640.0, 1.6, 12.0, 8.0)
	check_between(wide.b, 1.25, 1.27, "board scale on a 480 x 640 tablet")
	check_between(wide.f, 0.7, 0.7, "furniture scale on a 480 x 640 tablet")


func test_unfolded_foldable_uses_the_split_arrangement() -> void:
	var l := _layout(840.0, 720.0, 1.25)
	check(l.split, "an unfolded foldable is split")
	check_between(l.b, 1.53, 1.55, "board scale on the foldable")
	check_between(l.f, 0.8, 0.8, "furniture scale on the foldable")
	check(l.rail.position.x >= l.panel.end.x, "the rail is to the right of the board panel")
	# Every group of the rail sits inside the rail, top to bottom.
	check(l.boxes_bar.end.y <= l.tray_bar.position.y, "boxes above the tray")
	check(l.tray_bar.end.y <= l.helper_bar.position.y, "tray above the helper bar")
	check(l.helper_bar.end.y <= l.rail.end.y + 0.01, "helper bar at the bottom of the rail")


func test_the_board_scale_stays_between_one_and_two() -> void:
	for size: Vector2 in [Vector2(360, 640), Vector2(360, 900), Vector2(500, 640), Vector2(1200, 900), Vector2(2000, 800)]:
		var l := _layout(size.x, size.y, 1.0)
		check(l.b >= 1.0 and l.b <= 2.0, "board scale %.2f at %s" % [l.b, str(size)])
		check(l.f >= 0.7 and l.f <= 1.167 + 0.001, "furniture scale %.2f at %s" % [l.f, str(size)])


func test_touch_targets_scale_with_the_board() -> void:
	# A free screw's target is 24 design units at b = 1; in grid units it is 6 at any scale.
	for width: float in [360.0, 500.0]:
		var l := _layout(width, 640.0, 1.0)
		var center := Vector2(40.0, 40.0)
		var edge := center + Vector2(LevelHit.RADIUS_GU, 0.0)
		var px := l.gu_to_scene(edge).distance_to(l.gu_to_scene(center))
		check_between(px, 24.0 * l.b, 24.0 * l.b, "target radius in units at b %.2f" % l.b)
