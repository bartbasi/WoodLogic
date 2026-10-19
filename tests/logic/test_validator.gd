# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The blueprint rules B1 to B13 (GDD 9.2, docs/ARCHITECTURE.md 2 and 3.1).

const Kit := preload("res://tests/logic/kit.gd")


func test_b1_to_b13_every_shipped_blueprint_passes() -> void:
	var files := _json_files(Kit.BLUEPRINT_DIR)
	check(files.size() >= 10, "at least the first ten blueprints (found %d)" % files.size())
	for file: String in files:
		var text := FileAccess.get_file_as_string(Kit.BLUEPRINT_DIR.path_join(file))
		var errors := BlueprintValidator.check_text(text)
		check(errors.is_empty(), "%s: %s" % [file, "; ".join(errors)])
		var level := LevelData.parse(text, errors)
		if level != null:
			check_eq(level.id, file.get_basename(), "%s: the id is the file name" % file)
			check_eq(level.kind, LevelData.BLUEPRINT, "%s: a blueprint" % file)


func test_every_tutorial_file_passes_the_rules_except_the_screw_minimum() -> void:
	var files := _json_files(Kit.TUTORIAL_DIR)
	for file: String in files:
		var text := FileAccess.get_file_as_string(Kit.TUTORIAL_DIR.path_join(file))
		var errors := BlueprintValidator.check_text(text, 3)
		check(errors.is_empty(), "%s: %s" % [file, "; ".join(errors)])
		var level := LevelData.parse(text, errors)
		if level != null:
			check_eq(level.id, file.get_basename(), "%s: the id is the file name" % file)
			check_eq(level.kind, LevelData.TUTORIAL, "%s: a tutorial level" % file)


func _json_files(dir: String) -> PackedStringArray:
	var files := PackedStringArray()
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".json"):
			files.append(file)
	files.sort()
	return files


func test_b12_shipped_blueprints_free_at_start_match_the_gdd() -> void:
	# GDD section 10's table.
	var expected := {"house": 12, "sailboat": 13, "windmill": 10, "fish": 11, "tree": 15, "bridge": 14, "lighthouse": 16, "rings": 17, "bricks": 12, "lattice": 24}
	for id: String in Kit.BLUEPRINTS:
		var level := Kit.blueprint(id)
		var all := (1 << level.screw_count()) - 1
		var covered := level.geometry.covered(all)
		var free_count := 0
		for s: int in level.screw_count():
			if covered & (1 << s) == 0:
				free_count += 1
		check_eq(free_count, expected[id], "%s free at start" % id)


func test_b1_format_and_board() -> void:
	_expect("B1", func(d: Dictionary) -> void: d["format"] = 2)
	_expect("B1", func(d: Dictionary) -> void: d["board"] = [86, 91])


func test_b2_plank_count_and_layers() -> void:
	_expect("B2", func(d: Dictionary) -> void: d["planks"][5]["layer"] = 2; d["planks"][4]["layer"] = 2)
	var many := _small_board()
	for i: int in 16:
		many["planks"].append({"layer": 0, "shape": "disc", "center": [8 + 12 * (i % 6), 60 + 12 * int(i / 6.0)], "radius": 5, "holes": [[8 + 12 * (i % 6), 60 + 12 * int(i / 6.0)]]})
	_expect_on("B2", many, 3)


func test_b3_screw_count_and_holes() -> void:
	_expect("B3", func(d: Dictionary) -> void: d["planks"][2]["holes"] = [])
	_expect("B3", func(d: Dictionary) -> void: d["planks"].remove_at(2))
	var level := _parse(_small_board())
	check(BlueprintValidator.check(level).has("B3: 3 screws (a multiple of 3 from 9 to 36)"), "too few screws for a level")
	check(BlueprintValidator.check(level, 3).is_empty(), "but fine for a tutorial")


func test_b4_holes_inside_the_screw_area() -> void:
	_expect("B4", func(d: Dictionary) -> void: d["planks"][4]["holes"][0] = [5, 40]; d["planks"][4]["points"] = [[1, 34], [78, 34], [78, 88], [1, 88]])


func test_b5_holes_at_least_12_apart() -> void:
	_expect("B5", func(d: Dictionary) -> void: d["planks"][4]["holes"][2] = [14, 51])


func test_b6_rim_and_width() -> void:
	_expect("B6", func(d: Dictionary) -> void: d["planks"][4]["holes"][2] = [12, 82])
	_expect("B6", func(d: Dictionary) -> void: d["planks"][5]["width"] = 8)
	var ring := _small_board()
	ring["planks"][0] = {"layer": 0, "shape": "ring", "center": [43, 40], "radius": 15, "inner": 7, "holes": [[43, 29]]}
	_expect_on("B6", ring, 3)


func test_b7_planks_inside_the_board() -> void:
	_expect("B7", func(d: Dictionary) -> void: d["planks"][2]["radius"] = 21)


func test_b8_same_layer_planks_do_not_overlap() -> void:
	_expect("B8", func(d: Dictionary) -> void: d["planks"][2]["center"] = [31, 64]; d["planks"][2]["holes"] = [[31, 64]])
	# A disc inside a ring's hole, in the same layer, does not overlap it.
	var board := _small_board()
	board["planks"] = [
		{"layer": 0, "shape": "ring", "center": [43, 45], "radius": 20, "inner": 9, "holes": [[43, 30], [28, 45]]},
		{"layer": 0, "shape": "disc", "center": [43, 45], "radius": 6, "holes": [[43, 45]]},
	]
	var level := _parse(board)
	check(not "; ".join(BlueprintValidator.check(level, 3)).contains("B8"), "a disc in a ring's hole is no overlap")


func test_b9_one_hole_plank_hangs_at_rest() -> void:
	_expect("B9", func(d: Dictionary) -> void: d["planks"][1]["holes"] = [[43, 82]])


func test_b10_covering_is_plain_at_the_start() -> void:
	# The door top moves to 2 above the wall screw at (43, 61): d = 2, a near miss.
	_expect("B10", func(d: Dictionary) -> void: d["planks"][1]["points"] = [[35, 55], [51, 55], [51, 88], [35, 88]]; d["planks"][4]["holes"][4] = [43, 50])


func test_b11_swings_never_land_near_the_threshold() -> void:
	# Hanging on (22, 20) the bar turns +90 and its edge lands exactly 3.5 from (31, 40).
	var board := _small_board()
	board["planks"] = [
		{"layer": 0, "shape": "bar", "path": [[20, 20], [60, 20]], "width": 11, "holes": [[22, 20], [58, 20]]},
		{"layer": 1, "shape": "disc", "center": [31, 40], "radius": 6, "holes": [[31, 40]]},
	]
	_expect_on("B11", board, 3)


func test_b13_rejects_a_centroid_half_a_unit_from_a_pivot() -> void:
	var board := _small_board()
	board["planks"] = [
		{"layer": 0, "shape": "poly", "points": [[20, 30], [67, 30], [67, 71], [20, 71]], "holes": [[43, 50], [26, 36], [60, 64]]},
	]
	var errors := BlueprintValidator.check(_parse(board), 3)
	check(errors.size() == 1 and errors[0].begins_with("B13"), "only B13 (r = 0.71): %s" % "; ".join(errors))
	# A one hole plank too: a triangle whose centroid is two thirds of a unit below its hole
	# (the fish fin before Phase 2).
	var fin := _small_board()
	fin["planks"].append({"layer": 0, "shape": "poly", "points": [[30, 62], [45, 82], [60, 62]], "holes": [[45, 68]]})
	fin["planks"].append({"layer": 0, "shape": "disc", "center": [70, 50], "radius": 6, "holes": [[70, 50]]})
	fin["planks"].append({"layer": 0, "shape": "disc", "center": [16, 50], "radius": 6, "holes": [[16, 50]]})
	var fin_errors := BlueprintValidator.check(_parse(fin), 3)
	check(fin_errors.size() == 1 and fin_errors[0].begins_with("B13"), "one hole plank, r = 0.67: %s" % "; ".join(fin_errors))


func test_b12_free_screws_and_depth() -> void:
	var wide := _small_board()
	wide["planks"] = []
	for x: int in [8, 20, 32, 44, 56, 68]:
		wide["planks"].append({"layer": 0, "shape": "bar", "path": [[x, 8], [x, 56]], "width": 10, "holes": [[x, 8], [x, 20], [x, 32], [x, 44], [x, 56]]})
	_expect_on("B12", wide, 3)
	var deep := _small_board()
	deep["planks"] = []
	for layer: int in 4:
		deep["planks"].append({"layer": layer, "shape": "bar", "path": [[10 + 16 * layer, 20], [10 + 16 * layer, 80]], "width": 10, "holes": [[10 + 16 * layer, 20], [10 + 16 * layer, 80]]})
	deep["planks"].append({"layer": 4, "shape": "poly", "points": [[2, 40], [84, 40], [84, 60], [2, 60]], "holes": [[43, 50]]})
	# Every front bar crosses the back plate's screw.
	for layer: int in 4:
		deep["planks"][layer]["path"] = [[20 + 12 * layer, 20], [43, 50], [66 - 12 * layer, 84]]
		deep["planks"][layer]["holes"] = [[20 + 12 * layer, 20], [66 - 12 * layer, 84]]
	var errors := BlueprintValidator.check(_parse(deep), 3)
	check("; ".join(errors).contains("B12: screw 8 (plank 4 hole 0) is under 4 planks"), "a screw under 4 planks: %s" % "; ".join(errors))


func test_outlines_must_not_cross_themselves() -> void:
	_expect("crosses itself", func(d: Dictionary) -> void: d["planks"][1]["points"] = [[35, 58], [51, 88], [51, 58], [35, 88]])


## Checks that a change to the house breaks the named rule.
func _expect(rule: String, change: Callable) -> void:
	var d: Dictionary = JSON.parse_string(Kit.blueprint_text("house"))
	change.call(d)
	_expect_on(rule, d, 9)


func _expect_on(rule: String, d: Dictionary, min_screws: int) -> void:
	var errors := BlueprintValidator.check_text(JSON.stringify(d), min_screws)
	check("; ".join(errors).contains(rule), "%s expected, got: %s" % [rule, "; ".join(errors)])


func _small_board() -> Dictionary:
	return {
		"format": 1, "id": "small", "name": "Small", "kind": "pattern", "board": [86, 90],
		"planks": [
			{"layer": 0, "shape": "bar", "path": [[20, 20], [60, 20]], "width": 10, "holes": [[22, 20], [40, 20], [58, 20]]},
		],
	}


func _parse(d: Dictionary) -> LevelData:
	var errors := PackedStringArray()
	var level := LevelData.parse(JSON.stringify(d), errors)
	check(level != null, "parses: %s" % "; ".join(errors))
	return level
