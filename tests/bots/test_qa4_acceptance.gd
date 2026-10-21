# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Items of the GDD 12 acceptance list that no other suite pins down, checked against the GDD's
## own text where it has numbers (docs/GDD.md is read, never written). The generated-level
## items run in the script tests/bots/acceptance.gd (100 levels per tier takes minutes).

var _gdd := ""


func _text() -> String:
	if _gdd == "":
		_gdd = FileAccess.get_file_as_string("res://docs/GDD.md")
	return _gdd


func test_acc_21_tier_of_level_matches_gdd_6_3_for_9_to_30_and_151_to_160() -> void:
	# The GDD lists levels 9 to 30 in full: "9: 3, 10: 4, 11: 1, ...".
	var line := ""
	for l: String in _text().split("\n"):
		if l.begins_with("Levels 9 to 30 in full:") or l.begins_with("1, 1, 2, 3, 4"):
			line = l
	var at := _text().find("Levels 9 to 30 in full:")
	check(at >= 0, "the GDD has the 9 to 30 list")
	var chunk := _text().substr(at, 400).replace("\n", " ")
	var listed := {}
	for part: String in chunk.trim_prefix("Levels 9 to 30 in full:").split(".")[0].split(","):
		var pair := part.strip_edges().split(":")
		if pair.size() == 2 and pair[0].strip_edges().is_valid_int():
			listed[pair[0].strip_edges().to_int()] = pair[1].strip_edges().to_int()
	check_eq(listed.size(), 22, "22 levels listed in the GDD")
	for n: int in range(9, 31):
		check_eq(Tuning.tier_for_level(n), listed.get(n, -1), "tier of level %d" % n)
	# 151 on: the tiers cycle 6, 7, 8, 9, 10 for good.
	var cycle: Array[int] = [6, 7, 8, 9, 10]
	for n: int in range(151, 161):
		check_eq(Tuning.tier_for_level(n), cycle[(n - 151) % 5], "tier of level %d" % n)
	for n: int in [200, 501, 1000, 99999]:
		check_eq(Tuning.tier_for_level(n), cycle[(n - 151) % 5], "tier of level %d (the cycle goes on)" % n)


func test_acc_30_every_hard_level_is_followed_by_a_breather() -> void:
	for n: int in range(10, 400, 5):
		var hard := Tuning.tier_for_level(n)
		var after := Tuning.tier_for_level(n + 1)
		check(after <= hard - 3 or after == 1, "level %d (tier %d) is followed by level %d (tier %d)" % [n, hard, n + 1, after])
		check(hard >= Tuning.tier_for_level(n - 1), "level %d is at least as hard as the level before it" % n)


func test_acc_15a_the_tiers_in_tuning_json_match_the_gdd_6_1_table() -> void:
	var rows := 0
	for l: String in _text().split("\n"):
		var cells := l.split("|")
		if cells.size() != 10 or not cells[1].strip_edges().is_valid_int() or not cells[2].strip_edges() in ["Easy", "Medium", "Hard", "Expert"]:
			continue
		var t := cells[1].strip_edges().to_int()
		if t < 1 or t > 10:
			continue
		rows += 1
		var spec := Tuning.tier(t)
		check_eq(cells[2].strip_edges().to_lower(), spec.group, "tier %d group" % t)
		check_eq(_range(cells[3]), spec.screws, "tier %d screws" % t)
		check_eq(_range(cells[4]), spec.colors, "tier %d colors" % t)
		check_eq(_range(cells[5]), spec.layers, "tier %d layers" % t)
		check_eq(_range(cells[6]), spec.tray_uses, "tier %d fewest tray uses" % t)
		var novice := cells[7].strip_edges()
		var want := {"must win": Tuning.NOVICE_WIN, "either": Tuning.NOVICE_EITHER, "must lose": Tuning.NOVICE_LOSE}
		check_eq(want.get(novice, -1), spec.novice, "tier %d novice" % t)
		check_eq(_range(cells[8].replace(" percent", "")), spec.covered_pct, "tier %d covered at start" % t)
	check_eq(rows, 10, "ten tier rows were found in the GDD")


## "9 to 12" or "3" as a Vector2i.
func _range(text: String) -> Vector2i:
	var parts := text.strip_edges().split(" to ")
	var low := parts[0].strip_edges().to_int()
	return Vector2i(low, parts[parts.size() - 1].strip_edges().to_int())


func test_acc_22a_suits_tier_gives_the_gdd_10_column_and_tiers_7_to_10_have_8_boards() -> void:
	var listed := {}
	var in_table := false
	for l: String in _text().split("\n"):
		if l.begins_with("| Blueprint | Picture | Kind |"):
			in_table = true
			continue
		if in_table:
			if not l.begins_with("|"):
				break
			var cells := l.split("|")
			if cells.size() < 11 or cells[1].strip_edges() == "-" or cells[1].strip_edges().begins_with("-"):
				continue
			var tiers: Array[int] = []
			for t: String in cells[9].split(","):
				tiers.append(t.strip_edges().to_int())
			listed[cells[1].strip_edges()] = tiers
	check_eq(listed.size(), LevelCatalog.blueprints.size(), "the GDD lists every blueprint")
	var per_tier := PackedInt32Array()
	per_tier.resize(11)
	for bp: LevelData in LevelCatalog.blueprints:
		check(listed.has(bp.id), "%s is in the GDD table" % bp.id)
		var got: Array[int] = []
		for t: int in range(1, 11):
			if LevelCatalog.suits_tier(bp, Tuning.tier(t)):
				got.append(t)
				per_tier[t] += 1
		check_eq(got, listed.get(bp.id, []), "%s suits tiers" % bp.id)
	for t: int in range(7, 11):
		check(per_tier[t] >= 8, "tier %d has %d suitable blueprints (at least 8)" % [t, per_tier[t]])


func test_acc_14_every_blueprint_id_is_its_file_name_and_there_are_43() -> void:
	var names := LevelCatalog.json_files("res://data/blueprints")
	check_eq(names.size(), 43, "43 blueprint files")
	for file: String in names:
		var level := LevelData.from_json(LevelCatalog.read_text(file))
		check(level != null, "%s parses" % file.get_file())
		if level != null:
			check_eq(level.id, file.get_file().get_basename(), "%s: the id is the file name" % file)
			check_eq(level.kind, LevelData.BLUEPRINT, "%s is a blueprint" % file)
	var tutorials := LevelCatalog.json_files("res://data/tutorial")
	check_eq(tutorials.size(), 8, "8 tutorial files")
	for n: int in range(1, 9):
		check_eq(tutorials[n - 1].get_file(), "tutorial-%d.json" % n, "tutorial file %d" % n)


func test_acc_19_prices_arrive_levels_and_free_counts() -> void:
	check_eq(int(Tuning.helpers["undo"]["price"]), 4, "Undo costs 4")
	check_eq(int(Tuning.helpers["extra_slot"]["price"]), 6, "Extra slot costs 6")
	check_eq(int(Tuning.helpers["screwdriver"]["price"]), 8, "Screwdriver costs 8")
	check_eq([int(Tuning.helpers["undo"]["first_level"]), int(Tuning.helpers["extra_slot"]["first_level"]), int(Tuning.helpers["screwdriver"]["first_level"])], [8, 15, 25], "arrival levels")
	for h: String in ["undo", "extra_slot", "screwdriver"]:
		check_eq(int(Tuning.helpers[h]["free"]), 2, "%s arrives with 2 free" % h)


func test_acc_26_the_daily_is_tier_6_the_same_twice_and_slack_1() -> void:
	for date: int in [20261021, 20261231, 20270101, 20280229, 20260101]:
		var a := LevelCatalog.get_level(LevelData.DAILY, date, "")
		var b := LevelCatalog.get_level(LevelData.DAILY, date, "")
		check_eq(var_to_str(a.level.to_dict()), var_to_str(b.level.to_dict()), "%d: the same level both times" % date)
		check_eq(a.level.tier, 6, "%d: tier 6" % date)
		check_eq(a.level.group, "medium", "%d: Medium" % date)
		check_eq(a.level.number, date, "%d: numbered by the date" % date)
		check_eq(a.level.tray_par, a.solve.fewest_tray_uses + 1, "%d: slack +1" % date)
		check_eq(a.level.generator_version, Generator.GENERATOR_VERSION, "%d: version" % date)
	var one := LevelCatalog.get_level(LevelData.DAILY, 20261021, "")
	var two := LevelCatalog.get_level(LevelData.DAILY, 20261022, "")
	check(var_to_str(one.level.to_dict()) != var_to_str(two.level.to_dict()), "another date is another puzzle")


func test_acc_27_relaxed_tiers_follow_the_band_and_it_has_no_stars() -> void:
	for band: String in Tuning.BANDS:
		var span: Vector2i = Tuning.relaxed[band]
		for i: int in range(1, 16):
			var g := LevelCatalog.get_level(LevelData.RELAXED, i, band)
			check(g.level.tier >= span.x and g.level.tier <= span.y, "%s %d: tier %d in %s" % [band, i, g.level.tier, span])
			check_eq(g.level.kind, LevelData.RELAXED, "%s %d: kind" % [band, i])
			check_eq(Stars.award(g.level, true, 1, 0, PackedStringArray()), Vector3i.ZERO, "%s %d: no stars" % [band, i])


func test_acc_18_a_replay_adds_only_the_difference() -> void:
	var save: Node = (load("res://src/save/save.gd") as GDScript).new()
	save.dir = "%sqa4_s5/" % tree.root.get_node("Save").get("dir")
	DirAccess.make_dir_recursive_absolute(save.dir)
	add_node(save)
	save.load_all()
	var level := LevelCatalog.get_level(LevelData.NUMBERED, 9, "").level
	check_eq(save.record_win(level, 40000, Vector3i(1, 0, 0)), 1, "first clear: 1 star")
	check_eq(save.record_win(level, 40000, Vector3i(1, 1, 1)), 2, "a better replay adds 2")
	check_eq(save.record_win(level, 40000, Vector3i(1, 0, 0)), 0, "a worse replay adds nothing")
	check_eq(save.record_win(level, 40000, Vector3i(1, 1, 0)), 0, "an equal total adds nothing")
	check_eq(save.star_bank(), 3, "the bank is 3")
	check_eq(int(save.level_record(9)["stars"]), 3, "the record keeps the best")
	check_eq(save.stars_earned(), 3, "stars earned counts the same")
	check(save.spend_stars(2), "spend 2")
	check_eq(save.star_bank(), 1, "bank 1")
	check_eq(save.stars_earned(), 3, "spending never lowers stars earned")
	check_eq(save.record_win(level, 1000, Vector3i(1, 1, 1)), 0, "after spending, a replay does not refund")
	check(not save.spend_stars(5), "cannot overspend")
	check_eq(save.star_bank(), 1, "and nothing was taken")


func test_acc_16_17_fast_at_exactly_par_and_clean_at_par_with_no_helpers() -> void:
	var level := LevelCatalog.get_level(LevelData.NUMBERED, 14, "").level
	var par := level.par_time_s * 1000
	check_eq(Stars.award(level, true, par, level.tray_par, PackedStringArray()), Vector3i(1, 1, 1), "exactly par and exactly tray par")
	check_eq(Stars.award(level, true, par + 1000, level.tray_par, PackedStringArray()), Vector3i(1, 0, 1), "par plus one second misses Fast")
	check_eq(Stars.award(level, true, par, level.tray_par + 1, PackedStringArray()), Vector3i(1, 1, 0), "one tray use over par misses Clean")
	for helper: String in ["undo", "extra_slot", "screwdriver"]:
		check_eq(Stars.award(level, true, par, 0, PackedStringArray([helper])), Vector3i(1, 1, 0), "%s costs Clean, not Fast" % helper)
