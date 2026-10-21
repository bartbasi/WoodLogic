# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The level scene with its animations on: taps during animation, a double tap, retry in the
## middle of a level, the win and the loss, and the swing, fall and tray going where the logic
## says. Run under --fixed-fps 60, so a frame is 1/60 of a second of game time.

const Kit := preload("res://tests/level/kit.gd")
const Levels := preload("res://tests/level/levels.gd")

var _won: Array[LevelResult] = []
var _lost: Array[LevelData] = []
var _first := 0


func _on_won(result: LevelResult) -> void:
	_won.append(result)


func _on_lost(level: LevelData) -> void:
	_lost.append(level)


func _on_first() -> void:
	_first += 1


func _scene(level: LevelData, replay: bool = false) -> LevelScene:
	var scene := (load(Kit.SCENE) as PackedScene).instantiate() as LevelScene
	add_node(scene)
	scene.set_layout_size(Vector2(360.0, 640.0))
	scene.won.connect(_on_won)
	scene.lost.connect(_on_lost)
	scene.first_action.connect(_on_first)
	scene.play(level, replay)
	return scene


func test_a_tap_starts_animations_at_once_and_the_view_catches_up() -> void:
	var g := Kit.numbered(2)
	var scene := _scene(g.level)
	await Kit.settle(self, scene)
	check_eq(Kit.mismatches(scene).size(), 0, "after the level's start animation")
	var r := scene.tap_screw(g.solve.solution[0])
	check(r.ok, "the first tap is accepted")
	check(scene.debug_snapshot()["busy"] > 0, "a motion starts in the same call as the tap")
	check_eq(scene.debug_snapshot()["places"][g.solve.solution[0]], "box", "the model's answer is applied at once")
	# Mid flight the screw is neither at its hole nor at its well.
	await frames(25)
	var snap := scene.debug_snapshot()
	var at: Vector2 = snap["screws"][g.solve.solution[0]]
	var home := g.level.screw_center(g.solve.solution[0])
	var well: Vector2 = (snap["well_centers"][0] as Array)[0]
	check(at.distance_to(home) > 1.0 and at.distance_to(well) > 1.0, "the screw is in the air after 25 frames: %s" % str(at))
	var frames_used := await Kit.settle(self, scene)
	check(frames_used < 120, "the motion ends in under two seconds, took %d frames" % frames_used)
	check_eq(Kit.mismatches(scene).size(), 0, "after the flight ends: %s" % "; ".join(Kit.mismatches(scene)))
	var landed: Vector2 = scene.debug_snapshot()["screws"][g.solve.solution[0]]
	check(landed.distance_to(well) < Kit.TOLERANCE, "the screw lands in its well")


func test_taps_during_animation_are_all_accepted_in_order() -> void:
	var g := Kit.numbered(Kit.level_of_tier(4, 9))
	var scene := _scene(g.level)
	await Kit.settle(self, scene)
	# A quick player: one tap every 3 frames (50 ms), far faster than a flight lasts.
	for i: int in 8:
		var r := scene.tap_screw(g.solve.solution[i])
		check(r.ok, "tap %d is accepted while the earlier ones are still flying" % i)
		check_eq(Kit.mismatches(scene, false).size(), 0, "after tap %d: %s" % [i, "; ".join(Kit.mismatches(scene, false))])
		await frames(3)
	check(scene.debug_snapshot()["busy"] > 0, "earlier flights are still going")
	await Kit.settle(self, scene)
	check_eq(Kit.mismatches(scene).size(), 0, "once everything has landed: %s" % "; ".join(Kit.mismatches(scene)))
	# The model decided every destination at its tap, not when the earlier flights landed.
	var reference := PlayState.start(g.level)
	for i: int in 8:
		reference.tap(g.solve.solution[i])
	check_eq(scene.get_state().snapshot(), reference.snapshot(), "the same state as playing the taps with no view")


func test_a_double_tap_is_ignored() -> void:
	var g := Kit.numbered(2)
	var scene := _scene(g.level)
	await Kit.settle(self, scene)
	var s: int = g.solve.solution[0]
	check(scene.tap_screw(s).ok, "the first tap works")
	var again := scene.tap_screw(s)
	check(not again.ok, "the second tap on the same screw does nothing")
	check_eq(again.reason, TapResult.GONE, "because the screw is gone")
	check_eq(scene.get_state().tray_uses(), 0, "and nothing was spent")
	await Kit.settle(self, scene)
	check_eq(Kit.mismatches(scene).size(), 0, "the view agrees: %s" % "; ".join(Kit.mismatches(scene)))


func test_the_clock_starts_at_the_first_accepted_tap_only() -> void:
	var g := Kit.numbered(4)
	var scene := _scene(g.level)
	await Kit.settle(self, scene)
	await frames(10)
	check_eq(_first, 0, "no first_action before a tap")
	check(not scene.debug_snapshot()["clock_running"], "the clock waits")
	# A tap on a covered screw is not an action.
	var covered := -1
	for s: int in g.level.screw_count():
		if not scene.get_state().is_free(s):
			covered = s
			break
	check(covered >= 0, "tutorial 4 has a covered screw")
	var r := scene.tap_screw(covered)
	check_eq(r.reason, TapResult.COVERED, "a covered tap is answered as covered")
	check_eq(_first, 0, "a covered tap does not start the clock")
	scene.tap_screw(g.solve.solution[0])
	check_eq(_first, 1, "first_action fires at the first accepted tap")
	check(scene.debug_snapshot()["clock_running"], "the clock runs")
	scene.tap_screw(g.solve.solution[1])
	check_eq(_first, 1, "first_action fires once")


func test_pause_stops_the_clock_and_covers_the_board() -> void:
	var g := Kit.numbered(5)
	var scene := _scene(g.level)
	await Kit.settle(self, scene)
	scene.tap_screw(g.solve.solution[0])
	await frames(5)
	scene.pause()
	var before: int = scene.debug_snapshot()["elapsed_ms"]
	check(not scene.debug_snapshot()["clock_running"], "the clock stops in pause")
	OS.delay_msec(80)
	await frames(3)
	check_eq(scene.debug_snapshot()["elapsed_ms"], before, "no time passes while paused")
	check(scene.debug_snapshot()["board_covered"], "the board is covered while paused")
	var r := scene.tap_screw(g.solve.solution[1])
	check(not r.ok, "a tap is ignored while paused")
	scene.hold_clock(true)
	scene.resume()
	check(not scene.debug_snapshot()["clock_running"], "a held clock stays stopped after resume")
	scene.hold_clock(false)
	check(scene.debug_snapshot()["clock_running"], "and runs again when released")
	check(scene.tap_screw(g.solve.solution[1]).ok, "taps work again after resume")


func test_the_win_comes_after_the_last_screw_lands_and_fires_once() -> void:
	var g := Kit.numbered(1)
	var scene := _scene(g.level, true)
	await Kit.settle(self, scene)
	for s: int in g.solve.solution:
		scene.tap_screw(s)
		await frames(4)
	check_eq(_won.size(), 0, "not yet: the last screw is still flying")
	await frames(10)
	check_eq(_won.size(), 0, "still flying 10 frames later")
	await Kit.settle(self, scene)
	await frames(40)
	check_eq(_won.size(), 1, "won fires once")
	var r := _won[0]
	check(r.level == g.level, "the result names the level")
	check(r.replay, "the replay flag is passed through")
	check_eq(r.tray_uses, 0, "no tray use on level 1")
	check_eq(r.helpers_used.size(), 0, "no helpers")
	check_eq(r.stars.x, 1, "the cleared star")
	check(r.elapsed_ms >= 0 and r.elapsed_ms < 5000, "elapsed %d ms is the time to the winning tap" % r.elapsed_ms)
	check_eq(_lost.size(), 0, "never lost")
	await frames(60)
	check_eq(_won.size(), 1, "and still only once a second later")
	# A tap after the win does nothing.
	check(not scene.tap_screw(0).ok, "taps after the win do nothing")


func test_a_loss_is_reported_once_after_the_last_move_settles() -> void:
	var found := Kit.find_loss()
	check(not found.is_empty(), "a losing game was found among the stored levels")
	if found.is_empty():
		return
	var level: LevelData = found["level"]
	var taps: PackedInt32Array = found["taps"]
	var scene := _scene(level)
	await Kit.settle(self, scene)
	var refused := 0
	for s: int in taps:
		var r := scene.tap_screw(s)
		if r.reason == TapResult.REFUSED:
			refused += 1
		await frames(2)
	check_eq(scene.get_state().status(), PlayState.LOST, "the model says lost")
	check_eq(_lost.size(), 0, "the loss is shown only after the last move settles")
	await Kit.settle(self, scene)
	await frames(30)
	check_eq(_lost.size(), 1, "lost fires once")
	check(_lost[0] == level, "with the level")
	check_eq(_won.size(), 0, "no win")
	await frames(60)
	check_eq(_lost.size(), 1, "still once later")
	check_eq(Kit.mismatches(scene).size(), 0, "the view agrees at the end: %s" % "; ".join(Kit.mismatches(scene)))
	check(not scene.tap_screw(0).ok, "taps after the loss do nothing")


func test_retry_in_the_middle_starts_over_and_drops_old_results() -> void:
	var g := Kit.numbered(3)
	var scene := _scene(g.level)
	await Kit.settle(self, scene)
	for i: int in 2:
		scene.tap_screw(g.solve.solution[i])
		await frames(2)
	scene.retry()
	check_eq(scene.get_state().tray_uses(), 0, "a fresh attempt")
	check_eq(Kit.mismatches(scene).size(), 0, "the board is back as it was: %s" % "; ".join(Kit.mismatches(scene)))
	check_eq(scene.debug_snapshot()["tray"], PackedInt32Array([-1, -1, -1, -1, -1]), "an empty tray")
	check(not scene.debug_snapshot()["clock_running"], "the clock starts again at the first action")
	# Win, then retry before the win is announced: the old win never arrives.
	for s: int in g.solve.solution:
		scene.tap_screw(s)
	check_eq(scene.get_state().status(), PlayState.WON, "won in the model")
	scene.retry()
	await frames(120)
	check_eq(_won.size(), 0, "a retry cancels the win that was still to be announced")
	for s: int in g.solve.solution:
		scene.tap_screw(s)
	await Kit.settle(self, scene)
	await frames(40)
	check_eq(_won.size(), 1, "the new attempt wins once")


func test_a_swing_goes_to_the_logics_rest_angle_with_a_little_overshoot() -> void:
	var scene := _scene(Levels.swing_level())
	await Kit.settle(self, scene)
	var r := scene.tap_screw(Levels.SWING_SOLUTION[0])
	var swung := r.of_kind(LogicEvent.PLANK_SWUNG)
	check_eq(swung.size(), 1, "the first tap swings the bar")
	var plank: int = swung[0].plank
	var rest: float = swung[0].angle
	check_between(rest, 89.0, 91.0, "the logic's rest angle")
	var seen: Array[float] = []
	for i: int in 70:
		seen.append(scene.debug_snapshot()["plank_angles"][plank])
		await frames(1)
	check_between(seen[0], -0.01, 0.01, "the swing starts from the pose it was in")
	var crossed := false
	var overshoot := 0.0
	var peak_at := -1
	for i: int in seen.size():
		if seen[i] > rest:
			crossed = true
			if seen[i] - rest > overshoot:
				overshoot = seen[i] - rest
				peak_at = i
	check(crossed, "the swing overshoots the rest angle a little")
	check(overshoot > 5.0 and overshoot < 25.0, "by about 16 percent: %.1f degrees past %.1f" % [overshoot, rest])
	check(peak_at > 15 and peak_at < 35, "peaking around 0.4 s, at frame %d" % peak_at)
	check_between(seen[seen.size() - 1], rest - 0.01, rest + 0.01, "after 0.9 s it rests at the logic's angle")
	# The covered screw is covered from the moment of the tap, not partway through the swing.
	check(scene.debug_snapshot()["covered"][Levels.SWING_COVERED], "covered styling is applied at the tap")
	await Kit.settle(self, scene)
	check_eq(Kit.mismatches(scene).size(), 0, "the drawn plank is the logic's outline: %s" % "; ".join(Kit.mismatches(scene)))


func test_a_fallen_plank_leaves_the_board() -> void:
	var scene := _scene(Levels.swing_level())
	await Kit.settle(self, scene)
	scene.tap_screw(Levels.SWING_SOLUTION[0])
	await Kit.settle(self, scene)
	var r := scene.tap_screw(Levels.SWING_SOLUTION[1])
	var fall := r.of_kind(LogicEvent.PLANK_FELL)
	check_eq(fall.size(), 1, "the second tap drops the bar")
	var plank: int = fall[0].plank
	check(scene.debug_snapshot()["planks_shown"][plank], "it is still drawn at the tap, hanging a moment")
	var gone_after := -1
	for i: int in 90:
		await frames(1)
		if gone_after < 0 and not scene.debug_snapshot()["planks_shown"][plank]:
			gone_after = i
	check(gone_after >= 30 and gone_after < 60, "it is out of sight within 1 s, after %d frames" % gone_after)
	check_eq(Kit.mismatches(scene).size(), 0, "the board agrees: %s" % "; ".join(Kit.mismatches(scene)))
	check(not scene.debug_snapshot()["covered"][Levels.SWING_COVERED], "the disc screw is free again")


func test_the_tray_fills_and_jumps_into_boxes_in_tray_order() -> void:
	var scene := _scene(Levels.cascade_level())
	await Kit.settle(self, scene)
	var jumps := 0
	for s: int in Levels.CASCADE_SOLUTION:
		var r := scene.tap_screw(s)
		jumps += r.of_kind(LogicEvent.TRAY_TO_BOX).size()
		check_eq(scene.debug_snapshot()["tray"], scene.get_state().tray(), "the tray follows the logic")
		await frames(4)
	check_eq(jumps, 5, "five screws jumped from the tray")
	await Kit.settle(self, scene)
	check_eq(Kit.mismatches(scene).size(), 0, "the view agrees at the end: %s" % "; ".join(Kit.mismatches(scene)))
	await frames(40)
	check_eq(_won.size(), 1, "and the level is won once")


func test_a_resize_keeps_the_picture_in_step() -> void:
	var g := Kit.numbered(Kit.level_of_tier(5, 20))
	var scene := _scene(g.level)
	await Kit.settle(self, scene)
	for i: int in 5:
		scene.tap_screw(g.solve.solution[i])
	scene.set_layout_size(Vector2(840.0, 720.0))
	check(scene.get_layout().b > 1.0, "the board grows on a wide screen (b = %.2f)" % scene.get_layout().b)
	check_eq(Kit.mismatches(scene).size(), 0, "the picture still agrees after a resize: %s" % "; ".join(Kit.mismatches(scene)))
	scene.set_layout_size(Vector2(360.0, 800.0))
	check_eq(Kit.mismatches(scene).size(), 0, "and back: %s" % "; ".join(Kit.mismatches(scene)))


func test_the_tutorial_hand_glides_from_screw_to_screw_on_level_one() -> void:
	var g := Kit.numbered(1)
	var scene := _scene(g.level)
	await frames(15)
	check(not scene.debug_snapshot()["hint"], "no hand in the first quarter second")
	await frames(30)
	check(scene.debug_snapshot()["hint"], "the hand shows after half a second")
	var first: int = g.level.hint[0]
	var second: int = g.level.hint[1]
	check((scene.debug_snapshot()["hint_at"] as Vector2).distance_to(g.level.screw_center(first)) < 0.01, "pointing at the first screw of the hint")
	check_eq(scene.debug_snapshot()["line"], "", "level 1 has no line at first")
	scene.tap_screw(first)
	check((scene.debug_snapshot()["hint_at"] as Vector2).distance_to(g.level.screw_center(second)) < 0.01, "after a tap it points at the next screw")
	scene.tap_screw(second)
	scene.tap_screw(g.level.hint[2])
	await frames(5)
	check(not scene.debug_snapshot()["hint"], "and goes away when the level is won")


func test_level_one_says_tap_a_screw_after_eight_idle_seconds() -> void:
	var scene := _scene(Kit.numbered(1).level)
	await frames(60 * 7)
	check_eq(scene.debug_snapshot()["line"], "", "nothing yet at 7 seconds")
	await frames(60 * 2)
	check_eq(scene.debug_snapshot()["line"], "Tap a screw.", "the line appears after 8 seconds")


func test_on_other_tutorial_levels_the_hand_returns_after_eight_idle_seconds() -> void:
	var n := 2
	while Kit.numbered(n).level.hint.size() < 2:
		n += 1
	var g := Kit.numbered(n)
	var scene := _scene(g.level)
	await frames(45)
	check(scene.debug_snapshot()["hint"], "the hand shows at the start")
	var pointed := -1
	for s: int in g.level.hint:
		if scene.get_state().is_free(s):
			pointed = s
			break
	check((scene.debug_snapshot()["hint_at"] as Vector2).distance_to(g.level.screw_center(pointed)) < 0.01, "pointing at the first free screw of the hint")
	check(scene.tap_screw(pointed).ok, "the pointed screw can be tapped")
	check(not scene.debug_snapshot()["hint"], "a tap sends it away")
	await frames(60 * 7)
	check(not scene.debug_snapshot()["hint"], "still away at 7 seconds")
	await frames(60 * 2)
	check(scene.debug_snapshot()["hint"], "back after 8 idle seconds")
	var next := -1
	for s: int in g.level.hint:
		if scene.get_state().is_free(s):
			next = s
			break
	check(next >= 0, "a hinted screw is left")
	check((scene.debug_snapshot()["hint_at"] as Vector2).distance_to(g.level.screw_center(next)) < 0.01, "at the next screw to tap")


func test_quick_play_of_many_levels_with_animation_on() -> void:
	# A quick player taps every two frames; the picture must still end up in step with the
	# model and the level must be announced as won exactly once.
	var played := 0
	for tier: int in [2, 4, 5, 7, 9, 10]:
		var n := Kit.level_of_tier(tier, 12)
		var g := Kit.numbered(n)
		_won.clear()
		_lost.clear()
		var scene := _scene(g.level)
		for s: int in g.solve.solution:
			var r := scene.tap_screw(s)
			check(r.ok, "level %d: tap %d accepted" % [n, s])
			var problems := Kit.mismatches(scene, false)
			check(problems.is_empty(), "level %d: the view's beliefs after tap %d: %s" % [n, s, "; ".join(problems)])
			await frames(2)
		await Kit.settle(self, scene)
		await frames(60)
		var settled := Kit.mismatches(scene)
		check(settled.is_empty(), "level %d settled: %s" % [n, "; ".join(settled)])
		check_eq(_won.size(), 1, "level %d: won once" % n)
		check_eq(_lost.size(), 0, "level %d: never lost" % n)
		played += 1
		scene.queue_free()
		await frames(1)
	check_eq(played, 6, "levels played")


func test_random_quick_play_with_animation_on() -> void:
	# Random taps on free screws, refused ones included, every other frame.
	for tier: int in [6, 9]:
		var g: GeneratedLevel = LevelCatalog.fallback[tier - 1][0]
		var game := Kit.random_game(g.level, 5)
		_won.clear()
		_lost.clear()
		var scene := _scene(g.level)
		for s: int in game["taps"]:
			scene.tap_screw(s)
			var problems := Kit.mismatches(scene, false)
			check(problems.is_empty(), "tier %d: beliefs after tap %d: %s" % [tier, s, "; ".join(problems)])
			await frames(2)
		await Kit.settle(self, scene)
		await frames(60)
		var settled := Kit.mismatches(scene)
		check(settled.is_empty(), "tier %d settled: %s" % [tier, "; ".join(settled)])
		check_eq(_won.size() + _lost.size(), 1, "tier %d: exactly one ending announced" % tier)
		scene.queue_free()
		await frames(1)


func test_a_resize_while_paused_does_not_announce_the_loss_until_resume() -> void:
	var found := Kit.find_loss()
	check(not found.is_empty(), "a losing game exists")
	if found.is_empty():
		return
	var level: LevelData = found["level"]
	var scene := _scene(level)
	await Kit.settle(self, scene)
	for s: int in found["taps"]:
		scene.tap_screw(s)
		await frames(2)
	check_eq(scene.get_state().status(), PlayState.LOST, "the model says lost")
	check_eq(_lost.size(), 0, "the loss is still to be announced")
	scene.pause()
	scene.set_layout_size(Vector2(840.0, 720.0))
	await frames(120)
	check_eq(_lost.size(), 0, "nothing is announced under the pause screen, even after a resize")
	scene.resume()
	await Kit.settle(self, scene)
	await frames(60)
	check_eq(_lost.size(), 1, "lost fires once after resume")
	check_eq(Kit.mismatches(scene).size(), 0, "the picture agrees after the resize: %s" % "; ".join(Kit.mismatches(scene)))


func test_a_tap_on_a_plank_presses_it_in_and_back() -> void:
	var scene := Kit.make_scene(self, Levels.swing_level(), false)
	await Kit.settle(self, scene)
	var l := scene.get_layout()
	var planks: Array = scene.get("_planks")
	var view: Node2D = planks[0].view
	scene.tap_at(l.gu_to_scene(Vector2(43.0, 62.0)))
	await frames(4)
	check(view.scale.x < 0.999, "the plank is pressed in %.3f" % view.scale.x)
	await frames(20)
	check_eq(view.scale, Vector2.ONE, "and back to full size")
	check_eq(Kit.mismatches(scene).size(), 0, "the picture agrees: %s" % "; ".join(Kit.mismatches(scene)))


func test_a_plank_that_hangs_below_the_board_is_clipped_to_the_panel() -> void:
	var scene := Kit.make_scene(self, Levels.hang_level(), true)
	scene.tap_screw(Levels.HANG_SOLUTION[0])
	var l := scene.get_layout()
	var planks: Array = scene.get("_planks")
	var view: Node2D = planks[0].view
	# The logic's pose is unclipped and reaches far below the core.
	var outline: PackedVector2Array = scene.debug_snapshot()["planks"][0]
	var lowest := 0.0
	for p: Vector2 in outline:
		lowest = maxf(lowest, p.y)
	check(lowest > 120.0, "the hanging bar reaches y %.0f gu, below the 90 gu core" % lowest)
	check(l.gu_to_scene(Vector2(0.0, lowest)).y > l.panel.end.y, "and below the board panel on screen")
	check_eq(Kit.mismatches(scene).size(), 0, "the snapshot still reports the logic's pose")
	# Its drawing sits inside a clipping parent that is exactly the panel.
	var clip: Control = null
	var node: Node = view.get_parent()
	while node != null and node != scene:
		if node is Control and (node as Control).clip_contents:
			clip = node as Control
			break
		node = node.get_parent()
	check(clip != null, "a plank is drawn inside a clipping parent")
	if clip != null:
		check(Rect2(clip.position, clip.size).is_equal_approx(l.panel), "the clip is the board panel")
		check(clip.get_global_rect().end.y <= l.helper_bar.position.y + 0.01 or l.split, "so it ends above the helper bar")
	# Screws are not planks: they are outside the clip and drawn above every plank.
	var screws: Array = scene.get("_screws")
	var screw_view: Node2D = screws[0].view
	node = screw_view.get_parent()
	var screw_clipped := false
	while node != null and node != scene:
		if node is Control and (node as Control).clip_contents:
			screw_clipped = true
		node = node.get_parent()
	check(not screw_clipped, "a screw in flight is not clipped")
	# Draw order is tree order and no z_index is used: the screws' layer comes after the planks'.
	var content: Node = clip.get_parent()
	check(screw_view.get_parent().get_index() > clip.get_index(), "the screw layer is drawn after the plank layer")
	check_eq(screw_view.z_index, 0, "no z_index anywhere in the level")
	check_eq(view.z_index, 0, "not on a plank either")
	check(content != null, "the clip sits in the scene")


func test_draw_order_is_tree_order_back_layers_first_and_a_fall_goes_last() -> void:
	var scene := Kit.make_scene(self, Kit.numbered(Kit.level_of_tier(6, 30)).level, false)
	await Kit.settle(self, scene)
	var planks: Array = scene.get("_planks")
	var layers: Array[int] = []
	for child: Node in (planks[0].view as Node).get_parent().get_children():
		for slot: Variant in planks:
			if slot.view == child:
				layers.append(scene.get_level().planks[slot.plank].layer)
	var sorted := layers.duplicate()
	sorted.sort()
	sorted.reverse()
	check_eq(layers, sorted, "planks are added from the back layer to the front")
	var s := Levels.swing_level()
	var fall_scene := Kit.make_scene(self, s, false)
	await Kit.settle(self, fall_scene)
	fall_scene.tap_screw(Levels.SWING_SOLUTION[0])
	await Kit.settle(self, fall_scene)
	fall_scene.tap_screw(Levels.SWING_SOLUTION[1])
	await frames(10)
	var fall_planks: Array = fall_scene.get("_planks")
	var root: Node = (fall_planks[0].view as Node).get_parent()
	check_eq((fall_planks[0].view as Node).get_index(), root.get_child_count() - 1, "the falling plank is drawn last among the planks")
