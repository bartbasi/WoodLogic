# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends RefCounted
## Small hand made levels for the level suites, so a test does not depend on which levels the
## generator or the data files happen to give. Built from the logic suites' own helpers.

const LogicKit := preload("res://tests/logic/kit.gd")


## GDD E3: a bar (layer 0) on two screws, and a disc far behind it. Taking the right screw makes
## the bar swing a quarter turn about the left one, and it then covers the disc's screw. Taking
## the left screw drops the bar and frees the disc. Three screws of one color, one box.
## Solution: SWING_SOLUTION.
static func swing_level() -> LevelData:
	return LogicKit.level([
		LogicKit.bar(0, [[28, 62], [58, 62]], 10, [[30, 62], [56, 62]], [0, 0]),
		LogicKit.disc(3, [29, 84], 6, [0]),
	], [0], "swing")


const SWING_SOLUTION: Array[int] = [1, 0, 2]
## The screw that the swing covers.
const SWING_COVERED := 2


## Twelve loose discs, four colors, queue [0, 1, 2, 3]. Screws 0 to 2 are color 2 and 3 to 5 are
## color 3 (no open box for either at the start, so they wait in the tray); 6 to 8 are color 0
## and 9 to 11 are color 1. CASCADE_SOLUTION fills the tray with 2, 2, 2, 3, 3, then closes box 0
## with color 0: color 2 arrives and takes the three tray screws, closes at once (a cascade),
## color 3 arrives and takes two more. Box 1 closes with color 1 (the queue is used up) and the
## last color 3 screw finishes box 0.
@warning_ignore("integer_division")
static func cascade_level() -> LevelData:
	var colors: Array[int] = [2, 2, 2, 3, 3, 3, 0, 0, 0, 1, 1, 1]
	var planks: Array = []
	for i: int in colors.size():
		var x := 10 + 18 * (i % 4)
		var y := 20 + 18 * (i / 4)
		planks.append(LogicKit.disc(0, [x, y], 5, [colors[i]]))
	return LogicKit.level(planks, [0, 1, 2, 3], "cascade")


const CASCADE_SOLUTION: Array[int] = [0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 5]


## A long bar (layer 0) on two screws near its ends, and a disc. Taking the top screw makes the
## bar turn half way round and hang from the lower one, down to about y 146, far below the core.
## Solution: HANG_SOLUTION.
static func hang_level() -> LevelData:
	return LogicKit.level([
		LogicKit.bar(0, [[40, 12], [40, 78]], 10, [[40, 14], [40, 76]], [0, 0]),
		LogicKit.disc(1, [12, 40], 6, [0]),
	], [0], "hang")


const HANG_SOLUTION: Array[int] = [0, 1, 2]
