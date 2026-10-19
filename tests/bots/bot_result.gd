# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BotResult
extends RefCounted
## What one bot got out of one attempt at one level.

var bot: String = ""
var won: bool = false
## The attempt ended in the LOST status (it can only be that or won, unless the step cap hit).
var lost: bool = false
## Taps that worked (a tap on the tray counts, a refused one does not).
var taps: int = 0
## Calls that failed (refused, covered, gone, and so on). Only the random and chaos bots fail.
var failed_calls: int = 0
## PlayState.tray_uses() at the end.
var tray_uses: int = 0
## The most tray slots holding a screw at once ("tray pressure").
var peak_tray: int = 0
## Actions after which the tray had at most one free slot left.
var near_full: int = 0
## Stars.award at the simulated time: cleared, fast, clean.
var stars := Vector3i.ZERO
var elapsed_ms: int = 0
## Rule problems the session found. Empty means every check passed.
var violations := PackedStringArray()
var violation_count: int = 0
## How often each action/answer pair came up, for coverage (for example "tap:COVERED").
var reasons: Dictionary = {}


func star_total() -> int:
	return stars.x + stars.y + stars.z
