# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelHit
extends RefCounted
## Hit testing in grid units against the logic's current state (docs/ARCHITECTURE.md 5.2),
## never against where something is drawn mid animation. A free screw is hit by a circle of
## 24 design units, which is 6 grid units at any board scale (UX 6.1 and 7.3). The screws are
## at least 12 grid units apart, so two circles never meet.

const RADIUS_GU := 6.0


## The free screw nearest to p (grid units) within the touch circle, or -1.
static func free_screw(state: PlayState, p: Vector2) -> int:
	return _nearest(state, p, true)


## The covered screw nearest to p within the same circle, or -1.
static func covered_screw(state: PlayState, p: Vector2) -> int:
	return _nearest(state, p, false)


## The frontmost plank still on the board whose current outline holds p, or -1.
static func plank(state: PlayState, p: Vector2) -> int:
	var level := state.level()
	for plank_id: int in level.geometry.front_to_back:
		if state.plank_state(plank_id) == PlayState.FALLEN:
			continue
		if Geometry2D.is_point_in_polygon(p, state.plank_outline(plank_id)):
			return plank_id
	return -1


static func _nearest(state: PlayState, p: Vector2, want_free: bool) -> int:
	var level := state.level()
	var best := -1
	var best_d := RADIUS_GU * RADIUS_GU
	for s: int in level.screw_count():
		if not state.is_on_board(s) or state.is_free(s) != want_free:
			continue
		var d := p.distance_squared_to(level.screw_center(s))
		if d <= best_d:
			best_d = d
			best = s
	return best
