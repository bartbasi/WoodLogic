# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name PerfectBot
extends Bot
## Replays Solver.solve's solution tap by tap.

var _solution: PackedInt32Array
var _next: int = 0


func _init(solution: PackedInt32Array = PackedInt32Array()) -> void:
	bot_name = "perfect"
	tap_ms = 1500
	_solution = solution


func step(session: BotSession) -> bool:
	if _next >= _solution.size() or session.status() != PlayState.PLAYING:
		return false
	var screw := _solution[_next]
	_next += 1
	var r := session.tap(screw)
	if not r.ok:
		session.note_problem("the solution's tap %d (screw %d) failed: %s" % [_next, screw, TapResult.REASON_NAMES[r.reason]])
		return false
	return true
