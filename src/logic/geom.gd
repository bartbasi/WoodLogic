# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Geom
extends RefCounted
## Geometry for the rules, in grid units (gu). Points are pairs of 64 bit floats and polygons
## are flat arrays [x0, y0, x1, y1, ...]. (Vector2 is 32 bit, so it only appears at the API
## edge for the view.) Every vertex is rounded to 1/1024 gu as soon as it is made. After that
## only + - * / and sqrt are used, which IEEE 754 makes exact to the last bit, so every phone
## gets the same answer (docs/ARCHITECTURE.md section 2).
##
## Arcs are flattened into polygons with an outline error under 0.05 gu (GDD 1.2). The unit
## vectors they use come from halving angles with sqrt, never from sin or cos.

const SNAP := 1024.0
## A bend in a bar's path whose cross product is smaller than this counts as straight.
const STRAIGHT := 1e-9
## Arc directions this close to an arc's end (as a cross product) are skipped, so an arc
## never puts two vertices almost on top of each other.
const ARC_END := 1e-3


## Rounds to the 1/1024 gu grid. Multiplying by a power of two is exact, and roundf rounds
## halves away from zero, so the grid is the same on both sides of zero.
static func snap(value: float) -> float:
	return roundf(value * SNAP) / SNAP


## How many sides a flattened circle of this radius gets. An inscribed n-gon is off by
## r * (1 - cos(180 / n degrees)); these limits keep that under 0.045 gu, which leaves room
## for the rounding.
static func circle_sides(radius: float) -> int:
	if radius <= 2.25:
		return 16
	if radius <= 9.25:
		return 32
	if radius <= 37.25:
		return 64
	return 128


## Unit vectors at k * 360 / count degrees for k = 0 .. count - 1, turning clockwise on screen
## (from +x toward +y). count is 4 times a power of two. The first quarter is made by halving
## angles (the normalized sum of two neighbors) and the rest by swapping and negating, so the
## table is exactly symmetric.
static func unit_circle(count: int) -> PackedFloat64Array:
	var quarter := count >> 2
	var qx := PackedFloat64Array()
	var qy := PackedFloat64Array()
	qx.resize(quarter + 1)
	qy.resize(quarter + 1)
	qx[0] = 1.0
	qy[0] = 0.0
	qx[quarter] = 0.0
	qy[quarter] = 1.0
	var step := quarter >> 1
	while step >= 1:
		var i := step
		while i < quarter:
			var x := qx[i - step] + qx[i + step]
			var y := qy[i - step] + qy[i + step]
			var length := sqrt(x * x + y * y)
			qx[i] = x / length
			qy[i] = y / length
			i += step * 2
		step >>= 1
	var out := PackedFloat64Array()
	out.resize(count * 2)
	for k: int in count:
		@warning_ignore("integer_division")
		var turn := k / quarter
		var i := k - turn * quarter
		var x := qx[i]
		var y := qy[i]
		match turn:
			0:
				out[2 * k] = x
				out[2 * k + 1] = y
			1:
				out[2 * k] = -y
				out[2 * k + 1] = x
			2:
				out[2 * k] = -x
				out[2 * k + 1] = -y
			_:
				out[2 * k] = y
				out[2 * k + 1] = -x
	return out


## A circle as a polygon: the vertices are the center plus the rounded offsets, so a circle
## with a whole number center is exactly symmetric about it.
static func circle(cx: float, cy: float, radius: float) -> PackedFloat64Array:
	var sides := circle_sides(radius)
	var unit := unit_circle(sides)
	var out := PackedFloat64Array()
	out.resize(sides * 2)
	for k: int in sides:
		out[2 * k] = cx + snap(radius * unit[2 * k])
		out[2 * k + 1] = cy + snap(radius * unit[2 * k + 1])
	return out


## A bar's outline: every point within width / 2 of the path, so a bar has round ends and
## round outer corners, and its inner corners are where the two straight edges meet. Empty if
## the path has a segment of zero length. (A path that turns too sharply for its width makes a
## polygon that crosses itself; the blueprint validator rejects that.)
static func bar(path: PackedFloat64Array, width: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var half := width * 0.5
	var points := path.size() >> 1
	var segments := points - 1
	if segments < 1:
		return out
	var dx := PackedFloat64Array()
	var dy := PackedFloat64Array()
	dx.resize(segments)
	dy.resize(segments)
	for i: int in segments:
		var ax := path[2 * i + 2] - path[2 * i]
		var ay := path[2 * i + 3] - path[2 * i + 1]
		var length := sqrt(ax * ax + ay * ay)
		if length == 0.0:
			return PackedFloat64Array()
		dx[i] = ax / length
		dy[i] = ay / length
	var unit := unit_circle(circle_sides(half))
	# Side A has the normal (-dy, dx): the right of the path as seen on screen.
	_add(out, path[0] - half * dy[0], path[1] + half * dx[0])
	for i: int in range(1, segments):
		var px := path[2 * i]
		var py := path[2 * i + 1]
		var turn := dx[i - 1] * dy[i] - dy[i - 1] * dx[i]
		var ax := -dy[i - 1]
		var ay := dx[i - 1]
		var bx := -dy[i]
		var by := dx[i]
		if turn > STRAIGHT:
			_add_meet(out, px + half * ax, py + half * ay, dx[i - 1], dy[i - 1], px + half * bx, py + half * by, dx[i], dy[i])
		elif turn < -STRAIGHT:
			_add(out, px + half * ax, py + half * ay)
			_add_arc(out, unit, px, py, half, ax, ay, bx, by, ax + bx, ay + by, true)
		else:
			_add(out, px + half * bx, py + half * by)
	var last := segments - 1
	var ex := path[2 * points - 2]
	var ey := path[2 * points - 1]
	_add(out, ex - half * dy[last], ey + half * dx[last])
	_add_arc(out, unit, ex, ey, half, -dy[last], dx[last], dy[last], -dx[last], dx[last], dy[last], true)
	# Side B (the other normal), back along the path.
	for i: int in range(segments - 1, 0, -1):
		var px := path[2 * i]
		var py := path[2 * i + 1]
		var turn := dx[i - 1] * dy[i] - dy[i - 1] * dx[i]
		var ax := dy[i]
		var ay := -dx[i]
		var bx := dy[i - 1]
		var by := -dx[i - 1]
		if turn < -STRAIGHT:
			_add_meet(out, px + half * ax, py + half * ay, dx[i], dy[i], px + half * bx, py + half * by, dx[i - 1], dy[i - 1])
		elif turn > STRAIGHT:
			_add(out, px + half * ax, py + half * ay)
			_add_arc(out, unit, px, py, half, ax, ay, bx, by, ax + bx, ay + by, true)
		else:
			_add(out, px + half * bx, py + half * by)
	_add(out, path[0] + half * dy[0], path[1] - half * dx[0])
	_add_arc(out, unit, path[0], path[1], half, dy[0], -dx[0], -dy[0], dx[0], -dx[0], -dy[0], false)
	return out


static func _add(out: PackedFloat64Array, x: float, y: float) -> void:
	out.append(snap(x))
	out.append(snap(y))


## Adds where the line through (ax, ay) along (ux, uy) meets the line through (bx, by) along
## (vx, vy).
static func _add_meet(out: PackedFloat64Array, ax: float, ay: float, ux: float, uy: float, bx: float, by: float, vx: float, vy: float) -> void:
	var across := ux * vy - uy * vx
	var t := ((bx - ax) * vy - (by - ay) * vx) / across
	_add(out, ax + t * ux, ay + t * uy)


## Adds the arc around (cx, cy) from direction a to direction b, passing through direction m
## (at most half a turn): the table directions strictly between, then b if add_end. The
## caller has already added the point at a.
static func _add_arc(out: PackedFloat64Array, unit: PackedFloat64Array, cx: float, cy: float, radius: float, ax: float, ay: float, bx: float, by: float, mx: float, my: float, add_end: bool) -> void:
	var count := unit.size() >> 1
	var side_a := ax * my - ay * mx
	var side_b := mx * by - my * bx
	var first := -1
	var first_dot := -2.0
	for k: int in count:
		var ux := unit[2 * k]
		var uy := unit[2 * k + 1]
		if _in_arc(ux, uy, ax, ay, bx, by, side_a, side_b):
			var along := ax * ux + ay * uy
			if along > first_dot:
				first_dot = along
				first = k
	if first >= 0:
		var step := 1 if side_a > 0.0 else count - 1
		var k := first
		for _guard: int in count:
			var ux := unit[2 * k]
			var uy := unit[2 * k + 1]
			if not _in_arc(ux, uy, ax, ay, bx, by, side_a, side_b):
				break
			_add(out, cx + radius * ux, cy + radius * uy)
			k = (k + step) % count
	if add_end:
		_add(out, cx + radius * bx, cy + radius * by)


static func _in_arc(ux: float, uy: float, ax: float, ay: float, bx: float, by: float, side_a: float, side_b: float) -> bool:
	var from_a := ax * uy - ay * ux
	var to_b := ux * by - uy * bx
	return from_a * side_a > 0.0 and to_b * side_b > 0.0 and absf(from_a) > ARC_END and absf(to_b) > ARC_END


## Signed distance from (px, py) to a polygon's outline: negative inside, positive outside.
static func polygon_distance(px: float, py: float, poly: PackedFloat64Array) -> float:
	var n := poly.size() >> 1
	if n == 0:
		return INF
	var best := INF
	var inside := false
	var jx := poly[2 * n - 2]
	var jy := poly[2 * n - 1]
	for i: int in n:
		var ix := poly[2 * i]
		var iy := poly[2 * i + 1]
		var ex := ix - jx
		var ey := iy - jy
		var wx := px - jx
		var wy := py - jy
		var length2 := ex * ex + ey * ey
		var t := 0.0
		if length2 > 0.0:
			t = clampf((wx * ex + wy * ey) / length2, 0.0, 1.0)
		var qx := wx - t * ex
		var qy := wy - t * ey
		var d2 := qx * qx + qy * qy
		if d2 < best:
			best = d2
		if (iy > py) != (jy > py):
			if px < jx + (py - jy) * ex / ey:
				inside = not inside
		jx = ix
		jy = iy
	var d := sqrt(best)
	return -d if inside else d


## Signed distance to a plank's region: the outer polygon, less the inner one if it has one
## (a ring's hole). Inside the hole counts as outside the plank.
static func region_distance(px: float, py: float, outer: PackedFloat64Array, inner: PackedFloat64Array) -> float:
	var d := polygon_distance(px, py, outer)
	if inner.is_empty():
		return d
	return maxf(d, -polygon_distance(px, py, inner))


## Signed area and first moments [area, moment x, moment y] by the shoelace formula.
static func _moments(poly: PackedFloat64Array) -> PackedFloat64Array:
	var n := poly.size() >> 1
	var area := 0.0
	var mx := 0.0
	var my := 0.0
	for i: int in n:
		var j := (i + 1) % n
		var x1 := poly[2 * i]
		var y1 := poly[2 * i + 1]
		var x2 := poly[2 * j]
		var y2 := poly[2 * j + 1]
		var c := x1 * y2 - x2 * y1
		area += c
		mx += (x1 + x2) * c
		my += (y1 + y2) * c
	return PackedFloat64Array([area * 0.5, mx / 6.0, my / 6.0])


## Signed area of a region (outer less inner). Either winding.
static func area(outer: PackedFloat64Array, inner: PackedFloat64Array) -> float:
	var a := absf(_moments(outer)[0])
	if not inner.is_empty():
		a -= absf(_moments(inner)[0])
	return a


## The area centroid [x, y] of a region with uniform density. A ring's inner circle has the
## same winding as its outer one, so the hole is a plain subtraction.
static func centroid(outer: PackedFloat64Array, inner: PackedFloat64Array) -> PackedFloat64Array:
	var a := _moments(outer)
	var total := a[0]
	var mx := a[1]
	var my := a[2]
	if not inner.is_empty():
		var b := _moments(inner)
		var sign := 1.0 if (a[0] > 0.0) == (b[0] > 0.0) else -1.0
		total -= sign * b[0]
		mx -= sign * b[1]
		my -= sign * b[2]
	if total == 0.0:
		return PackedFloat64Array([0.0, 0.0])
	return PackedFloat64Array([mx / total, my / total])


## [min x, min y, max x, max y].
static func bounds(poly: PackedFloat64Array) -> PackedFloat64Array:
	var lo_x := INF
	var lo_y := INF
	var hi_x := -INF
	var hi_y := -INF
	for i: int in poly.size() >> 1:
		lo_x = minf(lo_x, poly[2 * i])
		hi_x = maxf(hi_x, poly[2 * i])
		lo_y = minf(lo_y, poly[2 * i + 1])
		hi_y = maxf(hi_y, poly[2 * i + 1])
	return PackedFloat64Array([lo_x, lo_y, hi_x, hi_y])


## The polygon turned about (px, py) by the rotation whose cosine and sine are c and s
## (clockwise on screen for a positive s), with every vertex rounded again.
static func rotate(poly: PackedFloat64Array, px: float, py: float, c: float, s: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(poly.size())
	for i: int in poly.size() >> 1:
		var x := poly[2 * i] - px
		var y := poly[2 * i + 1] - py
		out[2 * i] = snap(px + c * x - s * y)
		out[2 * i + 1] = snap(py + s * x + c * y)
	return out


## True if segments (a, b) and (c, d) cross at a point inside both (touching or running along
## each other does not count).
static func segments_cross(ax: float, ay: float, bx: float, by: float, cx: float, cy: float, dx: float, dy: float) -> bool:
	var d1 := (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
	var d2 := (bx - ax) * (dy - ay) - (by - ay) * (dx - ax)
	var d3 := (dx - cx) * (ay - cy) - (dy - cy) * (ax - cx)
	var d4 := (dx - cx) * (by - cy) - (dy - cy) * (bx - cx)
	return ((d1 > 0.0 and d2 < 0.0) or (d1 < 0.0 and d2 > 0.0)) and ((d3 > 0.0 and d4 < 0.0) or (d3 < 0.0 and d4 > 0.0))


## True if no two edges that are not neighbors cross.
static func is_simple(poly: PackedFloat64Array) -> bool:
	var n := poly.size() >> 1
	if n < 3:
		return false
	for i: int in n:
		var i2 := (i + 1) % n
		for j: int in range(i + 2, n):
			var j2 := (j + 1) % n
			if j2 == i:
				continue
			if segments_cross(poly[2 * i], poly[2 * i + 1], poly[2 * i2], poly[2 * i2 + 1], poly[2 * j], poly[2 * j + 1], poly[2 * j2], poly[2 * j2 + 1]):
				return false
	return true


## True if any edge of one polygon crosses an edge of the other.
static func edges_cross(a: PackedFloat64Array, b: PackedFloat64Array) -> bool:
	var na := a.size() >> 1
	var nb := b.size() >> 1
	for i: int in na:
		var i2 := (i + 1) % na
		for j: int in nb:
			var j2 := (j + 1) % nb
			if segments_cross(a[2 * i], a[2 * i + 1], a[2 * i2], a[2 * i2 + 1], b[2 * j], b[2 * j + 1], b[2 * j2], b[2 * j2 + 1]):
				return true
	return false


## The polygon as 32 bit points, for the view.
static func to_points(poly: PackedFloat64Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(poly.size() >> 1)
	for i: int in out.size():
		out[i] = Vector2(poly[2 * i], poly[2 * i + 1])
	return out
