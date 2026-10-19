# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name SolveResult
extends RefCounted
## What Solver.solve found (docs/ARCHITECTURE.md 4.4). A level whose search did not complete
## is never shown.

## A winning order was found.
var solved: bool = false
## The search finished: if solved, fewest_tray_uses is proven; if not, the level has no
## solution. False if it stopped at max_states.
var complete: bool = false
## The fewest tray uses any solution needs (-1 if not solved).
var fewest_tray_uses: int = -1
## A solution with that many tray uses: screw ids in tap order.
var solution := PackedInt32Array()
## The search stopped because every solution needs more tray uses than the cap it was given
## (complete is true then: that much is proven).
var over_cap: bool = false
## Distinct states the search reached.
var states: int = 0
## Whether the novice policy (GDD 6.4) wins.
var novice_won: bool = false
## The trap measure: the share of careless playouts that lose (see Solver).
var trap: float = 0.0
## Wall-clock milliseconds, for reports only. Nothing may depend on it.
var ms: int = 0
