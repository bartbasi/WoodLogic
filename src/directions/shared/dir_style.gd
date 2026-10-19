# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name DirStyle
extends Resource
## Base for a Phase 1 look direction. DirView builds the screens and asks the style how every
## part looks. A direction overrides the tokens in _init and any draw method it wants to make
## its own. Rects come from DirLayout (docs/UX.md); a style never moves them.

var label := "Direction"

# UI tokens. Text pairs are chosen for at least 4.5:1 contrast.
var bg := Color("#444444")
var text := Color("#f5efe6")
var text_dim := Color("#e0d6c8")
var plaque := Color("#2a1d14")
var plaque_border := Color(1, 1, 1, 0.12)
var primary := Color("#e0a33c")
var primary_text := Color("#2a1708")
var primary_edge := Color("#9c6a1c")
var secondary := Color("#5b3d27")
var secondary_text := Color("#fbf2e4")
var secondary_edge := Color("#3a2618")
var quiet_text := Color("#f5efe6")
var quiet_line := Color(1, 1, 1, 0.35)
var badge := Color("#e0a33c")
var badge_text := Color("#2a1708")
var star_fill := Color("#f0b53c")
var star_line := Color("#6b4413")
var warn := Color("#e9a23b")
var veil := Color(0, 0, 0, 0.45)
var corner := 12
var bold_buttons := true


func background_material() -> ShaderMaterial:
	return null


func draw_background(ci: CanvasItem, size: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), bg)


## Common settings for planks on the board.
func plank_look() -> Dictionary:
	return {"thickness": 6.0, "edge_dir": Vector2(0.25, 1.0), "shadow": Vector2(4, 7), "shadow_per_layer": 0.35,
		"shadow_blur": 6.0, "shadow_alpha": 0.4, "shadow_color": Color(0.1, 0.06, 0.03), "light": Vector2(-0.5, -0.85),
		"bevel": 4.0, "bevel_strength": 1.2, "hole_radius": 6.0}


## Settings for the back board (it casts its shadow on the background).
func board_look() -> Dictionary:
	var look := plank_look()
	look["thickness"] = 8.0
	look["shadow"] = Vector2(0, 10)
	look["shadow_blur"] = 14.0
	look["shadow_alpha"] = 0.5
	look["shadow_per_layer"] = 0.0
	return look


func board_wood() -> Dictionary:
	return {"wood_light": Color("#7a5236"), "wood_dark": Color("#5a3a24"), "edge_color": Color("#4a2e1c")}


## The wood for plank number i (the layout's "wood" index), cycled through the theme's tones.
func plank_wood(_i: int) -> Dictionary:
	return {"wood_light": Color("#d9ae74"), "wood_dark": Color("#b98448"), "edge_color": Color("#8f5f30")}


func screw_finish() -> Dictionary:
	return {}


## The panel behind the screw sheet in the boxes view.
func kit_back() -> Color:
	return Color(plaque, 0.55)


func ghost_strength() -> float:
	return 0.45


func ghost_ring() -> Color:
	return Color(0.1, 0.06, 0.03, 0.6)


# Drawing helpers

## A rounded panel with an optional border and soft shadow (StyleBoxFlat draws it antialiased).
func panel(ci: CanvasItem, rect: Rect2, fill: Color, radius: float = -1.0, border: Color = Color(0, 0, 0, 0),
		border_w: int = 0, shadow: Color = Color(0, 0, 0, 0), shadow_size: int = 0, shadow_off: Vector2 = Vector2.ZERO) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius if radius >= 0.0 else corner))
	sb.corner_detail = 10
	sb.anti_aliasing = true
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	if shadow_size > 0:
		sb.shadow_color = shadow
		sb.shadow_size = shadow_size
		sb.shadow_offset = shadow_off
	ci.draw_style_box(sb, rect)


## A button with a lower lip that reads as a pressable block. kind: primary, secondary, quiet.
func draw_button(ci: CanvasItem, rect: Rect2, title: String, note: String, kind: String) -> void:
	var fill := primary if kind == "primary" else secondary
	var edge := primary_edge if kind == "primary" else secondary_edge
	var ink := primary_text if kind == "primary" else secondary_text
	if kind == "quiet":
		panel(ci, rect, Color(0, 0, 0, 0), -1, quiet_line, 2)
		DirText.draw(ci, title, rect, 18, quiet_text, DirText.bold())
		return
	panel(ci, Rect2(rect.position + Vector2(0, 4), rect.size), edge, -1, Color(), 0, Color(0, 0, 0, 0.3), 6, Vector2(0, 3))
	panel(ci, rect, fill)
	_button_text(ci, rect, title, note, kind, ink)


func _button_text(ci: CanvasItem, rect: Rect2, title: String, note: String, kind: String, ink: Color) -> void:
	var size := 22 if kind == "primary" else 18
	if note == "":
		DirText.draw(ci, title, rect, size, ink, DirText.bold())
	else:
		var top := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.6))
		var bottom := Rect2(rect.position + Vector2(0, rect.size.y * 0.52), Vector2(rect.size.x, rect.size.y * 0.4))
		DirText.draw(ci, title, top.grow_individual(0, -2, 0, -2), size, ink, DirText.bold())
		DirText.draw(ci, note, bottom, 13 if kind != "primary" else 14, ink)


## An empty well: a hollow, lit from above, so its upper inside wall is in shadow and its
## lower lip catches the light. Its color is the neutral of the tray slots, never the box
## color, so an empty well can't be mistaken for a screw.
func draw_well(ci: CanvasItem, c: Vector2, r: float, base: Color, depth: float = 1.0) -> void:
	ci.draw_circle(c, r, base, true, -1.0, true)
	ci.draw_arc(c, r - 1.6, PI * 1.02, PI * 1.98, 16, Color(0, 0, 0, 0.32 * depth), 3.2, true)
	ci.draw_arc(c, r - 0.7, PI * 0.12, PI * 0.88, 16, Color(1, 1, 1, 0.38), 1.4, true)


# Level screen

func draw_top_bar(ci: CanvasItem, rect: Rect2, level: int, timer: String, stars: int) -> void:
	var y := rect.position.y
	var h := rect.size.y
	var x := rect.position.x
	panel(ci, Rect2(x + 8, y + 4, 100, h - 8), plaque, -1, plaque_border, 1)
	DirText.draw(ci, "Level %d" % level, Rect2(x + 8, y, 100, h), 20, text, DirText.bold())
	panel(ci, Rect2(x + 116, y + 6, 96, h - 12), plaque, -1, plaque_border, 1)
	DirText.draw(ci, timer, Rect2(x + 116, y, 96, h), 16, text)
	panel(ci, Rect2(x + 224, y + 6, 76, h - 12), plaque, -1, plaque_border, 1)
	DirIcons.star(ci, Vector2(x + 242, y + h / 2.0), 9, star_fill, star_line, true, 1.5)
	DirText.draw(ci, str(stars), Rect2(x + 254, y, 42, h), 16, text, DirText.bold())
	panel(ci, Rect2(x + 310, y + 2, 44, h - 4), plaque, -1, plaque_border, 1)
	DirIcons.pause(ci, Vector2(x + 332, y + h / 2.0), 20, text)


## Box well centers, by docs/UX.md: wells 24 across at x offsets 6, 34, 62, centers 22 below
## the top of the box.
func well_centers(rect: Rect2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for off: float in [6.0, 34.0, 62.0]:
		out.append(rect.position + Vector2(off + 12.0, 22.0))
	return out


func draw_box(ci: CanvasItem, rect: Rect2, color_index: int) -> void:
	var c := DirColors.color(color_index)
	panel(ci, rect, c.darkened(0.2), 8)
	for w: Vector2 in well_centers(rect):
		ci.draw_circle(w, 12, Color(0, 0, 0, 0.35), true, -1.0, true)
	DirSymbols.draw(ci, DirColors.symbol(color_index), Vector2(rect.get_center().x, rect.end.y - 9), 7, DirColors.ink(color_index))


func draw_preview(ci: CanvasItem, rect: Rect2, color_index: int) -> void:
	var c := DirColors.color(color_index)
	panel(ci, rect, c, 8)
	DirSymbols.draw(ci, DirColors.symbol(color_index), rect.get_center(), 10, DirColors.ink(color_index))


func draw_chevron(ci: CanvasItem, rect: Rect2) -> void:
	DirIcons.chevron(ci, rect.get_center(), 12, Color(text, 0.7))


func draw_tray(ci: CanvasItem, frame: Rect2, slots: Array[Rect2]) -> void:
	panel(ci, frame, plaque, 12)
	for s: Rect2 in slots:
		ci.draw_circle(s.get_center(), 17, Color(0, 0, 0, 0.35), true, -1.0, true)


func draw_helpers(ci: CanvasItem, rects: Array[Rect2], counts: Array[int]) -> void:
	var names: Array[String] = ["Undo", "Extra slot", "Screwdriver"]
	for i in rects.size():
		var r := rects[i]
		panel(ci, Rect2(r.position + Vector2(0, 3), r.size), secondary_edge)
		panel(ci, r, secondary)
		var ic := Vector2(r.get_center().x, r.position.y + r.size.y * 0.38)
		_helper_icon(ci, i, ic, 26, secondary_text)
		DirText.draw(ci, names[i], Rect2(r.position.x, r.end.y - 22, r.size.x, 18), 13, secondary_text)
		var bc := Vector2(r.end.x - 8, r.position.y + 6)
		ci.draw_circle(bc, 12, badge, true, -1.0, true)
		DirText.draw(ci, str(counts[i]), Rect2(bc - Vector2(12, 12), Vector2(24, 24)), 16, badge_text, DirText.bold())


func _helper_icon(ci: CanvasItem, i: int, c: Vector2, s: float, color: Color) -> void:
	match i:
		0:
			DirIcons.undo(ci, c, s, color)
		1:
			DirIcons.extra_slot(ci, c, s, color)
		_:
			DirIcons.screwdriver(ci, c, s, color, Color(primary, 0.95))


# Title

func draw_star_chip(ci: CanvasItem, rect: Rect2, stars: int) -> void:
	var r := Rect2(rect.position + Vector2(0, 8), Vector2(rect.size.x, 32))
	panel(ci, r, plaque, 16, plaque_border, 1)
	DirIcons.star(ci, Vector2(r.position.x + 20, r.get_center().y), 9, star_fill, star_line, true, 1.5)
	DirText.draw(ci, str(stars), Rect2(r.position.x + 32, r.position.y, r.size.x - 40, r.size.y), 16, text, DirText.bold())


func draw_coffee_chip(ci: CanvasItem, rect: Rect2) -> void:
	var r := Rect2(rect.position + Vector2(0, 8), Vector2(rect.size.x, 32))
	panel(ci, r, plaque, 16, plaque_border, 1)
	DirIcons.cup(ci, Vector2(r.position.x + 18, r.get_center().y), 20, text)
	DirText.draw(ci, "Buy me a coffee", Rect2(r.position.x + 30, r.position.y, r.size.x - 34, r.size.y), 13, text)


## Planks drawn behind the name on the title (screen coordinates, with a "wood" index and
## optional "screws": [{pos, color}]). Empty for a name on a plain plaque.
func logo_planks(_rect: Rect2) -> Array[Dictionary]:
	return []


func draw_logo(ci: CanvasItem, rect: Rect2) -> void:
	DirText.draw(ci, "WoodLogic", rect, 32, text, DirText.wide())


## Behind the decorative planks on the title.
func draw_deco_back(_ci: CanvasItem, _rect: Rect2) -> void:
	pass


# Level clear

func draw_veil(ci: CanvasItem, size: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), veil)


func draw_clear(ci: CanvasItem, r: Dictionary, level: int) -> void:
	var head: Rect2 = r["heading"]
	panel(ci, head.grow_individual(-40, 4, -40, 4), plaque, -1, plaque_border, 1)
	DirText.draw(ci, "Level %d cleared" % level, head, 24, text, DirText.bold())
	draw_star_row(ci, r["stars"], [true, true, false])
	draw_captions(ci, r["captions"])
	var sum: Rect2 = r["summary"]
	panel(ci, sum.grow(4), plaque, -1, plaque_border, 1)
	DirText.draw(ci, "+2 stars", sum, 20, text, DirText.bold())
	draw_button(ci, r["next"], "Next", "Level %d" % (level + 1), "primary")
	var nx: Rect2 = r["next"]
	DirIcons.arrow_right(ci, Vector2(nx.end.x - 40, nx.get_center().y), 24, primary_text)
	draw_button(ci, r["replay"], "Replay", "", "secondary")


func draw_star_row(ci: CanvasItem, rect: Rect2, earned: Array) -> void:
	for i in 3:
		var c := Vector2(rect.position.x + 36 + i * 96, rect.get_center().y)
		DirIcons.star(ci, c, 36, star_fill, star_line, earned[i], 3.0)


func draw_captions(ci: CanvasItem, rect: Rect2) -> void:
	var labels: Array[String] = ["Cleared", "Fast", "Clean"]
	var details: Array[String] = ["Every screw is out", "Under 1:20", "Tray 2 times or fewer"]
	panel(ci, rect.grow(4), plaque, -1, plaque_border, 1)
	for i in 3:
		var col := Rect2(rect.position.x + i * 100, rect.position.y, 100, rect.size.y)
		DirText.draw(ci, labels[i], Rect2(col.position + Vector2(0, 4), Vector2(100, 26)), 18, text, DirText.bold())
		DirText.draw(ci, details[i], Rect2(col.position + Vector2(2, 30), Vector2(96, 18)), 13, text_dim)
		if i == 1:
			DirText.draw(ci, "Yours 1:12", Rect2(col.position + Vector2(2, 48), Vector2(96, 18)), 13, text_dim)


func draw_celebration(_ci: CanvasItem, _size: Vector2, _r: Dictionary) -> void:
	pass
