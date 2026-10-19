# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name TapResult
extends RefCounted
## What an action did (docs/ARCHITECTURE.md 4.3). A failed action has ok false, a reason and
## no events, and changed nothing.

## It worked.
const NONE := 0
## The screw is no longer on the board (a double tap).
const GONE := 1
## The screw is covered (the view wiggles cover_plank(screw)).
const COVERED := 2
## No destination (R25, or a Screwdriver with nowhere to go, R31).
const REFUSED := 3
## Undo with an empty history (nothing is spent).
const NOTHING_TO_UNDO := 4
## Extra slot a second time this attempt.
const ALREADY_USED := 5
## Not allowed in this status.
const NOT_PLAYING := 6
const REASON_NAMES: Array[String] = ["NONE", "GONE", "COVERED", "REFUSED", "NOTHING_TO_UNDO", "ALREADY_USED", "NOT_PLAYING"]

var ok: bool = false
var reason: int = NONE
var events: Array[LogicEvent] = []


static func failed(why: int) -> TapResult:
	var r := TapResult.new()
	r.ok = false
	r.reason = why
	return r


static func done(list: Array[LogicEvent]) -> TapResult:
	var r := TapResult.new()
	r.ok = true
	r.reason = NONE
	r.events = list
	return r


## The event kinds in order, for tests.
func kinds() -> PackedInt32Array:
	var out := PackedInt32Array()
	for e: LogicEvent in events:
		out.append(e.kind)
	return out


## The events of one kind.
func of_kind(event_kind: int) -> Array[LogicEvent]:
	var out: Array[LogicEvent] = []
	for e: LogicEvent in events:
		if e.kind == event_kind:
			out.append(e)
	return out


func describe() -> String:
	if not ok:
		return "failed: " + REASON_NAMES[reason]
	var parts := PackedStringArray()
	for e: LogicEvent in events:
		parts.append(e.describe())
	return "; ".join(parts)
