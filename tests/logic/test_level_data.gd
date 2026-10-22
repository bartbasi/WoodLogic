# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Reading and writing levels (GDD 9.1 and 9.3, docs/ARCHITECTURE.md 3.1, 3.2 and 4.1).

const Kit := preload("res://tests/logic/kit.gd")

const TUTORIAL_EXAMPLE := """{
  "format": 1,
  "id": "tutorial-4",
  "name": "Covered screws",
  "kind": "tutorial",
  "board": [86, 90],
  "planks": [
    {"layer": 0, "shape": "bar", "path": [[43, 21], [43, 69]], "width": 12, "holes": [[43, 21], [43, 69]], "colors": [0, 1]},
    {"layer": 1, "shape": "bar", "path": [[19, 45], [67, 45]], "width": 10, "holes": [[19, 45], [43, 45], [67, 45]], "colors": [0, 0, 1]},
    {"layer": 0, "shape": "disc", "center": [67, 21], "radius": 6, "holes": [[67, 21]], "colors": [1]}
  ],
  "queue": [0, 1],
  "tray_par": 2,
  "par_time": 50,
  "line": "Covered screws are stuck. Free the plank on top.",
  "hint": [[1, 1], [0, 0], [0, 1]]
}"""


func test_9_1_blueprint_loads_without_colors() -> void:
	var level := Kit.blueprint("house")
	check(level != null, "house loads")
	check_eq(level.kind, LevelData.BLUEPRINT, "kind")
	check_eq(level.blueprint_kind, "silhouette", "blueprint kind")
	check_eq(level.id, "house", "id")
	check_eq(level.planks.size(), 6, "planks")
	check_eq(level.screw_count(), 15, "screws")
	check(not level.has_colors(), "a bare blueprint has no colors")
	check_eq(level.layer_count(), 2, "layers")
	check_eq(level.planks[2].shape, PlankData.DISC, "plank 2 is a disc")
	check_eq(level.planks[2].radius, 7, "its radius")
	check_eq(level.planks[5].width, 10, "the chimney's width")


func test_4_1_screw_ids_are_in_file_order() -> void:
	var level := Kit.blueprint("house")
	var expected := 0
	for p: int in level.planks.size():
		var plank := level.planks[p]
		for h: int in plank.hole_count():
			check_eq(plank.screws[h], expected, "plank %d hole %d" % [p, h])
			check_eq(level.screw_center(expected), plank.holes[h], "screw %d center" % expected)
			check_eq(level.screw_plank(expected), p, "screw %d plank" % expected)
			expected += 1
	check_eq(Kit.screw_at(level, 14, 40), 6, "the wall's first hole is screw 6")


func test_9_3_tutorial_format_loads() -> void:
	var errors := PackedStringArray()
	var level := LevelData.parse(TUTORIAL_EXAMPLE, errors)
	check(level != null, "loads: %s" % "; ".join(errors))
	if level == null:
		return
	check_eq(level.kind, LevelData.TUTORIAL, "kind")
	check_eq(level.number, 4, "number from the id")
	check_eq(level.screw_colors, PackedInt32Array([0, 1, 0, 0, 1, 1]), "colors in screw order")
	check_eq(level.queue, PackedInt32Array([0, 1]), "queue")
	check_eq(level.tray_par, 2, "tray par")
	check_eq(level.par_time_s, 50, "par time")
	check_eq(level.line, "Covered screws are stuck. Free the plank on top.", "line")
	check_eq(level.hint, PackedInt32Array([3, 0, 1]), "hint as screw ids")
	check_eq(level.tray_size, 5, "tray size from Tuning")
	check(level.has_colors(), "playable")


func test_4_1_to_dict_reads_back_the_same() -> void:
	var errors := PackedStringArray()
	var level := LevelData.parse(TUTORIAL_EXAMPLE, errors)
	var again := LevelData.parse(JSON.stringify(level.to_dict()), errors)
	check(again != null, "reads back: %s" % "; ".join(errors))
	if again != null:
		check_eq(again.to_dict(), level.to_dict(), "the same level")
	var house := Kit.blueprint("house")
	var house_again := LevelData.parse(JSON.stringify(house.to_dict()), errors)
	check(house_again != null and house_again.to_dict() == house.to_dict(), "a blueprint reads back the same")
	check_eq(JSON.parse_string(JSON.stringify(house.to_dict()["planks"])), JSON.parse_string(Kit.blueprint_text("house"))["planks"], "and matches the file")
	var colored := Kit.random_colors(house, 4, RandomNumberGenerator.new())
	var stored := colored.to_dict()
	stored["kind"] = "numbered"
	stored["id"] = "numbered-42"
	stored["number"] = 42
	stored["tier"] = 4
	stored["group"] = "medium"
	stored["blueprint"] = "house"
	stored["generator"] = 1
	stored["par_time"] = 60
	var back := LevelData.parse(JSON.stringify(stored), errors)
	check(back != null, "a stored numbered level reads: %s" % "; ".join(errors))
	if back != null:
		check_eq(back.kind, LevelData.NUMBERED, "kind")
		check_eq(back.number, 42, "number")
		check_eq(back.tier, 4, "tier")
		check_eq(back.blueprint_id, "house", "blueprint")
		check_eq(back.generator_version, 1, "generator version")
		check_eq(back.screw_colors, colored.screw_colors, "colors")


func test_4_1_outline_is_the_logic_polygon() -> void:
	var level := Kit.blueprint("rings")
	var ring := level.planks[0]
	var outline := ring.outline()
	check_eq(outline.size(), ring.outline_xy.size() / 2, "one point per vertex")
	check_eq(outline[0], Vector2(ring.outline_xy[0], ring.outline_xy[1]), "the same first vertex")
	check(not ring.inner_outline().is_empty(), "a ring has an inner outline")
	check(level.planks[4].inner_outline().is_empty(), "a disc has none")


func test_r3_colors_must_match_the_queue() -> void:
	var house := Kit.blueprint("house")
	var errors := PackedStringArray()
	var colors := PackedInt32Array()
	for s: int in 15:
		colors.append(s % 5)
	var ok := house.with_colors(colors, PackedInt32Array([0, 1, 2, 3, 4]), errors)
	check(ok != null, "five colors of three screws with five boxes: %s" % "; ".join(errors))
	var bad := house.with_colors(colors, PackedInt32Array([0, 1, 2, 3, 3]), errors)
	check(bad == null, "a queue that does not match is rejected")
	check(errors.size() > 0 and errors[-1].begins_with("R3"), "with an R3 message")


func test_3_bad_data_is_rejected_with_a_reason() -> void:
	var house: Dictionary = JSON.parse_string(Kit.blueprint_text("house"))
	var cases := {
		"not json": "{",
		"not an object": "[1, 2]",
	}
	for label: String in cases:
		var errors := PackedStringArray()
		check(LevelData.parse(cases[label], errors) == null and not errors.is_empty(), label)
	var edits := {
		"no kind": func(d: Dictionary) -> void: d.erase("kind"),
		"unknown field": func(d: Dictionary) -> void: d["extra"] = 1,
		"bad id": func(d: Dictionary) -> void: d["id"] = "House",
		"no planks": func(d: Dictionary) -> void: d["planks"] = [],
		"fractional coordinate": func(d: Dictionary) -> void: d["planks"][0]["holes"][0] = [43.5, 18],
		"unknown shape": func(d: Dictionary) -> void: d["planks"][0]["shape"] = "star",
		"layer 5": func(d: Dictionary) -> void: d["planks"][0]["layer"] = 5,
		"bar without width": func(d: Dictionary) -> void: d["planks"][5].erase("width"),
		"disc with points": func(d: Dictionary) -> void: d["planks"][2]["points"] = [[1, 1], [2, 2], [3, 1]],
		"ring inner too big": func(d: Dictionary) -> void: d["planks"][2] = {"layer": 0, "shape": "ring", "center": [20, 58], "radius": 7, "inner": 7, "holes": [[20, 58]]},
		"colors on a blueprint": func(d: Dictionary) -> void: d["planks"][2]["colors"] = [0],
		"string number": func(d: Dictionary) -> void: d["planks"][2]["radius"] = "7",
		"repeated path point": func(d: Dictionary) -> void: d["planks"][5]["path"] = [[68, 6], [68, 6], [68, 20]],
	}
	for label: String in edits:
		var d: Dictionary = house.duplicate(true)
		(edits[label] as Callable).call(d)
		var errors := PackedStringArray()
		var level := LevelData.parse(JSON.stringify(d), errors)
		check(level == null and not errors.is_empty(), "rejected: " + label)
	var tutorial: Dictionary = JSON.parse_string(TUTORIAL_EXAMPLE)
	var tutorial_edits := {
		"missing colors": func(d: Dictionary) -> void: d["planks"][0].erase("colors"),
		"too few colors": func(d: Dictionary) -> void: d["planks"][0]["colors"] = [0],
		"color 8": func(d: Dictionary) -> void: d["planks"][2]["colors"] = [8],
		"queue does not match (R3)": func(d: Dictionary) -> void: d["queue"] = [0, 0],
		"hint off the plank": func(d: Dictionary) -> void: d["hint"] = [[2, 1]],
		"bad tutorial id": func(d: Dictionary) -> void: d["id"] = "tutorial-x",
		"par time 0": func(d: Dictionary) -> void: d["par_time"] = 0,
	}
	for label: String in tutorial_edits:
		var d: Dictionary = tutorial.duplicate(true)
		(tutorial_edits[label] as Callable).call(d)
		var errors := PackedStringArray()
		check(LevelData.parse(JSON.stringify(d), errors) == null and not errors.is_empty(), "rejected: " + label)


func test_6_8_a_level_carries_its_own_tray() -> void:
	var colored := Kit.random_colors(Kit.blueprint("house"), 4, RandomNumberGenerator.new())
	var errors := PackedStringArray()
	var play := {"kind": LevelData.NUMBERED, "number": 30, "tier": 5, "group": "medium", "generator": 6, "par_time": 60, "blueprint": "house", "id": "numbered-30", "tray": 3}
	var three := colored.with_colors(colored.screw_colors, colored.queue, errors, play)
	check(three != null and three.tray_size == 3, "with_colors sets the tray: %s" % "; ".join(errors))
	var d := three.to_dict()
	check_eq(d["tray"], 3, "to_dict writes it")
	var back := LevelData.parse(JSON.stringify(d), errors)
	check(back != null and back.tray_size == 3, "from_dict reads it back")
	if back != null:
		check_eq(back.fingerprint(), three.fingerprint(), "with the same fingerprint")
	play["tray"] = 5
	var five := colored.with_colors(colored.screw_colors, colored.queue, errors, play)
	check(five.fingerprint() != three.fingerprint(), "the tray is part of the fingerprint")
	# A level saved by generator 5 or older has no tray: it reads with the tuning's 5.
	d.erase("tray")
	var old := LevelData.parse(JSON.stringify(d), errors)
	check(old != null and old.tray_size == Tuning.tray_size and old.tray_size == 5, "a level without a tray reads with 5 slots")
	for bad: Variant in [0, 8, 2.5, "3"]:
		d["tray"] = bad
		var errs := PackedStringArray()
		check(LevelData.parse(JSON.stringify(d), errs) == null and not errs.is_empty(), "rejected: tray %s" % str(bad))
	check_eq(Kit.tutorial(1).tray_size, 5, "a tutorial level has 5 slots")
	check_eq(Kit.blueprint("house").to_dict().has("tray"), false, "a bare blueprint has no tray in its file")


func test_6_8_with_colors_takes_a_tray_of_1_to_7() -> void:
	var colored := Kit.random_colors(Kit.blueprint("house"), 4, RandomNumberGenerator.new())
	for slots: int in [1, 7]:
		var errors := PackedStringArray()
		check(colored.with_colors(colored.screw_colors, colored.queue, errors, {"tray": slots}) != null, "a tray of %d" % slots)
	for slots: int in [0, 8]:
		var errors := PackedStringArray()
		check(colored.with_colors(colored.screw_colors, colored.queue, errors, {"tray": slots}) == null and not errors.is_empty(), "no tray of %d" % slots)
