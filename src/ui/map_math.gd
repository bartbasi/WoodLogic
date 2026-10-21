# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MapMath
extends RefCounted
## The arithmetic of the progress map (docs/UX.md 3.6). Nothing is built per level: a level's
## position comes from its number, and a tap becomes a level number by arithmetic, so the map
## is as cheap at level 1000 as at level 10.

const SPACING := 88.0
const LANE_STEP := 96.0
## Locked levels shown past the next one.
const LOCKED_AHEAD := 4
## Levels built around the view above and below (the pool is about 20).
const MARGIN_LEVELS := 3
## The trail fades out over this much of the body above the last locked node.
const FADE := 64.0

const CLEARED := 0
const NEXT := 1
const LOCKED := 2


## The state of level n when the highest cleared level is `highest`.
static func state_of(n: int, highest: int) -> int:
	if n <= highest:
		return CLEARED
	return NEXT if n == highest + 1 else LOCKED


## The last level on the map: the next level plus four locked ones.
static func top_level(highest: int) -> int:
	return highest + 1 + LOCKED_AHEAD


## Every 5th level from 10 on is a hard level and gets the bigger badge.
static func is_hard(n: int) -> bool:
	return n >= 10 and n % 5 == 0


## The badge size (touch target) for a level.
static func node_size(n: int, highest: int) -> float:
	match state_of(n, highest):
		NEXT:
			return 80.0
		CLEARED:
			return 72.0 if is_hard(n) else 64.0
		_:
			return 64.0


## The lane x of level n: a zigzag over three lanes around `center`, [c, c+s, c, c-s].
static func lane_x(n: int, center: float, step: float = LANE_STEP) -> float:
	return center + [0.0, step, 0.0, -step][(n - 1) % 4]


## Total height of the scrolled content: half a body of empty back board below level 1 (so
## even level 1 can be centered), 88 per level, and the fade above the last locked node.
static func content_height(highest: int, body_h: float) -> float:
	return FADE + (top_level(highest) - 1) * SPACING + 40.0 + body_h / 2.0 + 44.0


## The y of level n's center in content coordinates (0 is the top of the content).
static func node_y(n: int, highest: int, body_h: float) -> float:
	return content_height(highest, body_h) - body_h / 2.0 - 44.0 - (n - 1) * SPACING


## The scroll offset that puts level n's center at the middle of the body, clamped.
static func scroll_for(n: int, highest: int, body_h: float) -> float:
	var s := node_y(n, highest, body_h) - body_h / 2.0
	return clampf(s, 0.0, maxf(0.0, content_height(highest, body_h) - body_h))


## The levels that need a node view: those in view plus MARGIN_LEVELS each side, kept within
## 1 and the top level. Returns [first, last].
static func visible_levels(scroll: float, body_h: float, highest: int) -> Vector2i:
	var top := top_level(highest)
	var y_top := scroll
	var y_bottom := scroll + body_h
	# node_y falls by SPACING per level: the larger y is the lower level.
	var n_low := 1 + int(floor((node_y(1, highest, body_h) - y_bottom) / SPACING)) - MARGIN_LEVELS
	var n_high := 1 + int(ceil((node_y(1, highest, body_h) - y_top) / SPACING)) + MARGIN_LEVELS
	return Vector2i(clampi(n_low, 1, top), clampi(n_high, 1, top))


## The level whose badge holds the point (x across the column, y in content coordinates), or
## 0 if the point is on no badge. Turns a tap into a level number by arithmetic.
static func level_at(x: float, y: float, center: float, highest: int, body_h: float, step: float = LANE_STEP) -> int:
	var n := 1 + int(round((node_y(1, highest, body_h) - y) / SPACING))
	if n < 1 or n > top_level(highest):
		return 0
	var half := maxf(24.0, node_size(n, highest) / 2.0)
	if absf(x - lane_x(n, center, step)) <= half and absf(y - node_y(n, highest, body_h)) <= half:
		return n
	return 0


## The screen reader label of a node (UX 3.6).
static func label_of(n: int, highest: int, stars: int) -> String:
	match state_of(n, highest):
		CLEARED:
			return "Level %d, %d %s" % [n, stars, "star" if stars == 1 else "stars"]
		NEXT:
			return "Level %d, next" % n
		_:
			return "Level %d, locked" % n
