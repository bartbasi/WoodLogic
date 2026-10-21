# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends Node2D
## The parts on one sheet for review: the progress map's nodes in every state on a trail, the
## boxes (open, filled, shutting, shut, preview), the tray (normal, warning, full), screws in all
## three sizes free, covered, lifted and turned, and the level clear celebration at rest.
## tools/art/capture.gd renders it.

var _map: MapSheet


class MapSheet extends Node2D:
	var centers: Array[Vector2] = []
	var cleared_up_to := 0

	func _draw() -> void:
		for i in range(1, centers.size()):
			MapTrail.draw_segment(self, centers[i - 1], centers[i], i <= cleared_up_to)
		MapTrail.draw_fade(self, Rect2(0, centers[centers.size() - 1].y - 50, 200, 70), Tokens.PEGBOARD.darkened(0.3))


func _ready() -> void:
	var k := get_viewport_rect().size.x / 360.0
	scale = Vector2(k, k)
	var wall := BoardView.new()
	add_child(wall)
	var h := get_viewport_rect().size.y / k
	wall.setup(Vector2(360, h), [] as Array[Rect2])

	# The map: levels 19 to 27, highest cleared 22, so 23 is next and 24 to 27 are locked.
	_map = MapSheet.new()
	_map.position = Vector2(-60, 0)
	add_child(_map)
	var lanes: Array[float] = [180, 276, 180, 84]
	for n in range(19, 28):
		var c := Vector2(lanes[(n - 1) % 4] * 0.55 + 60, 760 - (n - 19) * 88 * 0.85)
		_map.centers.append(c)
		var v := MapNodeView.new()
		var state := MapNodeView.CLEARED if n <= 22 else (MapNodeView.NEXT if n == 23 else MapNodeView.LOCKED)
		v.setup(n, state, [3, 2, 1, 3][n % 4] if state == MapNodeView.CLEARED else 0, n % 5 == 0 and n >= 10)
		v.position = c
		_map.add_child(v)
	_map.cleared_up_to = 23 - 19

	# Boxes.
	var x := 175.0
	var states: Array[float] = [1.0, 1.0, 0.45, 0.0]
	for i in 4:
		var b := BoxView.new()
		b.setup(i * 2, false)
		b.set_lid(states[i])
		b.position = Vector2(x + (i % 2) * 96, 20 + floori(i / 2.0) * 74)
		add_child(b)
		for w in (3 if i == 1 else i % 2):
			var sv := ScrewView.new()
			sv.setup(i * 2, ScrewView.WELL)
			sv.position = b.position + BoxView.well_center(w)
			add_child(sv)
	for i in 2:
		var pv := BoxView.new()
		pv.setup(5 + i * 2, true)
		pv.position = Vector2(x + 10 + i * 80, 175)
		add_child(pv)

	# Trays: normal, one free (warning), full.
	var fills: Array[int] = [2, 4, 5]
	for t in 3:
		var tray := TrayView.new()
		tray.setup(5)
		var filled := PackedByteArray()
		for s in 5:
			filled.append(1 if s < fills[t] else 0)
		tray.set_filled(filled)
		tray.set_warning(fills[t] == 4)
		tray.set_full(fills[t] == 5)
		tray.position = Vector2(232, 260 + t * 64)
		tray.scale = Vector2(0.52, 0.52)
		add_child(tray)
		for s in fills[t]:
			var sv := ScrewView.new()
			sv.setup(s + t, ScrewView.TRAY)
			sv.position = tray.position + Vector2(TrayView.slot_x(s, 5) * 0.52, 0)
			sv.scale = Vector2(0.52, 0.52)
			add_child(sv)

	# Screws: each color free, covered, lifted half way and turned.
	for i in Palette.count():
		var y := 470.0 + i * 36.0
		var looks: Array[Array] = [[false, 0.0, 0.0], [true, 0.0, 0.0], [false, 0.6, 50.0]]
		for j in 3:
			var sv := ScrewView.new()
			sv.setup(i, [ScrewView.BOARD, ScrewView.BOARD, ScrewView.BOARD][j])
			sv.set_covered(looks[j][0])
			sv.set_lift(looks[j][1])
			sv.set_turn(looks[j][2])
			sv.position = Vector2(196 + j * 52, y)
			add_child(sv)

	# The clear celebration at rest, small, in the bottom right corner.
	var fx := ClearEffects.new()
	fx.position = Vector2(0, 0)
	add_child(fx)
	var stars: Array[Vector2] = [Vector2(212, 818), Vector2(262, 812), Vector2(312, 818)]
	var earned: Array[bool] = [true, true, false]
	fx.setup(Rect2(180, 780, 180, 80), stars, earned, 20.0)
	fx.skip()
