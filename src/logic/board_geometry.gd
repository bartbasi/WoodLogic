# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BoardGeometry
extends RefCounted
## Everything the rules need from the planks' shapes, worked out once per board (it does not
## depend on colors). Read-only once built, so a level can carry it from a worker thread to
## the main thread.
##
## A plank only ever has a few poses: as authored (fixed, or hanging from the start on its
## one screw), and for a plank with two or more holes, hanging at rest on each of its holes
## (GDD R16). So a plank's pose is a pure function of which of its screws are still on the
## board, and covering (R7) is worked out here for every pose: a bit mask of the screws each
## pose covers. Screw ids fit in one int's bits (at most 60, and the GDD caps levels at 36).

## Screw head radius (GDD 1.1): a screw is covered when a plank in front is closer than this.
const HEAD := 3.5
## R16: a plank whose centroid is closer than this to its pivot does not turn.
const NO_TURN := 0.5
## Distances are kept for screws this close to a pose's bounds (B10 needs 5.5, B11 3.75).
const NEAR := 6.0
const MAX_SCREWS := 60

var screw_count: int
var plank_count: int
var screw_x: PackedFloat64Array
var screw_y: PackedFloat64Array
var screw_plank: PackedInt32Array
var screw_layer: PackedInt32Array
var plank_first: PackedInt32Array
var plank_holes: PackedInt32Array
var plank_layer: PackedInt32Array
var plank_mask: PackedInt64Array
## Plank ids from front to back: by layer, then by id (ARCHITECTURE 4.2, cover_plank).
var front_to_back: PackedInt32Array

## Per plank: the screws its authored pose covers.
var cover_fixed: PackedInt64Array
## Per screw: the screws its plank covers while hanging on it alone. For a one hole plank, and
## for a plank that does not turn (R16), this is the authored pose.
var cover_hang: PackedInt64Array
## Per screw: whether its plank turns when it hangs on it, by how much (the rotation's cosine
## and sine, and the angle in degrees for the view, in (-180, 180]), and the distance from it
## to the plank's centroid.
var hang_turns: PackedByteArray
var hang_cos: PackedFloat64Array
var hang_sin: PackedFloat64Array
var hang_angle: PackedFloat64Array
var hang_r: PackedFloat64Array
## Per screw: its plank's outline (and a ring's hole) while hanging on it.
var hang_outline: Array[PackedFloat64Array] = []
var hang_inner: Array[PackedFloat64Array] = []
## Signed distances from screws behind a pose to that pose, for every screw near it (the
## blueprint validator's margins). Per plank for the authored pose, per screw for hanging.
var fixed_near_screws: Array[PackedInt32Array] = []
var fixed_near_d: Array[PackedFloat64Array] = []
var hang_near_screws: Array[PackedInt32Array] = []
var hang_near_d: Array[PackedFloat64Array] = []

var _planks: Array[PlankData] = []


static func build(planks: Array[PlankData]) -> BoardGeometry:
	var g := BoardGeometry.new()
	g._build(planks)
	return g


func plank(index: int) -> PlankData:
	return _planks[index]


## The screws covered when the screws in on_board are on the board (R7). Only screws on the
## board are in the answer.
func covered(on_board: int) -> int:
	var cover := 0
	for p: int in plank_count:
		cover |= pose_cover(p, on_board & plank_mask[p])
	return cover & on_board


## The screws plank p covers when its screws still on the board are on_plank.
func pose_cover(p: int, on_plank: int) -> int:
	if on_plank == 0:
		return 0
	if on_plank & (on_plank - 1) == 0:
		return cover_hang[bit_screw(p, on_plank)]
	return cover_fixed[p]


## The screw of plank p whose bit is the single bit in mask.
func bit_screw(p: int, mask: int) -> int:
	for s: int in range(plank_first[p], plank_first[p] + plank_holes[p]):
		if mask == 1 << s:
			return s
	return -1


func _build(planks: Array[PlankData]) -> void:
	_planks = planks
	plank_count = planks.size()
	plank_first.resize(plank_count)
	plank_holes.resize(plank_count)
	plank_layer.resize(plank_count)
	plank_mask.resize(plank_count)
	cover_fixed.resize(plank_count)
	var next := 0
	for p: int in plank_count:
		var pl := planks[p]
		plank_first[p] = next
		plank_holes[p] = pl.hole_count()
		plank_layer[p] = pl.layer
		var mask := 0
		for h: int in pl.hole_count():
			if next < MAX_SCREWS:
				mask |= 1 << next
			screw_x.append(pl.hole_xy[2 * h])
			screw_y.append(pl.hole_xy[2 * h + 1])
			screw_plank.append(p)
			screw_layer.append(pl.layer)
			next += 1
		plank_mask[p] = mask
	screw_count = next
	if screw_count > MAX_SCREWS:
		push_error("a board has %d screws; the logic handles at most %d" % [screw_count, MAX_SCREWS])
	# Front to back: by layer, then by plank id.
	for layer: int in 5:
		for p: int in plank_count:
			if plank_layer[p] == layer:
				front_to_back.append(p)
	for p: int in plank_count:
		if plank_layer[p] < 0 or plank_layer[p] > 4:
			front_to_back.append(p)
	# Authored poses.
	for p: int in plank_count:
		var near := _near(p, planks[p].outline_xy, planks[p].inner_xy)
		fixed_near_screws.append(near[0])
		fixed_near_d.append(near[1])
		cover_fixed[p] = near[2]
	# Hanging poses.
	hang_turns.resize(screw_count)
	hang_cos.resize(screw_count)
	hang_sin.resize(screw_count)
	hang_angle.resize(screw_count)
	hang_r.resize(screw_count)
	cover_hang.resize(screw_count)
	for s: int in screw_count:
		var p := screw_plank[s]
		var pl := planks[p]
		var vx := pl.centroid_x - screw_x[s]
		var vy := pl.centroid_y - screw_y[s]
		var r := sqrt(vx * vx + vy * vy)
		hang_r[s] = r
		hang_cos[s] = 1.0
		hang_sin[s] = 0.0
		hang_angle[s] = 0.0
		hang_turns[s] = 0
		if plank_holes[p] < 2 or r < NO_TURN:
			hang_outline.append(pl.outline_xy)
			hang_inner.append(pl.inner_xy)
			hang_near_screws.append(fixed_near_screws[p])
			hang_near_d.append(fixed_near_d[p])
			cover_hang[s] = cover_fixed[p]
			continue
		# The rotation that takes the pivot to centroid direction u to straight down (0, 1):
		# its cosine is u.y and its sine is u.x, taken as ratios (no trig in the rules).
		var c := vy / r
		var sn := vx / r
		hang_turns[s] = 1
		hang_cos[s] = c
		hang_sin[s] = sn
		var degrees := rad_to_deg(atan2(sn, c))
		if degrees <= -180.0:
			degrees += 360.0
		hang_angle[s] = degrees
		var outer := Geom.rotate(pl.outline_xy, screw_x[s], screw_y[s], c, sn)
		var inner := Geom.rotate(pl.inner_xy, screw_x[s], screw_y[s], c, sn)
		hang_outline.append(outer)
		hang_inner.append(inner)
		var near := _near(p, outer, inner)
		hang_near_screws.append(near[0])
		hang_near_d.append(near[1])
		cover_hang[s] = near[2]


## For plank p in a pose with this outline: the screws behind it that are near, their signed
## distances, and the mask of those it covers.
func _near(p: int, outer: PackedFloat64Array, inner: PackedFloat64Array) -> Array:
	var screws := PackedInt32Array()
	var dists := PackedFloat64Array()
	var mask := 0
	var box := Geom.bounds(outer)
	var layer := plank_layer[p]
	for s: int in screw_count:
		if screw_layer[s] <= layer:
			continue
		var x := screw_x[s]
		var y := screw_y[s]
		if x < box[0] - NEAR or x > box[2] + NEAR or y < box[1] - NEAR or y > box[3] + NEAR:
			continue
		var d := Geom.region_distance(x, y, outer, inner)
		screws.append(s)
		dists.append(d)
		if d < HEAD and s < MAX_SCREWS:
			mask |= 1 << s
	return [screws, dists, mask]
