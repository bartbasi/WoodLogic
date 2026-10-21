# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The color and legibility checks (docs/DESIGN.md 3 and 5, docs/UX.md 7.2 and 7.4). Each test
## prints its numbers, so `bash tools/test.sh test_colors` is the check script's report.
## - Every pair of screw colors stays apart under protanopia, deuteranopia and tritanopia
##   (Machado 2009, full severity, distance in OKLab).
## - Every screw stands out from every wood with every metal by its rim and shadow (3:1).
## - Every theme's planks stand out from its back board (1.6:1).
## - Every symbol is big enough with strokes of at least 2 units on a 28 unit head.
## - Every text pair is 4.5:1 or more and every meaningful mark 3:1 or more.

## The closest two screw colors may come under any simulation (DESIGN.md 3.2 reports 0.072).
const MIN_PAIR := 0.07
## Symbol radius on a board head: 16 units across on a 28 unit head.
const SYMBOL_RADIUS := 8.0

const SIMULATIONS := {
	"protanopia": [Vector3(0.152286, 1.052583, -0.204868), Vector3(0.114503, 0.786281, 0.099216), Vector3(-0.003882, -0.048116, 1.051998)],
	"deuteranopia": [Vector3(0.367322, 0.860646, -0.227968), Vector3(0.280085, 0.672501, 0.047413), Vector3(-0.011820, 0.042940, 0.968881)],
	"tritanopia": [Vector3(1.255528, -0.076749, -0.178779), Vector3(-0.078411, 0.930809, 0.147602), Vector3(0.004733, 0.691367, 0.303900)],
}


static func oklab(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	var lm := 0.4122214708 * l.r + 0.5363325363 * l.g + 0.0514459929 * l.b
	var mm := 0.2119034982 * l.r + 0.6806995451 * l.g + 0.1073969566 * l.b
	var sm := 0.0883024619 * l.r + 0.2817188376 * l.g + 0.6299787005 * l.b
	lm = pow(maxf(lm, 0.0), 1.0 / 3.0)
	mm = pow(maxf(mm, 0.0), 1.0 / 3.0)
	sm = pow(maxf(sm, 0.0), 1.0 / 3.0)
	return Vector3(0.2104542553 * lm + 0.7936177850 * mm - 0.0040720468 * sm,
		1.9779984951 * lm - 2.4285922050 * mm + 0.4505937099 * sm,
		0.0259040371 * lm + 0.7827717662 * mm - 0.8086757660 * sm)


## The color as seen with a color vision deficiency ("" for normal vision).
static func simulate(c: Color, kind: String) -> Color:
	if kind == "":
		return c
	var m: Array = SIMULATIONS[kind]
	var l := c.srgb_to_linear()
	var v := Vector3(l.r, l.g, l.b)
	var out := Color(clampf(m[0].dot(v), 0.0, 1.0), clampf(m[1].dot(v), 0.0, 1.0), clampf(m[2].dot(v), 0.0, 1.0))
	return out.linear_to_srgb()


static func distance(a: Color, b: Color, kind: String) -> float:
	return oklab(simulate(a, kind)).distance_to(oklab(simulate(b, kind)))


func test_every_screw_color_pair_stays_apart_under_each_simulation() -> void:
	for kind: String in ["", "protanopia", "deuteranopia", "tritanopia"]:
		var worst := 9.0
		var pair := ""
		for i in Palette.count():
			for j in range(i + 1, Palette.count()):
				var d := distance(Palette.color(i), Palette.color(j), kind)
				if d < worst:
					worst = d
					pair = "%s and %s" % [Palette.color_name(i), Palette.color_name(j)]
				check(d >= MIN_PAIR, "%s and %s under %s: %.3f" % [Palette.color_name(i), Palette.color_name(j), kind if kind != "" else "normal vision", d])
		print("    closest pair, %s: %s, %.3f" % [kind if kind != "" else "normal vision", pair, worst])


func test_every_screw_stands_out_from_every_wood_by_rim_and_shadow() -> void:
	for wood_id: String in Looks.WOODS:
		var w := Looks.wood(wood_id)
		for metal_id: String in Looks.METALS:
			var m := Looks.metal(metal_id)
			var worst := 99.0
			for face: Color in [w["wood_light"], w["wood_dark"]]:
				var shadow := face.lerp(Tokens.SHADOW, 0.55)
				var best := maxf(Palette.contrast(m["metal_light"], face), maxf(Palette.contrast(m["metal_dark"], face), Palette.contrast(shadow, face)))
				worst = minf(worst, best)
			check(worst >= 3.0, "screws on %s with %s: %.2f:1" % [wood_id, metal_id, worst])
			print("    rim or shadow on %s, %s: %.2f:1" % [wood_id, metal_id, worst])


func test_every_theme_parts_its_planks_from_its_board() -> void:
	for wood_id: String in Looks.WOODS:
		var w := Looks.wood(wood_id)
		var ratio := Palette.contrast(w["wood_light"], w["board_light"])
		check(ratio >= 1.6, "%s planks on their board: %.2f:1" % [wood_id, ratio])
		print("    %s planks on their board: %.2f:1" % [wood_id, ratio])


func test_every_symbol_is_big_enough_with_thick_enough_strokes() -> void:
	for i in Palette.count():
		var pts := Palette.outline(i)
		var area := absf(_area(pts))
		var perimeter := 0.0
		var box := Rect2(pts[0], Vector2.ZERO)
		for k in pts.size():
			perimeter += pts[k].distance_to(pts[(k + 1) % pts.size()])
			box = box.expand(pts[k])
		# For a stroke, twice its area over its perimeter is about its width.
		var stroke := 2.0 * area / perimeter * SYMBOL_RADIUS
		var across := maxf(box.size.x, box.size.y) * SYMBOL_RADIUS
		check(stroke >= 2.0, "%s stroke %.1f units" % [Palette.symbol_name(i), stroke])
		check(across >= 9.5, "%s is %.1f units across" % [Palette.symbol_name(i), across])
		print("    %s: %.1f units across, strokes about %.1f" % [Palette.symbol_name(i), across, stroke])


func test_text_and_marks_meet_their_contrast() -> void:
	for pair: Array in Tokens.text_pairs():
		var ratio := Palette.contrast(Tokens.over_pegboard(pair[1]), Tokens.over_pegboard(pair[2]))
		check(ratio >= 4.5, "%s: %.2f:1" % [pair[0], ratio])
		print("    text, %s: %.2f:1" % [pair[0], ratio])
	for pair: Array in Tokens.mark_pairs():
		var ratio := Palette.contrast(Tokens.over_pegboard(pair[1]), Tokens.over_pegboard(pair[2]))
		check(ratio >= 3.0, "%s: %.2f:1" % [pair[0], ratio])
		print("    mark, %s: %.2f:1" % [pair[0], ratio])
	for i in Palette.count():
		var ratio := Palette.contrast(Palette.ink(i), Palette.color(i))
		check(ratio >= 3.0, "symbol ink on %s: %.2f:1" % [Palette.color_name(i), ratio])
		print("    symbol ink on %s: %.2f:1" % [Palette.color_name(i), ratio])


static func _area(pts: PackedVector2Array) -> float:
	var a := 0.0
	for k in pts.size():
		a += pts[k].cross(pts[(k + 1) % pts.size()])
	return a * 0.5
