# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name DirView
extends Node2D
## Builds one Phase 1 mock-up screen (board, boxes, clear or title) in one direction's style.
## Everything is laid out in design units (360 wide) from DirLayout and scaled to the
## viewport, so the same scene works in a stretched window and in the capture tool's
## 1080 x 2400 SubViewport. These are still frames: nothing here is interactive.

@export var style: DirStyle
@export_enum("board", "boxes", "clear", "title") var view := "board"

var size := Vector2(360, 640)


func _ready() -> void:
	if style == null:
		style = DirStyle.new()
	var vp := get_viewport_rect().size
	var k := vp.x / 360.0
	scale = Vector2(k, k)
	size = vp / k
	_add_background()
	match view:
		"board":
			_build_level(false)
		"boxes":
			_build_kit()
		"clear":
			_build_clear()
		"title":
			_build_title()


func _paint(fn: Callable, parent: Node = self) -> DirPainter:
	var p := DirPainter.new(fn)
	parent.add_child(p)
	return p


func _add_background() -> void:
	var p := _paint(func(ci: CanvasItem) -> void: style.draw_background(ci, size))
	var mat := style.background_material()
	if mat != null:
		mat.set_shader_parameter("size", size)
		p.material = mat


func _screw(parent: Node, pos: Vector2, color_index: int, radius: float, turn: float = 0.0) -> DirScrew:
	var s := DirScrew.new()
	s.position = pos
	parent.add_child(s)
	s.setup(color_index, radius, style.screw_finish(), turn)
	return s


# Level screen

func _build_level(empty: bool) -> Dictionary:
	var bands := DirLayout.level_bands(size)
	var board_band: Rect2 = bands["board"]
	_build_board(board_band, empty)
	if not empty:
		_build_top(bands)
		var helper_band: Rect2 = bands["helpers"]
		var rects: Array[Rect2] = []
		for i in 3:
			rects.append(Rect2(helper_band.position.x + 12 + i * 116, helper_band.get_center().y - 28, 104, 56))
		_paint(func(ci: CanvasItem) -> void: style.draw_helpers(ci, rects, DirLayout.HELPERS))
	return bands


## The top bar, the box row and the tray.
func _build_top(bands: Dictionary) -> void:
	var top: Rect2 = bands["top"]
	_paint(func(ci: CanvasItem) -> void: style.draw_top_bar(ci, top, DirLayout.LEVEL, DirLayout.TIMER, DirLayout.STAR_BANK))
	var row: Rect2 = bands["boxes"]
	var x0 := row.position.x
	var cy := row.get_center().y
	var open_rects: Array[Rect2] = [Rect2(x0 + 12, cy - 28, 92, 56), Rect2(x0 + 112, cy - 28, 92, 56)]
	var prev_rects: Array[Rect2] = [Rect2(x0 + 216, cy - 22, 62, 44), Rect2(x0 + 286, cy - 22, 62, 44)]
	var chev := Rect2(x0 + 205, cy - 10, 10, 20)
	var box_layer := _paint(func(ci: CanvasItem) -> void:
		for i in open_rects.size():
			style.draw_box(ci, open_rects[i], DirLayout.OPEN_BOXES[i].x)
		style.draw_chevron(ci, chev)
		for i in prev_rects.size():
			style.draw_preview(ci, prev_rects[i], DirLayout.PREVIEW[i]))
	for i in open_rects.size():
		var wells := style.well_centers(open_rects[i])
		for j in DirLayout.OPEN_BOXES[i].y:
			_screw(box_layer, wells[j], DirLayout.OPEN_BOXES[i].x, DirLayout.BOX_HEAD / 2.0, 0.3 * j)
	var tray_band: Rect2 = bands["tray"]
	var frame := Rect2(tray_band.get_center().x - 130, tray_band.position.y, 260, tray_band.size.y)
	var slots: Array[Rect2] = []
	for i in DirLayout.TRAY_SLOTS:
		slots.append(Rect2(frame.position.x + 8 + i * 50, frame.get_center().y - 22, 44, 44))
	var tray_layer := _paint(func(ci: CanvasItem) -> void: style.draw_tray(ci, frame, slots))
	for i in DirLayout.TRAY.size():
		_screw(tray_layer, slots[i].get_center(), DirLayout.TRAY[i], DirLayout.HEAD / 2.0, 0.5 + i)


## The back board and, unless empty, the planks, screws and ghosts in layer order.
func _build_board(band: Rect2, empty: bool) -> Node2D:
	var board := Node2D.new()
	board.position = band.get_center()
	add_child(board)
	var back := DirPlank.new()
	board.add_child(back)
	var back_def := {"shape": "plate", "layer": 0, "size": Vector2(band.size.x - 8, band.size.y - 6), "corner": 14.0, "holes": []}
	back.setup(back_def, style.board_wood(), style.board_look(), 99)
	if empty:
		return board
	var planks := DirLayout.planks()
	var screws := DirLayout.screws(planks)
	var problems := DirLayout.spacing_problems(planks)
	for p: String in problems:
		push_warning("Board layout: " + p)
	for layer in 3:
		for i in planks.size():
			if int(planks[i]["layer"]) != layer:
				continue
			var node := DirPlank.new()
			board.add_child(node)
			node.setup(planks[i], style.plank_wood(int(planks[i].get("wood", i))), style.plank_look(), i)
			for s: Dictionary in screws:
				if s["plank"] == i:
					_screw(board, s["pos"], s["color"], DirLayout.HEAD / 2.0, sin(float(i) * 2.3 + Vector2(s["pos"]).x) * 0.12)
		for s: Dictionary in screws:
			if s["covered"] and int(planks[s["cover"]]["layer"]) == layer:
				var g := DirGhost.new()
				g.position = s["pos"]
				g.color_index = s["color"]
				g.radius = DirLayout.HEAD / 2.0
				g.strength = style.ghost_strength()
				g.ring_color = style.ghost_ring()
				board.add_child(g)
	return board


# Boxes and screws sheet

## The real box row and tray at the top, then the full proposed screw set large, then a close
## look at an open box beside a preview box and a free screw beside a covered one.
func _build_kit() -> void:
	var bands := DirLayout.level_bands(size)
	_build_top(bands)
	var y: float = Rect2(bands["tray"]).end.y + 14
	var head := Rect2(12, y, 336, 30)
	_paint(func(ci: CanvasItem) -> void:
		style.panel(ci, head, style.plaque, -1, style.plaque_border, 1)
		DirText.draw(ci, "Screw colors and symbols", head, 16, style.text, DirText.bold()))
	y += 38
	var cell := Vector2(112, 86)
	var grid := Rect2(12, y, 336, cell.y * 3 + 8)
	var grid_layer := _paint(func(ci: CanvasItem) -> void:
		style.panel(ci, grid, style.kit_back(), -1)
		for i in DirColors.COLORS.size():
			var c := Vector2(12 + 56 + (i % 3) * cell.x, y + 4 + floori(i / 3.0) * cell.y)
			var cap := Rect2(c.x - 54, c.y + 56, 108, 20)
			style.panel(ci, cap, style.plaque, 6)
			DirText.draw(ci, "%s, %s" % [DirColors.NAMES[i].capitalize(), DirColors.SYMBOL_NAMES[i]], cap, 13, style.text))
	for i in DirColors.COLORS.size():
		var c := Vector2(12 + 56 + (i % 3) * cell.x, y + 4 + floori(i / 3.0) * cell.y + 28)
		_screw(grid_layer, c, i, 24.0, 0.0)
	y = grid.end.y + 10
	# Close-up: an open box with two screws and a preview box, at twice the size.
	var zoom := Node2D.new()
	zoom.scale = Vector2(2, 2)
	zoom.position = Vector2(12, y)
	add_child(zoom)
	var box := Rect2(0, 2, 92, 56)
	var prev := Rect2(100, 8, 62, 44)
	var zl := _paint(func(ci: CanvasItem) -> void:
		style.draw_box(ci, box, DirColors.PINK)
		style.draw_preview(ci, prev, DirColors.SKY), zoom)
	var wells := style.well_centers(box)
	_screw(zl, wells[0], DirColors.PINK, DirLayout.BOX_HEAD / 2.0, 0.0)
	_screw(zl, wells[1], DirColors.PINK, DirLayout.BOX_HEAD / 2.0, 0.6)
	y += 128
	# Free and covered: a free screw, and one under the plank in front of it, at 1.5 times size.
	var sample := Node2D.new()
	sample.position = Vector2(180 - 16 * 1.5, y + 34)
	sample.scale = Vector2(1.5, 1.5)
	add_child(sample)
	var lower := DirPlank.new()
	sample.add_child(lower)
	lower.setup({"shape": "bar", "layer": 0, "pos": Vector2(-20, 0), "size": Vector2(130, 36), "corner": 10.0,
		"holes": [Vector2(-45, 0), Vector2(45, 0)]}, style.plank_wood(1), style.plank_look(), 11)
	_screw(sample, Vector2(-65, 0), DirColors.ORANGE, DirLayout.HEAD / 2.0, 0.1)
	_screw(sample, Vector2(25, 0), DirColors.BLUE, DirLayout.HEAD / 2.0, 0.0)
	var upper := DirPlank.new()
	sample.add_child(upper)
	upper.setup({"shape": "bar", "layer": 1, "pos": Vector2(62, 2), "rot": 6.0, "size": Vector2(110, 40), "corner": 10.0,
		"holes": [Vector2(10, 0), Vector2(40, 0)]}, style.plank_wood(4), style.plank_look(), 12)
	_screw(sample, Vector2(62, 2) + Vector2(40, 0).rotated(deg_to_rad(6)), DirColors.PURPLE, DirLayout.HEAD / 2.0, -0.1)
	var g := DirGhost.new()
	g.position = Vector2(25, 0)
	g.color_index = DirColors.BLUE
	g.radius = DirLayout.HEAD / 2.0
	g.strength = style.ghost_strength()
	g.ring_color = style.ghost_ring()
	sample.add_child(g)
	var cap_y := y + 34 + 36
	_paint(func(ci: CanvasItem) -> void:
		for item: Array in [[180 - 16 * 1.5 - 65 * 1.5, "Free"], [180 - 16 * 1.5 + 25 * 1.5, "Covered"]]:
			var cap := Rect2(float(item[0]) - 40, cap_y, 80, 22)
			style.panel(ci, cap, style.plaque, 6)
			DirText.draw(ci, item[1], cap, 13, style.text))


# Level clear

func _build_clear() -> void:
	var bands := DirLayout.level_bands(size)
	var board := _build_board(bands["board"], true)
	# The last plank on its way down, a still frame of the fall.
	var falling := DirPlank.new()
	board.add_child(falling)
	var bh: float = Rect2(bands["board"]).size.y
	falling.setup({"shape": "bar", "layer": 2, "pos": Vector2(-60, bh * 0.12), "rot": -32.0, "size": Vector2(170, 44),
		"corner": 12.0, "holes": [Vector2(-60, 0), Vector2(60, 0)]}, style.plank_wood(4), style.plank_look(), 4)
	var r := DirLayout.clear_rects(size)
	_paint(func(ci: CanvasItem) -> void: style.draw_veil(ci, size))
	_paint(func(ci: CanvasItem) -> void: style.draw_celebration(ci, size, r))
	_paint(func(ci: CanvasItem) -> void: style.draw_clear(ci, r, DirLayout.LEVEL))


# Title

func _build_title() -> void:
	var r := DirLayout.title_rects(size)
	var deco: Rect2 = r["deco"]
	_paint(func(ci: CanvasItem) -> void:
		style.draw_star_chip(ci, r["stars"], DirLayout.STAR_BANK)
		style.draw_coffee_chip(ci, r["coffee"])
		style.draw_deco_back(ci, deco))
	var logo := style.logo_planks(r["name"])
	for i in logo.size():
		var lp := DirPlank.new()
		add_child(lp)
		lp.setup(logo[i], style.plank_wood(int(logo[i].get("wood", 0))), style.plank_look(), 40 + i)
	for i in logo.size():
		for s: Dictionary in logo[i].get("screws", []):
			_screw(self, s["pos"], s["color"], float(s.get("radius", DirLayout.HEAD / 2.0)), float(s.get("turn", 0.3)))
	_paint(func(ci: CanvasItem) -> void: style.draw_logo(ci, r["name"]))
	var holder := Node2D.new()
	holder.position = deco.get_center()
	var k := clampf(minf(deco.size.x / 312.0, deco.size.y / 120.0), 1.0, 1.3)
	holder.scale = Vector2(k, k)
	add_child(holder)
	var planks := DirLayout.title_planks()
	for layer in 3:
		for i in planks.size():
			if int(planks[i]["layer"]) != layer:
				continue
			var node := DirPlank.new()
			holder.add_child(node)
			node.setup(planks[i], style.plank_wood(int(planks[i]["wood"])), style.plank_look(), 20 + i)
			var rot := deg_to_rad(float(planks[i]["rot"]))
			var screw_map: Dictionary = planks[i]["screws"]
			for h: int in screw_map:
				var pos: Vector2 = Vector2(planks[i]["pos"]) + Vector2(planks[i]["holes"][h]).rotated(rot)
				_screw(holder, pos, screw_map[h], DirLayout.HEAD / 2.0, 0.4 * i + h)
	_paint(func(ci: CanvasItem) -> void:
		style.draw_button(ci, r["play"], "Play", "Level %d" % DirLayout.LEVEL, "primary")
		style.draw_button(ci, r["daily"], "Daily", "Today's puzzle", "secondary")
		style.draw_button(ci, r["relaxed"], "Relaxed", "No clock", "secondary")
		style.draw_button(ci, r["levels"], "Levels", "", "secondary")
		style.draw_button(ci, r["stats"], "Stats", "", "secondary")
		style.draw_button(ci, r["settings"], "Settings", "", "secondary")
		style.draw_button(ci, r["about"], "About", "", "secondary"))
