# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Phase 4 puts an Undo button on the level screen; the view already follows the logic's UNDONE
## event (docs/ARCHITECTURE.md 4.3). These tests take back every tap of a few levels through
## the scene's test hook and check the picture against the model after each one.

const Kit := preload("res://tests/level/kit.gd")
const Levels := preload("res://tests/level/levels.gd")


func _levels() -> Array:
	return [
		[Levels.swing_level(), PackedInt32Array(Levels.SWING_SOLUTION), "swing level"],
		[Levels.cascade_level(), PackedInt32Array(Levels.CASCADE_SOLUTION), "cascade level"],
		[Kit.numbered(7).level, Kit.numbered(7).solve.solution, "tutorial 7"],
		[Kit.numbered(Kit.level_of_tier(6, 30)).level, Kit.numbered(Kit.level_of_tier(6, 30)).solve.solution, "a tier 6 level"],
	]


func test_r26_undo_walks_back_to_the_start_and_the_picture_follows() -> void:
	for entry: Array in _levels():
		var level: LevelData = entry[0]
		var taps: PackedInt32Array = entry[1]
		var scene := Kit.make_scene(self, level, true)
		var steps: Array[Dictionary] = [scene.get_state().snapshot()]
		# Stop before the winning tap: a won level cannot be undone.
		for i: int in taps.size() - 1:
			scene.tap_screw(taps[i])
			steps.append(scene.get_state().snapshot())
		for i: int in range(taps.size() - 1, 0, -1):
			var r := scene.debug_undo()
			check(r.ok, "%s: undo %d works" % [entry[2], i])
			check_eq(scene.get_state().snapshot(), steps[i - 1], "%s: undo %d restores the logic" % [entry[2], i])
			var problems := Kit.mismatches(scene)
			check(problems.is_empty(), "%s: after undo %d: %s" % [entry[2], i, "; ".join(problems)])
			if not problems.is_empty():
				break
		check(not scene.debug_undo().ok, "%s: nothing left to undo at the start" % entry[2])
		# And forward again: the same taps give the same pictures.
		for i: int in taps.size():
			scene.tap_screw(taps[i])
		check_eq(scene.get_state().status(), PlayState.WON, "%s: played to the win after undoing everything" % entry[2])
		check_eq(Kit.mismatches(scene).size(), 0, "%s: and the picture agrees" % entry[2])
		scene.queue_free()
		await frames(1)


func test_an_undo_in_the_air_flies_the_screw_back_and_the_picture_settles() -> void:
	var scene := Kit.make_scene(self, Levels.cascade_level(), false)
	await Kit.settle(self, scene)
	for s: int in Levels.CASCADE_SOLUTION.slice(0, 8):
		scene.tap_screw(s)
		await frames(3)
	var r := scene.debug_undo()
	check(r.ok, "undo while earlier screws are still flying")
	check_eq(Kit.mismatches(scene, false).size(), 0, "the view's beliefs agree at once: %s" % "; ".join(Kit.mismatches(scene, false)))
	await Kit.settle(self, scene)
	check_eq(Kit.mismatches(scene).size(), 0, "and the picture agrees when everything has landed: %s" % "; ".join(Kit.mismatches(scene)))


func test_random_play_with_undos_keeps_the_picture_in_step_with_animation_on() -> void:
	# Random taps at random speeds with an Undo every few taps (and after every loss), on stored
	# levels. The view's beliefs agree after each action and the picture agrees once settled.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for tier: int in [3, 6, 9]:
		var g: GeneratedLevel = LevelCatalog.fallback[tier - 1][0]
		for seed_value: int in 2:
			var game := Kit.random_game(g.level, seed_value + 10 * tier)
			var scene := Kit.make_scene(self, g.level, false)
			var every := rng.randi_range(3, 8)
			var count := 0
			for s: int in game["taps"]:
				scene.tap_screw(s)
				count += 1
				var status := scene.get_state().status()
				if (count % every == 0 and status != PlayState.WON) or status == PlayState.LOST:
					scene.debug_undo()
				var problems := Kit.mismatches(scene, false)
				check(problems.is_empty(), "tier %d seed %d tap %d: %s" % [tier, seed_value, count, "; ".join(problems)])
				await frames(rng.randi_range(0, 4))
			await Kit.settle(self, scene)
			await frames(70)
			var settled := Kit.mismatches(scene)
			check(settled.is_empty(), "tier %d seed %d settled: %s" % [tier, seed_value, "; ".join(settled)])
			scene.queue_free()
			await frames(1)
