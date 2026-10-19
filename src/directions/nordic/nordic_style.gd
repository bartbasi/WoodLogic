# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name NordicStyle
extends DirStyle
## Direction B, "Nordic": a quiet morning in a bright room. Pale birch plywood with its plies
## showing at the edges, on a linen wall. Soft cool shadows, matte powder coated screws with
## satin steel rims, white plaques with charcoal text, and a pine green for the main action.

const LINEN := preload("res://src/directions/nordic/linen.gdshader")

const BIRCH_LIGHT := Color("#efe2c9")
const BIRCH_DARK := Color("#d5bf98")
const BIRCH_EDGE := Color("#e6d5b4")
const PLY_LINE := Color("#a68d68")
const CHARCOAL := Color("#2e3338")
const PINE := Color("#2f5d50")
const SAND := Color("#e7e0d4")
const PAPER := Color("#fbfaf7")
const OCHRE := Color("#d9a441")


func _init() -> void:
	label = "Nordic"
	bg = Color("#ece8e1")
	text = CHARCOAL
	text_dim = Color("#4f565c")
	plaque = PAPER
	plaque_border = Color(CHARCOAL, 0.08)
	primary = PINE
	primary_text = Color("#ffffff")
	primary_edge = Color("#22453b")
	secondary = SAND
	secondary_text = CHARCOAL
	secondary_edge = Color("#d3cabb")
	quiet_text = CHARCOAL
	quiet_line = Color(CHARCOAL, 0.35)
	badge = PINE
	badge_text = Color("#ffffff")
	star_fill = OCHRE
	star_line = Color("#8a6420")
	veil = Color(0.93, 0.92, 0.89, 0.8)
	corner = 14


func background_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LINEN
	m.set_shader_parameter("noise_tex", DirNoise.texture())
	return m


func plank_look() -> Dictionary:
	return {"thickness": 5.0, "edge_dir": Vector2(0.15, 1.0), "shadow": Vector2(3, 7), "shadow_per_layer": 0.5,
		"shadow_blur": 9.0, "shadow_alpha": 0.24, "shadow_color": Color("#28323a"), "light": Vector2(-0.45, -0.9),
		"bevel": 2.5, "bevel_strength": 0.9, "hole_radius": 5.5}


func board_look() -> Dictionary:
	var look := plank_look()
	look["thickness"] = 6.0
	look["shadow"] = Vector2(0, 10)
	look["shadow_blur"] = 18.0
	look["shadow_alpha"] = 0.22
	look["shadow_per_layer"] = 0.0
	return look


func board_wood() -> Dictionary:
	# Sage painted plywood, the grain faint under the paint and raw birch plies at the edge.
	return {"wood_light": Color("#aab7ae"), "wood_dark": Color("#9eaca3"), "edge_color": Color("#dccaa8"),
		"ply_dark": PLY_LINE, "plies": 5.0, "ring_freq": 0.05, "ring_contrast": 0.25, "figure": 14.0, "fiber": 0.18,
		"tone_range": 0.0}


func plank_wood(i: int) -> Dictionary:
	var tones: Array[float] = [1.0, 0.97, 1.02, 0.985, 1.01, 0.965, 1.025]
	return {"wood_light": BIRCH_LIGHT, "wood_dark": BIRCH_DARK, "edge_color": BIRCH_EDGE, "ply_dark": PLY_LINE,
		"plies": 4.0, "ring_freq": 0.09, "ring_contrast": 0.38, "figure": 10.0, "fiber": 0.28, "pores": 0.0,
		"tone": tones[i % tones.size()], "tone_range": 0.015, "seed_base": 17}


func screw_finish() -> Dictionary:
	return {"metal_light": Color("#eef0f1"), "metal_dark": Color("#8d949a"), "rim": 0.16, "dome": 0.35,
		"gloss": 0.12, "spec_power": 8.0, "paint_sheen": 0.18, "shadow_alpha": 0.3, "shadow_blur": 0.3,
		"shadow_off": Vector2(0.08, 0.22), "shadow_color": Color("#28323a")}


func ghost_strength() -> float:
	return 0.42


func ghost_ring() -> Color:
	return Color(CHARCOAL, 0.55)


func kit_back() -> Color:
	return Color(PAPER, 0.6)


func _soft(ci: CanvasItem, rect: Rect2, fill: Color, radius: float = -1.0, lift: float = 1.0) -> void:
	panel(ci, rect, fill, radius, Color(), 0, Color(0.16, 0.2, 0.24, 0.12 * lift), int(10 * lift), Vector2(0, 3 * lift))


func draw_button(ci: CanvasItem, rect: Rect2, title: String, note: String, kind: String) -> void:
	if kind == "quiet":
		super.draw_button(ci, rect, title, note, kind)
		return
	var fill := primary if kind == "primary" else PAPER
	var ink := primary_text if kind == "primary" else secondary_text
	_soft(ci, rect, fill, rect.size.y / 2.0 if kind == "primary" else 16.0, 1.4 if kind == "primary" else 0.8)
	if kind != "primary":
		panel(ci, rect, Color(0, 0, 0, 0), 16, Color(CHARCOAL, 0.1), 1)
	_button_text(ci, rect, title, note, kind, ink)


func draw_top_bar(ci: CanvasItem, rect: Rect2, level: int, timer: String, stars: int) -> void:
	var y := rect.position.y
	var h := rect.size.y
	var x := rect.position.x
	var bar := Rect2(x + 10, y + 4, 290, h - 8)
	_soft(ci, bar, PAPER, bar.size.y / 2.0, 0.7)
	DirText.draw(ci, "Level %d" % level, Rect2(x + 26, y, 96, h), 20, CHARCOAL, DirText.bold(), HORIZONTAL_ALIGNMENT_LEFT)
	ci.draw_line(Vector2(x + 128, y + 14), Vector2(x + 128, y + h - 14), Color(CHARCOAL, 0.15), 1.0, true)
	DirText.draw(ci, timer, Rect2(x + 138, y, 70, h), 16, text_dim)
	ci.draw_line(Vector2(x + 216, y + 14), Vector2(x + 216, y + h - 14), Color(CHARCOAL, 0.15), 1.0, true)
	DirIcons.star(ci, Vector2(x + 238, y + h / 2.0), 9, OCHRE, star_line, true, 1.2)
	DirText.draw(ci, str(stars), Rect2(x + 252, y, 44, h), 16, CHARCOAL, DirText.bold(), HORIZONTAL_ALIGNMENT_LEFT)
	var c := Vector2(x + 332, y + h / 2.0)
	ci.draw_circle(c, 20, PAPER, true, -1.0, true)
	ci.draw_arc(c, 20, 0, TAU, 40, Color(CHARCOAL, 0.12), 1.0, true)
	DirIcons.pause(ci, c, 16, CHARCOAL)


# Boxes and tray

## A shallow birch tray lined with felt in its color. The lid has slid back and shows as a
## strip along the top, with the symbol on it.
func draw_box(ci: CanvasItem, rect: Rect2, color_index: int) -> void:
	var c := DirColors.color(color_index)
	_soft(ci, rect, BIRCH_LIGHT, 12, 0.9)
	panel(ci, Rect2(rect.position + Vector2(0, rect.size.y - 3), Vector2(rect.size.x, 3)), Color(PLY_LINE, 0.35), 2)
	var felt := Rect2(rect.position + Vector2(4, 21), Vector2(rect.size.x - 8, rect.size.y - 25))
	panel(ci, felt, c.lerp(Color("#d8d4cc"), 0.2), 9)
	for w: Vector2 in well_centers(rect):
		draw_well(ci, w, 11.5, Color("#e4d9c4"), 0.7)
	var lid := Rect2(rect.position + Vector2(4, 2), Vector2(rect.size.x - 8, 17))
	panel(ci, lid, c, 8)
	DirSymbols.draw(ci, DirColors.symbol(color_index), lid.get_center(), 7.5, DirColors.ink(color_index))


func well_centers(rect: Rect2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for off: float in [6.0, 34.0, 62.0]:
		out.append(rect.position + Vector2(off + 12.0, 38.0))
	return out


func draw_preview(ci: CanvasItem, rect: Rect2, color_index: int) -> void:
	var c := DirColors.color(color_index)
	_soft(ci, rect, BIRCH_LIGHT, 12, 0.8)
	var lid := rect.grow(-3)
	panel(ci, lid, c, 10)
	DirSymbols.draw(ci, DirColors.symbol(color_index), lid.get_center(), 10.0, DirColors.ink(color_index))


func draw_chevron(ci: CanvasItem, rect: Rect2) -> void:
	DirIcons.chevron(ci, rect.get_center(), 10, Color(CHARCOAL, 0.45))


## A slim birch shelf with five round dimples.
func draw_tray(ci: CanvasItem, frame: Rect2, slots: Array[Rect2]) -> void:
	_soft(ci, frame, BIRCH_LIGHT, frame.size.y / 2.0, 1.0)
	panel(ci, Rect2(frame.position + Vector2(10, frame.size.y - 3), Vector2(frame.size.x - 20, 3)), Color(PLY_LINE, 0.3), 2)
	for s: Rect2 in slots:
		var c := s.get_center()
		ci.draw_circle(c, 18.0, Color("#d9cdb6"), true, -1.0, true)
		ci.draw_circle(c + Vector2(0.4, 1.2), 16.5, Color("#e4d9c4"), true, -1.0, true)
		ci.draw_arc(c, 18.0, PI * 1.1, PI * 1.9, 14, Color(0.3, 0.25, 0.18, 0.18), 1.2, true)


func draw_helpers(ci: CanvasItem, rects: Array[Rect2], counts: Array[int]) -> void:
	var names: Array[String] = ["Undo", "Extra slot", "Screwdriver"]
	for i in rects.size():
		var r := rects[i]
		_soft(ci, r, PAPER, 16, 0.9)
		_helper_icon(ci, i, Vector2(r.get_center().x, r.position.y + 21), 24, CHARCOAL)
		DirText.draw(ci, names[i], Rect2(r.position.x, r.end.y - 20, r.size.x, 16), 13, text_dim)
		var bc := Vector2(r.end.x - 8, r.position.y + 6)
		ci.draw_circle(bc, 12.0, PINE, true, -1.0, true)
		DirText.draw(ci, str(counts[i]), Rect2(bc - Vector2(12, 12), Vector2(24, 24)), 16, Color.WHITE, DirText.bold())


func _helper_icon(ci: CanvasItem, i: int, c: Vector2, s: float, color: Color) -> void:
	if i == 2:
		DirIcons.screwdriver(ci, c, s, color, OCHRE)
	else:
		super._helper_icon(ci, i, c, s, color)


# Title

## A small mark above the name: a birch bar crossing a disc, two small screws.
func logo_planks(rect: Rect2) -> Array[Dictionary]:
	var c := Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.24)
	return [
		{"shape": "disc", "layer": 0, "pos": c + Vector2(40, 0), "size": Vector2(28, 0), "wood": 1, "holes": [Vector2.ZERO],
			"screws": [{"pos": c + Vector2(40, 0), "color": DirColors.GREEN, "radius": 10.0}]},
		{"shape": "bar", "layer": 1, "pos": c + Vector2(-12, 3), "rot": -14.0, "size": Vector2(120, 28), "corner": 12.0, "wood": 3,
			"holes": [Vector2(-40, 0)], "screws": [{"pos": c + Vector2(-12, 3) + Vector2(-40, 0).rotated(deg_to_rad(-14.0)),
			"color": DirColors.ORANGE, "radius": 10.0, "turn": 0.1}]},
	]


func draw_logo(ci: CanvasItem, rect: Rect2) -> void:
	var card := Rect2(rect.position.x + 40, rect.position.y + rect.size.y * 0.46, rect.size.x - 80, rect.size.y * 0.46)
	_soft(ci, card, PAPER, 18, 0.9)
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = 0.6
	f.spacing_glyph = 3
	DirText.draw(ci, "WoodLogic", card, 32, CHARCOAL, f)


func draw_star_chip(ci: CanvasItem, rect: Rect2, stars: int) -> void:
	var r := Rect2(rect.position + Vector2(0, 8), Vector2(rect.size.x, 32))
	_soft(ci, r, PAPER, 16, 0.7)
	DirIcons.star(ci, Vector2(r.position.x + 20, r.get_center().y), 9, OCHRE, star_line, true, 1.2)
	DirText.draw(ci, str(stars), Rect2(r.position.x + 34, r.position.y, r.size.x - 40, r.size.y), 16, CHARCOAL, DirText.bold(), HORIZONTAL_ALIGNMENT_LEFT)


func draw_coffee_chip(ci: CanvasItem, rect: Rect2) -> void:
	var r := Rect2(rect.position + Vector2(0, 8), Vector2(rect.size.x, 32))
	panel(ci, r, Color(PAPER, 0.7), 16, Color(CHARCOAL, 0.25), 1)
	DirIcons.cup(ci, Vector2(r.position.x + 18, r.get_center().y), 20, text_dim)
	DirText.draw(ci, "Buy me a coffee", Rect2(r.position.x + 32, r.position.y, r.size.x - 38, r.size.y), 13, text_dim, null, HORIZONTAL_ALIGNMENT_LEFT)


# Level clear

func draw_clear(ci: CanvasItem, r: Dictionary, level: int) -> void:
	var head: Rect2 = r["heading"]
	var card := Rect2(24, head.position.y - 22, 312, Rect2(r["summary"]).end.y - head.position.y + 44)
	_soft(ci, card, PAPER, 22, 2.0)
	DirText.draw(ci, "Level %d cleared" % level, head, 24, CHARCOAL, DirText.bold())
	draw_star_row(ci, r["stars"], [true, true, false])
	var labels: Array[String] = ["Cleared", "Fast", "Clean"]
	var details: Array[Array] = [["Every screw", "is out"], ["Under 1:20", "Yours 1:12"], ["Tray 2 times", "no helpers"]]
	var cap: Rect2 = r["captions"]
	for i in 3:
		var col := Rect2(cap.position.x + i * 100, cap.position.y, 100, cap.size.y)
		DirText.draw(ci, labels[i], Rect2(col.position + Vector2(0, 2), Vector2(100, 24)), 18, CHARCOAL, DirText.bold())
		for j in 2:
			DirText.draw(ci, details[i][j], Rect2(col.position + Vector2(0, 28 + j * 17), Vector2(100, 16)), 13, text_dim)
	var sum: Rect2 = r["summary"]
	ci.draw_line(Vector2(sum.position.x + 60, sum.position.y - 10), Vector2(sum.end.x - 60, sum.position.y - 10), Color(CHARCOAL, 0.1), 1.0)
	DirText.draw(ci, "+2 stars", sum, 20, PINE, DirText.bold())
	draw_button(ci, r["next"], "Next", "Level %d" % (level + 1), "primary")
	var nx: Rect2 = r["next"]
	DirIcons.arrow_right(ci, Vector2(nx.end.x - 44, nx.get_center().y), 22, Color.WHITE)
	draw_button(ci, r["replay"], "Replay", "", "secondary")


func draw_star_row(ci: CanvasItem, rect: Rect2, earned: Array) -> void:
	for i in 3:
		var c := Vector2(rect.position.x + 36 + i * 96, rect.get_center().y)
		if earned[i]:
			ci.draw_colored_polygon(DirIcons.star_points(c, 34, 0.48), OCHRE)
		else:
			ci.draw_polyline(_loop(DirIcons.star_points(c, 33, 0.48)), Color(star_line, 0.85), 2.5, true)


func _loop(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


## A few round paper dots and thin strips drifting down, in the screw colors, softened.
func draw_celebration(ci: CanvasItem, size: Vector2, r: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var card_top: float = Rect2(r["heading"]).position.y - 22.0
	var card_bottom: float = Rect2(r["summary"]).end.y + 22.0
	for i in 26:
		var p := Vector2(rng.randf_range(8, size.x - 8), rng.randf_range(20, size.y * 0.78))
		if p.y > card_top - 6 and p.y < card_bottom + 6 and p.x > 18 and p.x < 342:
			continue
		var c := DirColors.color(rng.randi_range(0, 7)).lerp(Color("#ece8e1"), 0.25)
		if i % 3 == 0:
			var a := rng.randf_range(0, PI)
			var d := Vector2(cos(a), sin(a)) * 7.0
			ci.draw_line(p - d, p + d, c, 3.0, true)
		else:
			ci.draw_circle(p, rng.randf_range(3.0, 5.5), c, true, -1.0, true)
