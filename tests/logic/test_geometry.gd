# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Outlines, distances, centroids and rest poses (GDD 1.2, R7, R16; ARCHITECTURE section 2).

const Kit := preload("res://tests/logic/kit.gd")


func test_precision_snap_rounds_to_1024ths_symmetrically() -> void:
	check_eq(Geom.snap(0.3), roundf(0.3 * 1024.0) / 1024.0, "snap(0.3)")
	check_eq(Geom.snap(-0.3), -Geom.snap(0.3), "snap(-0.3)")
	check_eq(Geom.snap(17.0), 17.0, "snap of a whole number")
	check_eq(Geom.snap(1.0 / 2048.0), 1.0 / 1024.0, "a half step rounds away from zero")


func test_precision_unit_circle_is_unit_and_exactly_symmetric() -> void:
	for sides: int in [16, 32, 64, 128]:
		var u := Geom.unit_circle(sides)
		var worst := 0.0
		for k: int in sides:
			worst = maxf(worst, absf(sqrt(u[2 * k] * u[2 * k] + u[2 * k + 1] * u[2 * k + 1]) - 1.0))
			var m := (sides - k) % sides
			check(u[2 * m] == u[2 * k] and u[2 * m + 1] == -u[2 * k + 1], "%d sides: direction %d mirrors %d" % [sides, k, m])
		check(worst < 1e-15, "%d sides: unit length within 1e-15 (off by %s)" % [sides, str(worst)])
		check_eq(u[2 * (sides >> 2) + 1], 1.0, "%d sides: a quarter turn is straight down" % sides)


func test_precision_every_outline_vertex_is_on_the_1024_grid() -> void:
	for id: String in Kit.BLUEPRINTS:
		var level := Kit.blueprint(id)
		var g := level.geometry
		var lists: Array[PackedFloat64Array] = []
		for p: PlankData in level.planks:
			lists.append(p.outline_xy)
			lists.append(p.inner_xy)
		lists.append_array(g.hang_outline)
		lists.append_array(g.hang_inner)
		var off := 0
		for list: PackedFloat64Array in lists:
			for v: float in list:
				if v * 1024.0 != roundf(v * 1024.0):
					off += 1
		check_eq(off, 0, "%s: vertices off the grid" % id)


func test_gdd_1_2_flattened_circles_stay_within_0_05() -> void:
	for r: int in range(1, 46):
		var poly := Geom.circle(43.0, 45.0, float(r))
		var n := (poly.size() >> 1)
		var worst := 0.0
		for i: int in n:
			var j := (i + 1) % n
			for t: float in [0.0, 0.5]:
				var x := poly[2 * i] + t * (poly[2 * j] - poly[2 * i]) - 43.0
				var y := poly[2 * i + 1] + t * (poly[2 * j + 1] - poly[2 * i + 1]) - 45.0
				worst = maxf(worst, absf(sqrt(x * x + y * y) - r))
		check(worst < 0.05, "radius %d: outline off by %.4f (under 0.05)" % [r, worst])


func test_gdd_1_2_straight_bar_has_round_ends() -> void:
	var poly := Geom.bar(PackedFloat64Array([10.0, 20.0, 40.0, 20.0]), 10.0)
	check(Geom.is_simple(poly), "the outline does not cross itself")
	var worst := 0.0
	for i: int in (poly.size() >> 1):
		var x := poly[2 * i]
		var y := poly[2 * i + 1]
		var cx := clampf(x, 10.0, 40.0)
		worst = maxf(worst, absf(sqrt((x - cx) * (x - cx) + (y - 20.0) * (y - 20.0)) - 5.0))
	check(worst < 0.002, "every vertex is 5 from the path (off by %.4f)" % worst)
	check_between(Geom.polygon_distance(25.0, 20.0, poly), -5.001, -4.999, "distance on the path")
	check_between(Geom.polygon_distance(25.0, 30.0, poly), 4.999, 5.001, "distance 10 from the path")
	check_between(Geom.polygon_distance(48.0, 20.0, poly), 2.95, 3.001, "distance past the round end")
	var c := Geom.centroid(poly, PackedFloat64Array())
	check_between(c[0], 24.999, 25.001, "centroid x")
	check_between(c[1], 19.999, 20.001, "centroid y")


func test_gdd_1_2_l_bar_has_a_sharp_inner_corner_and_a_round_outer_one() -> void:
	var poly := Geom.bar(PackedFloat64Array([10.0, 10.0, 40.0, 10.0, 40.0, 40.0]), 10.0)
	check(Geom.is_simple(poly), "the outline does not cross itself")
	var found_inner := false
	for i: int in (poly.size() >> 1):
		if poly[2 * i] == 35.0 and poly[2 * i + 1] == 15.0:
			found_inner = true
	check(found_inner, "the inner corner is the vertex (35, 15)")
	check_between(Geom.polygon_distance(45.0, 5.0, poly), sqrt(50.0) - 5.0 - 0.01, sqrt(50.0) - 5.0 + 0.01, "the outer corner is round")
	check_between(Geom.polygon_distance(34.0, 16.0, poly), 0.999, 1.001, "just outside the inner corner")


func test_gdd_1_2_every_shipped_outline_is_simple() -> void:
	for id: String in Kit.BLUEPRINTS:
		var level := Kit.blueprint(id)
		for i: int in level.planks.size():
			check(Geom.is_simple(level.planks[i].outline_xy), "%s plank %d outline is simple" % [id, i])


func test_r7_signed_distance_is_negative_inside() -> void:
	var square := PackedFloat64Array([0.0, 0.0, 10.0, 0.0, 10.0, 10.0, 0.0, 10.0])
	check_eq(Geom.polygon_distance(5.0, 5.0, square), -5.0, "the middle of a square")
	check_eq(Geom.polygon_distance(2.0, 5.0, square), -2.0, "near the left edge")
	check_eq(Geom.polygon_distance(13.0, 14.0, square), 5.0, "outside a corner")
	var reversed := PackedFloat64Array([0.0, 10.0, 10.0, 10.0, 10.0, 0.0, 0.0, 0.0])
	check_eq(Geom.polygon_distance(2.0, 5.0, reversed), -2.0, "either winding")


func test_r7_a_rings_hole_is_not_part_of_the_plank() -> void:
	var outer := Geom.circle(29.0, 31.0, 17.0)
	var inner := Geom.circle(29.0, 31.0, 6.0)
	var d := Geom.region_distance(29.0, 31.0, outer, inner)
	check_between(d, 5.95, 6.0, "the ring's center is 6 outside the plank (less the flattening)")
	check_between(Geom.region_distance(29.0 + 11.5, 31.0, outer, inner), -5.5, -5.45, "the middle of the band")
	check_between(Geom.region_distance(29.0 + 20.0, 31.0, outer, inner), 3.0, 3.01, "outside the ring")
	var c := Geom.centroid(outer, inner)
	check_between(c[0], 28.999, 29.001, "ring centroid x")
	check_between(c[1], 30.999, 31.001, "ring centroid y")


func test_e2_r16_house_chimney_turns_180_or_0() -> void:
	var level := Kit.blueprint("house")
	var g := level.geometry
	var top := Kit.screw_at(level, 68, 8)
	var bottom := Kit.screw_at(level, 68, 20)
	var chimney := level.screw_plank(top)
	var p := level.planks[chimney]
	check_between(p.centroid_x, 67.999, 68.001, "chimney centroid x")
	check_between(p.centroid_y, 12.999, 13.001, "chimney centroid y")
	# Take (68, 8): it hangs on (68, 20) and turns half way round.
	check_eq(g.hang_angle[bottom], 180.0, "angle hanging on (68, 20)")
	var box := Geom.bounds(g.hang_outline[bottom])
	check_between(box[1], 14.99, 15.01, "turned bar top (path (68, 20) to (68, 34), width 10)")
	check_between(box[3], 38.99, 39.01, "turned bar bottom")
	# Take (68, 20) first: it hangs on (68, 8), already at rest.
	check(absf(g.hang_angle[top]) < 1e-6, "angle hanging on (68, 8) is 0 (got %s)" % str(g.hang_angle[top]))


func test_e3_r16_windmill_gallery_turns_90() -> void:
	var level := Kit.blueprint("windmill")
	var g := level.geometry
	var left := Kit.screw_at(level, 30, 62)
	check_between(g.hang_angle[left], 89.999, 90.001, "gallery angle hanging on (30, 62)")
	var box := Geom.bounds(g.hang_outline[left])
	# Path (30, 60) to (30, 90), width 10.
	check_between(box[0], 24.99, 25.01, "turned gallery left")
	check_between(box[2], 34.99, 35.01, "turned gallery right")
	check_between(box[1], 54.99, 55.01, "turned gallery top")
	check_between(box[3], 94.99, 95.01, "turned gallery bottom")
	var tower := Kit.screw_at(level, 29, 84)
	var gallery := level.screw_plank(left)
	var before := Geom.region_distance(29.0, 84.0, level.planks[gallery].outline_xy, PackedFloat64Array())
	var after := Geom.region_distance(29.0, 84.0, g.hang_outline[left], PackedFloat64Array())
	check_between(before, 16.99, 17.01, "tower screw distance before (d = 17)")
	check_between(after, -4.01, -3.99, "tower screw distance after (d = -4)")
	check(g.cover_hang[left] & (1 << tower) != 0, "the turned gallery covers the tower screw")
	check(g.cover_fixed[gallery] & (1 << tower) == 0, "the gallery as authored does not")


func test_r16_disc_held_at_its_center_does_not_turn() -> void:
	var level := Kit.blueprint("windmill")
	var hub := Kit.screw_at(level, 43, 30)
	check_eq(level.geometry.hang_turns[hub], 0, "the hub disc does not turn")
	check_eq(level.geometry.hang_angle[hub], 0.0, "its angle")
	var t := Kit.level([
		{"layer": 0, "shape": "disc", "center": [43, 45], "radius": 14, "holes": [[43, 45], [43, 33], [55, 45]], "colors": [0, 0, 0]},
	], [0])
	var center := Kit.screw_at(t, 43, 45)
	check_eq(t.geometry.hang_turns[center], 0, "a three hole disc hanging on its center does not turn")
	var top := Kit.screw_at(t, 43, 33)
	check_between(t.geometry.hang_angle[top], -0.001, 0.001, "hanging on its top hole it is already at rest")
	var right := Kit.screw_at(t, 55, 45)
	check_between(t.geometry.hang_angle[right], -90.001, -89.999, "hanging on its right hole it turns -90")


func test_r16_every_rest_pose_puts_the_centroid_straight_below() -> void:
	for id: String in Kit.BLUEPRINTS:
		var level := Kit.blueprint(id)
		var g := level.geometry
		for s: int in g.screw_count:
			if g.hang_turns[s] == 0:
				continue
			var c := Geom.centroid(g.hang_outline[s], g.hang_inner[s])
			var dx := c[0] - g.screw_x[s]
			var dy := c[1] - g.screw_y[s]
			check(absf(dx) < 0.01 and dy > 0.0, "%s screw %d: centroid (%.3f, %.3f) below the pivot" % [id, s, dx, dy])
			check_between(sqrt(dx * dx + dy * dy), g.hang_r[s] - 0.01, g.hang_r[s] + 0.01, "%s screw %d: the turn keeps r" % [id, s])
			check(g.hang_angle[s] > -180.0 and g.hang_angle[s] <= 180.0, "%s screw %d: angle in (-180, 180]" % [id, s])


func test_r16_angle_is_positive_clockwise_on_screen() -> void:
	# A bar sticking out to the left of its pivot turns -90 (counterclockwise on screen).
	var t := Kit.level([
		Kit.bar(0, [[20, 40], [60, 40]], 10, [[22, 40], [58, 40]], [0, 0]),
		Kit.disc(0, [43, 70], 5, [0]),
	], [0])
	var right := Kit.screw_at(t, 58, 40)
	check_between(t.geometry.hang_angle[right], -90.001, -89.999, "hanging on its right end")
	var left := Kit.screw_at(t, 22, 40)
	check_between(t.geometry.hang_angle[left], 89.999, 90.001, "hanging on its left end")
