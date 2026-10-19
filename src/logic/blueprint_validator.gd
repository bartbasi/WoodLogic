# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BlueprintValidator
extends RefCounted
## The blueprint rules B1 to B13 (GDD 9.2; B13 is the margin around R16's cutoff,
## docs/ARCHITECTURE.md section 2), as static checks that tests, tools and the generator
## share. They hold for tutorial levels too, except the 9 screw minimum. Each message starts
## with the rule it breaks. Distances are signed (negative inside the plank) and come from the
## same rounded polygons the rules use.

const MIN_SCREWS := 9
const MAX_SCREWS := 36
const MAX_PLANKS := 16
const MAX_FREE_AT_START := 24
const MAX_PLANKS_OVER := 3
## B4: screw centers inside x 6 to 80 and y 6 to 84.
const SCREW_INSET := 6
## B5: center to center, at least 12 gu (48 du).
const SPACING := 12
## B6: every hole at least 4.5 gu inside its own plank; bars and ring bands at least 10 wide.
const RIM := 4.5
const MIN_BAND := 10
## B10: a screw is plainly covered (d at most 0) or plainly free (d at least 5.5).
const PLAINLY_FREE := 5.5
## B11: in every rest pose, |d - 3.5| at least 0.25.
const SWING_MARGIN := 0.25
## B13: R16's 0.5 gu cutoff, accepted only with r below 0.25 or above 0.75.
const TURN_LOW := 0.25
const TURN_HIGH := 0.75
## B9: a one hole plank's centroid within 0.5 of straight below its hole.
const AT_REST := 0.5
const EPS := 1e-9


## Reads a blueprint or tutorial file and checks it (B1 is checked while reading).
static func check_text(text: String, min_screws: int = MIN_SCREWS) -> PackedStringArray:
	var errors := PackedStringArray()
	var level := LevelData.parse(text, errors)
	if level == null:
		return errors
	return check(level, min_screws)


## Checks B2 to B13. An empty list means it passes.
static func check(level: LevelData, min_screws: int = MIN_SCREWS) -> PackedStringArray:
	var errors := PackedStringArray()
	var g := level.geometry
	var planks := level.planks
	# B2: 1 to 16 planks; layers from 0 with no gaps, at most 5.
	if planks.size() < 1 or planks.size() > MAX_PLANKS:
		errors.append("B2: %d planks (1 to %d)" % [planks.size(), MAX_PLANKS])
	var used := PackedInt32Array([0, 0, 0, 0, 0])
	for p: PlankData in planks:
		used[p.layer] = 1
	var deepest := used.rfind(1)
	for layer: int in deepest:
		if used[layer] == 0:
			errors.append("B2: layer %d has no planks but layer %d does" % [layer, deepest])
	# B3: every plank has a hole; the total is a multiple of the box size, 9 to 36.
	for i: int in planks.size():
		if planks[i].hole_count() == 0:
			errors.append("B3: plank %d has no holes" % i)
	var n := g.screw_count
	if n % Tuning.box_slots != 0 or n < min_screws or n > MAX_SCREWS:
		errors.append("B3: %d screws (a multiple of %d from %d to %d)" % [n, Tuning.box_slots, min_screws, MAX_SCREWS])
	# B4: inside the screw area.
	for s: int in n:
		var x := g.screw_x[s]
		var y := g.screw_y[s]
		if x < SCREW_INSET or x > LevelData.BOARD_W - SCREW_INSET or y < SCREW_INSET or y > LevelData.BOARD_H - SCREW_INSET:
			errors.append("B4: %s at (%d, %d) is outside x 6 to 80, y 6 to 84" % [_name(g, s), x, y])
	# B5: spacing.
	for a: int in n:
		for b: int in range(a + 1, n):
			var dx := g.screw_x[a] - g.screw_x[b]
			var dy := g.screw_y[a] - g.screw_y[b]
			if dx * dx + dy * dy < SPACING * SPACING:
				errors.append("B5: %s and %s are %.2f gu apart (at least %d)" % [_name(g, a), _name(g, b), sqrt(dx * dx + dy * dy), SPACING])
	# B6: rims and widths. Also: outlines must not cross themselves.
	for i: int in planks.size():
		var p := planks[i]
		if p.shape == PlankData.BAR and p.width < MIN_BAND:
			errors.append("B6: plank %d is a bar %d wide (at least %d)" % [i, p.width, MIN_BAND])
		if p.shape == PlankData.RING and p.radius - p.inner < MIN_BAND:
			errors.append("B6: plank %d is a ring with a band %d wide (at least %d)" % [i, p.radius - p.inner, MIN_BAND])
		for h: int in p.hole_count():
			var d := Geom.region_distance(p.hole_xy[2 * h], p.hole_xy[2 * h + 1], p.outline_xy, p.inner_xy)
			if d > -RIM + EPS:
				errors.append("B6: %s is %.2f gu inside its plank (at least %.1f)" % [_name(g, p.screws[h]), -d, RIM])
		var bends := p.shape == PlankData.POLY or (p.shape == PlankData.BAR and p.path.size() > 2)
		if bends and not Geom.is_simple(p.outline_xy):
			errors.append("plank %d: its outline crosses itself" % i)
		if Geom.area(p.outline_xy, p.inner_xy) <= EPS:
			errors.append("plank %d: its outline has no area" % i)
	# B7: inside the core as authored.
	for i: int in planks.size():
		var box := Geom.bounds(planks[i].outline_xy)
		if box[0] < 0.0 or box[1] < 0.0 or box[2] > LevelData.BOARD_W or box[3] > LevelData.BOARD_H:
			errors.append("B7: plank %d reaches outside the board (%.2f, %.2f to %.2f, %.2f)" % [i, box[0], box[1], box[2], box[3]])
	# B8: planks in one layer do not overlap.
	for a: int in planks.size():
		for b: int in range(a + 1, planks.size()):
			if planks[a].layer == planks[b].layer and _overlap(planks[a], planks[b]):
				errors.append("B8: planks %d and %d overlap in layer %d" % [a, b, planks[a].layer])
	# B9: a one hole plank hangs at rest.
	for i: int in planks.size():
		var p := planks[i]
		if p.hole_count() == 1:
			var hx := p.hole_xy[0]
			var hy := p.hole_xy[1]
			if absf(p.centroid_x - hx) > AT_REST + EPS or p.centroid_y < hy - AT_REST - EPS:
				errors.append("B9: plank %d hangs on one hole but its centroid (%.2f, %.2f) is not below it" % [i, p.centroid_x, p.centroid_y])
	# B10: plain covering at the start. B12: free screws and planks over a screw.
	var over := PackedInt32Array()
	over.resize(n)
	for p: int in g.plank_count:
		var near_screws := g.fixed_near_screws[p]
		var near_d := g.fixed_near_d[p]
		for i: int in near_screws.size():
			var d := near_d[i]
			if d > 0.0 and d < PLAINLY_FREE:
				errors.append("B10: %s is %.2f gu from plank %d (at most 0 or at least %.1f)" % [_name(g, near_screws[i]), d, p, PLAINLY_FREE])
			if d < BoardGeometry.HEAD:
				over[near_screws[i]] += 1
	var free_count := 0
	for s: int in n:
		if over[s] == 0:
			free_count += 1
		if over[s] > MAX_PLANKS_OVER:
			errors.append("B12: %s is under %d planks (at most %d)" % [_name(g, s), over[s], MAX_PLANKS_OVER])
	if free_count > MAX_FREE_AT_START:
		errors.append("B12: %d screws are free at the start (at most %d)" % [free_count, MAX_FREE_AT_START])
	# B13 for every plank and pivot (a one hole plank too: it is shown as authored, so its r
	# must be clear of the cutoff as well). B11 for every rest pose of a plank with two or more
	# holes.
	for s: int in n:
		var p := g.screw_plank[s]
		var r := g.hang_r[s]
		if r >= TURN_LOW and r <= TURN_HIGH:
			errors.append("B13: plank %d hanging on %s has its centroid %.3f gu from the pivot (below %.2f or above %.2f)" % [p, _name(g, s), r, TURN_LOW, TURN_HIGH])
		if g.plank_holes[p] < 2:
			continue
		var near_screws := g.hang_near_screws[s]
		var near_d := g.hang_near_d[s]
		for i: int in near_screws.size():
			if absf(near_d[i] - BoardGeometry.HEAD) < SWING_MARGIN:
				errors.append("B11: plank %d hanging on %s is %.2f gu from %s (|d - 3.5| at least %.2f)" % [p, _name(g, s), near_d[i], _name(g, near_screws[i]), SWING_MARGIN])
	return errors


## Two planks overlap if their outlines cross, or a vertex or a hole of one lies inside the
## other. (Holes sit inside their own plank, so a plank wholly inside another is caught.)
static func _overlap(a: PlankData, b: PlankData) -> bool:
	var ba := Geom.bounds(a.outline_xy)
	var bb := Geom.bounds(b.outline_xy)
	if ba[2] < bb[0] or bb[2] < ba[0] or ba[3] < bb[1] or bb[3] < ba[1]:
		return false
	for loop_a: PackedFloat64Array in [a.outline_xy, a.inner_xy]:
		for loop_b: PackedFloat64Array in [b.outline_xy, b.inner_xy]:
			if not loop_a.is_empty() and not loop_b.is_empty() and Geom.edges_cross(loop_a, loop_b):
				return true
	return _inside_any(a.outline_xy, b) or _inside_any(a.hole_xy, b) or _inside_any(b.outline_xy, a) or _inside_any(b.hole_xy, a)


static func _inside_any(points: PackedFloat64Array, plank: PlankData) -> bool:
	for i: int in points.size() >> 1:
		if Geom.region_distance(points[2 * i], points[2 * i + 1], plank.outline_xy, plank.inner_xy) < -EPS:
			return true
	return false


static func _name(g: BoardGeometry, screw: int) -> String:
	var p := g.screw_plank[screw]
	return "screw %d (plank %d hole %d)" % [screw, p, screw - g.plank_first[p]]
