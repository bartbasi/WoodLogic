# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Palette, Looks, Tokens and Icons: the parts every screen builds on.

## DESIGN.md 3.2, in index order.
const DESIGN_COLORS: Array[String] = ["e5331e", "f9d63a", "4bc4ed", "1e45b8", "f5922a", "f7f2ea", "2f875a", "8454d9", "e062a6"]
const DESIGN_SYMBOLS: Array[String] = ["triangle", "star", "diamond", "cross", "square", "moon", "circle", "ring", "bar"]
const WOOD_KEYS: Array[String] = ["wood_light", "wood_dark", "edge_color", "ring_freq", "ring_contrast", "figure", "fiber",
	"pores", "board_light", "board_dark", "board_edge"]
const METAL_KEYS: Array[String] = ["metal_light", "metal_dark", "gloss", "spec_power", "recess_metal"]


## Draws every icon and every symbol once from inside _draw, where drawing is allowed.
class Sheet extends Node2D:
	var drawn := 0

	func _draw() -> void:
		var x := 0.0
		for icon: String in Icons.NAMES:
			Icons.draw(self, icon, Vector2(x, 20), 28.0, Color.WHITE)
			x += 32.0
		for i in Palette.count():
			Palette.draw_symbol(self, i, Vector2(i * 20.0, 60.0), 8.0, Palette.ink(i), 15.0 * i)
		drawn += 1


func test_palette_matches_design_order() -> void:
	check_eq(Palette.count(), 9, "palette size")
	for i in DESIGN_COLORS.size():
		check_eq(Palette.color(i).to_html(false), DESIGN_COLORS[i], "color %d" % i)
		check_eq(Palette.symbol_name(i), DESIGN_SYMBOLS[i], "symbol %d" % i)
		var data := Palette.symbol(i)
		check_eq(String(data["name"]), DESIGN_SYMBOLS[i], "symbol data name %d" % i)


func test_every_symbol_outline_is_a_fillable_polygon() -> void:
	for i in Palette.count():
		var pts := Palette.outline(i)
		check(pts.size() >= 3, "%s has an outline" % Palette.symbol_name(i))
		check(not Geometry2D.triangulate_polygon(pts).is_empty(), "%s triangulates" % Palette.symbol_name(i))
		var reach := 0.0
		for p: Vector2 in pts:
			reach = maxf(reach, p.length())
		check_between(reach, 0.6, 1.08, "%s fits the unit circle" % Palette.symbol_name(i))


func test_printed_symbol_ink_reads_on_every_color() -> void:
	for i in Palette.count():
		check(Palette.contrast(Palette.ink(i), Palette.color(i)) >= 3.0, "%s ink at 3:1 or more" % Palette.color_name(i))


func test_every_wood_and_metal_has_its_parameters() -> void:
	for id: String in Looks.WOODS:
		var w := Looks.wood(id)
		check_eq(String(w["id"]), id, "wood id")
		for key: String in WOOD_KEYS:
			check(w.has(key), "%s has %s" % [id, key])
	for id: String in Looks.METALS:
		var m := Looks.metal(id)
		check_eq(String(m["id"]), id, "metal id")
		for key: String in METAL_KEYS:
			check(m.has(key), "%s has %s" % [id, key])
	check_eq(String(Looks.wood("nonsense")["id"]), "oak", "unknown wood reads as oak")
	check_eq(String(Looks.metal("nonsense")["id"]), "steel", "unknown metal reads as steel")


func test_current_look_has_its_three_keys() -> void:
	for key: String in ["wood", "metal", "symbols"]:
		check(Looks.current.has(key), "Looks.current has %s" % key)


func test_token_text_pairs_reach_4_5_to_1() -> void:
	for pair: Array in Tokens.text_pairs():
		var ratio := Palette.contrast(Tokens.over_pegboard(pair[1]), Tokens.over_pegboard(pair[2]))
		check(ratio >= 4.5, "%s is %.2f:1" % [pair[0], ratio])


func test_token_marks_reach_3_to_1() -> void:
	for pair: Array in Tokens.mark_pairs():
		var ratio := Palette.contrast(Tokens.over_pegboard(pair[1]), Tokens.over_pegboard(pair[2]))
		check(ratio >= 3.0, "%s is %.2f:1" % [pair[0], ratio])


func test_icon_names_cover_the_contract() -> void:
	for icon: String in ["star", "star_empty", "pause", "undo", "extra_slot", "screwdriver", "cup", "chevron", "arrow",
			"warning", "stopwatch", "pip", "hand", "padlock", "check", "speaker", "speaker_off", "note", "note_off",
			"home", "map", "stats", "info", "settings", "about"]:
		check(Icons.has(icon), "Icons has %s" % icon)


func test_every_icon_and_symbol_draws_without_errors() -> void:
	var sheet := Sheet.new()
	add_node(sheet)
	sheet.queue_redraw()
	await frames(2)
	check(sheet.drawn >= 1, "the sheet drew")
