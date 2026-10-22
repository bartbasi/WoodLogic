# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name PlankData
extends RefCounted
## One plank as authored (GDD 1.2 and 9.1): its layer (0 is the front), its shape with the
## shape's fields in gu, and its holes, one screw in each. Read-only once built, like
## LevelData: nothing outside the code that builds it writes to it.

const BAR := 0
const POLY := 1
const DISC := 2
const RING := 3
const SHAPE_NAMES: Array[String] = ["bar", "poly", "disc", "ring"]
## Every coordinate and size in a data file must lie within this range (the validator then
## applies the real limits).
const COORD_LIMIT := 1000
## The most points a path or outline may have in a data file (the shipped blueprints use up to
## 14). A plank's holes are capped at BoardGeometry.MAX_SCREWS, a level's most screws.
const MAX_POINTS := 64

var layer: int
var shape: int
## Bar: the path (2 or more points) and the width.
var path: PackedVector2Array
var width: int
## Poly: the points (3 or more, either winding).
var points: PackedVector2Array
## Disc and ring: the center and radius; ring: the inner radius.
var center: Vector2
var radius: int
var inner: int
## Hole centers in gu, in hole order, and the screw id in each.
var holes: PackedVector2Array
var screws: PackedInt32Array

## The logic's own 64 bit copies, worked out by build(). Read-only.
var hole_xy: PackedFloat64Array
var outline_xy: PackedFloat64Array
var inner_xy: PackedFloat64Array
var centroid_x: float
var centroid_y: float


## The authored outline in gu: the same polygon the logic and the renderer use, arcs
## flattened as GDD 1.2 says.
func outline() -> PackedVector2Array:
	return Geom.to_points(outline_xy)


## A ring's hole, in gu (empty for other shapes).
func inner_outline() -> PackedVector2Array:
	return Geom.to_points(inner_xy)


func hole_count() -> int:
	return holes.size()


## Works out the logic data from the fields. Called once by whoever builds the plank.
func build() -> void:
	hole_xy = _flat(holes)
	inner_xy = PackedFloat64Array()
	match shape:
		BAR:
			outline_xy = Geom.bar(_flat(path), float(width))
		POLY:
			outline_xy = _flat(points)
		DISC:
			outline_xy = Geom.circle(center.x, center.y, float(radius))
		RING:
			outline_xy = Geom.circle(center.x, center.y, float(radius))
			inner_xy = Geom.circle(center.x, center.y, float(inner))
	var c := Geom.centroid(outline_xy, inner_xy) if outline_xy.size() >= 6 else PackedFloat64Array([0.0, 0.0])
	centroid_x = c[0]
	centroid_y = c[1]


## A copy with the same fields (screws are given again by the level that holds it).
func copy() -> PlankData:
	var p := PlankData.new()
	p.layer = layer
	p.shape = shape
	p.path = path
	p.width = width
	p.points = points
	p.center = center
	p.radius = radius
	p.inner = inner
	p.holes = holes
	p.screws = screws
	p.hole_xy = hole_xy
	p.outline_xy = outline_xy
	p.inner_xy = inner_xy
	p.centroid_x = centroid_x
	p.centroid_y = centroid_y
	return p


## A varied copy for the generator: mirrored left to right across the board (x becomes
## 86 - x), then shifted by (dx, dy), on another layer. Holes keep their order, so screw ids
## keep theirs. Only the fields the shape uses are moved, so the copy holds exactly what
## to_dict writes and from_dict reads back (an unused center stays at zero). Built and ready.
func transformed(mirror: bool, dx: int, dy: int, new_layer: int) -> PlankData:
	var p := PlankData.new()
	p.layer = new_layer
	p.shape = shape
	p.width = width
	p.radius = radius
	p.inner = inner
	p.path = _moved(path, mirror, dx, dy)
	p.points = _moved(points, mirror, dx, dy)
	p.holes = _moved(holes, mirror, dx, dy)
	if shape == DISC or shape == RING:
		p.center = _moved(PackedVector2Array([center]), mirror, dx, dy)[0]
	p.build()
	return p


static func _moved(list: PackedVector2Array, mirror: bool, dx: int, dy: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(list.size())
	for i: int in list.size():
		var x := int(list[i].x)
		var y := int(list[i].y)
		out[i] = Vector2((LevelData.BOARD_W - x if mirror else x) + dx, y + dy)
	return out


## The plank as GDD 9.1 writes it (without colors).
func to_dict() -> Dictionary:
	var d := {"layer": layer, "shape": SHAPE_NAMES[shape]}
	match shape:
		BAR:
			d["path"] = _points_list(path)
			d["width"] = width
		POLY:
			d["points"] = _points_list(points)
		DISC:
			d["center"] = [int(center.x), int(center.y)]
			d["radius"] = radius
		RING:
			d["center"] = [int(center.x), int(center.y)]
			d["radius"] = radius
			d["inner"] = inner
	d["holes"] = _points_list(holes)
	return d


## Reads one plank of a data file. Checks types and ranges, not the blueprint rules (the
## validator does those). Returns null and adds to errors on bad data.
static func from_dict(d: Dictionary, index: int, errors: PackedStringArray) -> PlankData:
	var where := "plank %d" % index
	var errors_before := errors.size()
	var allowed: Array[String] = ["layer", "shape", "path", "width", "points", "center", "radius", "inner", "holes", "colors"]
	for key: Variant in d.keys():
		if not (key is String and allowed.has(key)):
			errors.append("%s: unknown field %s" % [where, str(key)])
			return null
	var p := PlankData.new()
	var shape_name: Variant = d.get("shape")
	if not (shape_name is String and SHAPE_NAMES.has(shape_name)):
		errors.append("%s: shape must be one of %s" % [where, ", ".join(SHAPE_NAMES)])
		return null
	p.shape = SHAPE_NAMES.find(shape_name)
	var ok := true
	p.layer = read_int(d, "layer", 0, 4, where, errors)
	var need: Array[String] = []
	match p.shape:
		BAR:
			need = ["path", "width"]
		POLY:
			need = ["points"]
		DISC:
			need = ["center", "radius"]
		RING:
			need = ["center", "radius", "inner"]
	for key: String in ["path", "width", "points", "center", "radius", "inner"]:
		if d.has(key) != need.has(key):
			errors.append("%s: a %s %s %s" % [where, shape_name, "needs" if need.has(key) else "has no", key])
			ok = false
	if not ok:
		return null
	match p.shape:
		BAR:
			p.path = read_points(d, "path", 2, where, errors)
			p.width = read_int(d, "width", 1, 100, where, errors)
			for i: int in range(1, p.path.size()):
				if p.path[i] == p.path[i - 1]:
					errors.append("%s: the path repeats a point" % where)
					ok = false
		POLY:
			p.points = read_points(d, "points", 3, where, errors)
		DISC, RING:
			var c := read_points({"center": [d["center"]]}, "center", 1, where, errors)
			if c.size() == 1:
				p.center = c[0]
			p.radius = read_int(d, "radius", 1, 100, where, errors)
			if p.shape == RING:
				p.inner = read_int(d, "inner", 1, 100, where, errors)
				if p.inner >= p.radius:
					errors.append("%s: a ring's inner radius must be smaller than its radius" % where)
					ok = false
	# B3: every plank has a hole (a plank with none would hold nothing, and costs work to read).
	if d.get("holes") is Array and (d.get("holes") as Array).is_empty():
		errors.append("%s: B3: a plank needs at least one hole" % where)
		return null
	p.holes = read_points(d, "holes", 1, where, errors, BoardGeometry.MAX_SCREWS)
	if not ok or errors.size() > errors_before:
		return null
	p.build()
	if p.outline_xy.size() < 6:
		errors.append("%s: the shape has no outline" % where)
		return null
	return p


## A whole number in [low, high] from d[key], or adds an error and returns low.
static func read_int(d: Dictionary, key: String, low: int, high: int, where: String, errors: PackedStringArray) -> int:
	var v: Variant = d.get(key)
	if (v is float or v is int) and float(v) == floorf(float(v)) and float(v) >= low and float(v) <= high:
		return int(v)
	errors.append("%s: %s must be a whole number from %d to %d" % [where, key, low, high])
	return low


## A list of min_count to max_count [x, y] whole number pairs from d[key].
static func read_points(d: Dictionary, key: String, min_count: int, where: String, errors: PackedStringArray, max_count: int = MAX_POINTS) -> PackedVector2Array:
	var out := PackedVector2Array()
	var v: Variant = d.get(key)
	if not v is Array or (v as Array).size() < min_count:
		errors.append("%s: %s must be a list of at least %d points" % [where, key, min_count])
		return out
	if (v as Array).size() > max_count:
		errors.append("%s: %s must be a list of at most %d points" % [where, key, max_count])
		return out
	for item: Variant in v:
		if not item is Array or (item as Array).size() != 2:
			errors.append("%s: every point in %s must be [x, y]" % [where, key])
			return PackedVector2Array()
		var xy := PackedInt32Array()
		for n: Variant in item:
			if not (n is float or n is int) or float(n) != floorf(float(n)) or absf(float(n)) > COORD_LIMIT:
				errors.append("%s: the coordinates in %s must be whole numbers within %d" % [where, key, COORD_LIMIT])
				return PackedVector2Array()
			xy.append(int(n))
		out.append(Vector2(xy[0], xy[1]))
	return out


static func _flat(list: PackedVector2Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(list.size() * 2)
	for i: int in list.size():
		out[2 * i] = float(list[i].x)
		out[2 * i + 1] = float(list[i].y)
	return out


static func _points_list(list: PackedVector2Array) -> Array:
	var out := []
	for v: Vector2 in list:
		out.append([int(v.x), int(v.y)])
	return out
