# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name GeneratedLevel
extends RefCounted
## What LevelCatalog.get_level and Generator.make hand back (docs/ARCHITECTURE.md 4.4).
## Read-only once built, like LevelData.

var level: LevelData
## The accepted level's solve: fewest tray uses (before slack), solution, novice, trap.
var solve: SolveResult
## How many tries it took: varied boards rejected by the blueprint rules plus colorings solved.
var attempts: int = 0
## True if no try was accepted and a stored fallback level was used (G7 does not apply then).
var fell_back: bool = false
## True if the make was stopped (GenerationStop): level and solve are then null, and nothing
## may be shown.
var stopped: bool = false
## Wall-clock milliseconds, for reports only.
var gen_ms: int = 0
## For reports: how the board was varied ("mirror shift 2,-1 swap 1-2 drop 4" and so on).
var variation: String = ""
## For reports: the coloring pressure of the accepted try (see Generator._color), or -1.
var pressure: int = -1
## For reports: the sum of states over every search this level took.
var total_states: int = 0
## For reports: why tries were turned down. Boards: the blueprint rules or the tier's screws
## and layers (G1, G2). Colorings: no screw free at the start fits an open box (G5). Before the
## search: the novice result is wrong for the tier (G4) or the novice is out too soon (G9a).
## Searches: stopped at max_states, no solution within the tray use cap (or none at all), too
## few tray uses (G3), a peak tray load below the tier's (G10, or not proven within the budget),
## or the solution's tray uses all come in the first third (G9b). The G9 counts are only where
## the tier requires the rule (Generator.SURVIVAL_TIERS and LATE_TRAY_TIERS).
var rejected_boards: int = 0
var rejected_colorings: int = 0
var over_budget: int = 0
var over_cap: int = 0
var too_easy: int = 0
var novice_wrong: int = 0
var short_survival: int = 0
var early_tray: int = 0
var low_peak: int = 0
var peak_unknown: int = 0


func rejections() -> String:
	return "boards %d, colorings %d, budget %d, cap %d, easy %d, novice %d, survival %d, peak %d, peak not proven %d, early tray %d" % [rejected_boards, rejected_colorings, over_budget, over_cap, too_easy, novice_wrong, short_survival, low_peak, peak_unknown, early_tray]
## For the fallback: the solved try that came nearest the tier, its solve and its variation.
var closest: LevelData
var closest_solve: SolveResult
var closest_variation: String = ""
