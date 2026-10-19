# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BotEntry
extends RefCounted
## One level the bots can play, with what the solver knows about it.

var level: LevelData
var solve: SolveResult
## "tutorial", "coloring" or "generated".
var source: String = ""
var label: String = ""
## The tier (1 to 10), or 0 for a tutorial level.
var tier: int = 0
## True when the tier is the level's own (generated), false when estimated from its size.
var tier_given: bool = false
## "Tutorial", "Easy", "Medium", "Hard" or "Expert".
var group: String = ""
var number: int = 0
var blueprint: String = ""
## A number that makes this level's random bot runs differ from other levels'.
var seed_base: int = 0


func screws() -> int:
	return level.screw_count()
