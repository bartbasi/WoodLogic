# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BotRecord
extends RefCounted
## Every bot's numbers for one level, and anything that looked wrong.

var entry: BotEntry
## Bot name ("perfect", "novice", "random") to BotStats.
var stats: Dictionary = {}
## Rule violations the sessions found, each with the bot and level in front.
var problems := PackedStringArray()
## Disagreements between a bot and the solver (the perfect bot's tray uses against the fewest,
## the novice bot against Solver's novice_won).
var mismatches := PackedStringArray()


func bot(name: String) -> BotStats:
	if not stats.has(name):
		stats[name] = BotStats.new()
	return stats[name]
