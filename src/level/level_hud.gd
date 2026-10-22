# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelHud
extends Node2D
## The level screen's text and controls, drawn in code on plaques (UX 1.3, 3.2.2): the top bar
## (coffee cup, level label, timer and pips, star bank, pause), the helper row or the tutorial
## line in the helper bar's place, the Screwdriver banner, the first-time highlight, and the
## toast. Every icon is drawn with Icons.draw. It holds no game state: the level scene tells it
## what to show and asks it which control a touch is on.

const PLAQUE := Color(0.173, 0.114, 0.075, 0.94)
const PLAQUE_EDGE := Color(0.847, 0.643, 0.271, 0.55)
const TEXT := Color("f7ead4")
const TEXT_DIM := Color("e8d6b8")
const BRASS := Color("d8a445")
const BRASS_TEXT := Color("2a1708")
const BUTTON := Color("4b3121")
const BUTTON_LIP := Color("24160d")
const FOCUS := Color("f7ead4")
const OUTLINE := Color("f2b84b")
const HELPERS: Array[String] = ["undo", "extra_slot", "screwdriver"]
const NAMES := {"undo": "Undo", "extra_slot": "Extra slot", "screwdriver": "Screwdriver"}
const BANNER_SECONDS := 0.15
const SHAKE_SECONDS := 0.2

var _layout: LevelLayout
var _label := ""
var _show_timer := false
var _timer_text := "0:00"
var _line := ""
var _fast_ok := true
var _clean_ok := true
var _cup := false
var _bank_shown := false
var _bank := 0
## One dictionary per helper button on screen: id, badge (text), star (a small star follows the
## badge: the price), dim, disabled.
var _buttons: Array[Dictionary] = []
var _banner := false
var _banner_t := 1.0
var _highlight := ""
var _pressed := ""
var _shake_id := ""
var _shake_t := 0.0
var _toast := ""
var _toast_left := 0.0
## The shrink line (UX 3.2.2): its text, how visible it is (0 to 1), the tray frame it outlines
## and the scale that frame is drawn at.
var _note := ""
var _note_alpha := 0.0
var _note_frame := Rect2()
var _note_scale := 1.0
## The touch targets of the controls that can be pressed now: id to rectangle.
var _rects := {}
var _line_rect := Rect2()
var _banner_rect := Rect2()
## The top bar and the helper row, each drawn once into a texture while it stays still
## (CachedDrawing: one draw call instead of dozens).
var _top: Part
var _bottom: Part
## The timer and its pips change every second, so they are a part of their own: only a small
## area is drawn live when the time ticks.
var _timer: Part


## A cached part of the HUD: paints through the HUD's own drawing functions.
class Part extends CachedDrawing:
	var hud: LevelHud
	var kind := 0

	func _paint(ci: CanvasItem) -> void:
		match kind:
			0:
				hud._paint_top(ci)
			1:
				hud._paint_bottom(ci)
			_:
				hud._paint_timer(ci)

	func _paint_rect() -> Rect2:
		return hud._part_rect(kind)


func _init() -> void:
	_top = Part.new()
	_top.hud = self
	_top.kind = 0
	add_child(_top)
	_bottom = Part.new()
	_bottom.hud = self
	_bottom.kind = 1
	add_child(_bottom)
	_timer = Part.new()
	_timer.hud = self
	_timer.kind = 2
	add_child(_timer)


func _ready() -> void:
	set_process(false)


## The area each cached part paints in, scene units, with room for badges, the arrow, a shake
## and the banner's slide.
func _part_rect(kind: int) -> Rect2:
	if _layout == null:
		return Rect2(0, 0, 1, 1)
	var f := _layout.f
	if kind == 2:
		return (top_items()["timer"] as Rect2).grow(6.0)
	if kind == 0:
		var bar := _layout.top_bar
		return Rect2(bar.position.x - 4.0, bar.position.y - 4.0, bar.size.x + 8.0, bar.size.y + 12.0 * f)
	var bar := _layout.helper_bar
	return Rect2(bar.position.x - 8.0, bar.position.y - 44.0 * f, bar.size.x + 16.0, bar.size.y + 52.0 * f)


func _repaint(top: bool, bottom: bool, timer: bool = false) -> void:
	if top:
		_top.repaint()
	if bottom:
		_bottom.repaint()
	if timer or top:
		_timer.repaint()


func configure(layout: LevelLayout, label: String, show_timer: bool, line: String) -> void:
	_layout = layout
	_label = label
	_show_timer = show_timer
	_line = line
	_timer_text = "0:00"
	_fast_ok = true
	_clean_ok = true
	_toast = ""
	_toast_left = 0.0
	_banner = false
	_banner_t = 1.0
	_highlight = ""
	_pressed = ""
	_shake_id = ""
	_rebuild()


func set_layout(layout: LevelLayout) -> void:
	_layout = layout
	_rebuild()


func set_timer_text(text: String) -> void:
	if text != _timer_text:
		_timer_text = text
		_repaint(false, false, true)


func set_pips(fast_ok: bool, clean_ok: bool) -> void:
	if fast_ok != _fast_ok or clean_ok != _clean_ok:
		_fast_ok = fast_ok
		_clean_ok = clean_ok
		_repaint(false, false, true)


func set_line(text: String) -> void:
	if text != _line:
		_line = text
		_rebuild()


func get_line() -> String:
	return _line


## The coffee cup in the top bar (UX 1.7); it moves the label and the rest to the right.
func set_cup(on: bool) -> void:
	if on != _cup:
		_cup = on
		_rebuild()


func is_timer_shown() -> bool:
	return _show_timer


## (fast pip filled, clean pip filled)
func pips() -> Vector2i:
	return Vector2i(1 if _fast_ok else 0, 1 if _clean_ok else 0)


func is_cup_shown() -> bool:
	return _cup


## The star bank in the top bar. `shown` is false before level 4 and in Relaxed.
func set_star_bank(shown: bool, stars: int) -> void:
	if shown != _bank_shown or stars != _bank:
		_bank_shown = shown
		_bank = stars
		_repaint(true, false)


## The helper buttons on screen, left to right. Empty shows the tutorial line instead.
func set_buttons(infos: Array[Dictionary]) -> void:
	_buttons = infos
	_rebuild()


func button_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for info: Dictionary in _buttons:
		out.append(info["id"])
	return out


func get_badge(id: String) -> String:
	for info: Dictionary in _buttons:
		if info["id"] == id:
			return info["badge"]
	return ""


func is_button_dim(id: String) -> bool:
	for info: Dictionary in _buttons:
		if info["id"] == id:
			return info["dim"] or info["disabled"]
	return false


## The Screwdriver banner replaces the helper row (UX 3.2.2).
func set_banner(on: bool) -> void:
	if on == _banner:
		return
	_banner = on
	_banner_t = 0.0 if on else 1.0
	set_process(true)
	_rebuild()


func is_banner_shown() -> bool:
	return _banner


## A steady ring and a down arrow on one helper button (UX 3.13.1); "" clears it.
func set_highlight(id: String) -> void:
	if id != _highlight:
		_highlight = id
		_repaint(false, true)


func get_highlight() -> String:
	return _highlight


func set_pressed(id: String) -> void:
	if id != _pressed:
		_pressed = id
		_repaint(true, true)


## The button shakes 4 units sideways twice in 200 ms (UX 6.2).
func shake(id: String) -> void:
	_shake_id = id
	_shake_t = 0.0
	set_process(true)


## The shrink line in the helper bar's place, with a steady outline round the tray. `alpha` is
## how visible both are; "" or 0 takes them away and the helper buttons come back.
func set_note(text: String, alpha: float) -> void:
	var a := clampf(alpha, 0.0, 1.0) if text != "" else 0.0
	if text == _note and is_equal_approx(a, _note_alpha):
		return
	_note = text
	_note_alpha = a
	_bottom.modulate.a = 1.0 - a
	_bottom.visible = a < 0.999
	queue_redraw()


## The tray frame the outline goes round (scene units) and the scale it is drawn at.
func set_note_frame(frame: Rect2, frame_scale: float) -> void:
	if frame != _note_frame or not is_equal_approx(frame_scale, _note_scale):
		_note_frame = frame
		_note_scale = frame_scale
		if _note_alpha > 0.0:
			queue_redraw()


func get_note() -> String:
	return _note if _note_alpha > 0.0 else ""


func get_note_alpha() -> float:
	return _note_alpha


func get_note_frame() -> Rect2:
	return _note_frame


## Where the line's plaque goes: the helper bar's place, 336 by 48 like the tutorial lines.
func note_rect() -> Rect2:
	if _layout == null:
		return Rect2()
	var f := _layout.f
	var bar := _layout.helper_bar
	var margin := 0.0 if _layout.split else 12.0
	var width := minf(bar.size.x - 2.0 * margin, 336.0 * f)
	return Rect2(bar.get_center() - Vector2(width, 48.0 * f) * 0.5, Vector2(width, 48.0 * f))


func get_toast() -> String:
	return _toast if _toast_left > 0.0 else ""


func show_toast(text: String, seconds: float = 2.0) -> void:
	_toast = text
	_toast_left = seconds
	set_process(true)
	queue_redraw()


## The id of the control under p ("pause", "cup", a helper, "cancel"), or "". Each target is its
## own rectangle and nothing snaps or grows (UX 6.1).
func hit(p: Vector2) -> String:
	for id: String in _rects:
		# The helper buttons are not there while the shrink line takes their place.
		if _note_alpha > 0.0 and HELPERS.has(id):
			continue
		if (_rects[id] as Rect2).has_point(p):
			return id
	return ""


func target_of(id: String) -> Rect2:
	return _rects.get(id, Rect2())


## The scale of the top bar's items. The bar's items need 360 units across (UX 3.2.2), so on a
## screen that is 360 wide they keep their size however tall the bar grows (the furniture scale
## f is above 1 on tall phones); on wider screens they grow with f.
func _item_scale() -> float:
	return minf(_layout.f, _layout.content.size.x / 360.0)


## The pause button's touch target: 48 by 48 at the top right, scaled with the bars (UX 3.2.2).
func pause_target() -> Rect2:
	if _layout == null:
		return Rect2()
	var top := _layout.top_bar
	var f := _item_scale()
	return Rect2(top.end.x - 52.0 * f, top.position.y, 48.0 * f, 48.0 * f)


## The coffee cup's touch target: exactly 48 by 48 at the top left (UX 1.7).
func cup_target() -> Rect2:
	if _layout == null:
		return Rect2()
	var top := _layout.top_bar
	var f := _item_scale()
	return Rect2(top.position.x + 4.0 * f, top.position.y, 48.0 * f, 48.0 * f)


## The rectangles of the top bar's items, for the cup layout or without it (UX 3.2.2).
func top_items() -> Dictionary:
	var top := _layout.top_bar
	var f := _item_scale()
	var x := top.position.x
	var y := top.position.y
	var h := top.size.y
	if _cup:
		return {
			"label": Rect2(x + 56.0 * f, y, 92.0 * f, h),
			"timer": Rect2(x + 150.0 * f, y, 86.0 * f, h),
			"bank": Rect2(x + 238.0 * f, y, 64.0 * f, h),
		}
	return {
		"label": Rect2(x + 12.0 * f, y, 96.0 * f, h),
		"timer": Rect2(x + 112.0 * f, y, 108.0 * f, h),
		"bank": Rect2(x + 224.0 * f, y, 76.0 * f, h),
	}


func _rebuild() -> void:
	_rects.clear()
	_line_rect = Rect2()
	_banner_rect = Rect2()
	if _layout == null:
		_repaint(true, true)
		return
	_rects["pause"] = pause_target()
	if _cup:
		_rects["cup"] = cup_target()
	var f := _layout.f
	var bar := _layout.helper_bar
	var margin := 0.0 if _layout.split else 12.0
	var total := bar.size.x - 2.0 * margin
	var gap := 12.0 * f
	var button_w := (total - 2.0 * gap) / 3.0
	var left := bar.position.x + margin
	if _banner:
		var cancel := Rect2(left + total - 96.0 * f, bar.get_center().y - 24.0 * f, 96.0 * f, 48.0 * f)
		_rects["cancel"] = cancel
		_banner_rect = Rect2(left, bar.get_center().y - 24.0 * f, total - 96.0 * f - 8.0 * f, 48.0 * f)
	elif not _buttons.is_empty():
		var n := _buttons.size()
		var group := n * button_w + (n - 1) * gap
		var start := bar.get_center().x - group * 0.5
		if _line != "" and n < 3:
			start = left
			var line_x := left + n * (button_w + gap)
			_line_rect = Rect2(line_x, bar.get_center().y - 24.0 * f, left + total - line_x, 48.0 * f)
		for i: int in n:
			_rects[_buttons[i]["id"]] = Rect2(start + i * (button_w + gap), bar.position.y, button_w, bar.size.y)
	elif _line != "":
		var width := minf(total, 336.0 * f)
		_line_rect = Rect2(bar.get_center() - Vector2(width, 48.0 * f) * 0.5, Vector2(width, 48.0 * f))
	_repaint(true, true)


func _process(delta: float) -> void:
	var busy := false
	var bottom := false
	if _toast_left > 0.0:
		_toast_left = maxf(0.0, _toast_left - delta)
		busy = _toast_left > 0.0
	if _banner and _banner_t < 1.0:
		_banner_t = minf(1.0, _banner_t + delta / BANNER_SECONDS)
		busy = true
		bottom = true
	if _shake_id != "":
		_shake_t += delta
		bottom = true
		if _shake_t >= SHAKE_SECONDS:
			_shake_id = ""
		else:
			busy = true
	if bottom:
		_repaint(false, true)
	queue_redraw()
	if not busy:
		set_process(false)


func _draw() -> void:
	if _layout == null:
		return
	var f := _layout.f
	if _note_alpha > 0.0 and _note != "":
		_draw_note()
	if _toast_left > 0.0 and _toast != "":
		var size := int(round(16.0 * f))
		var wide: float = ThemeDB.fallback_font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		var text_w := minf(wide, _layout.content.size.x - 40.0)
		var two := wide > text_w
		var h := (52.0 if two else 32.0) * f
		var rect := Rect2(_layout.content.get_center().x - (text_w + 24.0) * 0.5, _layout.content.end.y - 24.0 * f - h, text_w + 24.0, h)
		_plaque(self, rect)
		draw_multiline_string(ThemeDB.fallback_font, Vector2(rect.position.x + 12.0, rect.position.y + 20.0 * f), _toast, HORIZONTAL_ALIGNMENT_CENTER, text_w, size, 2, TEXT)




## The shrink line: Tutorial line style (18 bold, 16 if it wraps) on the 336 by 48 plaque, and
## a steady 3 unit outline just outside the tray frame (UX 3.2.2).
func _draw_note() -> void:
	var a := _note_alpha
	var f := _layout.f
	var rect := note_rect()
	draw_rect(rect, Color(PLAQUE, PLAQUE.a * a))
	draw_rect(rect, Color(PLAQUE_EDGE, PLAQUE_EDGE.a * a), false, 1.0)
	var bold := RenderFonts.bold()
	var inner := rect.size.x - 16.0
	var size := int(round(18.0 * f))
	var wide := bold.get_string_size(_note, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var two_lines := false
	if wide > inner:
		size = int(round(16.0 * f))
		two_lines = bold.get_string_size(_note, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x > inner
	var y := rect.get_center().y + (-size * 0.2 if two_lines else size * 0.35)
	draw_multiline_string(bold, Vector2(rect.position.x + 8.0, y), _note, HORIZONTAL_ALIGNMENT_CENTER, inner, size, 2, Color(TEXT, a))
	if _note_frame.size.x > 0.0:
		var width := 3.0 * _note_scale
		var outer := _note_frame.grow(width * 0.5)
		var radius := 12.0 * _note_scale + width * 0.5
		draw_polyline(_rounded_loop(outer, radius), Color(OUTLINE, a), width, true)


## A closed loop round a rectangle with rounded corners.
func _rounded_loop(rect: Rect2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var corners := [
		[Vector2(rect.end.x - radius, rect.position.y + radius), -PI * 0.5],
		[Vector2(rect.end.x - radius, rect.end.y - radius), 0.0],
		[Vector2(rect.position.x + radius, rect.end.y - radius), PI * 0.5],
		[Vector2(rect.position.x + radius, rect.position.y + radius), PI],
	]
	for corner: Array in corners:
		var c: Vector2 = corner[0]
		var start: float = corner[1]
		for i: int in 7:
			out.append(c + Vector2.from_angle(start + PI * 0.5 * i / 6.0) * radius)
	out.append(out[0])
	return out


func _paint_top(ci: CanvasItem) -> void:
	if _layout == null:
		return
	var f := _item_scale()
	var items := top_items()
	var top := _layout.top_bar
	var mid_y := top.position.y + top.size.y * 0.5
	var bold := RenderFonts.bold()
	# The coffee cup: an icon only, on a quiet plaque (UX 1.7).
	if _cup:
		var c := cup_target()
		var plaque := Rect2(c.position.x + 4.0 * f, top.position.y + 4.0 * f, 40.0 * f, top.size.y - 8.0 * f)
		_plaque(ci, _pressed_rect(plaque, "cup"))
		Icons.draw(ci, "cup", plaque.get_center(), 24.0 * f, TEXT_DIM)
	var label_rect: Rect2 = items["label"]
	_plaque(ci, label_rect.grow_individual(-2.0 * f, -4.0 * f, -2.0 * f, -4.0 * f))
	var label_size := int(round((18.0 if _cup else 20.0) * f))
	ci.draw_string(bold, Vector2(label_rect.position.x + 8.0 * f, mid_y + label_size * 0.35), _label, HORIZONTAL_ALIGNMENT_LEFT, label_rect.size.x - 12.0 * f, label_size, TEXT)
	if _bank_shown:
		var bank: Rect2 = items["bank"]
		_plaque(ci, bank.grow_individual(-2.0 * f, -4.0 * f, -2.0 * f, -4.0 * f))
		Icons.draw(ci, "star", Vector2(bank.position.x + 14.0 * f, mid_y), 16.0 * f, Color("e9b23e"))
		ci.draw_string(bold, Vector2(bank.position.x + 26.0 * f, mid_y + 6.0 * f), str(_bank), HORIZONTAL_ALIGNMENT_LEFT, bank.size.x - 28.0 * f, int(round(16.0 * f)), TEXT)
	var pause_rect := pause_target()
	var button := Rect2(pause_rect.position.x + 4.0 * f, top.position.y + 4.0 * f, 40.0 * f, top.size.y - 8.0 * f)
	button = _pressed_rect(button, "pause")
	ci.draw_rect(button, BRASS.darkened(0.25) if _pressed == "pause" else BRASS)
	Icons.draw(ci, "pause", button.get_center(), 24.0 * f, BRASS_TEXT)
	# The chevron between the open boxes and the queue (UX 3.2.2).
	if not _layout.split and _layout.open_pos.size() > 0 and _layout.preview_pos.size() > 0:
		var cx: float = _layout.open_pos[_layout.open_pos.size() - 1].x + (LevelLayout.OPEN_W + 6.0) * _layout.box_scale
		Icons.draw(ci, "chevron", Vector2(cx, _layout.open_pos[0].y + 28.0 * _layout.box_scale), 12.0 * _layout.box_scale, Color(TEXT, 0.8))


## The timer and the two pips (UX 3.2.2).
func _paint_timer(ci: CanvasItem) -> void:
	if not _show_timer or _layout == null:
		return
	var f := _item_scale()
	var top := _layout.top_bar
	var mid_y := top.position.y + top.size.y * 0.5
	var box: Rect2 = top_items()["timer"]
	_plaque(ci, box.grow_individual(-2.0 * f, -4.0 * f, -2.0 * f, -4.0 * f))
	ci.draw_string(ThemeDB.fallback_font, Vector2(box.position.x + 8.0 * f, mid_y + 6.0 * f), _timer_text, HORIZONTAL_ALIGNMENT_LEFT, 56.0 * f, int(round(16.0 * f)), TEXT)
	Icons.draw(ci, "stopwatch_full" if _fast_ok else "stopwatch", Vector2(box.end.x - 30.0 * f, mid_y), 14.0 * f, BRASS)
	Icons.draw(ci, "pip" if _clean_ok else "pip_empty", Vector2(box.end.x - 12.0 * f, mid_y), 14.0 * f, BRASS)


## The helper bar's place: the Screwdriver banner, the helper buttons, the tutorial line.
func _paint_bottom(ci: CanvasItem) -> void:
	var f := _layout.f
	var bold := RenderFonts.bold()
	if _banner:
		var slide := (1.0 - LevelAnim.out_cubic(_banner_t)) * 20.0 * f
		var alpha := _banner_t
		var rect := _banner_rect
		rect.position.y += slide
		ci.draw_rect(rect, Color(PLAQUE, PLAQUE.a * alpha))
		ci.draw_rect(rect, Color(PLAQUE_EDGE, PLAQUE_EDGE.a * alpha), false, 1.0)
		var size := int(round(16.0 * f))
		if bold.get_string_size("Tap any screw to remove it.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x > rect.size.x - 16.0:
			size = int(round(14.0 * f))
		ci.draw_multiline_string(bold, Vector2(rect.position.x + 8.0, rect.get_center().y + (-size * 0.1 if rect.size.x < 230.0 * f else size * 0.35)), "Tap any screw to remove it.", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16.0, size, 2, Color(TEXT, alpha))
		var cancel: Rect2 = _rects.get("cancel", Rect2())
		cancel.position.y += slide
		_draw_plain_button(ci, cancel, "Cancel", _pressed == "cancel", alpha, f, bold)
		return
	for info: Dictionary in _buttons:
		_draw_helper(ci, info, f, bold)
	if _line != "" and _line_rect.size.x > 0.0:
		_plaque(ci, _line_rect)
		var size := int(round(18.0 * f))
		var inner := _line_rect.size.x - 16.0
		var wide: float = bold.get_string_size(_line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		if not _buttons.is_empty() and wide > inner:
			size = int(round(14.0 * f))
			wide = bold.get_string_size(_line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		var two_lines := wide > inner
		var y := _line_rect.get_center().y + (-size * 0.2 if two_lines else size * 0.35)
		ci.draw_multiline_string(bold, Vector2(_line_rect.position.x + 8.0, y), _line, HORIZONTAL_ALIGNMENT_CENTER, inner, size, 2, TEXT)


func _draw_plain_button(ci: CanvasItem, rect: Rect2, text: String, pressed: bool, alpha: float, f: float, bold: Font) -> void:
	var r := _scaled(rect, pressed)
	ci.draw_rect(r, Color(BUTTON_LIP.lerp(BUTTON, 0.0), alpha))
	ci.draw_rect(Rect2(r.position, r.size - Vector2(0.0, 3.0 * f)), Color(BUTTON.darkened(0.12 if pressed else 0.0), alpha))
	ci.draw_rect(r, Color(PLAQUE_EDGE, PLAQUE_EDGE.a * alpha), false, 1.0)
	var size := int(round(18.0 * f))
	ci.draw_string(bold, Vector2(r.position.x, r.get_center().y + size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, Color(TEXT, alpha))


func _draw_helper(ci: CanvasItem, info: Dictionary, f: float, bold: Font) -> void:
	var id: String = info["id"]
	var rect: Rect2 = _rects.get(id, Rect2())
	if rect.size.x <= 0.0:
		return
	if id == _shake_id:
		rect.position.x += 4.0 * f * sin(_shake_t / SHAKE_SECONDS * TAU * 2.0)
	var dim: bool = info["dim"] or info["disabled"]
	var alpha := 0.5 if dim else 1.0
	var r := _scaled(rect, _pressed == id)
	ci.draw_rect(r, Color(BUTTON_LIP, alpha))
	ci.draw_rect(Rect2(r.position, r.size - Vector2(0.0, 3.0 * f)), Color(BUTTON.darkened(0.12 if _pressed == id else 0.0), alpha))
	ci.draw_rect(r, Color(PLAQUE_EDGE, PLAQUE_EDGE.a * alpha), false, 1.0)
	Icons.draw(ci, id, Vector2(r.get_center().x, r.position.y + r.size.y * 0.4), 28.0 * f, Color(TEXT, alpha))
	var caption := int(round(13.0 * f))
	ci.draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.end.y - 6.0 * f), NAMES[id], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, caption, Color(TEXT, alpha))
	# The count badge at the top right corner: a count, "Free", "Used", or a price with a star.
	var badge_text: String = info["badge"]
	if badge_text != "":
		var size := int(round((16.0 if badge_text.length() <= 2 else 12.0) * f))
		var text_w: float = bold.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		var star_w := 12.0 * f if info["star"] else 0.0
		var w := maxf(24.0 * f, text_w + star_w + 10.0 * f)
		var badge := Rect2(r.end.x - w + 4.0 * f, r.position.y - 4.0 * f, w, 24.0 * f)
		ci.draw_rect(badge.grow(0.0), Color(BRASS, alpha))
		ci.draw_rect(badge, Color(BRASS_TEXT, 0.6 * alpha), false, 1.0)
		var x := badge.position.x + (w - text_w - star_w) * 0.5
		ci.draw_string(bold, Vector2(x, badge.get_center().y + size * 0.35), badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(BRASS_TEXT, alpha))
		if info["star"]:
			Icons.draw(ci, "star", Vector2(x + text_w + 7.0 * f, badge.get_center().y), 11.0 * f, Color(BRASS_TEXT, alpha))
	if id == _highlight:
		ci.draw_rect(rect.grow(4.0), FOCUS, false, 3.0)
		Icons.draw(ci, "arrow_down", Vector2(rect.get_center().x, rect.position.y - 16.0 * f), 22.0 * f, FOCUS)


func _scaled(rect: Rect2, pressed: bool) -> Rect2:
	if not pressed:
		return rect
	return Rect2(rect.get_center() - rect.size * 0.48, rect.size * 0.96)


func _pressed_rect(rect: Rect2, id: String) -> Rect2:
	return _scaled(rect, _pressed == id)


func _plaque(ci: CanvasItem, rect: Rect2) -> void:
	ci.draw_rect(rect, PLAQUE)
	ci.draw_rect(rect, PLAQUE_EDGE, false, 1.0)
