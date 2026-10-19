# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name DirGhost
extends Node2D
## A covered screw showing faintly through the plank in front of it (docs/UX.md 3.2.2): flat,
## about 45 percent opacity, a dashed ring and no shadow, keeping its color and symbol. It is
## drawn just after the topmost plank that covers it.

var color_index := 0
var radius := 14.0
var strength := 0.45
var ring_color := Color(0, 0, 0, 0.5)


func _draw() -> void:
	var c := DirColors.color(color_index)
	draw_circle(Vector2.ZERO, radius * 0.92, Color(c, strength), true, -1.0, true)
	var ink := c.darkened(0.55)
	if DirColors.luminance(c) < 0.17:
		ink = c.lightened(0.6)
	DirSymbols.draw(self, DirColors.symbol(color_index), Vector2.ZERO, radius * 0.57, Color(ink, minf(strength + 0.25, 1.0)))
	var dashes := 12
	for i in dashes:
		var a := TAU * i / dashes
		draw_arc(Vector2.ZERO, radius, a, a + TAU / dashes * 0.55, 6, ring_color, 1.6, true)
