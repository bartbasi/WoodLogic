# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelLayout
extends RefCounted
## Where everything on the level screen goes, in design units (docs/UX.md 3.2.1 and 3.2.1a).
## A pure function of the content rect and how many dp one unit covers, so a test can check it
## against UX's worked examples. Two arrangements: stacked (top bar, boxes, tray, board, helper
## bar) and split (the boxes, tray and helpers on a rail to the right of the board).
##
## b is the board scale (1.0 to 2.0): the core is drawn at 4 * b units per grid unit. f is the
## furniture scale for the bars. box_scale is f, trimmed so the boxes row fits the width.

const CORE_W := 344.0
const CORE_H := 360.0
const F_CEILING := 1.167
const B_MAX := 2.0
## Design units in one grid unit (docs/ARCHITECTURE.md 2).
const GRID_DU := 4.0

## Sizes at f = 1 (UX 3.2.1 base table).
const TOP_H := 44.0
const BOXES_H := 64.0
const TRAY_H := 52.0
const HELPER_H := 56.0
## Open box body, preview box, well spacing and tray slot sizes (UX 3.2.2).
const OPEN_W := 92.0
const OPEN_H := 56.0
const PREVIEW_W := 62.0
const PREVIEW_H := 44.0
const BOX_GAP := 8.0
const CHEVRON_W := 12.0
const WELL_FIRST_X := 18.0
const WELL_STEP := 28.0
const WELL_Y := 20.0
const SLOT_W := 44.0
const SLOT_GAP := 6.0
const TRAY_PAD := 16.0

var split := false
var b := 1.0
var f := 1.0
var box_scale := 1.0
var content := Rect2()
var top_bar := Rect2()
var boxes_bar := Rect2()
var tray_bar := Rect2()
var panel := Rect2()
var helper_bar := Rect2()
var rail := Rect2()
## The scaled core's top left corner, and the units one grid unit covers.
var core_origin := Vector2.ZERO
var grid_px := 4.0
## Top left of each open box body, and of each preview box.
var open_pos: Array[Vector2] = []
var preview_pos: Array[Vector2] = []
var tray_center := Vector2.ZERO
## The widest the tray may be drawn, in scene units: the width of its column or rail.
var tray_room := 0.0


static func tray_width(slots: int) -> float:
	return slots * SLOT_W + (slots - 1) * SLOT_GAP + TRAY_PAD


## The x of a tray slot's center from the frame's center, at scale 1.
static func tray_slot_x(slot: int, slots: int) -> float:
	return -tray_width(slots) * 0.5 + TRAY_PAD * 0.5 + SLOT_W * 0.5 + slot * (SLOT_W + SLOT_GAP)


static func row_width(open: int, previews: int) -> float:
	var w := open * OPEN_W + (open - 1) * BOX_GAP
	if previews > 0:
		w += CHEVRON_W + previews * PREVIEW_W + (previews - 1) * BOX_GAP
	return w


## content_rect is the viewport minus the safe area insets; dpu is how many dp one unit covers.
static func compute(content_rect: Rect2, dpu: float, open: int = 2, previews: int = 2) -> LevelLayout:
	var l := LevelLayout.new()
	l.content = content_rect
	var wc := content_rect.size.x
	var hc := content_rect.size.y
	var f_floor := maxf(0.7, 1.0 / maxf(dpu, 0.01))
	var b_stacked := clampf(minf((wc - 16.0) / CORE_W, (hc - 240.0 * f_floor) / CORE_H), 1.0, B_MAX)
	var rail_w := 360.0 * f_floor
	var b_split_raw := minf((wc - rail_w - 24.0) / CORE_W, (hc - 48.0 * f_floor - 16.0) / CORE_H)
	if b_split_raw >= 1.0 and minf(b_split_raw, B_MAX) > b_stacked:
		l._split(open, previews, f_floor, minf(b_split_raw, B_MAX))
	else:
		l._stacked(open, previews, f_floor, b_stacked)
	l.grid_px = 4.0 * l.b
	return l


func _stacked(open: int, previews: int, f_floor: float, b_value: float) -> void:
	split = false
	b = b_value
	var wc := content.size.x
	var hc := content.size.y
	f = clampf((hc - CORE_H * b) / 240.0, f_floor, F_CEILING)
	var row_w := row_width(open, previews)
	box_scale = minf(f, (wc - 24.0) / row_w)
	var x0 := content.position.x
	var y := content.position.y
	top_bar = Rect2(x0, y, wc, TOP_H * f)
	y += (TOP_H + 4.0) * f
	boxes_bar = Rect2(x0, y, wc, BOXES_H * f)
	y += (BOXES_H + 4.0) * f
	tray_bar = Rect2(x0, y, wc, TRAY_H * f)
	y += (TRAY_H + 8.0) * f
	var panel_h := hc - 240.0 * f
	panel = Rect2(x0 + 8.0, y, wc - 16.0, panel_h)
	y += panel_h + 8.0 * f
	helper_bar = Rect2(x0, y, wc, HELPER_H * f)
	rail = Rect2()
	var row_x := x0 + (wc - row_w * box_scale) * 0.5
	var row_y := boxes_bar.position.y + (boxes_bar.size.y - BOXES_H * box_scale) * 0.5
	_place_boxes(open, previews, row_x, row_y + 6.0 * box_scale, row_y + 10.0 * box_scale)
	tray_center = Vector2(x0 + wc * 0.5, tray_bar.position.y + tray_bar.size.y * 0.5)
	tray_room = wc - 24.0
	_place_core()


func _split(open: int, previews: int, f_floor: float, b_value: float) -> void:
	split = true
	b = b_value
	f = f_floor
	box_scale = f
	var wc := content.size.x
	var hc := content.size.y
	var x0 := content.position.x
	var y0 := content.position.y
	var rail_w := 360.0 * f
	top_bar = Rect2(x0, y0, wc, TOP_H * f)
	var body_y := y0 + 48.0 * f
	var body_h := hc - 48.0 * f - 8.0
	panel = Rect2(x0 + 8.0, body_y, wc - rail_w - 24.0, body_h)
	rail = Rect2(x0 + wc - 8.0 - rail_w, body_y, rail_w, body_h)
	var used := (BOXES_H + PREVIEW_H + 8.0 + TRAY_H + HELPER_H) * f
	var gap := maxf(0.0, (body_h - used) / 3.0)
	var open_y := body_y
	var prev_y := open_y + BOXES_H * f + gap
	var tray_y := prev_y + (PREVIEW_H + 8.0) * f + gap
	var helper_y := tray_y + TRAY_H * f + gap
	boxes_bar = Rect2(rail.position.x, open_y, rail_w, BOXES_H * f)
	tray_bar = Rect2(rail.position.x, tray_y, rail_w, TRAY_H * f)
	helper_bar = Rect2(rail.position.x + 8.0 * f, helper_y, rail_w - 16.0 * f, HELPER_H * f)
	var cx := rail.position.x + rail_w * 0.5
	var open_w := (open * OPEN_W + (open - 1) * BOX_GAP) * f
	var prev_w := (previews * PREVIEW_W + (previews - 1) * BOX_GAP) * f
	open_pos.clear()
	preview_pos.clear()
	for i: int in open:
		open_pos.append(Vector2(cx - open_w * 0.5 + i * (OPEN_W + BOX_GAP) * f, open_y + 6.0 * f))
	for k: int in previews:
		preview_pos.append(Vector2(cx - prev_w * 0.5 + k * (PREVIEW_W + BOX_GAP) * f, prev_y + 4.0 * f))
	tray_center = Vector2(cx, tray_y + TRAY_H * f * 0.5)
	tray_room = rail_w - 24.0 * f
	_place_core()


func _place_boxes(open: int, previews: int, open_x: float, open_y: float, prev_y: float) -> void:
	open_pos.clear()
	preview_pos.clear()
	var row_x := open_x
	for i: int in open:
		open_pos.append(Vector2(row_x + i * (OPEN_W + BOX_GAP) * box_scale, open_y))
	var start := row_x + (open * (OPEN_W + BOX_GAP) + 4.0) * box_scale
	for k: int in previews:
		preview_pos.append(Vector2(start + k * (PREVIEW_W + BOX_GAP) * box_scale, prev_y))


func _place_core() -> void:
	var core := Vector2(CORE_W, CORE_H) * b
	core_origin = panel.position + (panel.size - core) * 0.5


## Where a well's center is, in scene units.
func well_center(position: int, well: int) -> Vector2:
	return open_pos[position] + Vector2(WELL_FIRST_X + WELL_STEP * well, WELL_Y) * box_scale


## The scale the tray is drawn at for this many slots: the boxes' scale, trimmed only if the
## frame would be wider than its column (UX 3.2.2: 310 at most, which fits at every size; a
## level with a longer tray still fits).
func tray_scale(slots: int) -> float:
	if tray_room <= 0.0:
		return box_scale
	return minf(box_scale, tray_room / tray_width(slots))


## Where a tray slot's center is, in scene units. The frame is always centered on tray_center,
## so the slots of a smaller tray sit closer together around the middle.
func tray_slot_center(slot: int, slots: int) -> Vector2:
	return tray_center + Vector2(tray_slot_x(slot, slots) * tray_scale(slots), 0.0)


## The tray frame as drawn, in scene units.
func tray_frame(slots: int) -> Rect2:
	var s := tray_scale(slots)
	var size := Vector2(tray_width(slots), TRAY_H) * s
	return Rect2(tray_center - size * 0.5, size)


func gu_to_scene(gu: Vector2) -> Vector2:
	return core_origin + gu * grid_px


func scene_to_gu(p: Vector2) -> Vector2:
	return (p - core_origin) / grid_px
