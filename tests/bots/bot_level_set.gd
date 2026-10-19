# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BotLevelSet
extends RefCounted
## Levels for the bots, and how many candidates were thrown away on the way.

var entries: Array[BotEntry] = []
## Candidates looked at, and why some were dropped.
var tried: int = 0
var unsolvable: int = 0
var incomplete: int = 0
var no_first_move: int = 0
var bad_queue: int = 0


func add_all(other: BotLevelSet) -> void:
	entries.append_array(other.entries)
	tried += other.tried
	unsolvable += other.unsolvable
	incomplete += other.incomplete
	no_first_move += other.no_first_move
	bad_queue += other.bad_queue
