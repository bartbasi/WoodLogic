# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name ChaosBot
extends Bot
## Makes calls at the wrong time on purpose: taps on covered, gone and out of range screws,
## undo with nothing to undo or after a win, Extra slot twice, Screwdriver on anything. Every
## one must give the right TapResult reason and never an engine error; BotSession checks that.
## It plays on after a loss by using helpers, as a player would, and probes a won game once.

var rng := RandomNumberGenerator.new()
var _after_end: int = 0
var _steps: int = 0
var max_steps: int = 400


func _init(seed_value: int = 1) -> void:
	bot_name = "chaos"
	tap_ms = 1500
	rng.seed = seed_value


func step(session: BotSession) -> bool:
	_steps += 1
	if _steps > max_steps:
		return false
	var n := session.level.screw_count()
	if _steps == 1:
		# Nothing has happened yet, so there is nothing to undo.
		session.undo()
		return true
	var status := session.status()
	if status == PlayState.WON:
		# Every action must now answer NOT_PLAYING.
		_after_end += 1
		if _after_end > 6:
			return false
		_act_randomly(session, n)
		return true
	var roll := rng.randf()
	if status == PlayState.LOST:
		_after_end += 1
		if _after_end > 60:
			return false
		if roll < 0.3:
			session.undo()
		elif roll < 0.45:
			session.extra_slot()
		elif roll < 0.8:
			session.screwdriver(rng.randi_range(0, n - 1))
		else:
			_act_randomly(session, n)
		return true
	_after_end = 0
	if roll < 0.62:
		var free := Bot.free_screws(session)
		if free.is_empty():
			return false
		session.tap(free[rng.randi_range(0, free.size() - 1)])
	else:
		_act_randomly(session, n)
	return true


func _act_randomly(session: BotSession, n: int) -> void:
	var kind := rng.randi_range(0, 6)
	match kind:
		0:
			# Any id: covered, gone (a double tap), or out of range.
			session.tap(rng.randi_range(-3, n + 3))
		1:
			session.undo()
		2:
			session.extra_slot()
		3:
			session.screwdriver(rng.randi_range(0, n - 1))
		4:
			session.screwdriver(rng.randi_range(-3, n + 3))
		5:
			# Any screw id again: usually gone or covered by now, sometimes free.
			session.tap(rng.randi_range(0, n - 1))
		_:
			session.undo()
			session.undo()
