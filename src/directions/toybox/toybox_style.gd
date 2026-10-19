# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name ToyboxStyle
extends DirStyle
## Direction C, "Toybox": a Saturday morning on the playroom floor. Chunky, very rounded,
## lacquered beech on a navy painted board, a bright sky with polka dots behind. Candy gloss
## screws with chrome rims, solid colored bins with lids, chunky buttons with a thick lip, and
## the name spelled in painted alphabet blocks.

const PLAYROOM := preload("res://src/directions/toybox/playroom.gdshader")

const BEECH_LIGHT := Color("#f2cf98")
const BEECH_DARK := Color("#d9a865")
const BEECH_EDGE := Color("#c98c4a")
const NAVY := Color("#22306e")
const WHITE := Color("#ffffff")
const SUN := Color("#ffbf1f")
const SUN_EDGE := Color("#d98a00")


func _init() -> void:
	label = "Toybox"
	bg = Color("#3fa9e0")
	text = NAVY
	text_dim = Color("#3a4a8a")
	plaque = WHITE
	plaque_border = Color(NAVY, 0.15)
	primary = SUN
	primary_text = Color("#3a2200")
	primary_edge = SUN_EDGE
	secondary = WHITE
	secondary_text = NAVY
	secondary_edge = Color("#b9c6e3")
	quiet_text = WHITE
	quiet_line = Color(WHITE, 0.7)
	badge = Color("#ff6b3d")
	badge_text = Color("#2a0f00")
	star_fill = SUN
	star_line = Color("#b86e00")
	veil = Color(0.09, 0.14, 0.36, 0.55)
	corner = 18


func background_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PLAYROOM
	return m


func plank_look() -> Dictionary:
	return {"thickness": 10.0, "edge_dir": Vector2(0.12, 1.0), "shadow": Vector2(4, 10), "shadow_per_layer": 0.3,
		"shadow_blur": 4.0, "shadow_alpha": 0.42, "shadow_color": Color("#0f1640"), "light": Vector2(-0.5, -0.86),
		"bevel": 7.0, "bevel_strength": 1.9, "gloss": 0.32, "corner_add": 8.0, "hole_radius": 6.5}


func board_look() -> Dictionary:
	var look := plank_look()
	look["thickness"] = 12.0
	look["shadow"] = Vector2(0, 10)
	look["shadow_blur"] = 8.0
	look["shadow_alpha"] = 0.35
	look["shadow_per_layer"] = 0.0
	look["gloss"] = 0.12
	look["bevel"] = 8.0
	return look


## Navy paint over wood, the grain still showing through.
func board_wood() -> Dictionary:
	return {"wood_light": Color("#34479b"), "wood_dark": Color("#283a86"), "edge_color": Color("#1a2560"),
		"ring_freq": 0.06, "ring_contrast": 0.35, "figure": 16.0, "fiber": 0.25, "tone_range": 0.0}


func plank_wood(i: int) -> Dictionary:
	var tones: Array[float] = [1.0, 0.96, 1.03, 0.98, 1.02, 0.95, 1.04]
	return {"wood_light": BEECH_LIGHT, "wood_dark": BEECH_DARK, "edge_color": BEECH_EDGE, "ring_freq": 0.1,
		"ring_contrast": 0.45, "figure": 10.0, "fiber": 0.25, "pores": 0.1, "tone": tones[i % tones.size()],
		"tone_range": 0.02, "seed_base": 29}


func screw_finish() -> Dictionary:
	return {"metal_light": Color("#ffffff"), "metal_dark": Color("#5f6b7a"), "rim": 0.15, "dome": 0.8,
		"gloss": 1.0, "spec_power": 55.0, "shadow_alpha": 0.45, "shadow_blur": 0.14, "shadow_off": Vector2(0.1, 0.26),
		"shadow_color": Color("#0f1640")}


func ghost_strength() -> float:
	return 0.5


func ghost_ring() -> Color:
	return Color("#5a3510", 0.7)


func kit_back() -> Color:
	return Color(NAVY, 0.35)


## A chunky button: thick lip underneath, a white sticker edge on the primary.
func draw_button(ci: CanvasItem, rect: Rect2, title: String, note: String, kind: String) -> void:
	if kind == "quiet":
		super.draw_button(ci, rect, title, note, kind)
		return
	var fill := primary if kind == "primary" else secondary
	var edge := primary_edge if kind == "primary" else secondary_edge
	var ink := primary_text if kind == "primary" else secondary_text
	var rad := 22.0 if kind == "primary" else 18.0
	panel(ci, Rect2(rect.position + Vector2(0, 7), rect.size), Color(0.06, 0.1, 0.3, 0.3), rad)
	panel(ci, Rect2(rect.position + Vector2(0, 5), rect.size), edge, rad)
	panel(ci, rect, fill, rad, WHITE if kind == "primary" else Color(0, 0, 0, 0), 3 if kind == "primary" else 0)
	panel(ci, Rect2(rect.position + Vector2(10, 5), Vector2(rect.size.x - 20, rect.size.y * 0.3)), Color(1, 1, 1, 0.3), rad * 0.6)
	_button_text(ci, rect, title, note, kind, ink)


func draw_top_bar(ci: CanvasItem, rect: Rect2, level: int, timer: String, stars: int) -> void:
	var y := rect.position.y
	var h := rect.size.y
	var x := rect.position.x
	_pill(ci, Rect2(x + 10, y + 5, 104, h - 10))
	DirText.draw(ci, "Level %d" % level, Rect2(x + 10, y, 104, h), 20, NAVY, DirText.bold())
	_pill(ci, Rect2(x + 122, y + 7, 90, h - 14))
	DirText.draw(ci, timer, Rect2(x + 122, y, 90, h), 16, NAVY, DirText.bold())
	_pill(ci, Rect2(x + 220, y + 7, 82, h - 14))
	DirIcons.star(ci, Vector2(x + 240, y + h / 2.0), 10, SUN, star_line, true, 1.5)
	DirText.draw(ci, str(stars), Rect2(x + 254, y, 44, h), 16, NAVY, DirText.bold(), HORIZONTAL_ALIGNMENT_LEFT)
	var c := Vector2(x + 332, y + h / 2.0)
	ci.draw_circle(c + Vector2(0, 4), 21, Color("#b9c6e3"), true, -1.0, true)
	ci.draw_circle(c, 21, WHITE, true, -1.0, true)
	DirIcons.pause(ci, c, 18, NAVY)


func _pill(ci: CanvasItem, r: Rect2) -> void:
	panel(ci, Rect2(r.position + Vector2(0, 3), r.size), Color("#b9c6e3"), r.size.y / 2.0)
	panel(ci, r, WHITE, r.size.y / 2.0)


# Boxes and tray

## A toy bin painted in its color: the lid flipped up behind it, three cups, the symbol on a
## white sticker on the front.
func draw_box(ci: CanvasItem, rect: Rect2, color_index: int) -> void:
	var c := DirColors.color(color_index)
	var lid := Rect2(rect.position + Vector2(8, -6), Vector2(rect.size.x - 16, 12))
	panel(ci, lid, c.darkened(0.3), 6)
	panel(ci, lid.grow_individual(0, 0, 0, -4), c.darkened(0.1), 6)
	panel(ci, Rect2(rect.position + Vector2(0, 6), rect.size), Color(0.06, 0.1, 0.3, 0.3), 14)
	panel(ci, Rect2(rect.position + Vector2(0, 4), rect.size), c.darkened(0.3), 14)
	panel(ci, rect, c, 14, WHITE, 2)
	panel(ci, Rect2(rect.position + Vector2(6, 3), Vector2(rect.size.x - 12, 6)), Color(1, 1, 1, 0.3), 3)
	for w: Vector2 in well_centers(rect):
		draw_well(ci, w, 12.0, Color("#dde5f5"), 0.9)
	var tag := Vector2(rect.get_center().x, rect.end.y - 10)
	panel(ci, Rect2(tag - Vector2(16, 9), Vector2(32, 18)), WHITE, 9)
	DirSymbols.draw(ci, DirColors.symbol(color_index), tag, 7.5, c.darkened(0.45) if DirColors.luminance(c) > 0.3 else c)


func well_centers(rect: Rect2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for off: float in [6.0, 34.0, 62.0]:
		out.append(rect.position + Vector2(off + 12.0, 20.0))
	return out


func draw_preview(ci: CanvasItem, rect: Rect2, color_index: int) -> void:
	var c := DirColors.color(color_index)
	panel(ci, Rect2(rect.position + Vector2(0, 6), rect.size), Color(0.06, 0.1, 0.3, 0.3), 12)
	panel(ci, Rect2(rect.position + Vector2(0, 4), rect.size), c.darkened(0.3), 12)
	panel(ci, rect, c, 12, WHITE, 2)
	panel(ci, Rect2(rect.position + Vector2(6, 3), Vector2(rect.size.x - 12, 5)), Color(1, 1, 1, 0.3), 3)
	# The symbol straight on the paint (a white disc behind it would turn a circle into a ring).
	DirSymbols.draw(ci, DirColors.symbol(color_index), rect.get_center() + Vector2(0, 1), 10.5, DirColors.ink(color_index))


func draw_chevron(ci: CanvasItem, rect: Rect2) -> void:
	DirIcons.chevron(ci, rect.get_center(), 12, WHITE)


func draw_tray(ci: CanvasItem, frame: Rect2, slots: Array[Rect2]) -> void:
	panel(ci, Rect2(frame.position + Vector2(0, 7), frame.size), Color(0.06, 0.1, 0.3, 0.3), 26)
	panel(ci, Rect2(frame.position + Vector2(0, 5), frame.size), Color("#b9c6e3"), 26)
	panel(ci, frame, WHITE, 26)
	for s: Rect2 in slots:
		var c := s.get_center()
		ci.draw_circle(c, 19.0, Color("#c9d4ec"), true, -1.0, true)
		ci.draw_circle(c + Vector2(0, 1.5), 17.0, Color("#dde5f5"), true, -1.0, true)


func draw_helpers(ci: CanvasItem, rects: Array[Rect2], counts: Array[int]) -> void:
	var names: Array[String] = ["Undo", "Extra slot", "Screwdriver"]
	for i in rects.size():
		var r := rects[i]
		panel(ci, Rect2(r.position + Vector2(0, 5), r.size), secondary_edge, 18)
		panel(ci, r, WHITE, 18)
		_helper_icon(ci, i, Vector2(r.get_center().x, r.position.y + 21), 26, NAVY)
		DirText.draw(ci, names[i], Rect2(r.position.x, r.end.y - 20, r.size.x, 16), 13, NAVY, DirText.bold())
		var bc := Vector2(r.end.x - 6, r.position.y + 4)
		ci.draw_circle(bc + Vector2(0, 2), 13.0, Color("#c94a22"), true, -1.0, true)
		ci.draw_circle(bc, 13.0, badge, true, -1.0, true)
		ci.draw_arc(bc, 13.0, 0, TAU, 28, WHITE, 2.0, true)
		DirText.draw(ci, str(counts[i]), Rect2(bc - Vector2(12, 12), Vector2(24, 24)), 16, badge_text, DirText.bold())


func _helper_icon(ci: CanvasItem, i: int, c: Vector2, s: float, color: Color) -> void:
	if i == 2:
		DirIcons.screwdriver(ci, c, s, color, Color("#ff6b3d"))
	else:
		super._helper_icon(ci, i, c, s, color)


# Title

## The name in painted alphabet blocks, each tipped a little.
func draw_logo(ci: CanvasItem, rect: Rect2) -> void:
	var word := "WoodLogic"
	var colors: Array[int] = [DirColors.RED, DirColors.ORANGE, DirColors.YELLOW, DirColors.GREEN, DirColors.SKY,
		DirColors.BLUE, DirColors.PURPLE, DirColors.PINK, DirColors.RED]
	var tilt: Array[float] = [-6.0, 4.0, -3.0, 5.0, -5.0, 3.0, -4.0, 6.0, -2.0]
	var lift: Array[float] = [0.0, -6.0, 2.0, -3.0, 4.0, -5.0, 1.0, -4.0, 2.0]
	var step := 37.0
	var x0 := rect.get_center().x - step * (word.length() - 1) / 2.0
	var cy := rect.get_center().y
	for i in word.length():
		var c := Vector2(x0 + i * step, cy + lift[i])
		var col := DirColors.color(colors[i])
		ci.draw_set_transform(c, deg_to_rad(tilt[i]))
		var face := Rect2(-18, -22, 36, 42)
		panel(ci, Rect2(face.position + Vector2(1, 9), face.size), Color(0.06, 0.1, 0.3, 0.3), 7)
		panel(ci, Rect2(face.position + Vector2(0, 6), face.size), col.darkened(0.35), 7)
		panel(ci, face, col, 7)
		panel(ci, face.grow(-3.5), Color(0, 0, 0, 0), 5, Color(1, 1, 1, 0.55), 2)
		var ink := Color("#1d1a17") if DirColors.luminance(col) > 0.2 else WHITE
		DirText.draw(ci, word[i], face, 30, ink, DirText.bold())
		ci.draw_set_transform(Vector2.ZERO)


func draw_star_chip(ci: CanvasItem, rect: Rect2, stars: int) -> void:
	var r := Rect2(rect.position + Vector2(0, 8), Vector2(rect.size.x, 32))
	_pill(ci, r)
	DirIcons.star(ci, Vector2(r.position.x + 20, r.get_center().y), 10, SUN, star_line, true, 1.5)
	DirText.draw(ci, str(stars), Rect2(r.position.x + 34, r.position.y, r.size.x - 40, r.size.y), 16, NAVY, DirText.bold(), HORIZONTAL_ALIGNMENT_LEFT)


func draw_coffee_chip(ci: CanvasItem, rect: Rect2) -> void:
	var r := Rect2(rect.position + Vector2(0, 8), Vector2(rect.size.x, 32))
	panel(ci, r, Color(NAVY, 0.55), 16, Color(WHITE, 0.5), 1)
	DirIcons.cup(ci, Vector2(r.position.x + 18, r.get_center().y), 20, WHITE)
	DirText.draw(ci, "Buy me a coffee", Rect2(r.position.x + 32, r.position.y, r.size.x - 38, r.size.y), 13, WHITE, null, HORIZONTAL_ALIGNMENT_LEFT)


# Level clear

func draw_clear(ci: CanvasItem, r: Dictionary, level: int) -> void:
	var head: Rect2 = r["heading"]
	var card := Rect2(22, head.position.y - 20, 316, Rect2(r["summary"]).end.y - head.position.y + 40)
	panel(ci, Rect2(card.position + Vector2(0, 8), card.size), Color(0.06, 0.1, 0.3, 0.35), 26)
	panel(ci, card, WHITE, 26)
	var ribbon := Rect2(head.position.x + 50, head.position.y - 4, 260, head.size.y + 8)
	panel(ci, Rect2(ribbon.position + Vector2(0, 4), ribbon.size), Color("#c94a22"), 22)
	panel(ci, ribbon, Color("#ff6b3d"), 22)
	DirText.draw(ci, "Level %d cleared" % level, head, 24, Color("#2a0f00"), DirText.bold())
	draw_star_row(ci, r["stars"], [true, true, false])
	var labels: Array[String] = ["Cleared", "Fast", "Clean"]
	var details: Array[Array] = [["Every screw", "is out"], ["Under 1:20", "Yours 1:12"], ["Tray 2 times", "no helpers"]]
	var cap: Rect2 = r["captions"]
	for i in 3:
		var col := Rect2(cap.position.x + i * 100, cap.position.y, 100, cap.size.y)
		DirText.draw(ci, labels[i], Rect2(col.position + Vector2(0, 2), Vector2(100, 24)), 18, NAVY, DirText.bold())
		for j in 2:
			DirText.draw(ci, details[i][j], Rect2(col.position + Vector2(0, 28 + j * 17), Vector2(100, 16)), 13, text_dim)
	DirText.draw(ci, "+2 stars", r["summary"], 20, NAVY, DirText.bold())
	draw_button(ci, r["next"], "Next", "Level %d" % (level + 1), "primary")
	var nx: Rect2 = r["next"]
	DirIcons.arrow_right(ci, Vector2(nx.end.x - 44, nx.get_center().y), 22, primary_text)
	draw_button(ci, r["replay"], "Replay", "", "secondary")


## Glossy stars with a white sticker edge; the missed one is a dashed outline.
func draw_star_row(ci: CanvasItem, rect: Rect2, earned: Array) -> void:
	for i in 3:
		var c := Vector2(rect.position.x + 36 + i * 96, rect.get_center().y + (-6.0 if i == 1 else 0.0))
		if earned[i]:
			ci.draw_colored_polygon(DirIcons.star_points(c + Vector2(0, 5), 38, 0.5), Color(0.06, 0.1, 0.3, 0.25))
			ci.draw_colored_polygon(DirIcons.star_points(c, 38, 0.5), WHITE)
			ci.draw_colored_polygon(DirIcons.star_points(c, 33, 0.5), SUN)
			ci.draw_colored_polygon(DirIcons.star_points(c - Vector2(5, 7), 12, 0.5), Color(1, 1, 1, 0.55))
		else:
			DirIcons.star(ci, c, 34, Color(), Color(NAVY, 0.55), false, 3.0)


## Confetti in the screw colors bursting out from behind the card, and soft rays.
func draw_celebration(ci: CanvasItem, size: Vector2, r: Dictionary) -> void:
	var center: Vector2 = Rect2(r["stars"]).get_center()
	for i in 12:
		var a := TAU * i / 12.0
		var pts := PackedVector2Array([center, center + Vector2(cos(a - 0.12), sin(a - 0.12)) * 420.0,
			center + Vector2(cos(a + 0.12), sin(a + 0.12)) * 420.0])
		ci.draw_colored_polygon(pts, Color(1, 1, 1, 0.07))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 70:
		var a := rng.randf_range(0, TAU)
		var d := rng.randf_range(120, 330)
		var p := center + Vector2(cos(a), sin(a) * 1.4) * d
		if p.y > size.y * 0.78 or p.y < 0:
			continue
		var c := DirColors.color(rng.randi_range(0, 8))
		ci.draw_set_transform(p, rng.randf_range(0, TAU))
		if i % 3 == 0:
			ci.draw_circle(Vector2.ZERO, 4.0, c, true, -1.0, true)
		else:
			ci.draw_rect(Rect2(-5, -2.5, 10, 5), c)
		ci.draw_set_transform(Vector2.ZERO)
