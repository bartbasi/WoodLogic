# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BotSession
extends RefCounted
## One attempt at one level, played through PlayState's public API only. Every action a bot
## makes goes through here, and after each one the session checks the rules from outside: it
## works out what must happen from the observable state (its own small model of R12, R13 and
## R18 to R24, and its own covering test) and compares. Problems go in `violations`; a bot never
## has to look at them. Nothing here reads a private member of the logic.

const MAX_VIOLATIONS := 20
const HEAD := 3.5
## Phases of a canonical event list (docs/ARCHITECTURE.md 4.3).
const _LEAVES := 1
const _PLANK := 2
const _COVER := 3
const _BOXES := 4
const _STATUS := 5

var state: PlayState
var level: LevelData
## Run the independent covering test after every action (slower).
var deep: bool = true
var violations := PackedStringArray()
var violation_count: int = 0
## Every call made, working or not.
var calls: int = 0
## Taps that worked.
var taps: int = 0
## Calls that failed, any kind.
var failed_calls: int = 0
var peak_tray: int = 0
var near_full: int = 0
## How often each answer (a TapResult reason name) was expected, for coverage.
var reason_counts: Dictionary = {}

var _n: int
var _slots: int
var _open: int
## Boxes that have closed, and the queue index of the next box to arrive.
var _closed: int = 0
var _next_q: int = 0
var _depth: int = 0
var _stack: Array[Dictionary] = []
var _helpers := PackedStringArray()
var _extra: bool = false
var _tray_len: int


## What can be seen of a state from outside, through the public calls.
class Obs extends RefCounted:
	var on_board := PackedInt32Array()
	var free := PackedInt32Array()
	var dest_kind := PackedInt32Array()
	var dest_index := PackedInt32Array()
	var tray := PackedInt32Array()
	var tray_uses: int = 0
	var box_color := PackedInt32Array()
	var box_count := PackedInt32Array()
	var wells: Array[PackedInt32Array] = []
	var status: int = 0
	var plank := PackedInt32Array()
	var pose: Array[Vector3] = []
	var preview := PackedInt32Array()
	var helpers := PackedStringArray()
	var extra: bool = false
	var can_undo: bool = false
	var snapshot_text: String = ""
	var snapshot: Dictionary = {}


static func start(level_data: LevelData, deep_checks: bool = true) -> BotSession:
	var session := BotSession.new()
	session.level = level_data
	session.deep = deep_checks
	session.state = PlayState.start(level_data)
	if session.state == null:
		return null
	session._n = level_data.screw_count()
	session._slots = Tuning.box_slots
	session._open = Tuning.open_boxes
	session._tray_len = level_data.tray_size
	session._next_q = mini(session._open, level_data.queue.size())
	var o := session._observe()
	session._check_invariants(o, "at the start")
	session._track(o)
	return session


# The four actions

func tap(screw: int) -> TapResult:
	return _act("tap", screw)


func screwdriver(screw: int) -> TapResult:
	return _act("screwdriver", screw)


func extra_slot() -> TapResult:
	return _act("extra_slot", -1)


func undo() -> TapResult:
	return _act("undo", -1)


func status() -> int:
	return state.status()


func _act(kind: String, screw: int) -> TapResult:
	var before := _observe()
	var expect := _expected_reason(kind, screw, before)
	var reason_name := "%s:%s" % [kind, TapResult.REASON_NAMES[expect]]
	reason_counts[reason_name] = int(reason_counts.get(reason_name, 0)) + 1
	var r: TapResult
	match kind:
		"tap":
			r = state.tap(screw)
		"screwdriver":
			r = state.use_screwdriver(screw)
		"extra_slot":
			r = state.use_extra_slot()
		_:
			r = state.undo()
	calls += 1
	var where := "call %d %s(%d)" % [calls, kind, screw]
	if r.ok != (expect == TapResult.NONE) or r.reason != expect:
		note_problem("%s: expected %s, got ok=%s reason=%s" % [where, TapResult.REASON_NAMES[expect], str(r.ok), TapResult.REASON_NAMES[r.reason]])
		failed_calls += 0 if r.ok else 1
		return r
	if not r.ok:
		failed_calls += 1
		_verify_failed(where, before, r)
		return r
	var after := _observe()
	match kind:
		"tap", "screwdriver":
			if kind == "tap":
				taps += 1
			_verify_move(where, kind, screw, before, after, r)
		"extra_slot":
			_verify_extra(where, before, after, r)
		_:
			_verify_undo(where, before, after, r)
	_check_invariants(after, where)
	_track(after)
	return r


func _track(o: Obs) -> void:
	var used := 0
	for s: int in o.tray:
		if s >= 0:
			used += 1
	peak_tray = maxi(peak_tray, used)
	if o.tray.size() - used <= 1:
		near_full += 1


func note_problem(message: String) -> void:
	violation_count += 1
	if violations.size() < MAX_VIOLATIONS:
		violations.append(message)


# Observing

func _observe() -> Obs:
	var o := Obs.new()
	for s: int in _n:
		o.on_board.append(1 if state.is_on_board(s) else 0)
		o.free.append(1 if state.is_free(s) else 0)
		var d := state.destination(s)
		o.dest_kind.append(d.x)
		o.dest_index.append(d.y)
	o.tray = state.tray()
	o.tray_uses = state.tray_uses()
	for position: int in _open:
		var box := state.open_box(position)
		o.box_color.append(box.x)
		o.box_count.append(box.y)
		o.wells.append(state.box_screws(position))
	o.status = state.status()
	for p: int in level.planks.size():
		o.plank.append(state.plank_state(p))
		o.pose.append(state.plank_pose(p))
	o.preview = state.preview()
	o.helpers = state.helpers_used()
	o.extra = state.extra_slot_used()
	o.can_undo = state.can_undo()
	o.snapshot = state.snapshot()
	o.snapshot_text = _snapshot_text(o.snapshot, o.tray.size(), false)
	return o


## The snapshot as text, with the tray padded to `tray_len` slots. With `loose`, the status
## and tray are left out (an Extra slot opened since the snapshot was taken can change them).
static func _snapshot_text(snap: Dictionary, tray_len: int, loose: bool) -> String:
	var copy := snap.duplicate(true)
	var tray: PackedInt32Array = copy["tray"]
	while tray.size() < tray_len:
		tray.append(-1)
	copy["tray"] = tray
	if loose:
		copy.erase("status")
		copy.erase("tray")
	return var_to_str(copy)


## Where each screw is: -1 on the board, a tray slot, 100 + position * 3 + well in a box, -2
## closed.
func _places(o: Obs) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(_n)
	out.fill(-2)
	for s: int in _n:
		if o.on_board[s] == 1:
			out[s] = -1
	for slot: int in o.tray.size():
		if o.tray[slot] >= 0:
			out[o.tray[slot]] = slot
	for position: int in o.wells.size():
		for well: int in o.wells[position].size():
			var s: int = o.wells[position][well]
			if s >= 0:
				out[s] = 100 + position * _slots + well
	return out


## R12, from what can be seen.
func _predict(screw: int, o: Obs) -> Vector2i:
	if screw < 0 or screw >= _n or o.on_board[screw] == 0:
		return Vector2i(PlayState.NONE, -1)
	var color := level.screw_colors[screw]
	var best := -1
	var best_count := -1
	for position: int in _open:
		if o.box_color[position] == color and o.box_count[position] < _slots and o.box_count[position] > best_count:
			best = position
			best_count = o.box_count[position]
	if best >= 0:
		return Vector2i(PlayState.BOX, best)
	var slot := o.tray.find(-1)
	if slot >= 0:
		return Vector2i(PlayState.TRAY, slot)
	return Vector2i(PlayState.NONE, -1)


func _expected_reason(kind: String, screw: int, o: Obs) -> int:
	var valid := screw >= 0 and screw < _n and o.on_board[screw] == 1
	match kind:
		"tap":
			if o.status != PlayState.PLAYING:
				return TapResult.NOT_PLAYING
			if not valid:
				return TapResult.GONE
			if o.free[screw] == 0:
				return TapResult.COVERED
			if _predict(screw, o).x == PlayState.NONE:
				return TapResult.REFUSED
			return TapResult.NONE
		"screwdriver":
			if o.status == PlayState.WON:
				return TapResult.NOT_PLAYING
			if not valid:
				return TapResult.GONE
			if _predict(screw, o).x == PlayState.NONE:
				return TapResult.REFUSED
			return TapResult.NONE
		"extra_slot":
			if o.status == PlayState.WON:
				return TapResult.NOT_PLAYING
			if _extra:
				return TapResult.ALREADY_USED
			return TapResult.NONE
		_:
			if o.status == PlayState.WON:
				return TapResult.NOT_PLAYING
			if _depth == 0:
				return TapResult.NOTHING_TO_UNDO
			return TapResult.NONE


## R22 and R23 from what can be seen.
func _expected_status(o: Obs) -> int:
	var any_board := o.on_board.has(1)
	if not any_board and o.tray.count(-1) == o.tray.size():
		return PlayState.WON
	if o.tray.has(-1):
		return PlayState.PLAYING
	for s: int in _n:
		if o.free[s] == 1 and _predict(s, o).x != PlayState.NONE:
			return PlayState.PLAYING
	return PlayState.LOST


# Checks after a failed action

func _verify_failed(where: String, before: Obs, r: TapResult) -> void:
	if not r.events.is_empty():
		note_problem("%s: a failed action returned %d events" % [where, r.events.size()])
	var after := _observe()
	if after.snapshot_text != before.snapshot_text:
		note_problem("%s: a failed action changed the state" % where)
	if after.helpers != before.helpers or after.extra != before.extra or after.can_undo != before.can_undo:
		note_problem("%s: a failed action changed helpers or the undo history" % where)
	if after.tray != before.tray or after.free != before.free:
		note_problem("%s: a failed action changed the tray or the free screws" % where)


# Tap and Screwdriver

func _verify_move(where: String, kind: String, screw: int, before: Obs, after: Obs, r: TapResult) -> void:
	var dest := _predict(screw, before)
	if _dest_differs(before, screw, dest):
		note_problem("%s: destination() said (%d, %d), R12 says (%d, %d)" % [where, before.dest_kind[screw], before.dest_index[screw], dest.x, dest.y])
	# The expected result, worked out here.
	var tray := before.tray.duplicate()
	var wells := PackedInt32Array()
	for w: PackedInt32Array in before.wells:
		wells.append_array(w)
	var colors := before.box_color.duplicate()
	var counts := before.box_count.duplicate()
	var tray_uses := before.tray_uses
	var expected: Array[LogicEvent] = []
	var next_q := _next_q
	var closed := _closed
	if dest.x == PlayState.BOX:
		var leave := LogicEvent.make(LogicEvent.SCREW_TO_BOX)
		leave.screw = screw
		leave.position = dest.y
		leave.well = counts[dest.y]
		expected.append(leave)
	else:
		var leave := LogicEvent.make(LogicEvent.SCREW_TO_TRAY)
		leave.screw = screw
		leave.slot = dest.y
		expected.append(leave)
	# The plank (R14 to R17).
	var plank := level.screw_plank(screw)
	var on_before := _plank_on_board(plank, before)
	var on_after := on_before - 1
	if on_after == 0:
		var fell := LogicEvent.make(LogicEvent.PLANK_FELL)
		fell.plank = plank
		expected.append(fell)
	elif on_after == 1:
		var swung := LogicEvent.make(LogicEvent.PLANK_SWUNG)
		swung.plank = plank
		for s: int in level.planks[plank].screws:
			if s != screw and before.on_board[s] == 1:
				swung.screw = s
		swung.angle = after.pose[plank].z
		expected.append(swung)
	# Covering (R9), as the view sees free and covered.
	var changed := PackedInt32Array()
	for s: int in _n:
		if s != screw and before.on_board[s] == 1 and before.free[s] != after.free[s]:
			changed.append(s)
	if not changed.is_empty():
		var cover := LogicEvent.make(LogicEvent.COVER_CHANGED)
		cover.screws = changed
		expected.append(cover)
	# Into its place, then the queue (R13 step 4 and 5, R18 to R21).
	if dest.x == PlayState.TRAY:
		tray[dest.y] = screw
		tray_uses += 1
	else:
		wells[dest.y * _slots + counts[dest.y]] = screw
		counts[dest.y] += 1
		while counts[dest.y] == _slots:
			var shut := LogicEvent.make(LogicEvent.BOX_CLOSED)
			shut.position = dest.y
			shut.color = colors[dest.y]
			expected.append(shut)
			closed += 1
			for well: int in _slots:
				wells[dest.y * _slots + well] = -1
			counts[dest.y] = 0
			var color := -1
			if next_q < level.queue.size():
				color = level.queue[next_q]
				next_q += 1
			colors[dest.y] = color
			var arrived := LogicEvent.make(LogicEvent.BOX_ARRIVED)
			arrived.position = dest.y
			arrived.color = color
			expected.append(arrived)
			if color < 0:
				break
			for slot: int in tray.size():
				var held := tray[slot]
				if held < 0 or level.screw_colors[held] != color:
					continue
				if counts[dest.y] >= _slots:
					break
				var jump := LogicEvent.make(LogicEvent.TRAY_TO_BOX)
				jump.screw = held
				jump.slot = slot
				jump.position = dest.y
				jump.well = counts[dest.y]
				expected.append(jump)
				wells[dest.y * _slots + counts[dest.y]] = held
				counts[dest.y] += 1
				tray[slot] = -1
	_note_status_event(expected, before.status, _expected_status(after))
	# Compare.
	var want := _describe(expected)
	var got := _describe(r.events)
	if want != got:
		note_problem("%s: events differ.\n    expected %s\n    got      %s" % [where, want, got])
	var order := order_problem(r.kinds(), kind)
	if order != "":
		note_problem("%s: %s" % [where, order])
	# The state it left.
	if after.tray != tray:
		note_problem("%s: tray is %s, expected %s" % [where, str(Array(after.tray)), str(Array(tray))])
	if after.tray_uses != tray_uses:
		note_problem("%s: tray_uses is %d, expected %d" % [where, after.tray_uses, tray_uses])
	for position: int in _open:
		var want_wells := wells.slice(position * _slots, (position + 1) * _slots)
		if after.box_color[position] != colors[position] or after.box_count[position] != counts[position] or after.wells[position] != want_wells:
			note_problem("%s: box %d holds color %d with %s, expected color %d with %s" % [where, position, after.box_color[position], str(Array(after.wells[position])), colors[position], str(Array(want_wells))])
	var want_preview := level.queue.slice(next_q, mini(next_q + Tuning.preview, level.queue.size()))
	if after.preview != want_preview:
		note_problem("%s: preview is %s, expected %s" % [where, str(Array(after.preview)), str(Array(want_preview))])
	for s: int in _n:
		var expect_on := 0 if s == screw else before.on_board[s]
		if after.on_board[s] != expect_on:
			note_problem("%s: screw %d is %s the board, expected %s" % [where, s, "on" if after.on_board[s] == 1 else "off", "on" if expect_on == 1 else "off"])
	if kind == "screwdriver":
		_note_helper("screwdriver")
	_stack.append({"obs": before, "screw": screw, "closed": _closed, "next_q": _next_q, "extra": _extra})
	_depth += 1
	_closed = closed
	_next_q = next_q


func _dest_differs(o: Obs, screw: int, dest: Vector2i) -> bool:
	return o.dest_kind[screw] != dest.x or o.dest_index[screw] != dest.y


func _plank_on_board(plank: int, o: Obs) -> int:
	var count := 0
	for s: int in level.planks[plank].screws:
		count += o.on_board[s]
	return count


## What the status event must be: WON or LOST at those statuses, RESUMED when a loss cleared,
## nothing otherwise.
func _note_status_event(events: Array[LogicEvent], was: int, now: int) -> void:
	if now == PlayState.WON:
		events.append(LogicEvent.make(LogicEvent.WON))
	elif now == PlayState.LOST:
		events.append(LogicEvent.make(LogicEvent.LOST))
	elif was == PlayState.LOST:
		events.append(LogicEvent.make(LogicEvent.RESUMED))


static func _describe(events: Array[LogicEvent]) -> String:
	var parts := PackedStringArray()
	for e: LogicEvent in events:
		parts.append(e.describe())
	return " | ".join(parts)


# Extra slot and Undo

func _verify_extra(where: String, before: Obs, after: Obs, r: TapResult) -> void:
	_extra = true
	_tray_len += 1
	_note_helper("extra_slot")
	var expected: Array[LogicEvent] = []
	var opened := LogicEvent.make(LogicEvent.TRAY_EXTENDED)
	opened.slot = before.tray.size()
	expected.append(opened)
	_note_status_event(expected, before.status, _expected_status(after))
	if _describe(expected) != _describe(r.events):
		note_problem("%s: events %s, expected %s" % [where, _describe(r.events), _describe(expected)])
	var want_tray := before.tray.duplicate()
	want_tray.append(-1)
	if after.tray != want_tray:
		note_problem("%s: the tray is %s, expected %s" % [where, str(Array(after.tray)), str(Array(want_tray))])
	if after.on_board != before.on_board or after.tray_uses != before.tray_uses or after.box_color != before.box_color or after.preview != before.preview:
		note_problem("%s: Extra slot changed more than the tray" % where)
	if before.status != PlayState.LOST and after.status != before.status:
		note_problem("%s: Extra slot changed the status from %d to %d" % [where, before.status, after.status])


func _verify_undo(where: String, before: Obs, after: Obs, r: TapResult) -> void:
	var entry: Dictionary = _stack.pop_back()
	_depth -= 1
	var was: Obs = entry["obs"]
	var screw: int = entry["screw"]
	_closed = entry["closed"]
	_next_q = entry["next_q"]
	_note_helper("undo")
	# The snapshot comes back (R26), allowing for an Extra slot opened since (R27).
	var extra_since := _extra and not bool(entry["extra"])
	var want_text := _snapshot_text(was.snapshot, after.tray.size(), extra_since)
	var got_text := _snapshot_text(after.snapshot, after.tray.size(), extra_since)
	if want_text != got_text:
		note_problem("%s: the snapshot after undo is not the one before the action" % where)
	var padded := was.tray.duplicate()
	while padded.size() < after.tray.size():
		padded.append(-1)
	if after.on_board != was.on_board or after.tray != padded or after.tray_uses != was.tray_uses or after.box_color != was.box_color or after.box_count != was.box_count or after.preview != was.preview:
		note_problem("%s: undo did not restore the board, boxes, tray or queue" % where)
	for position: int in _open:
		if after.wells[position] != was.wells[position]:
			note_problem("%s: undo did not restore box %d" % [where, position])
	if after.plank != was.plank or after.free != was.free:
		note_problem("%s: undo did not restore the planks or the free screws" % where)
	# The events.
	var places_before := _places(before)
	var places_after := _places(after)
	var moved := PackedInt32Array()
	for s: int in _n:
		if places_before[s] != places_after[s]:
			moved.append(s)
	var expected: Array[LogicEvent] = []
	var undone := LogicEvent.make(LogicEvent.UNDONE)
	undone.screw = screw
	undone.screws = moved
	expected.append(undone)
	_note_status_event(expected, before.status, _expected_status(after))
	if _describe(expected) != _describe(r.events):
		note_problem("%s: events %s, expected %s" % [where, _describe(r.events), _describe(expected)])
	if not moved.has(screw):
		note_problem("%s: the undone screw %d is not in the screws that moved" % [where, screw])


func _note_helper(helper: String) -> void:
	if not _helpers.has(helper):
		_helpers.append(helper)


# Checks that hold in every state

func _check_invariants(o: Obs, where: String) -> void:
	if o.tray.size() != _tray_len:
		note_problem("%s: the tray has %d slots, expected %d" % [where, o.tray.size(), _tray_len])
	if o.helpers != _helpers or o.extra != _extra:
		note_problem("%s: helpers_used is %s and extra_slot_used %s, expected %s and %s" % [where, str(Array(o.helpers)), str(o.extra), str(Array(_helpers)), str(_extra)])
	if o.can_undo != (_depth > 0 and o.status != PlayState.WON):
		note_problem("%s: can_undo is %s with %d actions in the history" % [where, str(o.can_undo), _depth])
	# Boxes (R2, R3, R18).
	var in_boxes := 0
	for position: int in _open:
		var filled := 0
		var gap := false
		for well: int in o.wells[position].size():
			var s: int = o.wells[position][well]
			if s >= 0:
				filled += 1
				if gap:
					note_problem("%s: box %d has a gap before well %d" % [where, position, well])
				if level.screw_colors[s] != o.box_color[position]:
					note_problem("%s: screw %d (color %d) sits in a box of color %d" % [where, s, level.screw_colors[s], o.box_color[position]])
			else:
				gap = true
		in_boxes += filled
		if o.box_count[position] != filled or filled > _slots - 1:
			note_problem("%s: box %d count %d with %d screws in its wells (a full box should have closed)" % [where, position, o.box_count[position], filled])
		if o.box_color[position] < -1 or o.box_color[position] >= LevelData.MAX_COLORS:
			note_problem("%s: box %d has color %d" % [where, position, o.box_color[position]])
		if o.box_color[position] == -1 and filled > 0:
			note_problem("%s: an empty position holds screws" % where)
	# Every screw in exactly one place (nothing lost, nothing twice).
	var seen := PackedInt32Array()
	seen.resize(_n)
	var on_board := 0
	var in_tray := 0
	for s: int in _n:
		seen[s] += o.on_board[s]
		on_board += o.on_board[s]
	for s: int in o.tray:
		if s >= 0:
			seen[s] += 1
			in_tray += 1
	for position: int in _open:
		for s: int in o.wells[position]:
			if s >= 0:
				seen[s] += 1
	for s: int in _n:
		if seen[s] > 1:
			note_problem("%s: screw %d is in more than one place" % [where, s])
	var closed_screws := _n - on_board - in_tray - in_boxes
	if closed_screws != _closed * _slots:
		note_problem("%s: %d screws are unaccounted for, but %d boxes have closed" % [where, closed_screws, _closed])
	# I1: no tray screw matches an open box with room.
	for s: int in o.tray:
		if s < 0:
			continue
		for position: int in _open:
			if o.box_color[position] == level.screw_colors[s] and o.box_count[position] < _slots:
				note_problem("%s: I1 broken: tray screw %d fits open box %d" % [where, s, position])
	# Status (R22 to R24).
	if o.status != _expected_status(o):
		note_problem("%s: status is %d but the board says %d" % [where, o.status, _expected_status(o)])
	# R12 again for every screw on the board, not only the one tapped.
	for s: int in _n:
		if o.on_board[s] == 1:
			var want_dest := _predict(s, o)
			if _dest_differs(o, s, want_dest):
				note_problem("%s: destination(%d) says (%d, %d), R12 says (%d, %d)" % [where, s, o.dest_kind[s], o.dest_index[s], want_dest.x, want_dest.y])
	# R10, and cover_plank agreeing with is_free.
	var any_free := false
	for s: int in _n:
		var cover := state.cover_plank(s)
		if o.on_board[s] == 0:
			if o.free[s] == 1 or cover != -1:
				note_problem("%s: screw %d is off the board but free or covered" % [where, s])
			continue
		if (o.free[s] == 1) != (cover == -1):
			note_problem("%s: screw %d is_free %s but cover_plank %d" % [where, s, str(o.free[s] == 1), cover])
		if cover >= 0 and (state.plank_state(cover) == PlayState.FALLEN or level.planks[cover].layer >= level.planks[level.screw_plank(s)].layer):
			note_problem("%s: screw %d is covered by plank %d, which is not in front of it" % [where, s, cover])
		if o.free[s] == 1:
			any_free = true
	if on_board > 0 and not any_free:
		note_problem("%s: R10 broken: screws on the board and none free" % where)
	# Planks.
	for p: int in level.planks.size():
		var count := _plank_on_board(p, o)
		var want := PlayState.FALLEN if count == 0 else (PlayState.HANGING if count == 1 else PlayState.FIXED)
		if o.plank[p] != want:
			note_problem("%s: plank %d is state %d with %d screws on it" % [where, p, o.plank[p], count])
		if want == PlayState.FIXED and o.pose[p] != Vector3.ZERO:
			note_problem("%s: a fixed plank %d has a pose %s" % [where, p, str(o.pose[p])])
		if want == PlayState.HANGING:
			for s: int in level.planks[p].screws:
				if o.on_board[s] == 1:
					var c := level.screw_center(s)
					if absf(o.pose[p].x - c.x) > 0.01 or absf(o.pose[p].y - c.y) > 0.01:
						note_problem("%s: plank %d hangs on screw %d but its pivot is (%.2f, %.2f)" % [where, p, s, o.pose[p].x, o.pose[p].y])
			if o.pose[p].z <= -180.0 or o.pose[p].z > 180.0:
				note_problem("%s: plank %d has angle %.2f outside (-180, 180]" % [where, p, o.pose[p].z])
			# R16: the centroid of the turned plank is straight below the pivot (a plank whose
			# centroid is within 0.5 gu of the pivot does not turn).
			var middle := _centroid(level.planks[p])
			var pivot := Vector2(o.pose[p].x, o.pose[p].y)
			var reach := middle.distance_to(pivot)
			if reach < 0.4:
				if absf(o.pose[p].z) > 0.001:
					note_problem("%s: plank %d should not turn but its angle is %.2f" % [where, p, o.pose[p].z])
			elif reach > 0.6:
				var rest := _turned(PackedVector2Array([middle]), o.pose[p])[0]
				if absf(rest.x - pivot.x) > 0.05 or rest.y <= pivot.y:
					note_problem("%s: plank %d at angle %.2f has its centroid at (%.2f, %.2f), not straight below its pivot (%.2f, %.2f)" % [where, p, o.pose[p].z, rest.x, rest.y, pivot.x, pivot.y])
	if deep:
		_check_cover(o, where)


## The centroid of a plank's area (outline minus a ring's hole), in gu, from the authored
## outline.
static func _centroid(shape: PlankData) -> Vector2:
	var sum := Vector2.ZERO
	var area := 0.0
	var parts: Array[PackedVector2Array] = [shape.outline()]
	var signs: Array[float] = [1.0]
	var hole := shape.inner_outline()
	if not hole.is_empty():
		parts.append(hole)
		signs.append(-1.0)
	for i: int in parts.size():
		var poly := parts[i]
		var a2 := 0.0
		var c := Vector2.ZERO
		for k: int in poly.size():
			var p0 := poly[k]
			var p1 := poly[(k + 1) % poly.size()]
			var cross := p0.x * p1.y - p1.x * p0.y
			a2 += cross
			c += (p0 + p1) * cross
		if absf(a2) < 1e-9:
			continue
		var a := absf(a2) / 2.0
		sum += (c / (3.0 * a2)) * a * signs[i]
		area += a * signs[i]
	return sum / area if absf(area) > 1e-9 else Vector2.ZERO


## The covering rule R7, worked out again here from the poses and outlines.
func _check_cover(o: Obs, where: String) -> void:
	var outer: Array[PackedVector2Array] = []
	var inner: Array[PackedVector2Array] = []
	var bounds: Array[Rect2] = []
	for p: int in level.planks.size():
		if o.plank[p] == PlayState.FALLEN:
			outer.append(PackedVector2Array())
			inner.append(PackedVector2Array())
			bounds.append(Rect2())
			continue
		var shape := level.planks[p]
		var out_poly := shape.outline()
		var in_poly := shape.inner_outline()
		if o.plank[p] == PlayState.HANGING:
			out_poly = _turned(out_poly, o.pose[p])
			in_poly = _turned(in_poly, o.pose[p])
		outer.append(out_poly)
		inner.append(in_poly)
		var box := Rect2(out_poly[0], Vector2.ZERO)
		for v: Vector2 in out_poly:
			box = box.expand(v)
		bounds.append(box.grow(HEAD + 0.5))
	for s: int in _n:
		if o.on_board[s] == 0:
			continue
		var point := level.screw_center(s)
		var layer := level.planks[level.screw_plank(s)].layer
		var covered := false
		for q: int in level.planks.size():
			if o.plank[q] == PlayState.FALLEN or level.planks[q].layer >= layer or not bounds[q].has_point(point):
				continue
			if _region_distance(point, outer[q], inner[q]) < HEAD:
				covered = true
				break
		if covered == (o.free[s] == 1):
			note_problem("%s: screw %d is_free %s but the covering rule says %s" % [where, s, str(o.free[s] == 1), "covered" if covered else "free"])


static func _turned(poly: PackedVector2Array, pose: Vector3) -> PackedVector2Array:
	var out := PackedVector2Array()
	var rad := deg_to_rad(pose.z)
	var c := cos(rad)
	var s := sin(rad)
	for v: Vector2 in poly:
		var d := v - Vector2(pose.x, pose.y)
		out.append(Vector2(pose.x + d.x * c - d.y * s, pose.y + d.x * s + d.y * c))
	return out


## Signed distance to a plank's area: negative inside, positive outside (a ring's hole is
## outside).
static func _region_distance(p: Vector2, outer: PackedVector2Array, inner: PackedVector2Array) -> float:
	var edge := _edge_distance(p, outer)
	var inside := Geometry2D.is_point_in_polygon(p, outer)
	if not inner.is_empty():
		edge = minf(edge, _edge_distance(p, inner))
		if Geometry2D.is_point_in_polygon(p, inner):
			inside = false
	return -edge if inside else edge


static func _edge_distance(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	var count := poly.size()
	for i: int in count:
		var a := poly[i]
		var ab := poly[(i + 1) % count] - a
		var length2 := ab.length_squared()
		var t := 0.0
		if length2 > 0.0:
			t = clampf((p - a).dot(ab) / length2, 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


# The canonical order (docs/ARCHITECTURE.md 4.3), checked on its own

static func _phase(kind: int) -> int:
	match kind:
		LogicEvent.SCREW_TO_BOX, LogicEvent.SCREW_TO_TRAY:
			return _LEAVES
		LogicEvent.PLANK_SWUNG, LogicEvent.PLANK_FELL:
			return _PLANK
		LogicEvent.COVER_CHANGED:
			return _COVER
		LogicEvent.BOX_CLOSED, LogicEvent.BOX_ARRIVED, LogicEvent.TRAY_TO_BOX:
			return _BOXES
		LogicEvent.WON, LogicEvent.LOST, LogicEvent.RESUMED:
			return _STATUS
	return 0


## "" if the kinds are in a legal order for the action ("tap", "screwdriver", "extra_slot" or
## "undo"), otherwise what is wrong.
static func order_problem(kinds: PackedInt32Array, action: String) -> String:
	var statuses := 0
	for i: int in kinds.size():
		if _phase(kinds[i]) == _STATUS:
			statuses += 1
			if i != kinds.size() - 1:
				return "WON, LOST or RESUMED is not the last event"
	if statuses > 1:
		return "more than one status event"
	if action == "extra_slot" or action == "undo":
		var head := LogicEvent.TRAY_EXTENDED if action == "extra_slot" else LogicEvent.UNDONE
		if kinds.is_empty() or kinds[0] != head:
			return "%s does not start with its own event" % action
		for i: int in range(1, kinds.size()):
			if _phase(kinds[i]) != _STATUS:
				return "unexpected event after the first in %s" % action
		if action == "extra_slot" and kinds.has(LogicEvent.WON):
			return "Extra slot cannot win"
		return ""
	if kinds.is_empty() or _phase(kinds[0]) != _LEAVES:
		return "does not start with SCREW_TO_BOX or SCREW_TO_TRAY"
	var phase := 0
	var planks := 0
	var covers := 0
	var in_group := false
	var after_arrival := false
	var to_tray := kinds[0] == LogicEvent.SCREW_TO_TRAY
	for i: int in kinds.size():
		var kind := kinds[i]
		var ph := _phase(kind)
		if ph == 0:
			return "event kind %d does not belong in a tap" % kind
		if ph < phase:
			return "event %d (%d) is out of order" % [i, kind]
		if ph == _LEAVES and i > 0:
			return "more than one screw leaves"
		phase = ph
		if ph == _PLANK:
			planks += 1
		elif ph == _COVER:
			covers += 1
		elif ph == _BOXES:
			if to_tray:
				return "a box event after a screw went to the tray"
			if kind == LogicEvent.BOX_CLOSED:
				if in_group and not after_arrival:
					return "BOX_CLOSED twice without BOX_ARRIVED"
				in_group = true
				after_arrival = false
			elif kind == LogicEvent.BOX_ARRIVED:
				if not in_group or after_arrival:
					return "BOX_ARRIVED without BOX_CLOSED"
				after_arrival = true
			else:
				if not after_arrival:
					return "TRAY_TO_BOX before BOX_ARRIVED"
	if planks > 1:
		return "more than one plank event"
	if covers > 1:
		return "more than one COVER_CHANGED"
	if in_group and not after_arrival:
		return "BOX_CLOSED without BOX_ARRIVED"
	return ""


## How many planks in front of the screw's own plank cover it on the starting board (the
## authored poses), by the same R7 test as above. GDD 6.2 allows at most 3.
static func planks_over(level_data: LevelData, screw: int) -> int:
	var point := level_data.screw_center(screw)
	var layer := level_data.planks[level_data.screw_plank(screw)].layer
	var count := 0
	for shape: PlankData in level_data.planks:
		if shape.layer < layer and _region_distance(point, shape.outline(), shape.inner_outline()) < HEAD:
			count += 1
	return count
