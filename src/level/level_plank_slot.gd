# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelPlankSlot
extends RefCounted
## What the level scene keeps for one plank: its view, what the logic last said about it, and the
## angle it is drawn at right now (a swing or a fall is in progress when that differs from `rest`).
## The view is placed by a pivot and an angle: it turns about the pivot (design units on the
## board), which is the hanging screw, or the authored pose when the plank is fixed.

var plank: int = 0
var view: Node2D
var outline_gu := PackedVector2Array()
var state: int = PlayState.FIXED
## The screw it hangs on, or -1.
var pivot_screw: int = -1
## The logic's rest angle (degrees), and the angle drawn now.
var rest := 0.0
var angle := 0.0
var pivot := Vector2.ZERO
var anim: LevelAnim


func stop() -> void:
	if anim != null:
		anim.cancel()
		anim = null


## Turns the view about `about` (board design units) to `deg` and remembers it.
func pose(about: Vector2, deg: float) -> void:
	pivot = about
	angle = deg
	var r := deg_to_rad(deg)
	view.rotation = r
	view.scale = Vector2.ONE
	view.position = about - about.rotated(r)
