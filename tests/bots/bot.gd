# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Bot
extends RefCounted
## A player. It sees the game only through a BotSession, which passes calls to PlayState's
## public API. A bot returns from step() with false when it has nothing more to do.

var bot_name: String = "bot"
## The time one tap takes in the simulated clock, in milliseconds (only for the Fast star).
var tap_ms: int = 2000


## Makes one move (or a few). Returns false when the bot is done or stuck.
func step(session: BotSession) -> bool:
	if session.status() != PlayState.PLAYING:
		return false
	var screw := pick(session)
	if screw < 0:
		return false
	session.tap(screw)
	return true


## The screw to tap next, or -1 for none. Subclasses override this.
func pick(_session: BotSession) -> int:
	return -1


## The free screws now, by id.
static func free_screws(session: BotSession) -> PackedInt32Array:
	var out := PackedInt32Array()
	for s: int in session.level.screw_count():
		if session.state.is_free(s):
			out.append(s)
	return out
