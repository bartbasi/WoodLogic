# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends Node2D
## Every icon on one sheet, at dock, helper and pip sizes, on a plaque and on brass, plus the
## nine symbols. For review screenshots only: tools/art/capture.gd renders it.


func _ready() -> void:
	var k := get_viewport_rect().size.x / 360.0
	scale = Vector2(k, k)
	queue_redraw()


func _draw() -> void:
	var h := get_viewport_rect().size.y / scale.y
	draw_rect(Rect2(0, 0, 360, h), Tokens.PEGBOARD.darkened(0.3))
	var font := ThemeDB.fallback_font
	var y := 10.0
	var cols := 3
	for i in Icons.NAMES.size():
		var icon: String = Icons.NAMES[i]
		var cx := 12.0 + (i % cols) * 116.0
		var cy := y + floori(i / float(cols)) * 46.0
		var plate := Rect2(cx, cy, 112, 42)
		draw_rect(plate, Tokens.PLAQUE_SOLID)
		Icons.draw(self, icon, Vector2(cx + 16, cy + 21), 22.0, Tokens.TEXT)
		draw_rect(Rect2(cx + 30, cy + 6, 30, 30), Tokens.PRIMARY)
		Icons.draw(self, icon, Vector2(cx + 45, cy + 21), 24.0, Tokens.PRIMARY_TEXT)
		Icons.draw(self, icon, Vector2(cx + 70, cy + 21), 14.0, Tokens.TEXT)
		draw_string(font, Vector2(cx + 80, cy + 25), icon, HORIZONTAL_ALIGNMENT_LEFT, 32, 8, Tokens.TEXT_DIM)
	y += ceili(Icons.NAMES.size() / float(cols)) * 46.0 + 8.0
	for i in Palette.count():
		var c := Vector2(24 + i * 38, y + 22)
		draw_circle(c, 16, Palette.color(i))
		Palette.draw_symbol(self, i, c, 9.0, Palette.ink(i))
		draw_string(font, Vector2(c.x - 18, y + 52), Palette.symbol_name(i), HORIZONTAL_ALIGNMENT_CENTER, 36, 8, Tokens.TEXT_DIM)
