# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends RefCounted
## Helpers the logic suites share: loading the shipped blueprints and tutorial levels,
## coloring blueprints, and small hand-built levels.

const BLUEPRINT_DIR := "res://data/blueprints"
const TUTORIAL_DIR := "res://data/tutorial"
const BLUEPRINTS: Array[String] = ["bricks", "bridge", "fish", "house", "lattice", "lighthouse", "rings", "sailboat", "tree", "windmill"]


static func blueprint_text(id: String) -> String:
	return FileAccess.get_file_as_string(BLUEPRINT_DIR.path_join(id + ".json"))


## A shipped blueprint, uncolored.
static func blueprint(id: String) -> LevelData:
	var errors := PackedStringArray()
	var level := LevelData.parse(blueprint_text(id), errors)
	if level == null:
		push_error("blueprint %s: %s" % [id, "; ".join(errors)])
	return level


## A blueprint with these colors (one per screw, in screw id order) and this queue.
static func colored(level: LevelData, colors: Array, queue: Array) -> LevelData:
	var errors := PackedStringArray()
	var out := level.with_colors(PackedInt32Array(colors), PackedInt32Array(queue), errors)
	if out == null:
		push_error("coloring: " + "; ".join(errors))
	return out


## Random valid colors: color_count colors, each a multiple of 3 screws, and a shuffled queue
## with no color twice in a row (GDD G6).
static func random_colors(level: LevelData, color_count: int, rng: RandomNumberGenerator) -> LevelData:
	var n := level.screw_count()
	@warning_ignore("integer_division")
	var boxes := n / 3
	var per := PackedInt32Array()
	per.resize(color_count)
	per.fill(1)
	for _i: int in boxes - color_count:
		per[rng.randi_range(0, color_count - 1)] += 1
	var colors: Array = []
	var queue: Array = []
	for c: int in color_count:
		for _j: int in per[c]:
			queue.append(c)
			for _k: int in 3:
				colors.append(c)
	_shuffle(colors, rng)
	for _try: int in 50:
		_shuffle(queue, rng)
		var ok := true
		for i: int in range(1, queue.size()):
			if queue[i] == queue[i - 1]:
				ok = false
		if ok:
			break
	return colored(level, colors, queue)


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i: int in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = list[i]
		list[i] = list[j]
		list[j] = t


## A level from plank dictionaries (GDD 9.3 planks with colors).
static func level(planks: Array, queue: Array, id: String = "test", kind: String = "tutorial-1") -> LevelData:
	var d := {
		"format": 1, "id": kind, "name": id, "kind": "tutorial", "board": [86, 90],
		"planks": planks, "queue": queue, "tray_par": 0, "par_time": 60, "line": "", "hint": [],
	}
	var errors := PackedStringArray()
	var out := LevelData.from_dict(d, errors)
	if out == null:
		push_error("level %s: %s" % [id, "; ".join(errors)])
	return out


static func bar(layer: int, path: Array, width: int, holes: Array, colors: Array) -> Dictionary:
	return {"layer": layer, "shape": "bar", "path": path, "width": width, "holes": holes, "colors": colors}


static func disc(layer: int, center: Array, radius: int, colors: Array) -> Dictionary:
	return {"layer": layer, "shape": "disc", "center": center, "radius": radius, "holes": [center], "colors": colors}


static func rect(layer: int, x0: int, y0: int, x1: int, y1: int, holes: Array, colors: Array) -> Dictionary:
	return {"layer": layer, "shape": "poly", "points": [[x0, y0], [x1, y0], [x1, y1], [x0, y1]], "holes": holes, "colors": colors}


## Tutorial level n from data/tutorial/tutorial-<n>.json.
static func tutorial(n: int) -> LevelData:
	var errors := PackedStringArray()
	var text := FileAccess.get_file_as_string(TUTORIAL_DIR.path_join("tutorial-%d.json" % n))
	var out := LevelData.parse(text, errors)
	if out == null:
		push_error("tutorial %d: %s" % [n, "; ".join(errors)])
	return out


## The screw id at a hole position, or -1.
static func screw_at(level: LevelData, x: int, y: int) -> int:
	for s: int in level.screw_count():
		if level.screw_center(s) == Vector2(x, y):
			return s
	return -1


## Plays taps in order; returns false (and says why in errors) at the first that fails.
static func play(state: PlayState, taps: Array, errors: PackedStringArray) -> bool:
	for s: Variant in taps:
		var r := state.tap(int(s))
		if not r.ok:
			errors.append("tap %d failed: %s" % [int(s), TapResult.REASON_NAMES[r.reason]])
			return false
	return true
