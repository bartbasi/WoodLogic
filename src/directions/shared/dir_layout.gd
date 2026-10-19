# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name DirLayout
extends RefCounted
## The one hand-placed mid-level board that all three directions show, so they can be compared
## on looks alone. Board core coordinates (docs/UX.md 3.2.1): 344 x 360, origin at the center,
## y down. Screws stay inside the 300 x 316 inset. Also the box row, tray and helper contents,
## and the level screen bands from the UX budget, computed for any viewport height.

const CORE := Vector2(344, 360)
const HEAD := 28.0  # screw head diameter on the board
const BOX_HEAD := 22.0  # screw head diameter inside a box well
const LEVEL := 24

const R := DirColors.RED
const Y := DirColors.YELLOW
const B := DirColors.BLUE
const G := DirColors.GREEN
const P := DirColors.PURPLE


## Planks back to front. "screws" maps a hole index to a color; holes without a screw show as
## empty holes. A plank with "pivot" hangs from that hole at its rest angle (center of mass
## straight below the screw), worked out in planks().
static func planks() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{"shape": "bar", "layer": 0, "pos": Vector2(-5, -132), "rot": -4.0, "size": Vector2(296, 50),
			"corner": 12.0, "holes": [Vector2(-120, 0), Vector2(0, 0), Vector2(120, 0)],
			"screws": {0: R, 1: B, 2: Y}, "wood": 0},
		{"shape": "plate", "layer": 0, "pos": Vector2(78, 92), "rot": 4.0, "size": Vector2(148, 124),
			"corner": 12.0, "holes": [Vector2(-50, -40), Vector2(50, -40), Vector2(-50, 40), Vector2(50, 40)],
			"screws": {0: G, 1: P, 3: B}, "wood": 1},
		{"shape": "l", "layer": 1, "pos": Vector2(-88, 48), "rot": 0.0, "size": Vector2(124, 188), "arm": 46.0,
			"corner": 12.0, "holes": [Vector2(-39, -70), Vector2(-39, 71), Vector2(35, 71)],
			"screws": {0: Y, 1: R, 2: G}, "wood": 2},
		{"shape": "ring", "layer": 1, "pos": Vector2(58, -62), "rot": 0.0, "size": Vector2(54, 22),
			"holes": [Vector2(-38, 0), Vector2(38, 0)], "screws": {0: P, 1: Y}, "wood": 3},
		{"shape": "bar", "layer": 2, "pos": Vector2(48, 40), "rot": -26.0, "size": Vector2(210, 46),
			"corner": 12.0, "holes": [Vector2(-80, 0), Vector2(80, 0)], "screws": {0: B, 1: R}, "wood": 4},
		{"shape": "tri", "layer": 2, "pos": Vector2(30, 140), "rot": 0.0, "corner": 9.0,
			"verts": [Vector2(-54, 30), Vector2(54, 30), Vector2(0, -48)],
			"holes": [Vector2(-32, 18), Vector2(32, 18), Vector2(0, -22)], "screws": {0: G, 1: P, 2: Y}, "wood": 5},
		{"shape": "plate", "layer": 2, "size": Vector2(80, 80), "corner": 12.0,
			"holes": [Vector2(-26, -26), Vector2(26, -26), Vector2(-26, 26), Vector2(26, 26)],
			"screws": {0: R}, "pivot": Vector2(-60, -80), "hang": 0, "wood": 6},
	]
	for p: Dictionary in list:
		if p.has("pivot"):
			var hole: Vector2 = p["holes"][p["hang"]]
			var to_mass: Vector2 = DirShape.centroid(p) - hole
			var rot := PI / 2.0 - to_mass.angle()
			p["rot"] = rad_to_deg(rot)
			p["pos"] = Vector2(p["pivot"]) - hole.rotated(rot)
	return list


## Every screw on the board: {pos (core coords), color, plank index, layer, covered}.
## A screw is covered when a plank in a later layer overlaps its head.
static func screws(list: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in list.size():
		var p: Dictionary = list[i]
		var rot := deg_to_rad(float(p["rot"]))
		var screw_map: Dictionary = p["screws"]
		for hole_index: int in screw_map:
			var world: Vector2 = Vector2(p["pos"]) + Vector2(p["holes"][hole_index]).rotated(rot)
			out.append({"pos": world, "color": screw_map[hole_index], "plank": i, "layer": int(p["layer"]),
				"covered": false, "cover": -1})
	for s: Dictionary in out:
		for j in list.size():
			var q: Dictionary = list[j]
			if int(q["layer"]) <= int(s["layer"]):
				continue
			var local: Vector2 = (Vector2(s["pos"]) - Vector2(q["pos"])).rotated(-deg_to_rad(float(q["rot"])))
			if DirShape.sdf(q, local) < HEAD / 2.0:
				s["covered"] = true
				if s["cover"] < 0 or int(list[s["cover"]]["layer"]) < int(q["layer"]):
					s["cover"] = j
	return out


## Spacing problems against docs/UX.md 3.2.1 (free screws 48 apart, any two 32 apart, all in
## the inset). Empty when the board is fine.
static func spacing_problems(list: Array[Dictionary]) -> PackedStringArray:
	var found := PackedStringArray()
	var all := screws(list)
	for i in all.size():
		var a: Vector2 = all[i]["pos"]
		if absf(a.x) > 150.0 or absf(a.y) > 158.0:
			found.append("screw %d at %s is outside the inset" % [i, a])
		for j in range(i + 1, all.size()):
			var d := a.distance_to(all[j]["pos"])
			var both_free: bool = not all[i]["covered"] and not all[j]["covered"]
			if d < 32.0 or (both_free and d < 48.0):
				found.append("screws %d and %d are %.1f apart" % [i, j, d])
	return found


## Open boxes: color and how many wells are filled. Then the two previewed boxes.
const OPEN_BOXES: Array[Vector2i] = [Vector2i(Y, 2), Vector2i(R, 1)]
const PREVIEW: Array[int] = [B, G]
const TRAY_SLOTS := 5
const TRAY: Array[int] = [P, B]
const HELPERS: Array[int] = [2, 1, 2]  # Undo, Extra slot, Screwdriver counts
const STAR_BANK := 128
const TIMER := "1:12"


## The level screen bands in viewport units for a viewport of the given size, following the
## budget in docs/UX.md 3.2.1 (24 top and 16 bottom insets assumed).
static func level_bands(view: Vector2) -> Dictionary:
	var content := Rect2(Vector2((view.x - minf(view.x, 480.0)) / 2.0, 24.0), Vector2(minf(view.x, 480.0), view.y - 40.0))
	var e := clampf((view.y - 640.0) / 40.0, 0.0, 1.0)
	var heights: Array[float] = [44.0 + 4 * e, 4.0 + 2 * e, 64 + 12 * e, 4 + 2 * e, 52 + 4 * e, 8 + 4 * e, 0.0, 8 + 4 * e, 56 + 8 * e]
	var fixed := 0.0
	for h: float in heights:
		fixed += h
	heights[6] = content.size.y - fixed
	var names: Array[String] = ["top", "g1", "boxes", "g2", "tray", "g3", "board", "g4", "helpers"]
	var bands := {"content": content}
	var y := content.position.y
	for i in names.size():
		bands[names[i]] = Rect2(content.position.x, y, content.size.x, heights[i])
		y += heights[i]
	return bands


## Title screen rects in viewport units (docs/UX.md 3.1), buttons anchored to the bottom and
## the extra height of a tall phone given to the name and the decoration.
static func title_rects(view: Vector2) -> Dictionary:
	var cw := minf(view.x, 480.0)
	var ox := (view.x - cw) / 2.0 + (cw - 360.0) / 2.0
	var oy := 24.0
	var extra := maxf(view.y - 640.0, 0.0)
	var name_grow := minf(extra, 40.0)
	var deco_grow := clampf(extra - 40.0, 0.0, 120.0)
	var shift := extra
	var r := {}
	r["stars"] = Rect2(ox + 12, oy, 96, 48)
	r["coffee"] = Rect2(ox + 208, oy, 140, 48)
	r["name"] = Rect2(ox, oy + 56, 360, 120 + name_grow)
	r["deco"] = Rect2(ox + 24, oy + 176 + name_grow + (extra - name_grow - deco_grow) / 2.0, 312, 120 + deco_grow)
	r["play"] = Rect2(ox + 32, oy + 312 + shift, 296, 72)
	r["daily"] = Rect2(ox + 32, oy + 392 + shift, 144, 56)
	r["relaxed"] = Rect2(ox + 184, oy + 392 + shift, 144, 56)
	r["levels"] = Rect2(ox + 32, oy + 456 + shift, 144, 52)
	r["stats"] = Rect2(ox + 184, oy + 456 + shift, 144, 52)
	r["settings"] = Rect2(ox + 32, oy + 516 + shift, 144, 52)
	r["about"] = Rect2(ox + 184, oy + 516 + shift, 144, 52)
	return r


## Level clear rects (docs/UX.md 3.4): heading near 15 percent and stars near 22 percent of the
## height on tall phones, buttons anchored to the bottom.
static func clear_rects(view: Vector2) -> Dictionary:
	var cw := minf(view.x, 480.0)
	var ox := (view.x - cw) / 2.0 + (cw - 360.0) / 2.0
	var oy := 24.0
	var ch := view.y - 40.0
	var extra := maxf(ch - 600.0, 0.0)
	var head_y := maxf(56.0, ch * 0.15 - 18.0)
	var star_y := maxf(120.0, ch * 0.22)
	var r := {}
	r["heading"] = Rect2(ox, oy + head_y, 360, 36)
	r["stars"] = Rect2(ox + 48, oy + star_y, 264, 72)
	r["captions"] = Rect2(ox + 30, oy + star_y + 80, 300, 72)
	r["summary"] = Rect2(ox + 32, oy + star_y + 164, 296, 28)
	r["unlock"] = Rect2(ox + 32, oy + star_y + 202, 296, 48)
	r["next"] = Rect2(ox + 32, oy + 460 + extra, 296, 72)
	r["replay"] = Rect2(ox + 32, oy + 540 + extra, 296, 48)
	return r


## A few planks for the title screen decoration, in a 312 x 120 box (origin at its center).
static func title_planks() -> Array[Dictionary]:
	return [
		{"shape": "bar", "layer": 0, "pos": Vector2(-30, -22), "rot": -6.0, "size": Vector2(220, 40), "corner": 10.0,
			"holes": [Vector2(-88, 0), Vector2(88, 0)], "screws": {0: DirColors.ORANGE, 1: DirColors.SKY}, "wood": 0},
		{"shape": "disc", "layer": 1, "pos": Vector2(100, 8), "rot": 0.0, "size": Vector2(44, 0),
			"holes": [Vector2(0, 0)], "screws": {0: DirColors.PINK}, "wood": 3},
		{"shape": "tri", "layer": 1, "pos": Vector2(-104, 38), "rot": 0.0, "corner": 8.0,
			"verts": [Vector2(-34, 20), Vector2(34, 20), Vector2(0, -28)],
			"holes": [Vector2(0, 4)], "screws": {0: DirColors.GREEN}, "wood": 5},
		{"shape": "bar", "layer": 2, "pos": Vector2(6, 26), "rot": 10.0, "size": Vector2(150, 36), "corner": 10.0,
			"holes": [Vector2(-52, 0), Vector2(52, 0)], "screws": {0: DirColors.BLUE, 1: DirColors.YELLOW}, "wood": 2},
	]
