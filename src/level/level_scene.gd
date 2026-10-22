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
## The helpers (Undo, Extra slot, Screwdriver), the timer and pips, the star bank and the coffee
## cup are here (docs/ARCHITECTURE.md 6 and 11.3). The looks are the placeholder views made in
## LevelViews until the real renderers are swapped in there. Pause, Out of room, Level clear and
## the helper sheets are the app flow's screens.

signal won(result: LevelResult)
signal lost(level: LevelData)
signal pause_requested
signal helper_used(helper: String)
signal helper_buy_requested(helper: String)
signal first_action
signal coffee_requested

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
## The tray warning ticks at most this often, in animation seconds (UX 3.2.2).
const TICK_GAP := 2.0
## The tray changing size (UX 3.2.2): the closing waits for the board to settle, then takes 300 ms;
## Extra slot takes 250 ms. The frame's end moves 25 units either way.
const CLOSING_WAIT := 0.45
const CLOSING_TIME := 0.3
const GROW_TIME := 0.25
const FRAME_SHIFT := 25.0
## The shrink line (UX 3.2.2): it appears once the board has settled, fades over 150 ms, stays at
## least 2.5 seconds and at most 6.
const NOTE_WAIT := 0.45
const NOTE_FADE := 0.15
const NOTE_MIN := 2.5
const NOTE_MAX := 6.0
const NOTE_NONE := 0
const NOTE_PENDING := 1
const NOTE_SHOWING := 2
const NOTE_LEAVING := 3

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
## The pegboard and the back panels, behind everything (src/render/BoardView).
var _board_view: Node2D
## Only a tutorial level with a hint list ever shows the hand.
var _hint_possible := false
var _board_area := Vector2.ZERO
var _board_panels: Array[Rect2] = []
var _hud: LevelHud
var _tray_view: Node2D
var _audio: Node
## While animations are finished in one go (an undo, a resize) their sounds stay silent.
var _muted := false

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
var _tray_ticks := 0
var _last_tick_time := -100.0
## True while one action's events include a screw flying to the tray.
var _action_to_tray := false
## While the tray changes size: the old frame in a view of its own, fading out as the new one
## fades in; and the motion that does it.
var _swap_ghost: Node2D
var _swap_anim: LevelAnim
## The shrink line: where it is in its life, its text, seconds since it began to show (or until
## it does), whether an action asked it to leave, and the fade out.
var _note_phase := NOTE_NONE
var _note_text := ""
var _note_age := 0.0
var _note_asked := false
var _note_out := 0.0
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
## Helpers: the counts the app flow gave, which buttons show, the star bank, the Screwdriver mode,
## the control a touch went down on, and the badge shown while a first-time count ticks up.
var _counts := {}
var _shown := PackedStringArray()
var _bank := 0
var _bank_shown_value := 0
var _bank_known := false
var _coffee := false
var _driver := false
var _press_id := ""
var _highlight := ""
var _badge_override := {}
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


## Sets every view up again from Looks.current (wood, metal, the symbols setting) and keeps the
## state: the screws and planks stay where they are, with their poses, and so do the boxes, the
## tray and the hand. Then it bakes again. The app flow calls it after Settings changed while the
## level was paused, so Back to level shows the new choice (UX 3.8).
func refresh_looks() -> void:
	if _state == null or _board_view == null:
		return
	for slot: LevelPlankSlot in _planks:
		var data := _level.planks[slot.plank]
		LevelViews.reset_plank(slot.view, slot.outline_gu, data.inner_outline(), data.layer, data.holes, slot.plank * 7919 + _level.number)
	for slot: LevelScrewSlot in _screws:
		LevelViews.resize_screw(slot.view, _level.screw_colors[slot.screw], LevelViews.SCREW_BOARD)
	for pos: int in _box_views.size():
		if _box_views[pos] != null:
			LevelViews.reset_box(_box_views[pos], _box_color[pos], false)
	for k: int in _preview_views.size():
		LevelViews.reset_box(_preview_views[k], _preview_colors[k], true)
	LevelViews.setup_tray(_tray_view, _tray_screws.size())
	_refresh_tray()
	_board_area = Vector2.ZERO
	_set_board_view()
	if not _instant:
		_bake_planks()


## Starts the same level again from the beginning (GDD R34).
func retry() -> void:
	if _level != null:
		_start_attempt()


## The tray closing (UX 3.2.2), for a level that comes after a bigger tray (Next from level 11 or
## 20): the tray shows at the old size, one slot more, and once the board has settled the extra
## slot closes (the frame's end slides in over 300 ms, a dull wood knock) and the frame is
## centered again. Call it right after play(). It ends at the first action, at a pause, and at
## the next play(); the picture then is the tray at the level's own size. The rules never see
## it: the tray has its own size from the first moment.
func play_tray_closing() -> void:
	if _state == null or _tray_view == null or _layout == null:
		return
	var old := _tray_screws.size() + 1
	var empty := PackedByteArray()
	empty.resize(old)
	_start_swap(old, empty, CLOSING_WAIT, CLOSING_TIME, -FRAME_SHIFT, true)


## The shrink line (UX 3.2.2): `text` shows on a plaque in the helper bar's place, with a steady
## outline round the tray, once the board has settled. It stays at least 2.5 seconds, and goes at
## the first action once it has shown that long, or at 6 seconds. It does not start the clock and
## needs no tap. While it shows, the helper buttons are not there. Call it right after play();
## the next play() removes it. Whether to show it is the app flow's and Save's to decide.
func show_tray_note(text: String) -> void:
	if _state == null or _hud == null or _layout == null or text == "":
		return
	_note_text = text
	_note_age = 0.0
	_note_asked = false
	_note_out = 0.0
	if _instant:
		_note_phase = NOTE_SHOWING
		_note_age = 0.0
		_push_note(1.0)
	else:
		_note_phase = NOTE_PENDING
		_note_age = -NOTE_WAIT
		_push_note(0.0)


## Covers the board and stops the clock (the pause screen takes over).
func pause() -> void:
	if _paused:
		return
	_finish_swap()
	_paused = true
	_clock.set_paused(true, Time.get_ticks_msec())
	_press_id = ""
	_sync_hud()
	if _content != null:
		_content.visible = false
		_board_view.visible = false
		_content.process_mode = Node.PROCESS_MODE_DISABLED


func resume() -> void:
	if not _paused:
		return
	_paused = false
	_clock.set_paused(false, Time.get_ticks_msec())
	if _content != null:
		_content.visible = true
		_board_view.visible = true
		_content.process_mode = Node.PROCESS_MODE_INHERIT
	if _layout_due:
		_apply_layout()
	_sync_hud()


## Stops the clock with the board still showing (a sheet or a dialog is open).
func hold_clock(on: bool) -> void:
	_held = on
	_press_id = ""
	_clock.set_held(on, Time.get_ticks_msec())
	_sync_hud()


## Back leaves the Screwdriver mode first (UX 3.2.3); otherwise the app flow opens Pause.
func handle_back() -> bool:
	if _driver:
		_leave_driver(true)
		return true
	return false


## The star bank in the top bar. A drop (buying with "Get and use") counts down over 400 ms.
func set_star_bank(stars: int) -> void:
	var old := _bank_shown_value
	_bank = stars
	if _hud == null:
		return
	if _bank_known and not _instant and stars < old:
		_anims.append(LevelAnims.Timed.new(0.0, 0.4, _bank_step.bind(old, stars)))
	else:
		_bank_shown_value = stars
	_bank_known = true
	_refresh_helpers()
	_sync_hud()


func _bank_step(p: float, from: int, to: int) -> void:
	_bank_shown_value = roundi(lerpf(float(from), float(to), p))
	_sync_hud()


## Which helper buttons show and how many of each the player owns (the app flow keeps both).
func set_helpers(counts: Dictionary, shown: PackedStringArray) -> void:
	_counts = counts.duplicate()
	_shown = shown
	_refresh_helpers()


## The coffee cup in the top bar (UX 1.7); the app flow passes Links.coffee_visible().
func set_coffee(on: bool) -> void:
	_coffee = on
	_sync_hud()


## The steady ring and arrow on a helper's button after its first-time sheet (UX 3.13.1), and
## its count ticking up from 0, one tick every 200 ms.
func highlight_helper(helper: String) -> void:
	_highlight = helper
	if _hud == null:
		return
	_hud.set_highlight(helper)
	var n := _helper_count(helper)
	if _instant or n <= 0 or not _shown.has(helper):
		return
	_badge_override[helper] = 0
	_refresh_helpers()
	for i: int in range(1, n + 1):
		_anims.append(LevelAnims.after(0.2 * i, _tick_badge.bind(helper, i, i == n)))


func _tick_badge(helper: String, value: int, last: bool) -> void:
	_sfx("tick")
	if last:
		_badge_override.erase(helper)
	else:
		_badge_override[helper] = value
	_refresh_helpers()


## Uses a helper: after "Get and use" (R38), or from the Out of room sheet (R37). The app flow
## has already taken care of the count; helper_used says it took effect.
func use_helper(helper: String) -> void:
	if _state == null or _paused:
		return
	_run_helper(helper)


## The owned helpers that can clear this loss (R37): Undo with something to take back, Extra
## slot not yet used this try, Screwdriver when some screw on the board, covered or not, fits an
## open box. Not in Relaxed, where only the free Undo exists.
func usable_after_loss() -> PackedStringArray:
	var out := PackedStringArray()
	if _state == null or _level == null:
		return out
	var relaxed := _level.kind == LevelData.RELAXED
	if (relaxed or _helper_count("undo") >= 1) and _state.can_undo():
		out.append("undo")
	if relaxed:
		return out
	if _helper_count("extra_slot") >= 1 and not _state.extra_slot_used():
		out.append("extra_slot")
	if _helper_count("screwdriver") >= 1:
		for s: int in _level.screw_count():
			if _state.is_on_board(s) and _state.destination(s).x != PlayState.NONE:
				out.append("screwdriver")
				break
	return out


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
	# The board only listens inside the board panel (UX 6.1): a touch that began in the top bar,
	# the boxes, the tray or the helper bar never gets here.
	if not _layout.panel.has_point(p):
		return
	_idle = 0.0
	if _driver:
		_driver_tap(p)
		return
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
		_sfx("tap", 1.0, -6.0)
	else:
		_marks.add_ripple(p, 22.0, Color(RING_COLOR, 0.7))
		_sfx("tap", 1.3, -9.0)


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


## Frees a box, a preview or the tray (a view that may be gone already).
func _free_view(node: Variant) -> void:
	if is_instance_valid(node):
		(node as Node).queue_free()


# == Helpers, the Screwdriver mode and the coffee cup ==

func _helper_count(helper: String) -> int:
	return int(_counts.get(helper, 0))


func _helper_price(helper: String) -> int:
	return int((Tuning.helpers[helper] as Dictionary).get("price", 0))


## Tells the HUD which helper buttons to draw and what each badge says (UX 3.2.2).
func _refresh_helpers() -> void:
	if _hud == null or _level == null:
		return
	var infos: Array[Dictionary] = []
	var relaxed := _level.kind == LevelData.RELAXED
	for helper: String in LevelHud.HELPERS:
		if not _shown.has(helper) or (relaxed and helper != "undo"):
			continue
		var info := {"id": helper, "badge": "", "star": false, "dim": false, "disabled": false}
		if relaxed:
			info["badge"] = "Free"
		elif helper == "extra_slot" and _state != null and _state.extra_slot_used():
			info["badge"] = "Used"
			info["disabled"] = true
		elif _badge_override.has(helper):
			info["badge"] = str(_badge_override[helper])
		elif _helper_count(helper) > 0:
			info["badge"] = str(_helper_count(helper))
		else:
			info["badge"] = str(_helper_price(helper))
			info["star"] = true
			info["dim"] = _bank < _helper_price(helper)
		infos.append(info)
	_hud.set_buttons(infos)


## The cup shows from level 4 (and in Daily and Relaxed), and never while a sheet, a dialog,
## the clear screen or the loss shows (UX 1.7).
func _cup_visible() -> bool:
	if not _coffee or _level == null or _held or _over or _paused:
		return false
	match _level.kind:
		LevelData.DAILY, LevelData.RELAXED:
			return true
	return _level.number >= 4


func _sync_hud() -> void:
	if _hud == null or _level == null:
		return
	_hud.set_cup(_cup_visible())
	_hud.set_star_bank(_timer_visible(), _bank_shown_value)


## A touch on a control acts on release, and only if it went down on it and is still on it.
func _activate(id: String) -> void:
	match id:
		"pause":
			if _driver:
				_leave_driver(false)
			pause_requested.emit()
		"cup":
			pause()
			coffee_requested.emit()
		"cancel":
			_leave_driver(true)
		_:
			if LevelHud.HELPERS.has(id):
				_helper_button(id)


func _helper_button(helper: String) -> void:
	if _state == null:
		return
	_set_highlight("")
	if _level.kind == LevelData.RELAXED and helper == "undo":
		_run_helper(helper)
	elif helper == "extra_slot" and _state.extra_slot_used():
		return
	elif _helper_count(helper) > 0:
		_run_helper(helper)
	elif _bank >= _helper_price(helper):
		helper_buy_requested.emit(helper)
	else:
		_hud.shake(helper)
		_hud.show_toast("Not enough stars. %d needed." % _helper_price(helper))
		_sfx("knock_dull", 1.0, 0.0)


func _set_highlight(helper: String) -> void:
	_highlight = helper
	if _hud != null:
		_hud.set_highlight(helper)


func _run_helper(helper: String) -> void:
	match helper:
		"undo":
			var r := _state.undo()
			if r.ok:
				_sfx("undo")
				_helper_action(r, "undo")
			elif r.reason == TapResult.NOTHING_TO_UNDO:
				_hud.show_toast("Nothing to undo.")
				_sfx("knock_dull", 0.85)
		"extra_slot":
			var r := _state.use_extra_slot()
			if r.ok:
				_sfx("wood_pop")
				_helper_action(r, "extra_slot")
		"screwdriver":
			_enter_driver()


## A helper took effect: apply what the logic said, then tell the app flow.
func _helper_action(r: TapResult, helper: String) -> void:
	_after_accepted_action()
	_begin_action()
	_apply_events(r.events)
	_hint.hide_hint()
	_end_action()
	helper_used.emit(helper)


func _enter_driver() -> void:
	if _driver or _state.status() == PlayState.WON:
		return
	_driver = true
	_clear_note()
	_hud.set_banner(true)
	_set_bright(true)
	_sfx("tick")
	_sync_hud()


## Leaves the mode and keeps the helper. After a loss the Out of room sheet is gone, so a
## cancel there announces the loss again and the sheet comes back.
func _leave_driver(cancelled: bool) -> void:
	if not _driver:
		return
	_driver = false
	_hud.set_banner(false)
	_set_bright(false)
	if cancelled and _state.status() == PlayState.LOST:
		lost.emit(_level)


func _set_bright(on: bool) -> void:
	for slot: LevelScrewSlot in _screws:
		LevelViews.set_bright(slot.view, on and slot.kind == LevelScrewSlot.BOARD)


## A touch in Screwdriver mode: any screw on the board, covered or free, is chosen (R31).
func _driver_tap(p: Vector2) -> void:
	var s := LevelHit.any_screw(_state, _layout.scene_to_gu(p))
	if s < 0:
		return
	var r := _state.use_screwdriver(s)
	if r.ok:
		_leave_driver(false)
		if not _instant:
			_marks.add_icon(_layout.gu_to_scene(_level.screw_center(s)) + Vector2(10.0, -10.0) * _layout.b, "screwdriver", 30.0 * _layout.b, Color(RING_COLOR, 0.95), 0.12)
		_helper_action(r, "screwdriver")
	elif r.reason == TapResult.REFUSED:
		_sfx("knock_dull", 0.85)
		_hud.show_toast("That screw has nowhere to go.")
		_shake_screw(s)


# == Building the level ==

func _ensure_nodes() -> void:
	if _content != null:
		return
	_board_view = LevelViews.make_board(Vector2(360.0, 640.0), [] as Array[Rect2])
	add_child(_board_view)
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
	_content.add_child(_marks)
	_hint = LevelHint.new()
	_content.add_child(_hint)
	_hud = LevelHud.new()
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
	_clear_note()
	_clock.reset()
	_force_unpaused()
	_relayout()
	_build_views()
	_driver = false
	_press_id = ""
	_highlight = ""
	_hint_possible = _level.kind == LevelData.TUTORIAL and not _level.hint.is_empty()
	_badge_override.clear()
	_hud.configure(_layout, _label(), _timer_visible(), _level.line)
	_refresh_helpers()
	_sync_hud()
	_apply_layout(true)
	_update_pips()
	if not _instant:
		_play_intro()
		_bake_planks()


## A new attempt always starts unpaused, shown and listening, whatever state the scene was in
## (the app flow keeps a paused level alive while the menus show).
func _force_unpaused() -> void:
	_paused = false
	_held = false
	_layout_due = false
	_pause_pressed_reset()
	if _content != null:
		_content.visible = true
		_board_view.visible = true
		_content.process_mode = Node.PROCESS_MODE_INHERIT


func _pause_pressed_reset() -> void:
	_press_id = ""
	if _hud != null:
		_hud.set_pressed("")


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
	_tray_ticks = 0
	_last_tick_time = -100.0
	_action_to_tray = false
	_swap_ghost = null
	_swap_anim = null


func _build_views() -> void:
	var ps := _state
	for p: int in _level.planks.size():
		var data := _level.planks[p]
		var slot := LevelPlankSlot.new()
		slot.plank = p
		slot.outline_gu = data.outline()
		slot.view = LevelViews.make_plank(slot.outline_gu, data.inner_outline(), data.layer, data.holes, p * 7919 + _level.number)
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
	# Draw order is tree order, never z: the back layers first, so a plank in front is drawn over
	# one behind it. The screws are in their own layer above all planks, so a plank that swings
	# across a free screw never covers it.
	var order: Array[int] = []
	for p: int in _level.planks.size():
		order.append(p)
	order.sort_custom(func(a: int, b: int) -> bool:
		var la := _level.planks[a].layer
		var lb := _level.planks[b].layer
		return la > lb if la != lb else a < b)
	for i: int in order.size():
		_planks_root.move_child(_planks[order[i]].view, i)
	for s: int in _level.screw_count():
		var slot := LevelScrewSlot.new()
		slot.screw = s
		slot.view = LevelViews.make_screw(_level.screw_colors[s], LevelViews.SCREW_BOARD)
		slot.covered = not ps.is_free(s)
		LevelViews.set_covered(slot.view, slot.covered)
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


## The workbench behind everything, full bleed, with the board panel (and the rail when the
## screen is split). It is made again, and baked, only when those rectangles change.
func _set_board_view() -> void:
	var area := _area()
	var panels: Array[Rect2] = [_layout.panel]
	if _layout.split:
		panels.append(_layout.rail)
	if area == _board_area and panels == _board_panels:
		return
	_board_area = area
	_board_panels = panels
	LevelViews.setup_board(_board_view, area, panels)
	if not _instant and is_inside_tree():
		LevelViews.bake(_board_view)


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
	_set_board_view()
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
		_place_tray_view()
		for slot: LevelScrewSlot in _screws:
			_place_screw_now(slot)
	_hud.set_layout(_layout)
	_sync_note_frame()
	if _state != null and _hint.is_showing():
		_point_hint(false)
	queue_redraw()


## Draws every plank into its textures (until then a plain stand-in shows). The planks are
## fading in at the start of a level, so this is the one moment the board is not yet in play.
func _bake_planks() -> void:
	if not is_inside_tree():
		return
	for slot: LevelPlankSlot in _planks:
		LevelViews.bake(slot.view)


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
			_anims.append(LevelAnims.after(wait, _sfx.bind("tap", 1.0 + 0.04 * i, -12.0)))
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
	if _held or _layout == null:
		return
	if pressed:
		var id := _hud.hit(p) if (not _over or _driver) else ""
		if id != "":
			_press_id = id
			_hud.set_pressed(id)
			_sfx("knock_dull", 1.3, -12.0)
			return
		tap_at(p)
	elif _press_id != "":
		var id := _press_id
		_press_id = ""
		_hud.set_pressed("")
		if _hud.hit(p) == id:
			_activate(id)


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
	_set_highlight("")
	_finish_swap()
	_note_action()
	if _clock.start(Time.get_ticks_msec()):
		first_action.emit()


func _begin_action() -> void:
	_action_land = _anim_time
	_action_arrive = 0.0
	_action_to_tray = false


func _end_action() -> void:
	_sync_previews()
	_refresh_tray()
	# The warning began with no screw flying to the tray (a helper, a box taking tray screws):
	# its tick plays now, not at a landing.
	if _tray_tick_due and (_instant or not _action_to_tray):
		_tray_tick()
	_reconcile()
	_update_pips()
	_hud.set_timer_text(_timer_text())
	_refresh_helpers()
	_sync_hud()
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
	_action_to_tray = true
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
	_sfx("creak")
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
			_free_view(box)
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
		_sfx("lid")


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
	# Screws still flying to the tray land first: their targets were worked out for the old size.
	for slot: LevelScrewSlot in _screws:
		if slot.kind == LevelScrewSlot.TRAY and slot.anim != null and not slot.anim.done:
			slot.anim.finish()
	_finish_swap()
	var old := _tray_screws.size()
	var was := PackedByteArray()
	was.resize(old)
	for i: int in old:
		was[i] = 1 if _tray_screws[i] >= 0 else 0
	_tray_screws = _state.tray()
	LevelViews.setup_tray(_tray_view, _tray_screws.size())
	_place_tray_view()
	_sync_note_frame()
	# The frame widens round its center (250 ms): the old frame fades out as the new one fades in.
	_start_swap(old, was, 0.0, GROW_TIME, 0.0, false)
	# The frame widens around its center, so the screws in it slide to their new slots (250 ms).
	for slot: LevelScrewSlot in _screws:
		if slot.kind != LevelScrewSlot.TRAY:
			continue
		if _instant:
			_place_screw_now(slot)
		else:
			_slide(slot.view, _screw_rest(slot), 0.0, 0.25, LevelAnims.EASE_OUT_CUBIC, 1.0)
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
			return _layout.tray_scale(_tray_screws.size()) * LevelViews.SCREW_DIAMETERS[LevelViews.SCREW_TRAY] / LevelViews.SCREW_DIAMETERS[LevelViews.SCREW_BOARD]
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
			_tray_tick()


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
	elif not warn:
		_tray_tick_due = false
	_tray_warned = warn


## The warning's one soft tick (UX 3.2.2): only while the warning still holds, and not more
## often than once every 2 seconds.
func _tray_tick() -> void:
	_tray_tick_due = false
	if not _tray_warned or _anim_time - _last_tick_time < TICK_GAP:
		return
	_last_tick_time = _anim_time
	_tray_ticks += 1
	_sfx("tick")


## Puts the tray frame where the layout says, at the scale its size needs. It is always centered.
func _place_tray_view() -> void:
	if _tray_view == null or _layout == null:
		return
	_tray_view.position = _layout.tray_center + Vector2(_tray_shift, 0.0)
	_tray_view.scale = Vector2.ONE * _layout.tray_scale(_tray_screws.size())


# == The tray changing size (UX 3.2.2) ==

## The frame changes size: the old one, `old_slots` wide with `old_filled`, stays in a view of
## its own and fades out while the real one fades in, sliding in from `from_x` units (at tray
## scale) to the center. After `wait` seconds, over `seconds`. `knock` ends it with a dull knock.
## Looks only: the real tray view already has its final size and the screws their final places.
func _start_swap(old_slots: int, old_filled: PackedByteArray, wait: float, seconds: float, from_x: float, knock: bool) -> void:
	_finish_swap()
	if _instant or _tray_view == null or _layout == null:
		return
	var ghost := LevelViews.make_tray(old_slots)
	LevelViews.set_tray_filled(ghost, old_filled)
	_box_root.add_child(ghost)
	_box_root.move_child(ghost, _tray_view.get_index())
	ghost.position = _layout.tray_center + Vector2(_tray_shift, 0.0)
	ghost.scale = Vector2.ONE * _layout.tray_scale(old_slots)
	_swap_ghost = ghost
	_tray_view.modulate.a = 0.0
	var anim := LevelAnims.Timed.new(wait, seconds, _swap_step.bind(from_x))
	anim.on_done = _swap_done.bind(knock)
	_swap_anim = anim
	_anims.append(anim)


func _swap_step(p: float, from_x: float) -> void:
	var e := LevelAnim.out_cubic(p)
	if is_instance_valid(_swap_ghost):
		_swap_ghost.modulate.a = 1.0 - e
	if _tray_view != null:
		_tray_view.modulate.a = e
		_tray_view.position = _layout.tray_center + Vector2(_tray_shift + from_x * _layout.tray_scale(_tray_screws.size()) * (1.0 - e), 0.0)


func _swap_done(knock: bool) -> void:
	_swap_anim = null
	if is_instance_valid(_swap_ghost):
		_swap_ghost.free()
	_swap_ghost = null
	if _tray_view != null:
		_tray_view.modulate.a = 1.0
		_place_tray_view()
	if knock:
		_sfx("knock_dull", 0.9)


## Ends the change at once, with no sound.
func _finish_swap() -> void:
	if _swap_anim == null:
		return
	var anim := _swap_anim
	_muted = true
	anim.finish()
	_muted = false
	_swap_anim = null


# == The shrink line (UX 3.2.2) ==

## What the HUD shows of the line: its text, how visible it is, and the frame it outlines.
func _push_note(alpha: float) -> void:
	if alpha > 0.999:
		alpha = 1.0
	_hud.set_note(_note_text if alpha > 0.0 else "", alpha)
	_sync_note_frame()


func _sync_note_frame() -> void:
	if _hud == null or _layout == null:
		return
	var slots := _tray_screws.size()
	if slots > 0:
		_hud.set_note_frame(_layout.tray_frame(slots), _layout.tray_scale(slots))


func _clear_note() -> void:
	_note_phase = NOTE_NONE
	_note_text = ""
	_note_age = 0.0
	_note_asked = false
	_note_out = 0.0
	if _hud != null:
		_hud.set_note("", 0.0)


## An action (an accepted tap, a helper) while the line shows: it leaves now if it has shown
## 2.5 seconds, else when it has.
func _note_action() -> void:
	if _note_phase == NOTE_NONE or _note_phase == NOTE_LEAVING:
		return
	if _note_phase == NOTE_SHOWING and _note_age >= NOTE_MIN:
		_leave_note()
	else:
		_note_asked = true


func _leave_note() -> void:
	if _instant:
		_clear_note()
		return
	_note_phase = NOTE_LEAVING
	_note_out = 0.0


func _step_note(dt: float) -> void:
	match _note_phase:
		NOTE_PENDING:
			_note_age += dt
			if _note_age >= 0.0:
				_note_phase = NOTE_SHOWING
				_push_note(clampf(_note_age / NOTE_FADE, 0.0, 1.0))
		NOTE_SHOWING:
			_note_age += dt
			if _note_age >= NOTE_MAX or (_note_asked and _note_age >= NOTE_MIN):
				_leave_note()
			elif not _instant and _note_age < NOTE_FADE + dt:
				_push_note(clampf(_note_age / NOTE_FADE, 0.0, 1.0))
		NOTE_LEAVING:
			_note_out += dt
			if _note_out >= NOTE_FADE:
				_clear_note()
			else:
				_push_note(1.0 - _note_out / NOTE_FADE)


## Previews follow the logic's queue: the ones that moved up slide one place, a new one
## slides in at the end.
func _sync_previews() -> void:
	var want := _state.preview()
	var wait := maxf(0.0, _action_arrive - _anim_time)
	while _preview_views.size() > want.size():
		var gone: Node2D = _preview_views.pop_back()
		_free_view(gone)
		_preview_colors.resize(_preview_views.size())
	for k: int in want.size():
		var target := _layout.preview_pos[mini(k, _layout.preview_pos.size() - 1)]
		var view: Node2D = null
		if k < _preview_views.size() and _preview_colors[k] == want[k]:
			view = _preview_views[k]
		else:
			if k < _preview_views.size():
				_free_view(_preview_views[k])
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


## A box that an undo brought back slides down into its place again with the screws in it.
func _reopen_box(box: Node2D, inside: PackedInt32Array) -> void:
	var rise := Vector2(0.0, -70.0 * _layout.box_scale)
	var group: Array[Node2D] = [box]
	for s: int in inside:
		if s >= 0:
			group.append(_screws[s].view)
	for n: Node2D in group:
		n.position += rise
		n.modulate.a = 0.0
	var mover := LevelAnims.GroupMove.new(group, -rise, 0.0, 0.25, LevelAnims.EASE_OUT_CUBIC)
	mover.alpha_end = 1.0
	_anims.append(mover)


## A plank that an undo brought back rises onto the board from below and fades in (250 ms).
func _raise_plank(slot: LevelPlankSlot) -> void:
	var base := slot.view.position
	slot.view.modulate.a = 0.0
	slot.anim = LevelAnims.Timed.new(0.0, 0.25, _raise_step.bind(slot, base))
	_anims.append(slot.anim)


func _raise_step(p: float, slot: LevelPlankSlot, base: Vector2) -> void:
	var e := LevelAnim.out_cubic(p)
	slot.view.position = base + Vector2(0.0, 60.0 * (1.0 - e))
	slot.view.modulate.a = e


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
				_free_view(_box_views[pos])
				_box_views[pos] = null
			_box_color[pos] = want
			if want >= 0:
				var box := LevelViews.make_box(want, false)
				_box_root.add_child(box)
				box.position = _layout.open_pos[pos]
				box.scale = Vector2.ONE * _layout.box_scale
				_box_views[pos] = box
				if not _instant:
					_reopen_box(box, inside)
	for k: int in _preview_views.size():
		_free_view(_preview_views[k])
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
		var was := slot.state
		var was_pivot := slot.pivot
		var was_angle := slot.angle
		slot.stop()
		LevelViews.set_shadow(slot.view, 1.0)
		slot.state = st
		slot.view.modulate.a = 1.0
		slot.view.visible = st != PlayState.FALLEN
		slot.pivot_screw = _pivot_screw(slot.plank) if st == PlayState.HANGING else -1
		slot.rest = pose.z
		if st == PlayState.FIXED:
			slot.pose(Vector2.ZERO, 0.0)
			if was == PlayState.FALLEN and not _instant:
				_raise_plank(slot)
			elif was == PlayState.HANGING and not _instant and absf(was_angle) > 0.01:
				# A swung plank swings back to where it was.
				slot.pose(was_pivot, was_angle)
				var back := LevelAnims.Swing.new(slot, was_pivot, was_angle, 0.0)
				slot.anim = back
				_anims.append(back)
		elif st == PlayState.HANGING:
			slot.pose(Vector2(pose.x, pose.y) * LevelLayout.GRID_DU, pose.z)
			if was == PlayState.FALLEN and not _instant:
				_raise_plank(slot)
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
	_shake_screw(screw)
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


## The screw lifts a little, turns back about 30 degrees and settles in its hole (160 ms).
func _shake_screw(screw: int) -> void:
	if _instant:
		return
	var slot := _screws[screw]
	if slot.anim != null:
		slot.anim.finish()
	slot.anim = LevelAnims.Timed.new(0.0, 0.16, _refuse_shake.bind(slot))
	_anims.append(slot.anim)


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

func _process(delta: float) -> void:
	_advance(minf(delta, 0.05))


## Tests: runs the scene's own time forward by `seconds`, in steps of 50 ms, as frames would.
func debug_step(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var dt := minf(left, 0.05)
		_advance(dt)
		left -= dt


@warning_ignore("integer_division")
func _advance(dt: float) -> void:
	if _paused or _state == null:
		return
	_anim_time += dt
	_step_anims(dt)
	_step_note(dt)
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
		if _hint_possible and not _hint.is_showing() and _idle >= (IDLE_HINT if _clock.started else 0.5):
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
	_muted = true
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
	_muted = false
	_moves.clear()
	_tray_shift = 0.0


## Finishes every animation but `keep` (which may be null). Finishing one can start others;
## they are finished too.
func _finish_anims_except(keep: LevelAnim) -> void:
	_muted = true
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
	_muted = false
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
	if _instant or _muted:
		return
	if _audio == null:
		_audio = get_node_or_null("/root/Audio")
		if _audio == null:
			return
	var audio: Variant = _audio
	audio.play(effect, pitch, volume_db)


# == Tests ==

## The tray frame as its view is drawn now: the view's position and scale with the frame's own
## width and height (the renderer's), so a test sees what the layout and the view agree on.
func _tray_view_frame() -> Rect2:
	if _tray_view == null:
		return Rect2()
	var size := Vector2(TrayView.width(_tray_screws.size()), TrayView.HEIGHT) * _tray_view.scale
	return Rect2(_tray_view.position - size * 0.5, size)


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
		"paused": _paused,
		"board_covered": _content != null and not _content.visible and not _board_view.visible,
		"timer_shown": _hud.is_timer_shown(),
		"pips": _hud.pips(),
		"cup": _hud.is_cup_shown(),
		"helpers": _hud.button_ids(),
		"driver": _driver,
		"banner": _hud.is_banner_shown(),
		"highlight": _hud.get_highlight(),
		"bank": _bank_shown_value,
		"marks": _marks.active_count(),
		"hint": _hint.is_showing(),
		"hint_at": _layout.scene_to_gu(_hint.get_target()) if _hint.is_showing() else Vector2(-1000.0, -1000.0),
		"toast": _hud.get_toast(),
		"line": _hud.get_line(),
		"tray_slots": _tray_screws.size(),
		"tray_warning": _tray_warned,
		"tray_ticks": _tray_ticks,
		"tray_frame": _layout.tray_frame(_tray_screws.size()),
		"tray_view_frame": _tray_view_frame(),
		"tray_alpha": _tray_view.modulate.a if _tray_view != null else 0.0,
		"swap": _swap_anim != null or _swap_ghost != null,
		"note": _hud.get_note(),
		"note_alpha": _hud.get_note_alpha(),
		"note_rect": _hud.note_rect(),
		"note_frame": _hud.get_note_frame(),
	}
