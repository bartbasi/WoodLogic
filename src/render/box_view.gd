# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BoxView
extends CachedDrawing
## A box (docs/ARCHITECTURE.md 7, docs/UX.md 3.2.2, docs/DESIGN.md 7): a small oak tray with
## three drilled wells, the color painted across its front with the symbol on it, and a thin lid
## leaning back above that swings forward over the wells when it shuts. A preview box is the
## closed queue look: 62 by 44 with a painted lid and its symbol. The origin is the top left of
## the body. Screws in the wells are separate ScrewViews; this draws the box only.

## Sizes and well places from docs/UX.md 3.2.2 (the same numbers as the level layout).
const OPEN_SIZE := Vector2(92.0, 56.0)
const PREVIEW_SIZE := Vector2(62.0, 44.0)
const WELL_FIRST_X := 18.0
const WELL_STEP := 28.0
const WELL_Y := 20.0
const WELL_RADIUS := 12.0
const BAND := Rect2(6.0, 36.0, 80.0, 18.0)
const CLOSE_SECONDS := 0.18

var _color := 0
var _preview := false
var _count := 0
var _lid := 1.0
var _tween: Tween
var _oak: Dictionary = {}


func setup(color: int, preview: bool) -> void:
	_color = posmod(color, Palette.count())
	_preview = preview
	_lid = 0.0 if preview else 1.0
	# The box is the theme's wood when it is light enough to read against, otherwise oak.
	var w := Looks.current_wood()
	_oak = w if not ["walnut", "ebony"].has(String(w["id"])) else Looks.wood("oak")
	repaint()


func set_count(n: int) -> void:
	_count = clampi(n, 0, 3)


## 0 closed, 1 open.
func set_lid(open: float) -> void:
	_lid = clampf(open, 0.0, 1.0)
	repaint()


## The lid swings down and shuts: 180 ms, quad in, with a small bounce at the end (DESIGN.md 9).
func close() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		set_lid(0.0)
		return
	var from := _lid
	_tween = create_tween()
	_tween.tween_method(func(p: float) -> void:
		var bounce := 0.06 * sin(PI * clampf((p - 0.8) / 0.2, 0.0, 1.0))
		set_lid(from * (1.0 - p * p) + bounce), 0.0, 1.0, CLOSE_SECONDS)
	_tween.tween_callback(set_lid.bind(0.0))


func _paint_rect() -> Rect2:
	if _preview:
		return Rect2(-8, -8, PREVIEW_SIZE.x + 18, PREVIEW_SIZE.y + 20)
	return Rect2(-8, -10, OPEN_SIZE.x + 18, OPEN_SIZE.y + 24)


## Where well i's center is, from the body's top left.
static func well_center(i: int) -> Vector2:
	return Vector2(WELL_FIRST_X + WELL_STEP * i, WELL_Y)


func _paint(ci: CanvasItem) -> void:
	var paint := Palette.color(_color)
	var ink := Palette.ink(_color)
	var light: Color = _oak["wood_light"]
	var dark: Color = _oak["wood_dark"]
	var edge: Color = _oak["edge_color"]
	var symbols := Looks.symbols_on()
	if _preview:
		var rect := Rect2(Vector2.ZERO, PREVIEW_SIZE)
		Paint.panel(ci, Rect2(rect.position + Vector2(0, 4), rect.size), edge.darkened(0.25), 7, Color(), 0, Color(0, 0, 0, 0.45), 6, Vector2(1, 2))
		Paint.panel(ci, rect, light.darkened(0.08), 7)
		var lid := rect.grow(-4.0)
		Paint.panel(ci, lid, paint, 5)
		Paint.panel(ci, Rect2(lid.position, Vector2(lid.size.x, 3)), Color(1, 1, 1, 0.22), 2)
		if symbols:
			Palette.draw_symbol(ci, _color, lid.get_center(), 10.0, ink)
		return
	var body := Rect2(Vector2.ZERO, OPEN_SIZE)
	if _lid > 0.5:
		_draw_lid(ci, paint, ink, edge, symbols)
	Paint.panel(ci, Rect2(body.position + Vector2(0, 4), body.size), edge.darkened(0.2), 8, Color(), 0, Color(0, 0, 0, 0.5), 7, Vector2(2, 3))
	Paint.panel(ci, body, light.darkened(0.06), 8)
	Paint.panel(ci, body.grow(-3.0), dark.lightened(0.05), 6)
	Paint.panel(ci, body.grow_individual(-3, -3, -3, -26), light.darkened(0.12), 6)
	Paint.grain_lines(ci, body.grow_individual(-3, -3, -3, -26), Color(dark, 0.35), _color + 3, 3)
	for i in 3:
		Paint.well(ci, well_center(i), WELL_RADIUS, Color("4a2f1b"))
	var band := BAND
	Paint.panel(ci, band, paint, 3)
	Paint.panel(ci, Rect2(band.position, Vector2(band.size.x, 2)), Color(1, 1, 1, 0.2), 1)
	if symbols:
		Palette.draw_symbol(ci, _color, band.get_center(), 7.0, ink)
	if _lid <= 0.5:
		_draw_lid(ci, paint, ink, edge, symbols)


## Open, the lid is a thin strip leaning back above the body; shut, a painted plate over the wells.
func _draw_lid(ci: CanvasItem, paint: Color, ink: Color, edge: Color, symbols: bool) -> void:
	var top := lerpf(3.0, -5.0, _lid)
	var height := lerpf(31.0, 3.0, _lid)
	var lid := Rect2(4.0, top, OPEN_SIZE.x - 8.0, height)
	if _lid <= 0.5:
		Paint.panel(ci, Rect2(lid.position + Vector2(0, 2), lid.size), Color(0, 0, 0, 0.35), 4)
	Paint.panel(ci, lid, edge.darkened(0.15), 4)
	Paint.panel(ci, lid.grow_individual(-1.5, -1.0, -1.5, -1.5), paint, 3)
	if _lid < 0.3 and symbols:
		Palette.draw_symbol(ci, _color, lid.get_center(), 8.0, ink)
