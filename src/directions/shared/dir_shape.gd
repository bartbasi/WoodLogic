# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name DirShape
extends RefCounted
## Plank shapes as signed distance functions, on the CPU. wood.gdshader draws the same shapes;
## this copy finds which screws a plank covers and where a hanging plank's center of mass is.
## A plank is a Dictionary from DirLayout (shape, size, corner, holes and so on), in plank
## local units, origin at the plank's center, y down.

enum { BOX, ELL, DISC, RING, TRI }


static func shape_id(plank: Dictionary) -> int:
	match String(plank["shape"]):
		"bar", "plate":
			return BOX
		"l":
			return ELL
		"disc":
			return DISC
		"ring":
			return RING
		"tri":
			return TRI
	return BOX


static func _box(p: Vector2, half: Vector2, r: float) -> float:
	var q := p.abs() - half + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


static func _segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba * h).length()


static func _tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> float:
	var d := minf(_segment(p, a, b), minf(_segment(p, b, c), _segment(p, c, a)))
	var s1 := (b - a).cross(p - a)
	var s2 := (c - b).cross(p - b)
	var s3 := (a - c).cross(p - c)
	var inside := (s1 >= 0.0 and s2 >= 0.0 and s3 >= 0.0) or (s1 <= 0.0 and s2 <= 0.0 and s3 <= 0.0)
	return -d if inside else d


## The L's two arms as [center, half size] pairs: a tall arm on the left, a foot along the
## bottom. size = (width, height), arm = thickness.
static func ell_rects(plank: Dictionary) -> Array[Vector2]:
	var s: Vector2 = plank["size"]
	var t: float = plank["arm"]
	# The arms overlap by half a thickness instead of sharing an outer edge, so the soft
	# union only fills the inside corner and never bulges an outside edge.
	return [Vector2(-s.x / 2.0 + t / 2.0, -t / 4.0), Vector2(t / 2.0, s.y / 2.0 - t / 4.0),
		Vector2(t / 4.0, s.y / 2.0 - t / 2.0), Vector2(s.x / 2.0 - t / 4.0, t / 2.0)]


## Signed distance from p (plank local) to the plank's outline, ignoring holes.
static func sdf(plank: Dictionary, p: Vector2) -> float:
	var r: float = plank.get("corner", 6.0)
	match shape_id(plank):
		BOX:
			return _box(p, Vector2(plank["size"]) / 2.0, r)
		ELL:
			var e := ell_rects(plank)
			return minf(_box(p - e[0], e[1], r), _box(p - e[2], e[3], r))
		DISC:
			return p.length() - Vector2(plank["size"]).x
		RING:
			var s: Vector2 = plank["size"]
			return maxf(p.length() - s.x, s.y - p.length())
		TRI:
			var v: Array = plank["verts"]
			return _tri(p, v[0], v[1], v[2]) - r
	return 1.0


## Center of mass in plank local units (holes ignored; they are small).
static func centroid(plank: Dictionary) -> Vector2:
	match shape_id(plank):
		ELL:
			var e := ell_rects(plank)
			var a1 := e[1].x * e[1].y
			var a2 := e[3].x * e[3].y
			return (e[0] * a1 + e[2] * a2) / (a1 + a2)
		TRI:
			var v: Array = plank["verts"]
			return (Vector2(v[0]) + Vector2(v[1]) + Vector2(v[2])) / 3.0
	return Vector2.ZERO


## Radius of a circle around the origin that holds the whole plank.
static func extent(plank: Dictionary) -> float:
	var s: Vector2 = plank.get("size", Vector2.ZERO)
	match shape_id(plank):
		DISC, RING:
			return s.x
		TRI:
			var m := 0.0
			for v: Vector2 in plank["verts"]:
				m = maxf(m, v.length())
			return m + float(plank.get("corner", 6.0))
	return s.length() / 2.0
