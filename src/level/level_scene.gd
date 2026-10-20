# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelScene
extends Control
## The level screen (docs/ARCHITECTURE.md 6 and 10.1): draws the board from the logic model,
## takes touches, and animates what the logic decided. It never decides a rule. A tap goes to
## PlayState at once; the events that come back are animated, and a quick player can tap again
## while the last screw is still flying. If the view and the model disagree, the model is right
## and the view is the bug: reconcile() puts the view right and counts the times it had to.
##
## Phase 3: the helpers are stubs (no helper row), the look is the placeholder views made in
## LevelViews, and Pause, Out of room and Level clear are the app flow's screens.

signal won(result: LevelResult)
signal lost(level: LevelData)
signal pause_requested
signal helper_used(helper: String)
signal helper_buy_requested(helper: String)
signal first_action

## Timings in seconds (UX 6.1, DESIGN.md 9).
const UNSCREW := 0.22
const FLIGHT_SHORT := 0.32
const FLIGHT_LONG := 0.38
const LID_CLOSE := 0.18
const BOX_LEAVE := 0.22
const BOX_ARRIVE := 0.26
const JUMP_FLIGHT := 0.2
const JUMP_STAGGER := 0.08
const JUMP_AFTER_ARRIVAL := 0.15
const FALL_HANG := 0.08
const WIN_DELAY := 0.5
const LOSS_DELAY := 0.3
const IDLE_HINT := 8.0
## Draw order inside the layers.
const Z_SCREW := 10
const Z_SCREW_FLYING := 30
const Z_MARKS := 60
const Z_HINT := 70
const Z_HUD := 100

const PEGBOARD := Color("7a5a3d")
const BOARD_BACK := Color("4a2b1a")
const BOARD_CORE := Color("55321f")
const BAND := Color(0.11, 0.07, 0.04, 0.35)
const RING_COLOR := Color("fff1c9")

var dp_per_unit := 0.0

var _level: LevelData
var _state: PlayState
var _replay := false
var _instant := false
var _paused := false
var _held := false
var _epoch := 0
var _over := false
var _fixes := 0
var _anim_time := 0.0
var _idle := 0.0
var _clock := LevelClock.new()
var _layout: LevelLayout
var _forced_size := Vector2.ZERO
var _inset_top := 24.0
var _inset_bottom := 16.0
var _inset_left := 0.0
var _inset_right := 0.0
var _insets_set := false
var _pause_down := false
var _last_timer_second := -1

var _content: Node2D
## Clips the planks to the board panel (GDD V1): a hanging plank is cut off at the panel's edge
## and never covers a bar or a button. Screws are outside it, so a screw in flight is not cut.
var _plank_clip: Control
var _board_root: Node2D
var _planks_root: Node2D
var _box_root: Node2D
var _screw_layer: Node2D
var _marks: LevelMarks
var _hint: LevelHint
var _hud: LevelHud
var _tray_view: Node2D
var _audio: Node

var _anims: Array[LevelAnim] = []
var _screws: Array[LevelScrewSlot] = []
var _planks: Array[LevelPlankSlot] = []
## What the view believes the boxes hold (the logic's answer, applied at the tap).
var _box_views: Array[Node2D] = []
var _box_color := PackedInt32Array()
var _box_wells := PackedInt32Array()
var _preview_views: Array[Node2D] = []
var _preview_colors := PackedInt32Array()
var _tray_screws := PackedInt32Array()
var _tray_shift := 0.0
var _tray_warned := false
## The tick for the tray's one free slot plays when the screw that caused it lands.
var _tray_tick_due := false
## Per open position: when its last screw lands, when it is free for the next step, when the
## box that arrived finishes sliding in, and how many tray screws have jumped into it.
var _pos_land_at := PackedFloat64Array()
var _pos_free_at := PackedFloat64Array()
var _pos_arrive_start := PackedFloat64Array()
var _pos_arrive_end := PackedFloat64Array()
var _pos_jumps := PackedInt32Array()
## While one action's events are applied: when its last screw lands, when its box arrives.
var _action_land := 0.0
var _action_arrive := 0.0
var _pending: Array[Callable] = []
var _end_anim: LevelAnim
## The slide each box view is in, so a new slide takes over from where the old one got to.
var _moves := {}
## A resize came while paused; the views are placed at resume().
var _layout_due := false


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ensure_nodes()
	set_process(true)
	if _layout == null:
		_relayout()


# == The contract (docs/ARCHITECTURE.md 6) ==

## Starts a level. `replay` is true when the player has cleared it before.
func play(level: LevelData, replay: bool) -> void:
	_level = level
	_replay = replay
	_start_attempt()


## Starts the same level again from the beginning (GDD R34).
func retry() -> void:
	if _level != null:
		_start_attempt()


## Covers the board and stops the clock (the pause screen takes over).
func pause() -> void:
	if _paused:
		return
	_paused = true
	_clock.set_paused(true, Time.get_ticks_msec())
	_pause_down = false
	if _content != null:
		_content.visible = false
		_content.process_mode = Node.PROCESS_MODE_DISABLED


func resume() -> void:
	if not _paused:
		return
	_paused = false
	_clock.set_paused(false, Time.get_ticks_msec())
	if _content != null:
		_content.visible = true
		_content.process_mode = Node.PROCESS_MODE_INHERIT
	if _layout_due:
		_apply_layout()


## Stops the clock with the board still showing (a sheet or a dialog is open).
func hold_clock(on: bool) -> void:
	_held = on
	_clock.set_held(on, Time.get_ticks_msec())


## Phase 3 has no mode to leave, so Back is never handled here.
func handle_back() -> bool:
	return false


@warning_ignore("unused_parameter")
func set_star_bank(stars: int) -> void:
	pass


@warning_ignore("unused_parameter")
func set_helpers(counts: Dictionary, shown: PackedStringArray) -> void:
	pass


@warning_ignore("unused_parameter")
func highlight_helper(helper: String) -> void:
	pass


@warning_ignore("unused_parameter")
func use_helper(helper: String) -> void:
	pass


func usable_after_loss() -> PackedStringArray:
	return PackedStringArray()


## Tests only: every animation jumps to its end, and later ones are not played.
func set_instant(on: bool) -> void:
	_instant = on
	if on:
		_finish_anims()


# == Extras for the app flow, tests and screenshots ==

## The safe area insets in design units. Without a call the UX budget's 24 top and 16 bottom
## are used (and the phone's own insets if they are larger).
func set_safe_insets(top: float, bottom: float, left: float = 0.0, right: float = 0.0) -> void:
	_inset_top = top
	_inset_bottom = bottom
	_inset_left = left
	_inset_right = right
	_insets_set = true
	_relayout()


## Lays the screen out for a viewport of this size, whatever the control's own size is. For
## tests and screenshots. A zero size goes back to the control's size.
func set_layout_size(area: Vector2) -> void:
	_forced_size = area
	_relayout()


func get_layout() -> LevelLayout:
	return _layout


func get_state() -> PlayState:
	return _state


func get_level() -> LevelData:
	return _level


func is_over() -> bool:
	return _over


## A touch at p, in this control's own units. What a tap does is in tap_screw and below.
func tap_at(p: Vector2) -> void:
	if _state == null or _paused or _held or _layout == null:
		return
	_idle = 0.0
	if _state.status() != PlayState.PLAYING:
		return
	var gu := _layout.scene_to_gu(p)
	var s := LevelHit.free_screw(_state, gu)
	if s < 0:
		s = LevelHit.covered_screw(_state, gu)
	if s >= 0:
		tap_screw(s)
		return
	var plank := LevelHit.plank(_state, gu)
	if plank >= 0:
		_press_plank(_planks[plank])
		_sfx("knock_dull", 1.5, -18.0)
	elif _layout.panel.has_point(p):
		_marks.add_ripple(p, 22.0, Color(RING_COLOR, 0.7))
		_sfx("knock_dull", 1.7, -20.0)


## Taps a screw by id: asks the logic, applies its answer, animates it. Returns the logic's
## answer. Input is never blocked by animation (docs/ARCHITECTURE.md 5.2).
func tap_screw(screw: int) -> TapResult:
	if _state == null or _paused or _held:
		return TapResult.failed(TapResult.NOT_PLAYING)
	_idle = 0.0
	var r := _state.tap(screw)
	if r.ok:
		_after_accepted_action()
		_begin_action()
		_apply_events(r.events)
		_update_hint_after_tap()
		_end_action()
	else:
		_feedback_for(screw, r.reason)
		_hint.hide_hint()
	return r


# == Building the level ==

func _ensure_nodes() -> void:
	if _content != null:
		return
	_content = Node2D.new()
	add_child(_content)
	_plank_clip = Control.new()
	_plank_clip.clip_contents = true
	_plank_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_plank_clip)
	_board_root = Node2D.new()
	_plank_clip.add_child(_board_root)
	_planks_root = Node2D.new()
	_board_root.add_child(_planks_root)
	_box_root = Node2D.new()
	_content.add_child(_box_root)
	_screw_layer = Node2D.new()
	_content.add_child(_screw_layer)
	_marks = LevelMarks.new()
	_marks.z_index = Z_MARKS
	_content.add_child(_marks)
	_hint = LevelHint.new()
	_hint.z_index = Z_HINT
	_content.add_child(_hint)
	_hud = LevelHud.new()
	_hud.z_index = Z_HUD
	_content.add_child(_hud)


func _start_attempt() -> void:
	_ensure_nodes()
	_epoch += 1
	_cancel_anims()
	_marks.clear()
	_hint.hide_hint()
	_clear_views()
	_state = PlayState.start(_level)
	if _state == null:
		return
	_over = false
	_fixes = 0
	_idle = 0.0
	_last_timer_second = -1
	_end_anim = null
	_pending.clear()
	_clock.reset()
	_clock.set_paused(_paused, Time.get_ticks_msec())
	_relayout()
	_build_views()
	_hud.configure(_layout, _label(), _timer_visible(), _level.line)
	_apply_layout(true)
	_update_pips()
	if not _instant:
		_play_intro()
	queue_redraw()


func _clear_views() -> void:
	for child: Node in _planks_root.get_children():
		child.free()
	for child: Node in _box_root.get_children():
		child.free()
	for child: Node in _screw_layer.get_children():
		child.free()
	_screws.clear()
	_planks.clear()
	_box_views.clear()
	_preview_views.clear()
	_preview_colors.clear()
	_tray_view = null
	_tray_shift = 0.0
	_tray_warned = false
	_tray_tick_due = false


func _build_views() -> void:
	var ps := _state
	for p: int in _level.planks.size():
		var data := _level.planks[p]
		var slot := LevelPlankSlot.new()
		slot.plank = p
		slot.outline_gu = data.outline()
		slot.view = LevelViews.make_plank(slot.outline_gu, data.inner_outline(), data.layer, data.holes, p * 7919 + _level.number)
		slot.view.z_index = 4 - data.layer
		_planks_root.add_child(slot.view)
		_planks.append(slot)
		slot.state = ps.plank_state(p)
		var pose := ps.plank_pose(p)
		slot.pivot_screw = -1
		if slot.state == PlayState.HANGING:
			slot.pivot_screw = _pivot_screw(p)
		slot.rest = pose.z
		if slot.state == PlayState.HANGING:
			slot.pose(Vector2(pose.x, pose.y) * LevelLayout.GRID_DU, pose.z)
		else:
			slot.pose(Vector2.ZERO, 0.0)
	for s: int in _level.screw_count():
		var slot := LevelScrewSlot.new()
		slot.screw = s
		slot.view = LevelViews.make_screw(_level.screw_colors[s], LevelViews.SCREW_BOARD)
		slot.covered = not ps.is_free(s)
		LevelViews.set_covered(slot.view, slot.covered)
		slot.view.z_index = Z_SCREW
		_screw_layer.add_child(slot.view)
		_screws.append(slot)
	var open := Tuning.open_boxes
	var wells := Tuning.box_slots
	_box_views.resize(open)
	_box_color.resize(open)
	_box_color.fill(-1)
	_box_wells.resize(open * wells)
	_box_wells.fill(-1)
	for pos: int in open:
		var color := ps.open_box(pos).x
		_box_color[pos] = color
		if color >= 0:
			var box := LevelViews.make_box(color, false)
			_box_root.add_child(box)
			_box_views[pos] = box
		var inside := ps.box_screws(pos)
		for w: int in wells:
			_box_wells[pos * wells + w] = inside[w]
	for color: int in ps.preview():
		var box := LevelViews.make_box(color, true)
		_box_root.add_child(box)
		_preview_views.append(box)
		_preview_colors.append(color)
	_tray_screws = ps.tray()
	_tray_view = LevelViews.make_tray(_tray_screws.size())
	_box_root.add_child(_tray_view)
	_pos_land_at.resize(open)
	_pos_free_at.resize(open)
	_pos_arrive_start.resize(open)
	_pos_arrive_end.resize(open)
	_pos_jumps.resize(open)
	_pos_land_at.fill(0.0)
	_pos_free_at.fill(0.0)
	_pos_arrive_start.fill(0.0)
	_pos_arrive_end.fill(0.0)
	_pos_jumps.fill(0)
	_refresh_tray()


## The screw a hanging plank hangs on: the one still on the board.
func _pivot_screw(plank: int) -> int:
	for s: int in _level.planks[plank].screws:
		if _state.is_on_board(s):
			return s
	return -1


## Places every view for the current layout. While paused it only notes that this is due: placing
## views finishes running animations, which would announce a pending win or loss under the pause
## screen. resume() does it, and the ending is announced then.
func _apply_layout(force: bool = false) -> void:
	if _layout == null or _board_root == null:
		return
	if _paused and not force:
		_layout_due = true
		queue_redraw()
		return
	_layout_due = false
	_plank_clip.position = _layout.panel.position
	_plank_clip.size = _layout.panel.size
	_board_root.position = _layout.core_origin - _layout.panel.position
	_board_root.scale = Vector2.ONE * _layout.b
	if _state != null:
		_finish_anims()
		for pos: int in _box_views.size():
			var box := _box_views[pos]
			if box != null:
				box.position = _layout.open_pos[pos]
				box.scale = Vector2.ONE * _layout.box_scale
		for k: int in _preview_views.size():
			_preview_views[k].position = _layout.preview_pos[mini(k, _layout.preview_pos.size() - 1)]
			_preview_views[k].scale = Vector2.ONE * _layout.box_scale
		if _tray_view != null:
			_tray_view.position = _layout.tray_center + Vector2(_tray_shift, 0.0)
			_tray_view.scale = Vector2.ONE * _layout.box_scale
		for slot: LevelScrewSlot in _screws:
			_place_screw_now(slot)
	_hud.set_layout(_layout)
	if _state != null and _hint.is_showing():
		_point_hint(false)
	queue_redraw()


@warning_ignore("integer_division")
func _play_intro() -> void:
	var n := _planks.size()
	var sound_step := maxi(1, n / 5)
	for i: int in n:
		var plank := _planks[i]
		if plank.state == PlayState.FALLEN:
			continue
		var wait := 0.1 * i / maxf(1.0, n)
		var base := plank.view.position
		plank.view.modulate.a = 0.0
		var drop := LevelAnims.Timed.new(wait, 0.2, _intro_plank.bind(plank, base))
		plank.anim = drop
		_anims.append(drop)
		if i % sound_step == 0:
			_anims.append(LevelAnims.after(wait, _sfx.bind("knock", 1.0 + 0.04 * i, -18.0)))
		for s: int in _level.planks[plank.plank].screws:
			var slot := _screws[s]
			slot.view.modulate.a = 0.0
			var screw_drop := LevelAnims.Timed.new(wait, 0.2, _intro_screw.bind(slot))
			slot.anim = screw_drop
			_anims.append(screw_drop)


func _intro_plank(p: float, plank: LevelPlankSlot, base: Vector2) -> void:
	var e := LevelAnim.out_quad(p)
	plank.view.position = base + Vector2(0.0, -36.0 * (1.0 - e))
	plank.view.modulate.a = e


func _intro_screw(p: float, slot: LevelScrewSlot) -> void:
	var e := LevelAnim.out_quad(p)
	slot.view.position = _screw_rest(slot) + Vector2(0.0, -36.0 * _layout.b * (1.0 - e))
	slot.view.modulate.a = e


# == Layout ==

func _area() -> Vector2:
	if _forced_size.x > 0.0 and _forced_size.y > 0.0:
		return _forced_size
	if size.x >= 1.0 and size.y >= 1.0:
		return size
	return get_viewport_rect().size if is_inside_tree() else Vector2(360.0, 640.0)


func _dpu() -> float:
	if dp_per_unit > 0.0:
		return dp_per_unit
	if OS.has_feature("mobile") and is_inside_tree():
		var units := get_viewport().get_visible_rect().size.x
		var window_px := float(get_window().size.x)
		var dpi := float(DisplayServer.screen_get_dpi())
		if units > 0.0 and dpi > 0.0:
			return (window_px / units) / (dpi / 160.0)
	return 1.0


func _relayout() -> void:
	var area := _area()
	var top := _inset_top
	var bottom := _inset_bottom
	if not _insets_set and OS.has_feature("mobile") and is_inside_tree():
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		var units := get_viewport().get_visible_rect().size.x
		if units > 0.0 and screen.x > 0:
			var px := float(screen.x) / units
			top = maxf(top, float(safe.position.y) / px)
			bottom = maxf(bottom, float(screen.y - safe.end.y) / px)
	var content := Rect2(Vector2(_inset_left, top), area - Vector2(_inset_left + _inset_right, top + bottom))
	_layout = LevelLayout.compute(content, _dpu(), Tuning.open_boxes, Tuning.preview)
	_apply_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _content != null:
		_relayout()
	elif what == NOTIFICATION_PREDELETE:
		_cancel_anims()
		for slot: LevelScrewSlot in _screws:
			slot.anim = null
		for slot: LevelPlankSlot in _planks:
			slot.anim = null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _area()), PEGBOARD)
	if _layout == null:
		return
	var l := _layout
	draw_rect(Rect2(l.content.position.x, 0.0, l.content.size.x, l.top_bar.end.y + 2.0), BAND)
	draw_rect(l.panel.grow(4.0), BOARD_BACK)
	draw_rect(Rect2(l.core_origin, Vector2(LevelLayout.CORE_W, LevelLayout.CORE_H) * l.b), BOARD_CORE)
	if l.split:
		draw_rect(l.rail.grow(4.0), BOARD_BACK)
	else:
		draw_rect(l.boxes_bar, BAND)
		draw_rect(l.tray_bar, BAND)
	if l.open_pos.size() > 0 and l.preview_pos.size() > 0:
		var x: float = l.open_pos[l.open_pos.size() - 1].x + (LevelLayout.OPEN_W + 2.0) * l.box_scale
		var y: float = l.open_pos[0].y + 28.0 * l.box_scale
		var c := 4.0 * l.box_scale
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - c), Vector2(x + c, y), Vector2(x, y + c)]), Color(RING_COLOR, 0.8))


# == Input ==

func _gui_input(event: InputEvent) -> void:
	if _paused or _state == null:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_touch(touch.position, touch.pressed)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		# A touch also arrives as an emulated mouse click; the touch itself was handled above.
		if click.button_index == MOUSE_BUTTON_LEFT and click.device != InputEvent.DEVICE_ID_EMULATION:
			_touch(click.position, click.pressed)


func _touch(p: Vector2, pressed: bool) -> void:
	var target := _hud.pause_target()
	if pressed:
		if target.has_point(p):
			_pause_down = true
			_hud.set_pause_pressed(true)
			_sfx("knock_dull", 1.3, -12.0)
			return
		tap_at(p)
	elif _pause_down:
		_pause_down = false
		_hud.set_pause_pressed(false)
		if target.has_point(p):
			pause_requested.emit()


# == Applying what the logic said ==

## The first hinted screw still free, or -1 (tutorial levels only).
func _hint_screw() -> int:
	if _level == null or _state == null or _level.kind != LevelData.TUTORIAL:
		return -1
	for s: int in _level.hint:
		if _state.is_free(s):
			return s
	return -1


func _point_hint(glide: bool) -> void:
	var s := _hint_screw()
	if s < 0 or _over:
		_hint.hide_hint()
	else:
		_hint.point_at(_layout.gu_to_scene(_level.screw_center(s)), _layout.b, glide)


## After a tap: on level 1 the hand glides on to the next screw; elsewhere it waits for 8 seconds.
func _update_hint_after_tap() -> void:
	if _level.kind == LevelData.TUTORIAL and _level.number == 1:
		_point_hint(true)
	else:
		_hint.hide_hint()


func _after_accepted_action() -> void:
	if _clock.start(Time.get_ticks_msec()):
		first_action.emit()


func _begin_action() -> void:
	_action_land = _anim_time
	_action_arrive = 0.0


func _end_action() -> void:
	_sync_previews()
	_refresh_tray()
	_reconcile()
	_update_pips()
	_hud.set_timer_text(_timer_text())
	var calls := _pending.duplicate()
	_pending.clear()
	for c: Callable in calls:
		c.call()


func _apply_events(events: Array[LogicEvent]) -> void:
	for e: LogicEvent in events:
		match e.kind:
			LogicEvent.SCREW_TO_BOX:
				_ev_screw_to_box(e)
			LogicEvent.SCREW_TO_TRAY:
				_ev_screw_to_tray(e)
			LogicEvent.PLANK_SWUNG:
				_ev_plank_swung(e)
			LogicEvent.PLANK_FELL:
				_ev_plank_fell(e)
			LogicEvent.COVER_CHANGED:
				for s: int in e.screws:
					_set_covered(s, not _state.is_free(s))
			LogicEvent.BOX_CLOSED:
				_ev_box_closed(e)
			LogicEvent.BOX_ARRIVED:
				_ev_box_arrived(e)
			LogicEvent.TRAY_TO_BOX:
				_ev_tray_to_box(e)
			LogicEvent.TRAY_EXTENDED:
				_ev_tray_extended(e)
			LogicEvent.UNDONE:
				_ev_undone(e)
			LogicEvent.WON:
				_ev_won()
			LogicEvent.LOST:
				_ev_lost()
			LogicEvent.RESUMED:
				_ev_resumed()


func _ev_screw_to_box(e: LogicEvent) -> void:
	var slot := _screws[e.screw]
	_box_wells[e.position * Tuning.box_slots + e.well] = e.screw
	var land := _fly_screw(slot, LevelScrewSlot.BOX, e.position, e.well, 0.0, false, false, _pos_arrive_end[e.position], 1.0)
	_pos_land_at[e.position] = maxf(_pos_land_at[e.position], land)
	_action_land = maxf(_action_land, land)


func _ev_screw_to_tray(e: LogicEvent) -> void:
	var slot := _screws[e.screw]
	_tray_screws[e.slot] = e.screw
	var land := _fly_screw(slot, LevelScrewSlot.TRAY, e.slot, -1, 0.0, false, false, 0.0, 1.0)
	_action_land = maxf(_action_land, land)


func _ev_tray_to_box(e: LogicEvent) -> void:
	var slot := _screws[e.screw]
	var pos := e.position
	_tray_screws[e.slot] = -1
	_box_wells[pos * Tuning.box_slots + e.well] = e.screw
	var k := _pos_jumps[pos]
	_pos_jumps[pos] = k + 1
	var start := _pos_arrive_start[pos] + JUMP_AFTER_ARRIVAL + k * JUMP_STAGGER
	var land := _fly_screw(slot, LevelScrewSlot.BOX, pos, e.well, maxf(0.0, start - _anim_time), true, true, 0.0, 1.0 + 0.1 * k)
	_pos_land_at[pos] = maxf(_pos_land_at[pos], land)
	_action_land = maxf(_action_land, land)


func _ev_plank_swung(e: LogicEvent) -> void:
	var slot := _planks[e.plank]
	slot.state = PlayState.HANGING
	slot.pivot_screw = e.screw
	slot.rest = e.angle
	var about := _level.screw_center(e.screw) * LevelLayout.GRID_DU
	if _instant:
		slot.stop()
		slot.view.modulate.a = 1.0
		slot.pose(about, e.angle)
		return
	var from := slot.angle
	slot.stop()
	slot.view.modulate.a = 1.0
	if absf(from - e.angle) < 0.01:
		slot.pose(about, e.angle)
		return
	var swing := LevelAnims.Swing.new(slot, about, from, e.angle)
	slot.anim = swing
	_anims.append(swing)
	slot.pose(about, from)


func _ev_plank_fell(e: LogicEvent) -> void:
	var slot := _planks[e.plank]
	slot.state = PlayState.FALLEN
	var pose := _state.plank_pose(e.plank)
	var about := Vector2(pose.x, pose.y) * LevelLayout.GRID_DU
	slot.pivot_screw = -1
	slot.stop()
	slot.view.modulate.a = 1.0
	if _instant:
		slot.view.visible = false
		return
	var from := slot.angle if slot.pivot.is_equal_approx(about) else pose.z
	slot.pose(about, from)
	var fall := LevelAnims.Fall.new(slot, about, from, FALL_HANG)
	fall.spin = 55.0 if e.plank % 2 == 0 else -55.0
	fall.drift = -fall.spin * 0.4
	fall.on_leave = _sfx.bind("knock", 1.0, 0.0)
	slot.anim = fall
	_anims.append(fall)


func _ev_box_closed(e: LogicEvent) -> void:
	var pos := e.position
	var wells := Tuning.box_slots
	var box := _box_views[pos]
	var group: Array[Node2D] = []
	if box != null:
		group.append(box)
	var start := maxf(_anim_time, maxf(_pos_land_at[pos], _pos_free_at[pos]))
	for w: int in wells:
		var s := _box_wells[pos * wells + w]
		if s >= 0:
			var slot := _screws[s]
			slot.kind = LevelScrewSlot.CLOSED
			slot.a = pos
			slot.b = w
			group.append(slot.view)
		_box_wells[pos * wells + w] = -1
	_box_views[pos] = null
	_box_color[pos] = -1
	if _instant:
		for n: Node2D in group:
			n.visible = false
		if box != null:
			box.queue_free()
		return
	var wait := start - _anim_time
	if box != null:
		_anims.append(LevelAnims.after(wait, _close_box.bind(box)))
	var mover := LevelAnims.GroupMove.new(group, Vector2(0.0, -70.0 * _layout.box_scale), wait + LID_CLOSE, BOX_LEAVE, LevelAnims.EASE_IN_CUBIC)
	mover.alpha_end = 0.0
	mover.hide_at_end = true
	if box != null:
		mover.on_done = box.queue_free
	_anims.append(mover)
	_pos_free_at[pos] = start + LID_CLOSE + BOX_LEAVE * 0.5


func _close_box(box: Variant) -> void:
	if is_instance_valid(box):
		LevelViews.close_box(box)
		_sfx("knock", 1.25, -6.0)


func _ev_box_arrived(e: LogicEvent) -> void:
	var pos := e.position
	_pos_jumps[pos] = 0
	if e.color < 0:
		return
	var box: Node2D = null
	if not _preview_views.is_empty() and _preview_colors[0] == e.color:
		box = _preview_views.pop_front()
		_preview_colors.remove_at(0)
	else:
		box = LevelViews.make_box(e.color, true)
		_box_root.add_child(box)
		box.position = _layout.preview_pos[_layout.preview_pos.size() - 1] + Vector2(60.0, 0.0)
		box.scale = Vector2.ONE * _layout.box_scale
	_box_views[pos] = box
	_box_color[pos] = e.color
	var target := _layout.open_pos[pos]
	if _instant:
		box.position = target
		LevelViews.reset_box(box, e.color, false)
		_pos_arrive_start[pos] = _anim_time
		_pos_arrive_end[pos] = _anim_time
		return
	var start := maxf(_anim_time, _pos_free_at[pos])
	var wait := start - _anim_time
	_pos_arrive_start[pos] = start
	_pos_arrive_end[pos] = start + BOX_ARRIVE
	_pos_free_at[pos] = start + BOX_ARRIVE
	_action_arrive = maxf(_action_arrive, start)
	_slide(box, target, wait, BOX_ARRIVE, LevelAnims.EASE_OUT_BACK, 1.0)
	_anims.append(LevelAnims.after(wait + BOX_ARRIVE * 0.3, _open_look.bind(box, e.color)))


## Slides one view to `target`, taking over from any slide it is already in.
func _slide(view: Node2D, target: Vector2, wait: float, seconds: float, easing: int, alpha_end: float) -> void:
	var key := view.get_instance_id()
	if _moves.has(key):
		(_moves[key] as LevelAnim).cancel()
	var group: Array[Node2D] = [view]
	var mover := LevelAnims.GroupMove.new(group, target - view.position, wait, seconds, easing)
	mover.alpha_end = alpha_end
	mover.on_done = _forget_move.bind(key)
	_moves[key] = mover
	_anims.append(mover)


func _forget_move(key: int) -> void:
	_moves.erase(key)


func _open_look(box: Variant, color: int) -> void:
	if is_instance_valid(box):
		LevelViews.reset_box(box, color, false)


func _ev_tray_extended(_e: LogicEvent) -> void:
	_tray_screws = _state.tray()
	LevelViews.setup_tray(_tray_view, _tray_screws.size())
	_refresh_tray()


## Undo (Phase 4 wires the button): the undone screw flies back, everything else changes at once.
func _ev_undone(e: LogicEvent) -> void:
	# Whatever was moving finishes at once (a box leaving, previews sliding), except the undone
	# screw's own flight: it lands first, then flies back.
	if _end_anim != null:
		_end_anim.cancel()
		_end_anim = null
	_finish_anims_except(_screws[e.screw].anim)
	var tray := _state.tray()
	_tray_screws = tray
	for s: int in e.screws:
		var kind := LevelScrewSlot.CLOSED
		var a := -1
		var b := -1
		if _state.is_on_board(s):
			kind = LevelScrewSlot.BOARD
		elif tray.has(s):
			kind = LevelScrewSlot.TRAY
			a = tray.find(s)
		else:
			for pos: int in _box_views.size():
				var inside := _state.box_screws(pos)
				if inside.has(s):
					kind = LevelScrewSlot.BOX
					a = pos
					b = inside.find(s)
		var slot := _screws[s]
		if s == e.screw and kind == LevelScrewSlot.BOARD and not _instant:
			_fly_screw(slot, kind, a, b, 0.0, true, false, 0.0, 1.0)
			_sfx("ratchet", 0.7, -8.0)
			continue
		slot.kind = kind
		slot.a = a
		slot.b = b
		_set_covered(s, kind == LevelScrewSlot.BOARD and not _state.is_free(s))
		_place_screw_now(slot)
	# An undo can also change which screws are covered without moving them.
	for slot: LevelScrewSlot in _screws:
		var want := slot.kind == LevelScrewSlot.BOARD and not _state.is_free(slot.screw)
		if slot.covered != want:
			_set_covered(slot.screw, want)
	_rebuild_boxes_and_planks()


func _ev_won() -> void:
	_over = true
	var now := Time.get_ticks_msec()
	_clock.stop(now)
	var result := LevelResult.new()
	result.level = _level
	result.replay = _replay
	result.elapsed_ms = _clock.elapsed_ms(now)
	result.tray_uses = _state.tray_uses()
	result.helpers_used = _state.helpers_used()
	result.stars = Stars.award(_level, true, result.elapsed_ms, result.tray_uses, result.helpers_used)
	var wait := maxf(WIN_DELAY, _action_land - _anim_time + 0.1)
	_schedule_end(wait, _emit_won.bind(result, _epoch))


func _ev_lost() -> void:
	_over = true
	_clock.stop(Time.get_ticks_msec())
	var land := maxf(0.0, _action_land - _anim_time)
	if not _instant:
		_anims.append(LevelAnims.Timed.new(land, 0.25, _shake_tray))
	_schedule_end(land + LOSS_DELAY, _emit_lost.bind(_epoch))


func _ev_resumed() -> void:
	_over = false
	if _end_anim != null:
		_end_anim.cancel()
		_end_anim = null
	_pending.clear()
	_clock.resume_after_stop(Time.get_ticks_msec())


func _schedule_end(wait: float, what: Callable) -> void:
	if _instant:
		_pending.append(what)
		return
	_end_anim = LevelAnims.after(wait, what)
	_anims.append(_end_anim)


func _emit_won(result: LevelResult, epoch: int) -> void:
	if epoch == _epoch:
		won.emit(result)


func _emit_lost(epoch: int) -> void:
	if epoch == _epoch:
		lost.emit(_level)


func _shake_tray(p: float) -> void:
	_set_tray_shift(6.0 * sin(p * TAU * 3.0) * (1.0 - p))


## Moves the tray and the screws resting in it sideways (the refused tap and the loss).
func _set_tray_shift(shift: float) -> void:
	_tray_shift = shift
	if _layout == null or _tray_view == null:
		return
	_tray_view.position = _layout.tray_center + Vector2(shift, 0.0)
	for slot: LevelScrewSlot in _screws:
		if slot.kind == LevelScrewSlot.TRAY and (slot.anim == null or slot.anim.done):
			slot.view.position = _screw_rest(slot)


# == Screws ==

func _screw_scale(kind: int) -> float:
	match kind:
		LevelScrewSlot.BOX:
			return _layout.box_scale * LevelViews.SCREW_DIAMETERS[LevelViews.SCREW_WELL] / LevelViews.SCREW_DIAMETERS[LevelViews.SCREW_BOARD]
		LevelScrewSlot.TRAY:
			return _layout.box_scale * LevelViews.SCREW_DIAMETERS[LevelViews.SCREW_TRAY] / LevelViews.SCREW_DIAMETERS[LevelViews.SCREW_BOARD]
	return _layout.b


## Where a screw rests for its place now.
func _screw_rest(slot: LevelScrewSlot) -> Vector2:
	match slot.kind:
		LevelScrewSlot.BOX:
			return _layout.well_center(slot.a, slot.b)
		LevelScrewSlot.TRAY:
			return _layout.tray_slot_center(slot.a, _tray_screws.size()) + Vector2(_tray_shift, 0.0)
		LevelScrewSlot.CLOSED:
			# Gone with its box; the well it was in is remembered, for an undo.
			if slot.a >= 0:
				return _layout.well_center(slot.a, slot.b)
	return _layout.gu_to_scene(_level.screw_center(slot.screw))


## Puts a screw where its place says, with no motion.
func _place_screw_now(slot: LevelScrewSlot) -> void:
	slot.stop()
	var v := slot.view
	v.visible = slot.kind != LevelScrewSlot.CLOSED
	v.position = _screw_rest(slot)
	v.scale = Vector2.ONE * _screw_scale(slot.kind)
	v.modulate.a = 1.0
	v.z_index = Z_SCREW
	LevelViews.set_lift(v, 0.0)
	LevelViews.set_turn(v, 0.0)


func _set_covered(s: int, covered: bool) -> void:
	var slot := _screws[s]
	slot.covered = covered
	LevelViews.set_covered(slot.view, covered)


## A screw leaves for a new place. Returns when it lands, in animation time.
## `hop` is a short hop with no unscrewing: a tray screw jumping into a new box, or the undone
## screw flying back. `chain` makes a tray screw that is still flying into the tray land first
## and then hop from its slot, after `wait` seconds. `not_before` keeps a screw from landing in
## a box that has not finished sliding in.
func _fly_screw(slot: LevelScrewSlot, kind: int, a: int, b: int, wait: float, hop: bool, chain: bool, not_before: float, pitch: float) -> float:
	var was := LevelScrewSlot.new()
	was.screw = slot.screw
	was.kind = slot.kind
	was.a = slot.a
	was.b = slot.b
	slot.kind = kind
	slot.a = a
	slot.b = b
	_set_covered(slot.screw, false)
	if _instant:
		_place_screw_now(slot)
		return _anim_time
	var v := slot.view
	var delay := wait
	var from := v.position
	if chain:
		if slot.anim != null and not slot.anim.done:
			delay = maxf(delay, slot.anim.remaining())
		from = _screw_rest(was)
	else:
		var flying := slot.anim != null and not slot.anim.done and slot.anim is LevelAnims.Flight
		if not flying and hop:
			from = _screw_rest(was)
		slot.stop()
		v.visible = true
		v.modulate.a = 1.0
		if not hop:
			_sfx("ratchet")
	var to := _screw_rest(slot)
	if kind == LevelScrewSlot.TRAY:
		# The tray may be mid shake; the screw lands where the tray rests.
		to.x -= _tray_shift
	var unscrew := 0.0 if hop else UNSCREW
	var fly := JUMP_FLIGHT if (hop and chain) else lerpf(FLIGHT_SHORT, FLIGHT_LONG, clampf(from.distance_to(to) / 500.0, 0.0, 1.0))
	var land := _anim_time + delay + unscrew + fly
	if land < not_before:
		fly += not_before - land
		land = not_before
	var start_scale := v.scale.x
	if chain:
		start_scale = _screw_scale(was.kind)
	var flight := LevelAnims.Flight.new(v, from, to, start_scale, _screw_scale(kind), delay, unscrew, fly)
	flight.arc = (30.0 if hop and chain else clampf(from.distance_to(to) * 0.25, 40.0, 60.0)) * maxf(1.0, _layout.box_scale)
	flight.z_rest = Z_SCREW
	flight.z_fly = Z_SCREW_FLYING
	if not hop:
		flight.on_pop = _sfx.bind("pop")
	flight.on_land = _on_screw_landed.bind(slot.screw, kind, a, pitch, _epoch)
	flight.turn_dir = 1.0 if kind == LevelScrewSlot.BOARD else -1.0
	slot.anim = flight
	_anims.append(flight)
	return land


func _on_screw_landed(screw: int, kind: int, position: int, pitch: float, epoch: int) -> void:
	if epoch != _epoch:
		return
	if kind == LevelScrewSlot.BOARD:
		_set_covered(screw, not _state.is_free(screw))
	elif kind == LevelScrewSlot.BOX:
		_sfx("clink", pitch)
		var count := 0
		for w: int in Tuning.box_slots:
			if _box_wells[position * Tuning.box_slots + w] >= 0:
				count += 1
		if _box_views[position] != null:
			LevelViews.set_box_count(_box_views[position], count)
	elif kind == LevelScrewSlot.TRAY:
		_sfx("clink_tray")
		_refresh_tray()
		if _tray_tick_due:
			_tray_tick_due = false
			_sfx("knock_dull", 1.6, -14.0)


func _refresh_tray() -> void:
	if _tray_view == null:
		return
	var filled := PackedByteArray()
	filled.resize(_tray_screws.size())
	var free := 0
	for i: int in _tray_screws.size():
		filled[i] = 1 if _tray_screws[i] >= 0 else 0
		if _tray_screws[i] < 0:
			free += 1
	LevelViews.set_tray_filled(_tray_view, filled)
	var warn := free == 1
	LevelViews.set_tray_warning(_tray_view, warn)
	LevelViews.set_tray_full(_tray_view, free == 0)
	if warn and not _tray_warned:
		_tray_tick_due = true
	_tray_warned = warn


## Previews follow the logic's queue: the ones that moved up slide one place, a new one
## slides in at the end.
func _sync_previews() -> void:
	var want := _state.preview()
	var wait := maxf(0.0, _action_arrive - _anim_time)
	while _preview_views.size() > want.size():
		var gone: Node2D = _preview_views.pop_back()
		gone.queue_free()
		_preview_colors.resize(_preview_views.size())
	for k: int in want.size():
		var target := _layout.preview_pos[mini(k, _layout.preview_pos.size() - 1)]
		var view: Node2D = null
		if k < _preview_views.size() and _preview_colors[k] == want[k]:
			view = _preview_views[k]
		else:
			if k < _preview_views.size():
				_preview_views[k].queue_free()
			view = LevelViews.make_box(want[k], true)
			_box_root.add_child(view)
			view.scale = Vector2.ONE * _layout.box_scale
			view.position = target + Vector2(50.0 * _layout.box_scale, 0.0)
			if not _instant:
				view.modulate.a = 0.0
			if k < _preview_views.size():
				_preview_views[k] = view
				_preview_colors[k] = want[k]
			else:
				_preview_views.append(view)
				_preview_colors.append(want[k])
		if _instant or view.position.is_equal_approx(target):
			view.position = target
			view.modulate.a = 1.0
		else:
			_slide(view, target, wait, BOX_ARRIVE, LevelAnims.EASE_OUT_CUBIC, 1.0)


## Puts boxes, previews and planks right after an undo.
func _rebuild_boxes_and_planks() -> void:
	var wells := Tuning.box_slots
	for pos: int in _box_views.size():
		var want := _state.open_box(pos).x
		var inside := _state.box_screws(pos)
		for w: int in wells:
			_box_wells[pos * wells + w] = inside[w]
		if _box_color[pos] != want or (_box_views[pos] == null) != (want < 0):
			if _box_views[pos] != null:
				_box_views[pos].queue_free()
				_box_views[pos] = null
			_box_color[pos] = want
			if want >= 0:
				var box := LevelViews.make_box(want, false)
				_box_root.add_child(box)
				box.position = _layout.open_pos[pos]
				box.scale = Vector2.ONE * _layout.box_scale
				_box_views[pos] = box
	for k: int in _preview_views.size():
		_preview_views[k].queue_free()
	_preview_views.clear()
	_preview_colors.clear()
	for color: int in _state.preview():
		var box := LevelViews.make_box(color, true)
		_box_root.add_child(box)
		box.scale = Vector2.ONE * _layout.box_scale
		box.position = _layout.preview_pos[mini(_preview_views.size(), _layout.preview_pos.size() - 1)]
		_preview_views.append(box)
		_preview_colors.append(color)
	for slot: LevelPlankSlot in _planks:
		var st := _state.plank_state(slot.plank)
		var pose := _state.plank_pose(slot.plank)
		slot.stop()
		slot.state = st
		slot.view.modulate.a = 1.0
		slot.view.visible = st != PlayState.FALLEN
		slot.pivot_screw = _pivot_screw(slot.plank) if st == PlayState.HANGING else -1
		slot.rest = pose.z
		if st == PlayState.FIXED:
			slot.pose(Vector2.ZERO, 0.0)
		elif st == PlayState.HANGING:
			slot.pose(Vector2(pose.x, pose.y) * LevelLayout.GRID_DU, pose.z)
	_refresh_tray()


# == Feedback for taps that change nothing (UX 6.1) ==

func _feedback_for(screw: int, reason: int) -> void:
	match reason:
		TapResult.COVERED:
			_covered_tap(screw)
		TapResult.REFUSED:
			_refused_tap(screw)


func _covered_tap(screw: int) -> void:
	var plank := _state.cover_plank(screw)
	_sfx("knock_dull")
	if plank >= 0:
		LevelViews.wiggle(_planks[plank].view)
		if not _instant:
			_marks.add_outline(_drawn_outline_scene(_planks[plank]), Color(RING_COLOR, 0.8), 0.6)
	if not _instant:
		_marks.add_ring(_layout.gu_to_scene(_level.screw_center(screw)), 15.0 * _layout.b, Color(RING_COLOR, 0.9), 0.6)


func _refused_tap(screw: int) -> void:
	_sfx("knock_dull", 0.85)
	_hud.show_toast("The tray is full. Tap a screw that fits an open box.")
	if _instant:
		return
	var slot := _screws[screw]
	if slot.anim != null:
		slot.anim.finish()
	slot.anim = LevelAnims.Timed.new(0.0, 0.16, _refuse_shake.bind(slot))
	_anims.append(slot.anim)
	_anims.append(LevelAnims.Timed.new(0.0, 0.2, _nudge_tray))
	for s: int in _level.screw_count():
		if _state.is_free(s) and _state.destination(s).x == PlayState.BOX:
			_marks.add_ring(_layout.gu_to_scene(_level.screw_center(s)), 16.0 * _layout.b, Color(RING_COLOR, 0.9), 1.0)


## A tap on a plank away from its screws: it presses in by about 2 units and back (120 ms).
## Skipped while the plank is already moving (intro, swing, fall).
func _press_plank(slot: LevelPlankSlot) -> void:
	if _instant or (slot.anim != null and not slot.anim.done):
		return
	slot.anim = LevelAnims.Timed.new(0.0, 0.12, _press_step.bind(slot))
	_anims.append(slot.anim)


func _press_step(p: float, slot: LevelPlankSlot) -> void:
	slot.pose(slot.pivot, slot.angle)
	var shrink := 0.03 * sin(PI * p)
	if shrink < 0.0005:
		return
	var center := Vector2.ZERO
	for q: Vector2 in slot.outline_gu:
		center += q
	center = center * LevelLayout.GRID_DU / maxf(1.0, slot.outline_gu.size())
	slot.view.scale = Vector2.ONE * (1.0 - shrink)
	slot.view.position += (center * shrink).rotated(slot.view.rotation)


func _refuse_shake(p: float, slot: LevelScrewSlot) -> void:
	var bump := sin(PI * p)
	LevelViews.set_lift(slot.view, 0.35 * bump)
	LevelViews.set_turn(slot.view, 30.0 * bump)


func _nudge_tray(p: float) -> void:
	_set_tray_shift(4.0 * sin(p * TAU * 2.0))


## The outline of a plank as it is drawn now, in scene units, closed.
func _drawn_outline_scene(slot: LevelPlankSlot) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in slot.outline_gu:
		out.append(_layout.core_origin + (slot.view.transform * (p * LevelLayout.GRID_DU)) * _layout.b)
	if out.size() > 0:
		out.append(out[0])
	return out


# == The safety net: the model is right ==

## Compares what the view believes with the model and corrects it, counting each correction.
## Normal play never needs one; a test checks the count stays 0.
func _reconcile() -> void:
	var tray := _state.tray()
	var wells := Tuning.box_slots
	for s: int in _level.screw_count():
		var kind := LevelScrewSlot.CLOSED
		var a := -1
		var b := -1
		if _state.is_on_board(s):
			kind = LevelScrewSlot.BOARD
		elif tray.has(s):
			kind = LevelScrewSlot.TRAY
			a = tray.find(s)
		else:
			for pos: int in _box_views.size():
				var inside := _state.box_screws(pos)
				if inside.has(s):
					kind = LevelScrewSlot.BOX
					a = pos
					b = inside.find(s)
		var slot := _screws[s]
		if slot.kind != kind or (kind != LevelScrewSlot.CLOSED and (slot.a != a or slot.b != b)):
			_fixes += 1
			slot.kind = kind
			slot.a = a
			slot.b = b
			_place_screw_now(slot)
		var want_cover := kind == LevelScrewSlot.BOARD and not _state.is_free(s)
		if slot.covered != want_cover:
			_fixes += 1
			_set_covered(s, want_cover)
	for slot: LevelPlankSlot in _planks:
		var st := _state.plank_state(slot.plank)
		var pose := _state.plank_pose(slot.plank)
		var pivot := _pivot_screw(slot.plank) if st == PlayState.HANGING else -1
		if slot.state != st or slot.pivot_screw != pivot or (st == PlayState.HANGING and not is_equal_approx(slot.rest, pose.z)):
			_fixes += 1
			slot.stop()
			slot.state = st
			slot.pivot_screw = pivot
			slot.rest = pose.z
			slot.view.modulate.a = 1.0
			slot.view.visible = st != PlayState.FALLEN
			if st == PlayState.HANGING:
				slot.pose(Vector2(pose.x, pose.y) * LevelLayout.GRID_DU, pose.z)
			elif st == PlayState.FIXED:
				slot.pose(Vector2.ZERO, 0.0)
	var mismatch := _tray_screws != tray or _preview_colors != _state.preview()
	for pos: int in _box_views.size():
		if _box_color[pos] != _state.open_box(pos).x or _state.box_screws(pos) != _box_wells.slice(pos * wells, (pos + 1) * wells):
			mismatch = true
	if mismatch:
		_fixes += 1
		_ev_undone_all()


func _ev_undone_all() -> void:
	_tray_screws = _state.tray()
	LevelViews.setup_tray(_tray_view, _tray_screws.size())
	_rebuild_boxes_and_planks()


# == Time ==

@warning_ignore("integer_division")
func _process(delta: float) -> void:
	if _paused or _state == null:
		return
	var dt := minf(delta, 0.05)
	_anim_time += dt
	_step_anims(dt)
	var now := Time.get_ticks_msec()
	if _clock.is_running():
		var second := int(_clock.elapsed_ms(now) / 1000)
		if second != _last_timer_second:
			_last_timer_second = second
			_hud.set_timer_text(_timer_text())
			_update_pips()
	if not _over and not _held:
		_idle += dt
		if not _clock.started and _idle >= IDLE_HINT and _level.kind == LevelData.TUTORIAL and _level.number == 1 and _hud.get_line() == "":
			_hud.set_line("Tap a screw.")
		# The hand appears half a second after the level starts, and again after 8 idle seconds.
		if not _hint.is_showing() and _idle >= (IDLE_HINT if _clock.started else 0.5):
			_point_hint(false)


func _step_anims(dt: float) -> void:
	var i := _anims.size() - 1
	while i >= 0:
		if i >= _anims.size():
			i = _anims.size() - 1
			continue
		var a := _anims[i]
		var finished := a.done or a.step(dt)
		if finished and i < _anims.size() and _anims[i] == a:
			_anims.remove_at(i)
		i -= 1


func _finish_anims() -> void:
	var guard := 0
	while not _anims.is_empty() and guard < 100:
		var list := _anims.duplicate()
		_anims.clear()
		for a: LevelAnim in list:
			a.finish()
		guard += 1
	for slot: LevelScrewSlot in _screws:
		slot.anim = null
	for slot: LevelPlankSlot in _planks:
		slot.anim = null
	_moves.clear()
	_tray_shift = 0.0


## Finishes every animation but `keep` (which may be null). Finishing one can start others;
## they are finished too.
func _finish_anims_except(keep: LevelAnim) -> void:
	var guard := 0
	while guard < 100:
		var work: Array[LevelAnim] = []
		for a: LevelAnim in _anims:
			if a != keep:
				work.append(a)
		if work.is_empty():
			break
		for a: LevelAnim in work:
			_anims.erase(a)
			a.finish()
		guard += 1
	_moves.clear()


func _cancel_anims() -> void:
	for a: LevelAnim in _anims:
		a.cancel()
	_anims.clear()
	_moves.clear()


@warning_ignore("integer_division")
func _timer_text() -> String:
	var seconds := mini(int(_clock.elapsed_ms(Time.get_ticks_msec()) / 1000), 59 * 60 + 59)
	return "%d:%02d" % [seconds / 60, seconds % 60]


func _update_pips() -> void:
	if _level == null or _state == null:
		return
	# One source for the two bonus stars: what Stars.award would give if the level were won now.
	var elapsed := _clock.elapsed_ms(Time.get_ticks_msec())
	var stars := Stars.award(_level, true, elapsed, _state.tray_uses(), _state.helpers_used())
	_hud.set_pips(stars.y == 1, stars.z == 1)


func _label() -> String:
	match _level.kind:
		LevelData.DAILY:
			return "Daily"
		LevelData.RELAXED:
			return "Relaxed"
	return "Level %d" % _level.number


## The timer and pips show from level 4 (GDD S9), never in Relaxed.
func _timer_visible() -> bool:
	match _level.kind:
		LevelData.RELAXED:
			return false
		LevelData.DAILY:
			return true
	return _level.number >= 4


## Plays an effect through the Audio autoload (looked up by name, so this script compiles
## whether or not the autoload exists yet, for example in a tool run with -s).
func _sfx(effect: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if _instant:
		return
	if _audio == null:
		_audio = get_node_or_null("/root/Audio")
		if _audio == null:
			return
	var audio: Variant = _audio
	audio.play(effect, pitch, volume_db)


# == Tests ==

## Takes back the last action, as Phase 4's Undo button will. Tests only for now: the helper
## row and its counts belong to the app flow and the save.
func debug_undo() -> TapResult:
	if _state == null:
		return TapResult.failed(TapResult.NOT_PLAYING)
	var r := _state.undo()
	if r.ok:
		_begin_action()
		_apply_events(r.events)
		_end_action()
	return r


## What the player sees, in grid units, for tests (docs/ARCHITECTURE.md 5.3): where each screw
## is drawn, each plank's drawn outline, and what the boxes and the tray hold. "believed" is
## what the view thinks the logic said; "fixes" counts the times the safety net had to
## correct it (normal play keeps it at 0).
func debug_snapshot() -> Dictionary:
	var screws := {}
	var places := {}
	var covered := {}
	var shown := {}
	var names := ["board", "box", "tray", "closed"]
	for slot: LevelScrewSlot in _screws:
		screws[slot.screw] = _layout.scene_to_gu(slot.view.position)
		places[slot.screw] = names[slot.kind]
		covered[slot.screw] = slot.covered
		shown[slot.screw] = slot.view.visible
	var planks := {}
	var planks_shown := {}
	var plank_angles := {}
	for slot: LevelPlankSlot in _planks:
		plank_angles[slot.plank] = slot.angle
		var outline := PackedVector2Array()
		if slot.view.visible:
			for p: Vector2 in slot.outline_gu:
				outline.append((slot.view.transform * (p * LevelLayout.GRID_DU)) / LevelLayout.GRID_DU)
		planks[slot.plank] = outline
		planks_shown[slot.plank] = slot.view.visible
	var boxes := []
	var wells := Tuning.box_slots
	for pos: int in _box_views.size():
		boxes.append({"color": _box_color[pos], "screws": _box_wells.slice(pos * wells, (pos + 1) * wells), "shown": _box_views[pos] != null})
	var well_centers := []
	for pos: int in _box_views.size():
		var row := []
		for w: int in wells:
			row.append(_layout.scene_to_gu(_layout.well_center(pos, w)))
		well_centers.append(row)
	var slot_centers := []
	for i: int in _tray_screws.size():
		slot_centers.append(_layout.scene_to_gu(_layout.tray_slot_center(i, _tray_screws.size())))
	return {
		"screws": screws,
		"places": places,
		"covered": covered,
		"shown": shown,
		"planks": planks,
		"planks_shown": planks_shown,
		"boxes": boxes,
		"preview": _preview_colors.duplicate(),
		"tray": _tray_screws.duplicate(),
		"well_centers": well_centers,
		"slot_centers": slot_centers,
		"plank_angles": plank_angles,
		"fixes": _fixes,
		"busy": _anims.size(),
		"over": _over,
		"elapsed_ms": _clock.elapsed_ms(Time.get_ticks_msec()),
		"clock_running": _clock.is_running(),
		"marks": _marks.active_count(),
		"hint": _hint.is_showing(),
		"hint_at": _layout.scene_to_gu(_hint.get_target()) if _hint.is_showing() else Vector2(-1000.0, -1000.0),
		"toast": _hud.get_toast(),
		"line": _hud.get_line(),
	}
