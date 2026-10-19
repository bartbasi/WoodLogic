# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name PlayState
extends RefCounted
## The rules of one attempt at a level (GDD section 2, docs/ARCHITECTURE.md 4.2). One per
## attempt, used on one thread only. Every call resolves completely: the logic never waits,
## animates or sleeps (R13, R14). Retry (R34) is a new PlayState.start on the same level.
##
## Which calls work when: PLAYING, all of them. LOST: undo, use_extra_slot and
## use_screwdriver (R29, R37), while tap returns NOT_PLAYING. WON: every action returns
## NOT_PLAYING. Queries always work.

const PLAYING := 0
const WON := 1
const LOST := 2

const FIXED := 0
const HANGING := 1
const FALLEN := 2

## Destination kinds, the x of destination().
const NONE := 0
const BOX := 1
const TRAY := 2

## Places, for working out which screws an undo moved.
const _ON_BOARD := -1
const _CLOSED := -2
const _IN_BOX := 1000

var _level: LevelData
var _geo: BoardGeometry
var _colors: PackedInt32Array
var _slots: int
var _preview: int
var _on_board: int
## The covered screws among those on the board (R7), kept up to date after every change (R9).
var _cover: int
## Per open position, the box color or -1.
var _box_color := PackedInt32Array()
## Per position and well (position * slots + well), the screw in it or -1.
var _wells := PackedInt32Array()
var _next_box: int
var _tray := PackedInt32Array()
var _tray_uses: int
## Per plank, the screw it last hung on when it fell (for its pose), or -1.
var _fell_on := PackedInt32Array()
var _status: int = PLAYING
var _helpers := PackedStringArray()
var _extra_used := false
var _history: Array[Dictionary] = []


## A fresh attempt at a level (R4, R5). Null and an error if the level has no colors.
static func start(level: LevelData) -> PlayState:
	if level == null or level.geometry == null or not level.has_colors():
		push_error("PlayState.start needs a level with colors and a queue")
		return null
	var state := PlayState.new()
	state._setup(level)
	return state


func _setup(level: LevelData) -> void:
	_level = level
	_geo = level.geometry
	_colors = level.screw_colors
	_slots = Tuning.box_slots
	_preview = Tuning.preview
	_on_board = (1 << _geo.screw_count) - 1
	_box_color.resize(Tuning.open_boxes)
	_box_color.fill(-1)
	_wells.resize(Tuning.open_boxes * _slots)
	_wells.fill(-1)
	_next_box = 0
	for position: int in Tuning.open_boxes:
		if _next_box < level.queue.size():
			_box_color[position] = level.queue[_next_box]
			_next_box += 1
	_tray.resize(level.tray_size)
	_tray.fill(-1)
	_tray_uses = 0
	_fell_on.resize(_geo.plank_count)
	_fell_on.fill(-1)
	_cover = _geo.covered(_on_board)
	_status = PLAYING


func level() -> LevelData:
	return _level


func status() -> int:
	return _status


## Taps a screw (R11 to R25).
func tap(screw: int) -> TapResult:
	if _status != PLAYING:
		return TapResult.failed(TapResult.NOT_PLAYING)
	if not _valid(screw) or not is_on_board(screw):
		return TapResult.failed(TapResult.GONE)
	if _cover & (1 << screw):
		return TapResult.failed(TapResult.COVERED)
	var dest := destination(screw)
	if dest.x == NONE:
		return TapResult.failed(TapResult.REFUSED)
	return _take(screw, dest, false)


## Removes any screw on the board, free or covered, exactly as a tap would (R31). Refused, and
## so not spent, if it has nowhere to go.
func use_screwdriver(screw: int) -> TapResult:
	if _status == WON:
		return TapResult.failed(TapResult.NOT_PLAYING)
	if not _valid(screw) or not is_on_board(screw):
		return TapResult.failed(TapResult.GONE)
	var dest := destination(screw)
	if dest.x == NONE:
		return TapResult.failed(TapResult.REFUSED)
	return _take(screw, dest, true)


## Opens a sixth tray slot for the rest of the attempt (R30). Once per attempt; never undone.
func use_extra_slot() -> TapResult:
	if _status == WON:
		return TapResult.failed(TapResult.NOT_PLAYING)
	if _extra_used:
		return TapResult.failed(TapResult.ALREADY_USED)
	var was_lost := _status == LOST
	var events: Array[LogicEvent] = []
	_extra_used = true
	_tray.append(-1)
	_note_helper("extra_slot")
	var e := LogicEvent.make(LogicEvent.TRAY_EXTENDED)
	e.slot = _tray.size() - 1
	events.append(e)
	_check_status(events, was_lost)
	return TapResult.done(events)


## Takes back the last tap or Screwdriver removal (R26 to R29).
func undo() -> TapResult:
	if _status == WON:
		return TapResult.failed(TapResult.NOT_PLAYING)
	if _history.is_empty():
		return TapResult.failed(TapResult.NOTHING_TO_UNDO)
	var was_lost := _status == LOST
	var before := _places()
	var step: Dictionary = _history.pop_back()
	_restore(step)
	_note_helper("undo")
	var after := _places()
	var e := LogicEvent.make(LogicEvent.UNDONE)
	e.screw = step["screw"]
	for s: int in after.size():
		if before[s] != after[s]:
			e.screws.append(s)
	var events: Array[LogicEvent] = [e]
	_check_status(events, was_lost)
	return TapResult.done(events)


func is_on_board(screw: int) -> bool:
	return _valid(screw) and (_on_board & (1 << screw)) != 0


func is_free(screw: int) -> bool:
	return is_on_board(screw) and (_cover & (1 << screw)) == 0


## The frontmost plank covering the screw (the lowest layer, then the lowest plank id), or -1
## if it is free or not on the board.
func cover_plank(screw: int) -> int:
	if not is_on_board(screw) or (_cover & (1 << screw)) == 0:
		return -1
	var bit := 1 << screw
	for p: int in _geo.front_to_back:
		if _geo.pose_cover(p, _on_board & _geo.plank_mask[p]) & bit:
			return p
	return -1


## Where the screw would go now (R12): Vector2i(BOX, position), Vector2i(TRAY, slot), or
## Vector2i(NONE, -1). Works for covered screws too; NONE for a screw not on the board.
func destination(screw: int) -> Vector2i:
	if not is_on_board(screw):
		return Vector2i(NONE, -1)
	var color := _colors[screw]
	var best := -1
	var best_count := -1
	for position: int in _box_color.size():
		if _box_color[position] == color:
			var count := _box_count(position)
			if count < _slots and count > best_count:
				best = position
				best_count = count
	if best >= 0:
		return Vector2i(BOX, best)
	var slot := _tray.find(-1)
	if slot >= 0:
		return Vector2i(TRAY, slot)
	return Vector2i(NONE, -1)


func plank_state(plank: int) -> int:
	var on := _on_board & _geo.plank_mask[plank]
	if on == 0:
		return FALLEN
	if on & (on - 1) == 0:
		return HANGING
	return FIXED


## Vector3(pivot x, pivot y, angle in degrees). FIXED: (0, 0, 0), the authored pose. HANGING:
## the pivot screw's center and the rest angle (0 for a plank that hangs as authored). FALLEN:
## the pose it had when it fell.
func plank_pose(plank: int) -> Vector3:
	var pivot := _pivot(plank)
	if pivot < 0:
		return Vector3.ZERO
	return Vector3(_geo.screw_x[pivot], _geo.screw_y[pivot], _geo.hang_angle[pivot])


## The plank's outline in its current pose, in gu.
func plank_outline(plank: int) -> PackedVector2Array:
	var pivot := _pivot(plank)
	if pivot < 0:
		return Geom.to_points(_geo.plank(plank).outline_xy)
	return Geom.to_points(_geo.hang_outline[pivot])


## Vector2i(color or -1, screws in it 0 .. 3).
func open_box(position: int) -> Vector2i:
	return Vector2i(_box_color[position], _box_count(position))


## The screws in a box's wells, in well order, -1 for an empty well. (An addition to the
## contract, for the view after an undo.)
func box_screws(position: int) -> PackedInt32Array:
	return _wells.slice(position * _slots, (position + 1) * _slots)


## The next colors in the queue after the open boxes, up to Tuning.preview of them.
func preview() -> PackedInt32Array:
	return _level.queue.slice(_next_box, mini(_next_box + _preview, _level.queue.size()))


## Per tray slot, the screw in it or -1 (5 slots, or 6 after Extra slot).
func tray() -> PackedInt32Array:
	return _tray.duplicate()


func tray_uses() -> int:
	return _tray_uses


## Helpers used this attempt, each name once, in the order first used.
func helpers_used() -> PackedStringArray:
	return _helpers.duplicate()


func extra_slot_used() -> bool:
	return _extra_used


func can_undo() -> bool:
	return _status != WON and not _history.is_empty()


## The rule state undo restores (R26), plus the status, for tests: snapshot() before an
## action equals snapshot() after undoing it. Helpers used and the Extra slot are not in it
## (R27; see helpers_used() and extra_slot_used()), but the tray's length is.
func snapshot() -> Dictionary:
	var board := PackedInt32Array()
	var loose := PackedInt32Array()
	for s: int in _geo.screw_count:
		if is_on_board(s):
			board.append(s)
			if is_free(s):
				loose.append(s)
	var planks := []
	for p: int in _geo.plank_count:
		planks.append([plank_state(p), plank_pose(p)])
	var boxes := []
	for position: int in _box_color.size():
		boxes.append([_box_color[position], box_screws(position)])
	return {
		"on_board": board,
		"free": loose,
		"planks": planks,
		"boxes": boxes,
		"next_box": _next_box,
		"tray": _tray.duplicate(),
		"tray_uses": _tray_uses,
		"status": _status,
	}


func _valid(screw: int) -> bool:
	return screw >= 0 and screw < _geo.screw_count


func _box_count(position: int) -> int:
	var count := 0
	for well: int in _slots:
		if _wells[position * _slots + well] >= 0:
			count += 1
	return count


## The screw a plank hangs or hung on for its current pose, or -1 for the authored pose.
func _pivot(plank: int) -> int:
	var on := _on_board & _geo.plank_mask[plank]
	if on == 0:
		return _fell_on[plank]
	if on & (on - 1) == 0:
		return _geo.bit_screw(plank, on)
	return -1


## R13: takes the screw off the board and resolves everything that follows.
func _take(screw: int, dest: Vector2i, by_screwdriver: bool) -> TapResult:
	var was_lost := _status == LOST
	_history.append(_save(screw))
	var events: Array[LogicEvent] = []
	var free_before := _on_board & ~_cover
	# 1. The screw leaves and lands (one event; the logic has no time in between).
	var well := -1
	if dest.x == BOX:
		well = _box_count(dest.y)
		var e := LogicEvent.make(LogicEvent.SCREW_TO_BOX)
		e.screw = screw
		e.position = dest.y
		e.well = well
		events.append(e)
	else:
		var e := LogicEvent.make(LogicEvent.SCREW_TO_TRAY)
		e.screw = screw
		e.slot = dest.y
		events.append(e)
	# 2. Off the board; its plank swings or falls (R14 to R17).
	var plank := _geo.screw_plank[screw]
	var on_before := _on_board & _geo.plank_mask[plank]
	_on_board &= ~(1 << screw)
	var on_after := _on_board & _geo.plank_mask[plank]
	if on_after == 0:
		_fell_on[plank] = screw
		var e := LogicEvent.make(LogicEvent.PLANK_FELL)
		e.plank = plank
		events.append(e)
	elif on_after & (on_after - 1) == 0 and on_before & (on_before - 1) != 0:
		var pivot := _geo.bit_screw(plank, on_after)
		var e := LogicEvent.make(LogicEvent.PLANK_SWUNG)
		e.plank = plank
		e.screw = pivot
		e.angle = _geo.hang_angle[pivot]
		events.append(e)
	# 3. Covering, recomputed at once (R9).
	_cover = _geo.covered(_on_board)
	var changed := (free_before ^ (_on_board & ~_cover)) & _on_board
	if changed != 0:
		var e := LogicEvent.make(LogicEvent.COVER_CHANGED)
		for s: int in _geo.screw_count:
			if changed & (1 << s):
				e.screws.append(s)
		events.append(e)
	# 4. Into its place.
	if dest.x == BOX:
		_wells[dest.y * _slots + well] = screw
		_run_queue(dest.y, events)
	else:
		_tray[dest.y] = screw
		_tray_uses += 1
	if by_screwdriver:
		_note_helper("screwdriver")
	# 5. Win, then loss.
	_check_status(events, was_lost)
	return TapResult.done(events)


## R18 to R21: while the box at this position is full it closes, the next queue box takes the
## position, and tray screws of its color jump in, left to right.
func _run_queue(position: int, events: Array[LogicEvent]) -> void:
	while _box_count(position) == _slots:
		var closed := LogicEvent.make(LogicEvent.BOX_CLOSED)
		closed.position = position
		closed.color = _box_color[position]
		events.append(closed)
		for well: int in _slots:
			_wells[position * _slots + well] = -1
		var color := -1
		if _next_box < _level.queue.size():
			color = _level.queue[_next_box]
			_next_box += 1
		_box_color[position] = color
		var arrived := LogicEvent.make(LogicEvent.BOX_ARRIVED)
		arrived.position = position
		arrived.color = color
		events.append(arrived)
		if color < 0:
			return
		for slot: int in _tray.size():
			var s := _tray[slot]
			if s < 0 or _colors[s] != color:
				continue
			var well := _box_count(position)
			if well >= _slots:
				break
			_wells[position * _slots + well] = s
			_tray[slot] = -1
			var jump := LogicEvent.make(LogicEvent.TRAY_TO_BOX)
			jump.screw = s
			jump.slot = slot
			jump.position = position
			jump.well = well
			events.append(jump)


## R22 to R24, after every successful action. An action that started at LOST always ends with
## RESUMED or a fresh LOST.
func _check_status(events: Array[LogicEvent], was_lost: bool) -> void:
	if _on_board == 0 and _tray.count(-1) == _tray.size():
		_status = WON
		events.append(LogicEvent.make(LogicEvent.WON))
	elif _is_lost():
		_status = LOST
		events.append(LogicEvent.make(LogicEvent.LOST))
	else:
		_status = PLAYING
		if was_lost:
			events.append(LogicEvent.make(LogicEvent.RESUMED))


## R23: every tray slot is full and no free screw has a destination.
func _is_lost() -> bool:
	if _tray.find(-1) >= 0:
		return false
	var loose := _on_board & ~_cover
	for s: int in _geo.screw_count:
		if loose & (1 << s) and destination(s).x != NONE:
			return false
	return true


func _note_helper(helper: String) -> void:
	if not _helpers.has(helper):
		_helpers.append(helper)


func _save(screw: int) -> Dictionary:
	return {
		"screw": screw,
		"on_board": _on_board,
		"box_color": _box_color.duplicate(),
		"wells": _wells.duplicate(),
		"next_box": _next_box,
		"tray": _tray.duplicate(),
		"tray_uses": _tray_uses,
		"fell_on": _fell_on.duplicate(),
	}


func _restore(step: Dictionary) -> void:
	_on_board = step["on_board"]
	_box_color = step["box_color"]
	_wells = step["wells"]
	_next_box = step["next_box"]
	var tray: PackedInt32Array = step["tray"]
	# The Extra slot stays open (R27): an older tray gets an empty sixth slot.
	while tray.size() < _tray.size():
		tray.append(-1)
	_tray = tray
	_tray_uses = step["tray_uses"]
	_fell_on = step["fell_on"]
	_cover = _geo.covered(_on_board)


## Where every screw is: on the board, in a tray slot, in a box well, or in a closed box.
func _places() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(_geo.screw_count)
	out.fill(_CLOSED)
	for s: int in _geo.screw_count:
		if _on_board & (1 << s):
			out[s] = _ON_BOARD
	for slot: int in _tray.size():
		if _tray[slot] >= 0:
			out[_tray[slot]] = slot
	for i: int in _wells.size():
		if _wells[i] >= 0:
			out[_wells[i]] = _IN_BOX + i
	return out
