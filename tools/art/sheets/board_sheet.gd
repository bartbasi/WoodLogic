# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends Node2D
## A real generated level, played part way along its own solution, drawn with src/render's views
## at the level screen's layout (LevelLayout), for review screenshots of the look at any screen
## size. The top bar and helper bar here are simple stand-ins; the level scene draws the real
## ones. tools/art/capture.gd renders it; the viewport size picks the layout.

const LEVEL := 34
## How much of the solution to play before the shot.
const PLAYED := 0.3

var _planks: Array[PlankView] = []
var _board: BoardView


func _ready() -> void:
	# SHEET_WOOD and SHEET_METAL pick another look for the shot.
	if OS.get_environment("SHEET_WOOD") != "":
		Looks.current["wood"] = OS.get_environment("SHEET_WOOD")
	if OS.get_environment("SHEET_METAL") != "":
		Looks.current["metal"] = OS.get_environment("SHEET_METAL")
	var vp := get_viewport_rect().size
	# Phones are 360 units wide; wider viewports are drawn at 3 pixels a unit like the phones.
	var k := vp.x / 360.0 if vp.x / vp.y < 0.6 else vp.y / 640.0
	scale = Vector2(k, k)
	var size := vp / k
	var dpu := 1.0 if size.x <= 400.0 else 1.46
	var content := Rect2(0.0, 24.0, size.x, size.y - 40.0)
	var layout := LevelLayout.compute(content, dpu)
	LevelCatalog.load_all()
	var level := LevelCatalog.get_level(LevelData.NUMBERED, LEVEL, "").level
	var state := PlayState.start(level)
	var moves := LevelCatalog.get_level(LevelData.NUMBERED, LEVEL, "").solve.solution
	for i in int(moves.size() * PLAYED):
		state.tap(moves[i])

	_board = BoardView.new()
	add_child(_board)
	var panels: Array[Rect2] = [layout.panel]
	if layout.split:
		panels.append(layout.rail)
	_board.setup(size, panels)

	var root := Node2D.new()
	root.position = layout.core_origin
	root.scale = Vector2.ONE * layout.b
	add_child(root)
	var order: Array[int] = []
	for p in level.planks.size():
		order.append(p)
	order.sort_custom(func(a: int, b: int) -> bool: return level.planks[a].layer > level.planks[b].layer)
	for p: int in order:
		if state.plank_state(p) == PlayState.FALLEN:
			continue
		var data: PlankData = level.planks[p]
		var view := PlankView.new()
		root.add_child(view)
		view.setup(data.outline(), data.inner_outline(), data.layer, data.holes, p * 7919 + level.number)
		var pose := state.plank_pose(p)
		if state.plank_state(p) == PlayState.HANGING:
			var about := Vector2(pose.x, pose.y) * 4.0
			var r := deg_to_rad(pose.z)
			view.rotation = r
			view.position = about - about.rotated(r)
		_planks.append(view)

	var screws := Node2D.new()
	add_child(screws)
	for s in level.screw_count():
		if not state.is_on_board(s):
			continue
		var v := ScrewView.new()
		v.setup(level.screw_colors[s], ScrewView.BOARD)
		v.set_covered(not state.is_free(s))
		v.set_turn(float((s * 37) % 20 - 10))
		v.position = layout.gu_to_scene(level.screw_center(s))
		v.scale = Vector2.ONE * layout.b
		screws.add_child(v)

	for pos in layout.open_pos.size():
		var info := state.open_box(pos)
		if info.x < 0:
			continue
		var box := BoxView.new()
		box.setup(info.x, false)
		box.position = layout.open_pos[pos]
		box.scale = Vector2.ONE * layout.box_scale
		add_child(box)
		for well in info.y:
			var sv := ScrewView.new()
			sv.setup(info.x, ScrewView.WELL)
			sv.position = layout.well_center(pos, well)
			sv.scale = Vector2.ONE * layout.box_scale
			sv.set_turn(well * 25.0)
			add_child(sv)
	var preview := state.preview()
	for k2 in mini(preview.size(), layout.preview_pos.size()):
		var pv := BoxView.new()
		pv.setup(preview[k2], true)
		pv.position = layout.preview_pos[k2]
		pv.scale = Vector2.ONE * layout.box_scale
		add_child(pv)
	var tray_ids := state.tray()
	var tray := TrayView.new()
	tray.setup(tray_ids.size())
	var filled := PackedByteArray()
	var free := 0
	for id: int in tray_ids:
		filled.append(1 if id >= 0 else 0)
		free += 1 if id < 0 else 0
	tray.set_filled(filled)
	tray.set_warning(free == 1)
	tray.set_full(free == 0)
	tray.position = layout.tray_center
	tray.scale = Vector2.ONE * layout.box_scale
	add_child(tray)
	for slot in tray_ids.size():
		if tray_ids[slot] < 0:
			continue
		var tv := ScrewView.new()
		tv.setup(level.screw_colors[tray_ids[slot]], ScrewView.TRAY)
		tv.position = layout.tray_slot_center(slot, tray_ids.size())
		tv.scale = Vector2.ONE * layout.box_scale
		add_child(tv)

	# For measuring: SHEET_SKIP=boxes,bars,screws leaves those out.
	var skip := OS.get_environment("SHEET_SKIP").split(",")
	for child: Node in get_children():
		if (skip.has("boxes") and (child is BoxView or child is TrayView or (child is ScrewView and child.get_parent() == self))) 				or (skip.has("screws") and child == screws):
			child.queue_free()
	var bars := Bars.new()
	bars.layout = layout
	if not skip.has("bars"):
		add_child(bars)
	_board.bake()
	for p: PlankView in _planks:
		p.bake()


## Stand-ins for the level's own top bar and helper bar.
class Bars extends Node2D:
	var layout: LevelLayout

	func _draw() -> void:
		var f := layout.f
		var top := layout.top_bar
		var y := top.get_center().y
		var font := ThemeDB.fallback_font
		Paint.panel(self, Rect2(top.position + Vector2(8, 4) * f, Vector2(top.size.x - 70 * f, top.size.y - 8 * f)), Tokens.PLAQUE, 8, Tokens.PLAQUE_BORDER, 1)
		draw_string(font, Vector2(top.position.x + 18 * f, y + 7 * f), "Level %d" % LEVEL, HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * f), Tokens.TEXT)
		Icons.draw(self, "stopwatch", Vector2(top.position.x + 150 * f, y), 16 * f, Tokens.TEXT_DIM)
		draw_string(font, Vector2(top.position.x + 162 * f, y + 6 * f), "1:12", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * f), Tokens.TEXT)
		Icons.draw(self, "star", Vector2(top.end.x - 110 * f, y), 18 * f, Tokens.STAR_FACE)
		draw_string(font, Vector2(top.end.x - 98 * f, y + 6 * f), "128", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * f), Tokens.TEXT)
		var pause := Rect2(Vector2(top.end.x - 52 * f, top.position.y + 2 * f), Vector2(44, 40) * f)
		Paint.panel(self, Rect2(pause.position + Vector2(0, 3 * f), pause.size), Tokens.PRIMARY_LIP, 8)
		Paint.panel(self, pause, Tokens.PRIMARY, 8)
		Icons.draw(self, "pause", pause.get_center(), 20 * f, Tokens.PRIMARY_TEXT)
		var hb := layout.helper_bar
		var names: Array[String] = ["Undo", "Extra slot", "Screwdriver"]
		var icons: Array[String] = ["undo", "extra_slot", "screwdriver"]
		var bw := (hb.size.x - 24.0 * f - 24.0 * f) / 3.0
		for i in 3:
			var r := Rect2(Vector2(hb.position.x + 12 * f + i * (bw + 12 * f), hb.position.y), Vector2(bw, hb.size.y))
			Paint.panel(self, Rect2(r.position + Vector2(0, 4 * f), r.size), Tokens.SECONDARY_LIP, 8)
			Paint.panel(self, r, Tokens.SECONDARY, 8, Color(Tokens.PRIMARY, 0.35), 1)
			Icons.draw(self, icons[i], Vector2(r.get_center().x, r.position.y + r.size.y * 0.38), 26 * f, Tokens.TEXT)
			draw_string(font, Vector2(r.position.x, r.end.y - 8 * f), names[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(13 * f), Tokens.TEXT)
			var bc := Vector2(r.end.x - 6 * f, r.position.y + 4 * f)
			draw_circle(bc, 12 * f, Tokens.BADGE, true, -1.0, true)
			draw_string(font, bc + Vector2(-12, 6) * f, str(2 - i % 2), HORIZONTAL_ALIGNMENT_CENTER, 24 * f, int(16 * f), Tokens.BADGE_TEXT)
