# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name ProbeResult
extends RefCounted
## What Solver.probe measured: how forgiving a level is, and how far ahead it makes a player
## think. Report only (Phase 5, Playtest Gate 2): nothing that decides a level reads it.
##
## Mistakes. A wrong tap is a tap on a free screw with no open box of its color, so it goes to
## the tray, while some free screw does fit an open box (so a better move existed). From POINTS
## states along the level's own solution (after 0, n / 3 and 2n / 3 of its n taps), k wrong taps
## in a row (k = 1 to MAX_MISTAKES, chosen at random), then a search: can the level still be
## won? Each trial ends one of four ways, counted per point and k:
## - won: the search found a win;
## - lost: it proved there is none (or the wrong taps already lost the level, R23);
## - unknown: the search stopped at its state budget, so neither is proven;
## - skipped: k wrong taps could not be made (no free screw fit a box, none went to the tray,
##   or the tray was full), so there was nothing to measure.
##
## Lookahead. At every state along the solution, the novice's move (GDD 6.4: the topmost free
## screw that fits an open box). Where it is not the solution's own move, a search after it: is
## the level still winnable? A fatal novice move is a trap, and its delay is how many more taps
## the novice makes before it is stuck (R23): how far ahead a player has to look to see the trap.
## A level with no traps needs no lookahead at all; one whose traps spring at once (delay 0)
## needs one tap of it.
##
## The novice's point of no return. Following the novice from the start: the first tap after
## which no win is left (winnability only ever goes away along a path, so a binary search over
## its taps finds it in a few searches), and how many more taps it makes before it is stuck.
## That hidden stretch is how far ahead the level makes a careless player look: it is lost
## long before it shows. A level the novice wins has none.
##
## Peak tray load: the most screws in the tray at once along the solution. The tray size less
## this is the spare room that absorbs wrong taps.

const POINTS := 3
const MAX_MISTAKES := 3

## Per point and k, at index point * MAX_MISTAKES + (k - 1).
var won := PackedInt32Array()
var lost := PackedInt32Array()
var unknown := PackedInt32Array()
var skipped := PackedInt32Array()
## Lookahead: states looked at, where the novice's move differs from the solution's, where it
## is fatal, where its search stopped at the budget, and each trap's delay.
var greedy_states: int = 0
var greedy_differs: int = 0
var greedy_fatal: int = 0
var greedy_unknown: int = 0
var trap_delays := PackedInt32Array()
## The novice's taps, the tap after which it has no win left (-1 if it wins), whether a search
## on the way stopped at the budget (then no_return is only an upper bound), and the hidden
## stretch (novice_taps less no_return; 0 if it wins).
var novice_taps: int = 0
var no_return: int = -1
var no_return_unknown: bool = false
var hidden: int = 0
## The most screws in the tray at once along the solution.
var peak_tray: int = 0
## Searches made (states already searched are not searched again) and wall-clock ms (report
## only).
var searches: int = 0
var ms: int = 0


func _init() -> void:
	for list: PackedInt32Array in [won, lost, unknown, skipped]:
		list.resize(POINTS * MAX_MISTAKES)


## The share of trials still winnable after k wrong taps, over all points, among those proven
## either way; -1 if none was.
func tolerance(k: int) -> float:
	var w := 0
	var l := 0
	for p: int in POINTS:
		w += won[p * MAX_MISTAKES + k - 1]
		l += lost[p * MAX_MISTAKES + k - 1]
	return float(w) / (w + l) if w + l > 0 else -1.0


## The same at one point (0: the start, 1: a third in, 2: two thirds in).
func tolerance_at(point: int, k: int) -> float:
	var w := won[point * MAX_MISTAKES + k - 1]
	var l := lost[point * MAX_MISTAKES + k - 1]
	return float(w) / (w + l) if w + l > 0 else -1.0


## Trials for k wrong taps, over all points, that a list counts (won, lost, unknown, skipped).
func count(list: PackedInt32Array, k: int) -> int:
	var c := 0
	for p: int in POINTS:
		c += list[p * MAX_MISTAKES + k - 1]
	return c


## The share of looked at states where the novice's move is fatal (0 when there were none).
func trap_share() -> float:
	return float(greedy_fatal) / greedy_states if greedy_states > 0 else 0.0
