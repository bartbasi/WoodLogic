# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## LevelCatalog and LevelPrefetcher (docs/ARCHITECTURE.md 3 and 4.4).

const TEMP_DIR := "user://test_catalog_files"


func test_load_all_reads_tuning_blueprints_tutorials_and_fallbacks() -> void:
	check(LevelCatalog.load_all(), "loads cleanly")
	check(LevelCatalog.is_loaded(), "loaded")
	check_eq(LevelCatalog.blueprints.size(), LevelCatalog.json_files(LevelCatalog.BLUEPRINT_DIR).size(), "every blueprint file")
	for i: int in range(1, LevelCatalog.blueprints.size()):
		check(LevelCatalog.blueprints[i - 1].id < LevelCatalog.blueprints[i].id, "blueprints sorted by id")
	check_eq(LevelCatalog.tutorials.size(), Tuning.tutorial_levels, "every tutorial level")
	check_eq(LevelCatalog.fallback.size(), Tuning.tiers.size(), "a fallback list per tier")
	check_eq(LevelCatalog.halves.size(), 2, "two halves")
	var both := LevelCatalog.halves[0].size() + LevelCatalog.halves[1].size()
	check_eq(both, LevelCatalog.blueprints.size(), "every blueprint in one half")
	check(LevelCatalog.load_all(), "a second call does nothing and is fine")


func test_suits_need_screws_layers_and_enough_cover_for_tray_tiers() -> void:
	LevelCatalog.load_all()
	var robot := LevelCatalog.blueprint_index("robot")
	var bricks := LevelCatalog.blueprint_index("bricks")
	check(not LevelCatalog.suits[3].has(robot), "robot (nothing covered) does not suit tier 4, which needs the tray")
	check(LevelCatalog.suits[4].has(bricks), "bricks (12 covered) suits tier 5")
	for t: int in Tuning.tiers.size():
		for h: int in 2:
			var count := 0
			for b: int in LevelCatalog.suits[t]:
				if LevelCatalog.halves[h].has(b):
					count += 1
			check(count >= 1, "tier %d has a blueprint in half %d" % [t + 1, h])


func test_get_level_serves_the_tutorial_for_levels_1_to_8() -> void:
	LevelCatalog.load_all()
	for n: int in range(1, Tuning.tutorial_levels + 1):
		var g := LevelCatalog.get_level(LevelData.NUMBERED, n, "")
		check(g.level == LevelCatalog.tutorials[n - 1], "level %d is tutorial %d" % [n, n])
		check(g.solve.solved and g.solve.complete and g.solve.fewest_tray_uses == 0, "tutorial %d solved" % n)
	var g9 := LevelCatalog.get_level(LevelData.NUMBERED, 9, "")
	check(g9.level.kind == LevelData.NUMBERED and g9.level.number == 9, "level 9 is generated")


func test_json_files_lists_json_and_remapped_json_sorted() -> void:
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	for name: String in ["b.json", "a.json.remap", "c.txt", "b.json.remap"]:
		var f := FileAccess.open(TEMP_DIR.path_join(name), FileAccess.WRITE)
		f.store_string("{}")
		f.close()
	check_eq(LevelCatalog.json_files(TEMP_DIR), PackedStringArray([TEMP_DIR.path_join("a.json"), TEMP_DIR.path_join("b.json")]), "a.json (from a.json.remap) and b.json, once each")
	check_eq(LevelCatalog.json_files("user://no_such_folder"), PackedStringArray(), "a missing folder lists nothing")
	for name: String in DirAccess.get_files_at(TEMP_DIR):
		DirAccess.remove_absolute(TEMP_DIR.path_join(name))
	DirAccess.remove_absolute(TEMP_DIR)


func test_fallback_file_reader_rejects_bad_files() -> void:
	var errors := PackedStringArray()
	check(LevelCatalog.parse_fallback("{", errors).is_empty() and not errors.is_empty(), "not JSON")
	errors.clear()
	check(LevelCatalog.parse_fallback('{"format": 1, "levels": [{"level": {}}]}', errors).is_empty() and not errors.is_empty(), "no solve")


func test_prefetcher_makes_levels_on_worker_threads() -> void:
	LevelCatalog.load_all()
	var p := LevelPrefetcher.new()
	var key := p.request(LevelData.NUMBERED, 12, "")
	check_eq(key, "numbered:12", "the key")
	check_eq(p.request(LevelData.NUMBERED, 12, ""), key, "asking again is the same request")
	var daily := p.request(LevelData.DAILY, 20261019, "")
	var relaxed := p.request(LevelData.RELAXED, 7, "easy")
	check_eq([daily, relaxed], ["daily:20261019", "relaxed:easy:7"], "keys")
	var started := Time.get_ticks_msec()
	while not (p.is_ready(key) and p.is_ready(daily) and p.is_ready(relaxed)) and Time.get_ticks_msec() - started < 60000:
		p.poll()
		await tree.process_frame
	check(p.is_ready(key) and p.is_ready(daily) and p.is_ready(relaxed), "all three ready")
	var g := p.take(key)
	check(g != null and g.level.fingerprint() == LevelCatalog.get_level(LevelData.NUMBERED, 12, "").level.fingerprint(), "the same level as asking directly")
	check(p.take(key) == null, "taken once")
	check(not p.is_ready(key), "no longer ready")
	p.shutdown()


func test_prefetcher_shutdown_waits_for_running_jobs() -> void:
	LevelCatalog.load_all()
	var p := LevelPrefetcher.new()
	var keys: Array[String] = []
	for n: int in range(20, 24):
		keys.append(p.request(LevelData.NUMBERED, n, ""))
	p.shutdown()
	for key: String in keys:
		check(p.is_ready(key) and not p.is_running(key), "%s is done after shutdown" % key)
