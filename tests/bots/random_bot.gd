# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name RandomBot
extends Bot
## Taps a uniformly random free screw. A screw with nowhere to go is refused and the bot picks
## again, as a person mashing the screen would.

var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	bot_name = "random"
	tap_ms = 1500
	rng.seed = seed_value


func pick(session: BotSession) -> int:
	var free := Bot.free_screws(session)
	if free.is_empty():
		return -1
	return free[rng.randi_range(0, free.size() - 1)]
