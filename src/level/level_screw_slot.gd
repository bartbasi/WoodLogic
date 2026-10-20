# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelScrewSlot
extends RefCounted
## What the level scene keeps for one screw: its view, where the view thinks the screw is (the
## logic's answer, applied at the tap, not where it has flown to yet) and the motion in progress.

const BOARD := 0
const BOX := 1
const TRAY := 2
const CLOSED := 3

var screw: int = 0
var view: Node2D
## Where the screw is: BOARD, BOX (a is the position, b the well), TRAY (a is the slot) or CLOSED
## (it left with a closed box).
var kind: int = BOARD
var a: int = -1
var b: int = -1
var covered := false
var anim: LevelAnim


## Drops the motion in progress, wherever it has got to.
func stop() -> void:
	if anim != null:
		anim.cancel()
		anim = null
