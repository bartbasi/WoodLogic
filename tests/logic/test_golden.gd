# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The golden test (docs/ARCHITECTURE.md 4.4 and 5.4): a fixed set of levels (numbered 9 to 40,
## a spread of 100 to 160 covering tiers 7 to 10 with a deep opening and fallbacks, three
## dailies, two Relaxed levels per band) must keep their fingerprints (blueprint, board,
## tier, tray par, par time, colors and queue; whole numbers only). A change that alters any of
## them fails here until GENERATOR_VERSION goes up and the file is written again with
## tools/levels/levels.gd -- --golden.

const PATH := "res://tests/logic/golden_levels.json"


func test_golden_levels_keep_their_fingerprints() -> void:
	check(LevelCatalog.load_all(), "the catalog loads")
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(d is Dictionary, "the golden file reads")
	if not d is Dictionary:
		return
	check_eq(int((d as Dictionary).get("generator_version", 0)), Generator.GENERATOR_VERSION, "the fingerprints were made with this GENERATOR_VERSION (write them again after raising it)")
	var levels: Array = (d as Dictionary).get("levels", [])
	var numbered := 0
	var late_tiers := {}
	var late_fallbacks := 0
	var late_deep := 0
	var dailies := 0
	var relaxed := 0
	var changed := 0
	for item: Variant in levels:
		var key: String = (item as Dictionary)["key"]
		var parts := key.split(":")
		var g: GeneratedLevel
		match parts[0]:
			"numbered":
				g = LevelCatalog.get_level(LevelData.NUMBERED, parts[1].to_int(), "")
				numbered += 1
			"daily":
				g = LevelCatalog.get_level(LevelData.DAILY, parts[1].to_int(), "")
				dailies += 1
			"relaxed":
				g = LevelCatalog.get_level(LevelData.RELAXED, parts[2].to_int(), parts[1])
				relaxed += 1
		var expected: String = (item as Dictionary)["fingerprint"]
		var got := g.level.fingerprint() if g != null and g.level != null else "none"
		if got != expected:
			changed += 1
			check(false, "%s changed: %s, was %s" % [key, got, expected])
			continue
		check_eq(g.fell_back, (item as Dictionary)["fell_back"] == true, "%s: fell back as before" % key)
		check_eq(g.pressure, int((item as Dictionary)["pressure"]), "%s: the same coloring pressure" % key)
		if parts[0] == "numbered" and parts[1].to_int() >= 100:
			late_tiers[g.level.tier] = true
			late_fallbacks += 1 if g.fell_back else 0
			late_deep += 1 if g.pressure >= 2 and g.pressure % 2 == 0 else 0
	check(numbered >= 32 + 5, "numbered 9 to 40 and a spread of 100 to 160 (%d numbered)" % numbered)
	for t: int in [7, 8, 9, 10]:
		check(late_tiers.has(t), "levels 100 to 160 include tier %d" % t)
	check(late_fallbacks >= 1, "levels 100 to 160 include a fallback")
	check(late_deep >= 1, "levels 100 to 160 include a deep opening")
	check_eq([dailies, relaxed], [3, 6], "three dailies, two Relaxed per band")
	check_eq(changed, 0, "levels that changed (raise GENERATOR_VERSION and renew the file if that was meant)")
