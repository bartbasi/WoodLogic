# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name WorkshopStyle
extends DirStyle
## Direction A, "Workshop": an evening at the workbench. Honey oak offcuts on a dark walnut
## board, hung on lamp-lit pegboard. Polished steel screws with enamel caps, brass plates for
## the controls, little oak trays for boxes and a magnetic steel parts tray.

const PEGBOARD := preload("res://src/directions/workshop/pegboard.gdshader")

const OAK_LIGHT := Color("#dcae6c")
const OAK_DARK := Color("#a8713a")
const OAK_EDGE := Color("#8a5a2c")
const BRASS := Color("#d8a445")
const BRASS_DARK := Color("#8a6420")
const WALNUT := Color("#2c1d13")
const CREAM := Color("#f7ead4")


func _init() -> void:
	label = "Workshop"
	bg = Color("#5a412c")
	text = CREAM
	text_dim = Color("#e8d6b8")
	plaque = Color(WALNUT, 0.94)
	plaque_border = Color(BRASS, 0.55)
	primary = BRASS
	primary_text = Color("#2a1708")
	primary_edge = BRASS_DARK
	secondary = Color("#4b3121")
	secondary_text = CREAM
	secondary_edge = Color("#24160d")
	quiet_text = CREAM
	quiet_line = Color(BRASS, 0.6)
	badge = BRASS
	badge_text = Color("#2a1708")
	star_fill = Color("#e9b23e")
	star_line = Color("#fff0c8")
	veil = Color(0.08, 0.05, 0.03, 0.62)
	corner = 8


func background_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PEGBOARD
	m.set_shader_parameter("noise_tex", DirNoise.texture())
	m.set_shader_parameter("board", Color("#7a5a3d"))
	m.set_shader_parameter("hole", Color("#1e120a"))
	return m


func plank_look() -> Dictionary:
	return {"thickness": 7.0, "edge_dir": Vector2(0.3, 1.0), "shadow": Vector2(5, 8), "shadow_per_layer": 0.4,
		"shadow_blur": 6.0, "shadow_alpha": 0.55, "shadow_color": Color("#1a0d05"), "light": Vector2(-0.55, -0.83),
		"bevel": 4.5, "bevel_strength": 1.5, "hole_radius": 6.0}


func board_look() -> Dictionary:
	var look := plank_look()
	look["thickness"] = 10.0
	look["shadow"] = Vector2(4, 12)
	look["shadow_blur"] = 16.0
	look["shadow_alpha"] = 0.7
	look["shadow_per_layer"] = 0.0
	look["bevel"] = 6.0
	look["face_light"] = 0.35
	return look


func board_wood() -> Dictionary:
	return {"wood_light": Color("#6f4a30"), "wood_dark": Color("#47291a"), "edge_color": Color("#3a2215"),
		"ring_freq": 0.07, "ring_contrast": 0.55, "figure": 18.0, "fiber": 0.45, "pores": 0.12, "tone_range": 0.0}


func plank_wood(i: int) -> Dictionary:
	var tones: Array[float] = [1.0, 0.94, 1.04, 0.97, 1.02, 0.92, 1.06]
	return {"wood_light": OAK_LIGHT, "wood_dark": OAK_DARK, "edge_color": OAK_EDGE, "ring_freq": 0.11,
		"ring_contrast": 0.7, "figure": 14.0, "fiber": 0.4, "pores": 0.22, "tone": tones[i % tones.size()],
		"tone_range": 0.03, "seed_base": 3}


func screw_finish() -> Dictionary:
	return {"metal_light": Color("#f4f1ea"), "metal_dark": Color("#4c463e"), "rim": 0.2, "dome": 0.5,
		"gloss": 0.55, "spec_power": 26.0, "shadow_alpha": 0.55, "shadow_color": Color("#1a0d05")}


func ghost_ring() -> Color:
	return Color("#2a1708", 0.7)


func kit_back() -> Color:
	return Color(WALNUT, 0.7)


# Plates and buttons

## A brass plate with a bevel and two screw dots, or a walnut block.
func draw_button(ci: CanvasItem, rect: Rect2, title: String, note: String, kind: String) -> void:
	if kind == "quiet":
		super.draw_button(ci, rect, title, note, kind)
		return
	var fill := primary if kind == "primary" else secondary
	var edge := primary_edge if kind == "primary" else secondary_edge
	var ink := primary_text if kind == "primary" else secondary_text
	panel(ci, Rect2(rect.position + Vector2(0, 5), rect.size), edge, -1, Color(), 0, Color(0, 0, 0, 0.45), 8, Vector2(2, 4))
	panel(ci, rect, fill)
	# Top bevel highlight and bottom shade.
	panel(ci, Rect2(rect.position + Vector2(3, 2), Vector2(rect.size.x - 6, 3)), Color(1, 1, 1, 0.28 if kind == "primary" else 0.1), 2)
	panel(ci, Rect2(rect.position + Vector2(3, rect.size.y - 4), Vector2(rect.size.x - 6, 2)), Color(0, 0, 0, 0.18), 1)
	if kind == "primary":
		for x: float in [rect.position.x + 14, rect.end.x - 14]:
			_screw_dot(ci, Vector2(x, rect.get_center().y))
	_button_text(ci, rect, title, note, kind, ink)


func _screw_dot(ci: CanvasItem, c: Vector2) -> void:
	ci.draw_circle(c + Vector2(0.6, 0.8), 4.2, Color(0, 0, 0, 0.35), true, -1.0, true)
	ci.draw_circle(c, 4.0, Color("#b8892f"), true, -1.0, true)
	ci.draw_circle(c - Vector2(1, 1), 2.4, Color("#f3d48a"), true, -1.0, true)
	ci.draw_line(c + Vector2(-2.6, 1.4), c + Vector2(2.6, -1.4), Color("#5e4210"), 1.2, true)


func draw_top_bar(ci: CanvasItem, rect: Rect2, level: int, timer: String, stars: int) -> void:
	var y := rect.position.y
	var h := rect.size.y
	var x := rect.position.x
	panel(ci, Rect2(x + 10, y + 4, 300, h - 8), plaque, 8, plaque_border, 1, Color(0, 0, 0, 0.4), 6, Vector2(0, 3))
	DirText.draw(ci, "Level %d" % level, Rect2(x + 16, y, 96, h), 20, text, DirText.bold(), HORIZONTAL_ALIGNMENT_LEFT)
	DirIcons.stopwatch(ci, Vector2(x + 142, y + h / 2.0), 16, text_dim)
	DirText.draw(ci, timer, Rect2(x + 154, y, 56, h), 16, text)
	DirIcons.star(ci, Vector2(x + 244, y + h / 2.0), 9, star_fill, Color("#6b4413"), true, 1.2)
	DirText.draw(ci, str(stars), Rect2(x + 256, y, 46, h), 16, text, DirText.bold(), HORIZONTAL_ALIGNMENT_LEFT)
	var pr := Rect2(x + 314, y + 2, 40, h - 4)
	panel(ci, Rect2(pr.position + Vector2(0, 3), pr.size), BRASS_DARK, 8)
	panel(ci, pr, BRASS, 8)
	DirIcons.pause(ci, pr.get_center(), 18, primary_text)


# Boxes and tray

## A small oak tray: the open lid leans back above it, three drilled wells, and a painted band
## on the front with the symbol stenciled on it.
func draw_box(ci: CanvasItem, rect: Rect2, color_index: int) -> void:
	var c := DirColors.color(color_index)
	# The lid, swung open and leaning back: a thin strip above the box.
	var lid := Rect2(rect.position + Vector2(6, -7), Vector2(rect.size.x - 12, 9))
	panel(ci, lid, OAK_DARK.darkened(0.25), 4)
	panel(ci, lid.grow_individual(-2, -2, -2, -5), c.darkened(0.15), 3)
	# Shadow, body, edge.
	panel(ci, Rect2(rect.position + Vector2(2, 5), rect.size), Color(0, 0, 0, 0.0), 8, Color(), 0, Color(0, 0, 0, 0.5), 7, Vector2(2, 4))
	panel(ci, Rect2(rect.position + Vector2(0, 4), rect.size), OAK_EDGE.darkened(0.2), 8)
	panel(ci, rect, OAK_LIGHT.darkened(0.06), 8)
	panel(ci, rect.grow(-3), OAK_DARK.lightened(0.05), 6)
	panel(ci, rect.grow_individual(-3, -3, -3, -26), OAK_LIGHT.darkened(0.12), 6)
	for w: Vector2 in well_centers(rect):
		draw_well(ci, w, 12.0, Color("#4a2f1b"))
	var band := Rect2(rect.position.x + 5, rect.end.y - 19, rect.size.x - 10, 15)
	panel(ci, band, c, 3)
	panel(ci, Rect2(band.position, Vector2(band.size.x, 2)), Color(1, 1, 1, 0.2), 1)
	DirSymbols.draw(ci, DirColors.symbol(color_index), band.get_center(), 7.5, DirColors.ink(color_index))


func well_centers(rect: Rect2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for off: float in [6.0, 34.0, 62.0]:
		out.append(rect.position + Vector2(off + 12.0, 19.0))
	return out


## A closed tray waiting in the queue: the lid on top, painted in its color with the symbol.
func draw_preview(ci: CanvasItem, rect: Rect2, color_index: int) -> void:
	var c := DirColors.color(color_index)
	panel(ci, Rect2(rect.position + Vector2(1, 4), rect.size), Color(0, 0, 0, 0), 7, Color(), 0, Color(0, 0, 0, 0.45), 6, Vector2(1, 3))
	panel(ci, Rect2(rect.position + Vector2(0, 5), rect.size), OAK_EDGE.darkened(0.25), 7)
	panel(ci, rect, OAK_LIGHT.darkened(0.08), 7)
	var lid := rect.grow(-4)
	panel(ci, lid, c, 5)
	panel(ci, Rect2(lid.position, Vector2(lid.size.x, 3)), Color(1, 1, 1, 0.22), 2)
	DirSymbols.draw(ci, DirColors.symbol(color_index), lid.get_center(), 10.0, DirColors.ink(color_index))


func draw_chevron(ci: CanvasItem, rect: Rect2) -> void:
	DirIcons.chevron(ci, rect.get_center() + Vector2(1, 1), 12, Color(0, 0, 0, 0.4))
	DirIcons.chevron(ci, rect.get_center(), 12, BRASS.lightened(0.2))


## A magnetic parts tray: brushed steel with five dished recesses and a rivet at each end.
func draw_tray(ci: CanvasItem, frame: Rect2, slots: Array[Rect2]) -> void:
	panel(ci, Rect2(frame.position + Vector2(0, 5), frame.size), Color("#3c3a36"), 12, Color(), 0, Color(0, 0, 0, 0.5), 8, Vector2(2, 4))
	panel(ci, frame, Color("#a7a39b"), 12)
	for i in 9:
		var yy := frame.position.y + 4 + i * (frame.size.y - 8) / 8.0
		ci.draw_line(Vector2(frame.position.x + 8, yy), Vector2(frame.end.x - 8, yy), Color(1, 1, 1, 0.05 + 0.04 * (i % 2)), 1.0)
	panel(ci, Rect2(frame.position + Vector2(4, 2), Vector2(frame.size.x - 8, 3)), Color(1, 1, 1, 0.35), 2)
	for s: Rect2 in slots:
		var c := s.get_center()
		ci.draw_circle(c, 19.0, Color("#5f5b55"), true, -1.0, true)
		ci.draw_circle(c + Vector2(0.8, 1.4), 17.0, Color("#77736c"), true, -1.0, true)
		ci.draw_arc(c, 19.0, PI * 0.1, PI * 0.9, 14, Color(1, 1, 1, 0.35), 1.4, true)
		ci.draw_arc(c, 19.0, PI * 1.15, PI * 1.85, 14, Color(0, 0, 0, 0.35), 1.4, true)
	for x: float in [frame.position.x + 4.5, frame.end.x - 4.5]:
		var c := Vector2(x, frame.get_center().y)
		ci.draw_circle(c, 2.6, Color("#55524c"), true, -1.0, true)
		ci.draw_circle(c - Vector2(0.6, 0.6), 1.5, Color("#e6e2da"), true, -1.0, true)


func draw_helpers(ci: CanvasItem, rects: Array[Rect2], counts: Array[int]) -> void:
	var names: Array[String] = ["Undo", "Extra slot", "Screwdriver"]
	for i in rects.size():
		var r := rects[i]
		panel(ci, Rect2(r.position + Vector2(0, 5), r.size), secondary_edge, -1, Color(), 0, Color(0, 0, 0, 0.45), 7, Vector2(1, 3))
		panel(ci, r, secondary, -1, Color(BRASS, 0.35), 1)
		panel(ci, Rect2(r.position + Vector2(3, 2), Vector2(r.size.x - 6, 2)), Color(1, 1, 1, 0.08), 1)
		var ic := Vector2(r.get_center().x, r.position.y + 21)
		_helper_icon(ci, i, ic, 26, CREAM)
		DirText.draw(ci, names[i], Rect2(r.position.x, r.end.y - 20, r.size.x, 16), 13, secondary_text)
		var bc := Vector2(r.end.x - 6, r.position.y + 4)
		ci.draw_circle(bc + Vector2(0.5, 1.5), 12.5, Color(0, 0, 0, 0.4), true, -1.0, true)
		ci.draw_circle(bc, 12.0, BRASS, true, -1.0, true)
		ci.draw_arc(bc, 11.0, PI * 1.1, PI * 1.9, 10, Color(1, 1, 1, 0.4), 1.2, true)
		DirText.draw(ci, str(counts[i]), Rect2(bc - Vector2(12, 12), Vector2(24, 24)), 16, badge_text, DirText.bold())


# Title

## The name is burned into a wide oak sign held up by two screws.
func logo_planks(rect: Rect2) -> Array[Dictionary]:
	var c := rect.get_center() + Vector2(0, 4)
	var w := 300.0
	var h := minf(rect.size.y - 34, 96.0)
	return [{"shape": "plate", "layer": 1, "pos": c, "rot": -2.0, "size": Vector2(w, h), "corner": 10.0, "wood": 2,
		"holes": [Vector2(-w / 2 + 20, 0), Vector2(w / 2 - 20, 0)],
		"screws": [{"pos": c + Vector2(-w / 2 + 20, 0).rotated(deg_to_rad(-2.0)), "color": DirColors.ORANGE, "radius": 11.0},
			{"pos": c + Vector2(w / 2 - 20, 0).rotated(deg_to_rad(-2.0)), "color": DirColors.SKY, "radius": 11.0, "turn": 1.2}]}]


func draw_logo(ci: CanvasItem, rect: Rect2) -> void:
	var c := rect.get_center() + Vector2(0, 4)
	ci.draw_set_transform(c, deg_to_rad(-2.0))
	var r := Rect2(Vector2(-130, -30), Vector2(260, 52))
	# Burned letters: a soft scorch halo, then the dark burn, then a faint lit lower lip.
	r = Rect2(Vector2(-120, -26), Vector2(240, 52))
	DirText.draw(ci, "WoodLogic", r.grow(1), 36, Color("#5a2e12", 0.35), DirText.wide(), HORIZONTAL_ALIGNMENT_CENTER, 6, Color("#6a3a18", 0.25))
	DirText.draw(ci, "WoodLogic", Rect2(r.position + Vector2(0, 1.2), r.size), 36, Color(1, 0.9, 0.7, 0.3), DirText.wide())
	DirText.draw(ci, "WoodLogic", r, 36, Color("#2b1407"), DirText.wide())
	ci.draw_set_transform(Vector2.ZERO)


## A short shelf for the decorative planks to sit on.
func draw_deco_back(ci: CanvasItem, rect: Rect2) -> void:
	# A soft pool of lamp light, as stacked faint discs (no texture).
	for i in 8:
		ci.draw_circle(rect.get_center(), rect.size.x * (0.2 + 0.05 * i), Color(1, 0.8, 0.45, 0.012), true, -1.0, true)


func draw_star_chip(ci: CanvasItem, rect: Rect2, stars: int) -> void:
	var r := Rect2(rect.position + Vector2(0, 8), Vector2(rect.size.x, 32))
	panel(ci, r, plaque, 8, plaque_border, 1, Color(0, 0, 0, 0.4), 5, Vector2(0, 2))
	DirIcons.star(ci, Vector2(r.position.x + 20, r.get_center().y), 9, star_fill, Color("#6b4413"), true, 1.2)
	DirText.draw(ci, str(stars), Rect2(r.position.x + 34, r.position.y, r.size.x - 40, r.size.y), 16, text, DirText.bold(), HORIZONTAL_ALIGNMENT_LEFT)


func draw_coffee_chip(ci: CanvasItem, rect: Rect2) -> void:
	var r := Rect2(rect.position + Vector2(0, 8), Vector2(rect.size.x, 32))
	panel(ci, r, plaque, 8, Color(BRASS, 0.3), 1)
	DirIcons.cup(ci, Vector2(r.position.x + 18, r.get_center().y), 20, text_dim)
	DirText.draw(ci, "Buy me a coffee", Rect2(r.position.x + 32, r.position.y, r.size.x - 38, r.size.y), 13, text_dim, null, HORIZONTAL_ALIGNMENT_LEFT)


# Level clear

func draw_clear(ci: CanvasItem, r: Dictionary, level: int) -> void:
	var head: Rect2 = r["heading"]
	var card := Rect2(20, head.position.y - 18, 320, Rect2(r["summary"]).end.y - head.position.y + 36)
	panel(ci, card, Color(WALNUT, 0.96), 10, Color(BRASS, 0.6), 2, Color(0, 0, 0, 0.5), 14, Vector2(0, 6))
	panel(ci, card.grow(-6), Color(0, 0, 0, 0), 7, Color(BRASS, 0.18), 1)
	DirText.draw(ci, "Level %d cleared" % level, head, 24, text, DirText.bold())
	draw_star_row(ci, r["stars"], [true, true, false])
	_captions(ci, r["captions"])
	DirText.draw(ci, "+2 stars", r["summary"], 20, Color("#f3c766"), DirText.bold())
	draw_button(ci, r["next"], "Next", "Level %d" % (level + 1), "primary")
	var nx: Rect2 = r["next"]
	DirIcons.arrow_right(ci, Vector2(nx.end.x - 44, nx.get_center().y), 22, primary_text)
	draw_button(ci, r["replay"], "Replay", "", "secondary")


## Brass stars stamped from sheet: a darker rim, a lit face and a crease to the center.
func draw_star_row(ci: CanvasItem, rect: Rect2, earned: Array) -> void:
	for i in 3:
		var c := Vector2(rect.position.x + 36 + i * 96, rect.get_center().y)
		if earned[i]:
			ci.draw_colored_polygon(DirIcons.star_points(c + Vector2(2, 4), 36), Color(0, 0, 0, 0.4))
			ci.draw_colored_polygon(DirIcons.star_points(c, 36), Color("#9a6c1c"))
			ci.draw_colored_polygon(DirIcons.star_points(c, 31), Color("#e8b648"))
			var pts := DirIcons.star_points(c, 31)
			for j in range(0, 10, 2):
				ci.draw_colored_polygon(PackedVector2Array([c, pts[j], pts[(j + 1) % 10]]), Color("#f7d77e", 0.85 if j < 4 else 0.25))
		else:
			DirIcons.star(ci, c, 34, Color(), Color("#d9b46a", 0.9), false, 3.0)


func _captions(ci: CanvasItem, rect: Rect2) -> void:
	var labels: Array[String] = ["Cleared", "Fast", "Clean"]
	var details: Array[Array] = [["Every screw", "is out"], ["Under 1:20", "Yours 1:12"], ["Tray 2 times", "no helpers"]]
	for i in 3:
		var col := Rect2(rect.position.x + i * 100, rect.position.y, 100, rect.size.y)
		DirText.draw(ci, labels[i], Rect2(col.position + Vector2(0, 2), Vector2(100, 24)), 18, text, DirText.bold())
		for j in 2:
			DirText.draw(ci, details[i][j], Rect2(col.position + Vector2(0, 28 + j * 17), Vector2(100, 16)), 13, text_dim)


## Oak shavings curling through the lamp light around the card, and a few warm motes.
func draw_celebration(ci: CanvasItem, size: Vector2, r: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var card_top: float = Rect2(r["heading"]).position.y - 18.0
	var card_bottom: float = Rect2(r["summary"]).end.y + 18.0
	var spots: Array[Vector2] = [Vector2(34, card_top - 22), Vector2(120, card_top - 34), Vector2(250, card_top - 18),
		Vector2(330, card_top - 40), Vector2(14, card_top + 90), Vector2(348, card_top + 150), Vector2(10, card_bottom - 40),
		Vector2(70, card_bottom + 24), Vector2(200, card_bottom + 48), Vector2(300, card_bottom + 16), Vector2(345, card_bottom + 70),
		Vector2(150, card_bottom + 110)]
	for p: Vector2 in spots:
		_shaving(ci, p, rng.randf_range(12, 19), rng.randf_range(0, TAU), rng.randf_range(0.9, 1.08))
	for i in 36:
		var p := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y * 0.7))
		ci.draw_circle(p, rng.randf_range(0.8, 1.8), Color(1, 0.85, 0.55, rng.randf_range(0.15, 0.4)), true, -1.0, true)


## A curled ribbon of shaving: wide where it was cut, tapering as it rolls up.
func _shaving(ci: CanvasItem, c: Vector2, r: float, a0: float, tone: float) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var steps := 22
	for j in steps:
		var t := j / float(steps - 1)
		var a := a0 + t * TAU * 1.15
		var rr := r * (1.0 - 0.6 * t)
		var p := c + Vector2(cos(a), sin(a) * 0.62) * rr
		var tangent := Vector2(-sin(a), cos(a) * 0.62).normalized()
		var n := Vector2(-tangent.y, tangent.x)
		var w := r * 0.42 * (1.0 - 0.75 * t)
		left.append(p + n * w * 0.5)
		right.append(p - n * w * 0.5)
	var poly := left.duplicate()
	right.reverse()
	poly.append_array(right)
	ci.draw_colored_polygon(poly, Color(OAK_LIGHT.lightened(0.12) * tone, 1.0))
	ci.draw_polyline(left, Color(OAK_DARK, 0.9), 1.2, true)
	right.reverse()
	ci.draw_polyline(right, Color(OAK_EDGE.darkened(0.2), 0.8), 1.0, true)
