# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name NoviceBot
extends Bot
## The GDD 6.4 novice policy: if some free screw fits an open box, tap the topmost such screw
## (smallest y, then smallest x, then smallest id); otherwise tap the topmost free screw, which
## goes to the tray. It never uses a helper.

var _order := PackedInt32Array()


func _init() -> void:
	bot_name = "novice"
	tap_ms = 2000


func pick(session: BotSession) -> int:
	if _order.is_empty():
		var list: Array[int] = []
		for s: int in session.level.screw_count():
			list.append(s)
		var level := session.level
		list.sort_custom(func(a: int, b: int) -> bool:
			var ca := level.screw_center(a)
			var cb := level.screw_center(b)
			if ca.y != cb.y:
				return ca.y < cb.y
			if ca.x != cb.x:
				return ca.x < cb.x
			return a < b)
		_order = PackedInt32Array(list)
	var first := -1
	for s: int in _order:
		if not session.state.is_free(s):
			continue
		if first < 0:
			first = s
		if session.state.destination(s).x == PlayState.BOX:
			return s
	return first
