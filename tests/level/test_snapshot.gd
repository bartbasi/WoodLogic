# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## ARCHITECTURE 5.3: plays levels tap by tap with every animation jumping to its end, and checks
## after every tap that what the scene shows is what PlayState says (where every screw is
## drawn, each plank's drawn outline, what the boxes, the previews and the tray hold).

const Kit := preload("res://tests/level/kit.gd")
const Levels := preload("res://tests/level/levels.gd")

var _won: Array[LevelResult] = []
var _lost: Array[LevelData] = []


func _on_won(result: LevelResult) -> void:
	_won.append(result)


func _on_lost(level: LevelData) -> void:
	_lost.append(level)


func _instant_scene(level: LevelData) -> LevelScene:
	_won.clear()
	_lost.clear()
	var scene := Kit.make_scene(self, level, true)
	scene.won.connect(_on_won)
	scene.lost.connect(_on_lost)
	return scene


## Plays taps, comparing the scene with the model at the start and after every tap. Returns the
## results, one per tap. Stops at the first failure.
func _play(scene: LevelScene, taps: PackedInt32Array, what: String) -> Array[TapResult]:
	var results: Array[TapResult] = []
	var problems := Kit.mismatches(scene)
	check(problems.is_empty(), "%s at the start: %s" % [what, "; ".join(problems)])
	for i: int in taps.size():
		var r := scene.tap_screw(taps[i])
		results.append(r)
		problems = Kit.mismatches(scene)
		check(problems.is_empty(), "%s after tap %d (screw %d, %s): %s" % [what, i, taps[i], r.describe(), "; ".join(problems)])
		if not problems.is_empty():
			break
	return results


func test_a_swing_that_covers_a_screw() -> void:
	var level := Levels.swing_level()
	var scene := _instant_scene(level)
	var results := _play(scene, PackedInt32Array(Levels.SWING_SOLUTION), "swing level")
	check_eq(results.size(), 3, "all three taps played")
	var first := results[0]
	check(first.ok and first.kinds().has(LogicEvent.PLANK_SWUNG), "the first tap swings the bar")
	check(first.kinds().has(LogicEvent.COVER_CHANGED), "and covers a screw")
	check_between(first.of_kind(LogicEvent.PLANK_SWUNG)[0].angle, 89.0, 91.0, "the logic's rest angle is a quarter turn")
	check(results[1].kinds().has(LogicEvent.PLANK_FELL), "the second tap drops the bar")
	check_eq(scene.get_state().status(), PlayState.WON, "won")
	check_eq(_won.size(), 1, "won fires once")
	check_eq(_lost.size(), 0, "lost never fires")
	# After the swing, in the middle of the level, the covered screw is drawn covered.
	scene.retry()
	scene.tap_screw(1)
	check(scene.debug_snapshot()["covered"][Levels.SWING_COVERED], "the disc screw is drawn as covered at the tap")
	check(not scene.tap_screw(Levels.SWING_COVERED).ok, "and cannot be tapped")


func test_tray_jumps_and_a_cascade() -> void:
	var level := Levels.cascade_level()
	var scene := _instant_scene(level)
	var results := _play(scene, PackedInt32Array(Levels.CASCADE_SOLUTION), "cascade level")
	check_eq(results.size(), 12, "all twelve taps played")
	var cascades := 0
	var jumps := 0
	for r: TapResult in results:
		jumps += r.of_kind(LogicEvent.TRAY_TO_BOX).size()
		if r.of_kind(LogicEvent.BOX_CLOSED).size() > 1:
			cascades += 1
	check_eq(cascades, 1, "one tap closed two boxes")
	check_eq(jumps, 5, "five tray screws jumped into boxes")
	check_eq(scene.get_state().status(), PlayState.WON, "won")
	check_eq(_won.size(), 1, "won fires once")


func test_a_refused_tap_and_a_covered_tap_change_nothing() -> void:
	var level := Levels.cascade_level()
	var scene := _instant_scene(level)
	_play(scene, PackedInt32Array([0, 1, 2, 3, 4]), "filling the tray")
	check_eq(scene.get_state().tray().count(-1), 0, "the tray is full")
	var before := scene.debug_snapshot()
	var r := scene.tap_screw(5)
	check_eq(r.reason, TapResult.REFUSED, "a screw with nowhere to go is refused")
	check(not scene.debug_snapshot()["toast"].is_empty(), "and the toast says why")
	check_eq(scene.debug_snapshot()["tray"], before["tray"], "the tray is unchanged")
	check_eq(scene.get_state().tray_uses(), 5, "a refused tap is not a tray use")
	check_eq(Kit.mismatches(scene).size(), 0, "the picture is unchanged: %s" % "; ".join(Kit.mismatches(scene)))
	# A covered screw: the swing level after the first tap.
	var swing := _instant_scene(Levels.swing_level())
	swing.tap_screw(1)
	var snap := swing.debug_snapshot()
	var covered := swing.tap_screw(Levels.SWING_COVERED)
	check_eq(covered.reason, TapResult.COVERED, "a covered tap is answered as covered")
	check_eq(swing.debug_snapshot()["screws"], snap["screws"], "nothing moved")
	check_eq(Kit.mismatches(swing).size(), 0, "the picture is unchanged by a covered tap")


func test_a_loss() -> void:
	var found := Kit.find_loss()
	check(not found.is_empty(), "a losing game exists among the stored levels")
	if found.is_empty():
		return
	var level: LevelData = found["level"]
	var scene := _instant_scene(level)
	var taps: PackedInt32Array = found["taps"]
	var results := _play(scene, taps, "a losing game")
	var refused := 0
	for r: TapResult in results:
		if r.reason == TapResult.REFUSED:
			refused += 1
	check_eq(scene.get_state().status(), PlayState.LOST, "the model says lost")
	check_eq(_lost.size(), 1, "lost fires once")
	check(_lost.size() == 1 and _lost[0] == level, "with the level")
	check_eq(_won.size(), 0, "won never fires")
	check(scene.is_over(), "the scene is over")
	check(not scene.tap_screw(taps[0]).ok, "taps after the loss do nothing")
	check_eq(_lost.size(), 1, "and lost does not fire again")


func test_tutorial_levels_one_to_eight() -> void:
	for n: int in range(1, 9):
		var g := Kit.numbered(n)
		var scene := _instant_scene(g.level)
		_play(scene, g.solve.solution, "tutorial %d" % n)
		check_eq(scene.get_state().status(), PlayState.WON, "tutorial %d is won" % n)
		check_eq(_won.size(), 1, "tutorial %d fires won once" % n)
		scene.queue_free()
		await frames(1)


func test_generated_levels_across_all_tiers() -> void:
	var played := 0
	var tiers_seen := PackedInt32Array()
	var wins := 0
	# Two levels of every tier, found by the app's own tier schedule.
	for tier: int in range(1, 11):
		var first := Kit.level_of_tier(tier, 9)
		var second := Kit.level_of_tier(tier, first + 1)
		for n: int in [first, second]:
			var g := Kit.numbered(n)
			check(g.solve.solved, "level %d has a solution" % n)
			var scene := _instant_scene(g.level)
			_play(scene, g.solve.solution, "level %d (tier %d)" % [n, tier])
			wins += _won.size()
			played += 1
			if not tiers_seen.has(g.level.tier):
				tiers_seen.append(g.level.tier)
			scene.queue_free()
			await frames(1)
	check(played >= 20, "played %d levels, expected at least 20" % played)
	check_eq(wins, played, "every level was won once")
	check_eq(tiers_seen.size(), 10, "tiers covered")


func test_random_play_keeps_the_picture_in_step() -> void:
	# Random taps on free screws (refused ones included) on hard levels, until won or lost.
	var checked := 0
	for tier: int in [5, 8, 10]:
		for g: GeneratedLevel in LevelCatalog.fallback[tier - 1].slice(0, 2):
			for seed_value: int in 3:
				var game := Kit.random_game(g.level, seed_value)
				var scene := _instant_scene(g.level)
				_play(scene, game["taps"], "random game %d on %s" % [seed_value, g.level.id])
				check_eq(scene.get_state().status(), game["status"], "the same ending as the model alone")
				check_eq(_won.size() + _lost.size(), 1, "exactly one ending announced")
				checked += 1
				scene.queue_free()
				await frames(1)
	check(checked >= 12, "played %d random games" % checked)


func test_the_checker_notices_a_picture_that_is_wrong() -> void:
	# A check that cannot fail is worth nothing: break the picture three ways and see it caught.
	var scene := _instant_scene(Levels.swing_level())
	scene.tap_screw(1)
	check_eq(Kit.mismatches(scene).size(), 0, "agrees to begin with")
	var screws: Array = scene.get("_screws")
	var planks: Array = scene.get("_planks")
	var screw_view: Node2D = screws[0].view
	screw_view.position += Vector2(30.0, 0.0)
	check(not Kit.mismatches(scene).is_empty(), "a screw drawn in the wrong place is caught")
	screw_view.position -= Vector2(30.0, 0.0)
	var plank_view: Node2D = planks[0].view
	plank_view.rotation += 0.4
	check(not Kit.mismatches(scene).is_empty(), "a plank turned to the wrong angle is caught")
	plank_view.rotation -= 0.4
	check_eq(Kit.mismatches(scene).size(), 0, "and it agrees again once put back")
	scene.get_state().tap(0)
	check(not Kit.mismatches(scene).is_empty(), "a model change the view was not told about is caught")
