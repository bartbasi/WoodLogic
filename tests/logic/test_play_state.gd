# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The rules of play, R4 to R31 and R37, the worked examples E1 to E7 on the shipped
## blueprints, the event order and which calls work when (GDD section 2, docs/ARCHITECTURE.md
## 4.2 and 4.3). R32 is in test_stars. R33, R35, R36 and R38 belong to the screens.

const Kit := preload("res://tests/logic/kit.gd")

# House screw ids (file order): roof 0 (43, 18), 1 (29, 34), 2 (57, 34); door 3 (43, 73);
# discs 4 (20, 58), 5 (66, 58); wall 6 (14, 40), 7 (72, 40), 8 (14, 82), 9 (72, 82),
# 10 (43, 61), 11 (28, 82), 12 (58, 82); chimney 13 (68, 8), 14 (68, 20).
# Covered at the start: 6 and 7 (under the roof) and 10 (under the door).

## E4 on the house: colors A B C D X = 0 1 2 3 4, queue D B X A C.
const E4_COLORS := [1, 2, 0, 3, 4, 2, 0, 0, 1, 1, 4, 3, 3, 2, 4]
const E4_QUEUE := [3, 1, 4, 0, 2]
## C, X, C to the tray; B, B; D, D, then the door's D closes D, X arrives and takes the tray
## X; X, X close X and A arrives empty. That is E4's setup.
const E4_SETUP := [13, 4, 5, 8, 9, 11, 12, 3, 14, 10]
const E4_REST := [0, 1, 2, 6, 7]
## E5 on the house: queue A B C D A; C, C, C to the tray, then B, B, B.
const E5_COLORS := [0, 0, 0, 0, 2, 2, 3, 3, 1, 1, 3, 1, 0, 2, 0]
const E5_QUEUE := [0, 1, 2, 3, 0]
## E7 on the house: queue B A A C D.
const E7_COLORS := [2, 2, 2, 1, 0, 0, 3, 3, 0, 0, 3, 1, 1, 0, 0]
const E7_QUEUE := [1, 0, 0, 2, 3]
## E6 on the bricks: A B D E F G H I = 0 .. 7, queue in that order. After an A into its box
## and D D E E F into the tray, the free screws are D E F F G G: lost.
const E6_COLORS := [2, 3, 4, 4, 5, 5, 0, 0, 1, 0, 1, 1, 5, 3, 6, 6, 4, 6, 2, 7, 7, 2, 7, 3]
const E6_QUEUE := [0, 1, 2, 3, 4, 5, 6, 7]
const E6_TAPS := [9, 18, 21, 23, 13, 16]


func _house(colors: Array, queue: Array) -> PlayState:
	return PlayState.start(Kit.colored(Kit.blueprint("house"), colors, queue))


func _bricks(colors: Array) -> PlayState:
	return PlayState.start(Kit.colored(Kit.blueprint("bricks"), colors, E6_QUEUE))


func _play(state: PlayState, taps: Array) -> bool:
	var errors := PackedStringArray()
	var ok := Kit.play(state, taps, errors)
	check(ok, "; ".join(errors))
	return ok


func _kinds(result: TapResult) -> Array:
	var out := []
	for e: LogicEvent in result.events:
		out.append(e.kind_name())
	return out


## E6's lost board.
func _lost_bricks() -> PlayState:
	var state := _bricks(E6_COLORS)
	_play(state, E6_TAPS)
	return state


# Start (R4, R5) and retry (R34).

func test_r4_boxes_come_from_the_queue_and_two_are_previewed() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	check_eq(state.open_box(0), Vector2i(3, 0), "position 0 gets queue entry 0")
	check_eq(state.open_box(1), Vector2i(1, 0), "position 1 gets entry 1")
	check_eq(state.preview(), PackedInt32Array([4, 0]), "the preview shows entries 2 and 3")
	var one := Kit.level([Kit.bar(0, [[20, 45], [66, 45]], 10, [[22, 45], [43, 45], [64, 45]], [0, 0, 0])], [0])
	var single := PlayState.start(one)
	check_eq(single.open_box(0), Vector2i(0, 0), "a one box queue fills position 0")
	check_eq(single.open_box(1), Vector2i(-1, 0), "and leaves position 1 empty")
	check_eq(single.preview(), PackedInt32Array(), "with nothing to preview")


func test_r5_start_has_an_empty_tray_and_authored_poses() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	check_eq(state.tray(), PackedInt32Array([-1, -1, -1, -1, -1]), "five empty tray slots")
	check_eq(state.tray_uses(), 0, "tray uses")
	check_eq(state.status(), PlayState.PLAYING, "status")
	check_eq(state.plank_state(0), PlayState.FIXED, "the roof is fixed")
	check_eq(state.plank_pose(0), Vector3.ZERO, "fixed planks report the authored pose")
	check_eq(state.plank_state(2), PlayState.HANGING, "a one screw disc hangs from the start")
	check_eq(state.plank_pose(2), Vector3(20, 58, 0), "at its authored pose")
	check_eq(state.plank_outline(0), state.level().planks[0].outline(), "the roof's outline as authored")
	check(not state.can_undo(), "nothing to undo")
	check_eq(state.helpers_used(), PackedStringArray(), "no helpers")


func test_r34_retry_starts_the_same_level_over() -> void:
	var level := Kit.colored(Kit.blueprint("house"), E4_COLORS, E4_QUEUE)
	var first := PlayState.start(level)
	var fresh := first.snapshot()
	_play(first, [13, 4, 5])
	first.use_extra_slot()
	var again := PlayState.start(level)
	check_eq(again.snapshot(), fresh, "the same start")
	check_eq(again.tray().size(), 5, "five slots again")
	check(not again.extra_slot_used(), "Extra slot reset")
	check_eq(again.tray_uses(), 0, "tray uses reset")


# Covering (R7 to R10, R17).

func test_e1_r7_house_wall_screw_under_the_roof_is_covered() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	var g := state.level().geometry
	var d := 99.0
	for i: int in g.fixed_near_screws[0].size():
		if g.fixed_near_screws[0][i] == 6:
			d = g.fixed_near_d[0][i]
	check_between(d, -2.001, -1.999, "d from (14, 40) to the roof")
	check(not state.is_free(6), "(14, 40) is covered")
	check_eq(state.cover_plank(6), 0, "by the roof")
	check(state.is_free(8), "(14, 82) is free")
	check_eq(state.cover_plank(8), -1, "nothing covers it")
	check(not state.is_free(10), "(43, 61) is under the door")
	check_eq(state.cover_plank(10), 1, "the door")


func test_r7_only_planks_in_front_cover() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	# The roof's screws sit on top of the wall (layer 1) and are free.
	for s: int in [0, 1, 2]:
		check(state.is_free(s), "roof screw %d is free" % s)


func test_r7_a_rings_hole_covers_nothing() -> void:
	var level := Kit.random_colors(Kit.blueprint("rings"), 3, RandomNumberGenerator.new())
	var state := PlayState.start(level)
	var center := Kit.screw_at(level, 29, 31)
	check(state.is_free(center), "the disc in the front ring's hole is free")


func test_r8_same_layer_planks_never_cover_each_other() -> void:
	# Two front bars; taking the top bar's right screw swings it down over the bottom bar's
	# left screw, in the same layer. (The tutorials never do this, so it is built here.)
	var level := Kit.level([
		Kit.bar(0, [[19, 30], [67, 30]], 10, [[19, 30], [67, 30]], [0, 0]),
		Kit.disc(1, [43, 30], 6, [1]),
		Kit.bar(0, [[19, 62], [67, 62]], 10, [[19, 62], [67, 62]], [1, 1]),
		Kit.disc(1, [43, 62], 6, [0]),
	], [0, 1])
	check(BlueprintValidator.check(level, 3).is_empty(), "the level keeps the blueprint rules")
	var state := PlayState.start(level)
	var r := state.tap(1)
	check(r.ok, "tap the top bar's right screw")
	var swung := r.of_kind(LogicEvent.PLANK_SWUNG)
	check(swung.size() == 1 and absf(swung[0].angle - 90.0) < 0.001, "it swings +90: %s" % r.describe())
	check(Geometry2D.is_point_in_polygon(Vector2(19, 62), state.plank_outline(0)), "it now lies over (19, 62)")
	check(state.is_free(3), "but (19, 62) on a plank in the same layer stays free")
	check(state.is_free(2), "and the disc behind it is uncovered")


func test_r9_e3_a_swing_covers_at_the_tap() -> void:
	var level := Kit.random_colors(Kit.blueprint("windmill"), 5, RandomNumberGenerator.new())
	var state := PlayState.start(level)
	var tower := Kit.screw_at(level, 29, 84)
	var right := Kit.screw_at(level, 56, 62)
	var left := Kit.screw_at(level, 30, 62)
	check(state.is_free(tower), "the tower screw starts free")
	# Force the gallery screw out with a Screwdriver so the colors do not matter.
	var r := state.use_screwdriver(right)
	check(r.ok, "take (56, 62)")
	var swung := r.of_kind(LogicEvent.PLANK_SWUNG)
	check(swung.size() == 1 and swung[0].screw == left and absf(swung[0].angle - 90.0) < 0.001, "the gallery swings +90 on (30, 62)")
	check(not state.is_free(tower), "the tower screw is covered at once")
	var changed := r.of_kind(LogicEvent.COVER_CHANGED)
	check(changed.size() == 1 and changed[0].screws.has(tower), "COVER_CHANGED names it")
	check_eq(state.cover_plank(tower), level.screw_plank(left), "the gallery covers it")
	check_eq(state.plank_pose(level.screw_plank(left)), Vector3(30, 62, 90), "the gallery's pose")


func test_r10_i1_random_play_always_has_a_free_screw_and_no_tray_match() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var taps := 0
	for id: String in Kit.BLUEPRINTS:
		for game: int in 6:
			var level := Kit.random_colors(Kit.blueprint(id), rng.randi_range(2, mini(6, level_boxes(id))), rng)
			var state := PlayState.start(level)
			while state.status() == PlayState.PLAYING:
				var moves := PackedInt32Array()
				var any_free := false
				for s: int in level.screw_count():
					if state.is_free(s):
						any_free = true
						if state.destination(s).x != PlayState.NONE:
							moves.append(s)
				check(any_free, "R10 %s game %d: a free screw while screws remain" % [id, game])
				if moves.is_empty():
					break
				state.tap(moves[rng.randi_range(0, moves.size() - 1)])
				taps += 1
				for slot_screw: int in state.tray():
					if slot_screw < 0:
						continue
					for position: int in 2:
						var box := state.open_box(position)
						check(not (box.x == level.screw_colors[slot_screw] and box.y < 3), "I1 %s: tray screw %d matches an open box" % [id, slot_screw])
	check(taps > 500, "played %d taps" % taps)


func level_boxes(id: String) -> int:
	return int(Kit.blueprint(id).screw_count() / 3.0)


func test_r17_a_fallen_plank_covers_nothing() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	var r := state.use_screwdriver(3)
	check(r.ok, "take the door screw")
	check_eq(_kinds(r), ["SCREW_TO_BOX", "PLANK_FELL", "COVER_CHANGED"], "events")
	check_eq(state.plank_state(1), PlayState.FALLEN, "the door fell")
	check(state.is_free(10), "the wall screw under it is free")
	check_eq(state.plank_pose(1), Vector3(43, 73, 0), "a fallen one screw plank keeps its pose")


# Taps (R11 to R16).

func test_r11_a_covered_tap_changes_nothing() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	var before := state.snapshot()
	var r := state.tap(6)
	check(not r.ok and r.reason == TapResult.COVERED and r.events.is_empty(), "COVERED, no events")
	check_eq(state.snapshot(), before, "nothing changed")
	check(not state.can_undo(), "and nothing to undo")


func test_r12_e7_the_fullest_box_takes_the_screw() -> void:
	var state := _house(E7_COLORS, E7_QUEUE)
	_play(state, [8, 9, 3, 11, 12])
	check_eq(state.open_box(0), Vector2i(0, 0), "position 0: A with 0")
	check_eq(state.open_box(1), Vector2i(0, 2), "position 1: A with 2")
	check_eq(state.destination(4), Vector2i(PlayState.BOX, 1), "an A screw goes right")
	var r := state.tap(4)
	check_eq(_kinds(r).slice(0, 3), ["SCREW_TO_BOX", "PLANK_FELL", "BOX_CLOSED"], "into the right box, which closes")
	check(r.events[0].position == 1 and r.events[0].well == 2, "position 1, well 2")
	check_eq(r.events[2].position, 1, "the right box closed")


func test_r12_a_tie_goes_left() -> void:
	var state := _house(E7_COLORS, [0, 0, 1, 2, 3])
	check_eq(state.destination(8), Vector2i(PlayState.BOX, 0), "two empty A boxes: the left one")


func test_r12_no_box_means_the_leftmost_empty_tray_slot() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	_play(state, [13, 4, 5, 8, 9, 11, 12, 3])
	check_eq(state.tray(), PackedInt32Array([13, -1, 5, -1, -1]), "a gap at slot 1")
	check_eq(state.destination(1), Vector2i(PlayState.TRAY, 1), "the next tray screw fills the gap")
	var r := state.tap(1)
	check(r.ok and r.events[0].kind == LogicEvent.SCREW_TO_TRAY and r.events[0].slot == 1, "SCREW_TO_TRAY slot 1")
	check_eq(state.tray_uses(), 4, "four tray uses")
	check(not state.is_free(6), "(14, 40) is still covered")
	check_eq(state.destination(6), Vector2i(PlayState.TRAY, 3), "destination works for a covered screw")
	check_eq(state.destination(10), Vector2i(PlayState.BOX, 0), "an X goes to its box")
	check_eq(state.destination(13), Vector2i(PlayState.NONE, -1), "and is NONE off the board")


func test_r13_one_tap_drops_a_plank_and_closes_a_box_in_order() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	_play(state, [13, 4, 5, 8, 9, 11, 12])
	var r := state.tap(3)
	check_eq(_kinds(r), ["SCREW_TO_BOX", "PLANK_FELL", "COVER_CHANGED", "BOX_CLOSED", "BOX_ARRIVED", "TRAY_TO_BOX"], "canonical order: %s" % r.describe())
	if r.events.size() == 6:
		check(r.events[0].screw == 3 and r.events[0].position == 0 and r.events[0].well == 2, "the door screw into D's last well")
		check_eq(r.events[1].plank, 1, "the door falls")
		check_eq(r.events[2].screws, PackedInt32Array([10]), "uncovering (43, 61)")
		check(r.events[3].position == 0 and r.events[3].color == 3, "D closes")
		check(r.events[4].position == 0 and r.events[4].color == 4, "X arrives")
		check(r.events[5].screw == 4 and r.events[5].slot == 1 and r.events[5].position == 0 and r.events[5].well == 0, "the tray X jumps in")
	check_eq(state.open_box(0), Vector2i(4, 1), "X holds 1")


func test_r14_a_double_tap_finds_the_screw_gone() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	check(state.tap(8).ok, "first tap")
	var before := state.snapshot()
	var r := state.tap(8)
	check(not r.ok and r.reason == TapResult.GONE, "second tap: GONE")
	check_eq(state.snapshot(), before, "nothing changed")
	check_eq(state.tap(99).reason, TapResult.GONE, "a screw id past the end")
	check_eq(state.tap(-1).reason, TapResult.GONE, "a negative screw id")
	check_eq(state.use_screwdriver(-1).reason, TapResult.GONE, "a Screwdriver on a negative id")
	check(not state.is_on_board(-1) and not state.is_free(-1) and state.cover_plank(-1) == -1, "queries on a bad id")
	check_eq(state.destination(-1), Vector2i(PlayState.NONE, -1), "no destination for a bad id")


func test_r15_a_plank_with_two_screws_left_does_not_move() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	var r := state.tap(0)
	check_eq(_kinds(r), ["SCREW_TO_BOX"], "no plank event")
	check_eq(state.plank_state(0), PlayState.FIXED, "the roof is still fixed")
	check_eq(state.plank_pose(0), Vector3.ZERO, "at its authored pose")


func test_e2_r16_the_chimney_swings_180_then_falls_keeping_its_pose() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	var r := state.tap(13)
	var swung := r.of_kind(LogicEvent.PLANK_SWUNG)
	check(swung.size() == 1 and swung[0].plank == 5 and swung[0].screw == 14 and swung[0].angle == 180.0, "PLANK_SWUNG plank 5 on 14 at 180: %s" % r.describe())
	check_eq(state.plank_state(5), PlayState.HANGING, "hanging")
	check_eq(state.plank_pose(5), Vector3(68, 20, 180), "pose")
	var box := Geom.bounds(state.level().geometry.hang_outline[14])
	check(absf(box[3] - 39.0) < 0.01, "the path now runs (68, 20) to (68, 34)")
	r = state.use_screwdriver(14)
	check(r.of_kind(LogicEvent.PLANK_FELL).size() == 1, "then it falls")
	check_eq(state.plank_pose(5), Vector3(68, 20, 180), "a fallen plank reports the pose it fell from")
	var other := _house(E4_COLORS, E4_QUEUE)
	r = other.use_screwdriver(14)
	swung = r.of_kind(LogicEvent.PLANK_SWUNG)
	check(swung.size() == 1 and swung[0].screw == 13 and absf(swung[0].angle) < 1e-6, "taken the other way it hangs at 0")


# Boxes and the queue (R18 to R21).

func test_r18_r19_a_full_box_closes_and_the_next_takes_its_place() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	_play(state, [8, 9])
	var r := state.tap(0)
	check_eq(_kinds(r), ["SCREW_TO_BOX", "BOX_CLOSED", "BOX_ARRIVED"], "closes and the next arrives")
	check(r.events[2].position == 1 and r.events[2].color == 4, "X arrives at position 1")
	check_eq(state.open_box(1), Vector2i(4, 0), "position 1 holds an empty X")
	check_eq(state.preview(), PackedInt32Array([0, 2]), "the preview moves on")


func test_r19_when_the_queue_runs_out_the_position_stays_empty() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	_play(state, E4_SETUP + [0])
	var r := state.tap(1)
	var arrived := r.of_kind(LogicEvent.BOX_ARRIVED)
	check(arrived.size() == 1 and arrived[0].color == -1 and arrived[0].position == 1, "BOX_ARRIVED with color -1")
	check_eq(state.open_box(1), Vector2i(-1, 0), "position 1 is empty")
	check_eq(state.preview(), PackedInt32Array(), "nothing left to preview")


func test_r20_e4_tray_jumps_in_tray_order() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	_play(state, E4_SETUP)
	check_eq(state.open_box(0), Vector2i(0, 0), "E4: A with 0")
	check_eq(state.open_box(1), Vector2i(1, 2), "E4: B with 2")
	check_eq(state.preview(), PackedInt32Array([2]), "next is C")
	check_eq(state.tray(), PackedInt32Array([13, -1, 5, -1, -1]), "tray C - C - -")
	var r := state.tap(0)
	check_eq(_kinds(r), ["SCREW_TO_BOX", "BOX_CLOSED", "BOX_ARRIVED", "TRAY_TO_BOX", "TRAY_TO_BOX"], "B closes, C arrives, two jumps")
	if r.events.size() == 5:
		check(r.events[3].screw == 13 and r.events[3].slot == 0 and r.events[3].well == 0, "slot 0 first")
		check(r.events[4].screw == 5 and r.events[4].slot == 2 and r.events[4].well == 1, "then slot 2")
		check(r.events[3].position == 1 and r.events[4].position == 1, "into the position that changed (R21)")
	check_eq(state.open_box(0), Vector2i(0, 0), "position 0 is untouched")
	check_eq(state.open_box(1), Vector2i(2, 2), "C now holds 2")
	check_eq(state.tray(), PackedInt32Array([-1, -1, -1, -1, -1]), "the tray is empty")
	check_eq(state.box_screws(1), PackedInt32Array([13, 5, -1]), "the wells")


func test_r21_e5_a_cascade_runs_in_one_tap() -> void:
	var state := _house(E5_COLORS, E5_QUEUE)
	_play(state, [13, 4, 5, 8, 9])
	check_eq(state.tray(), PackedInt32Array([13, 4, 5, -1, -1]), "three C in the tray")
	var r := state.tap(11)
	check_eq(_kinds(r), ["SCREW_TO_BOX", "BOX_CLOSED", "BOX_ARRIVED", "TRAY_TO_BOX", "TRAY_TO_BOX", "TRAY_TO_BOX", "BOX_CLOSED", "BOX_ARRIVED"], "cascade: %s" % r.describe())
	if r.events.size() == 8:
		check(r.events[6].color == 2 and r.events[7].color == 3 and r.events[7].position == 1, "C closes and D slides in at position 1")
	check_eq(state.open_box(1), Vector2i(3, 0), "D is open and empty")
	check_eq(state.preview(), PackedInt32Array([0]), "A is next")


# Win and loss (R22 to R25).

func test_r22_e4_the_house_is_won_when_every_screw_is_boxed() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	_play(state, E4_SETUP + E4_REST)
	check_eq(state.status(), PlayState.WON, "won")
	check_eq(state.tray_uses(), 3, "three tray uses")


func test_r22_the_win_check_comes_before_the_loss_check() -> void:
	# With no tray at all the tray is always "full", so after the last screw both the win and
	# the loss conditions hold. The win comes first.
	var base := Kit.level([Kit.bar(0, [[20, 45], [66, 45]], 10, [[22, 45], [43, 45], [64, 45]], [0, 0, 0])], [0])
	var errors := PackedStringArray()
	var level := base.with_colors(base.screw_colors, base.queue, errors)
	level.tray_size = 0
	var state := PlayState.start(level)
	_play(state, [0, 2])
	var r := state.tap(1)
	check_eq(_kinds(r).back(), "WON", "WON, not LOST")
	check_eq(state.status(), PlayState.WON, "status")


func test_e6_r23_a_full_tray_and_no_fitting_free_screw_is_a_loss() -> void:
	var state := _bricks(E6_COLORS)
	_play(state, E6_TAPS.slice(0, 5))
	check_eq(state.status(), PlayState.PLAYING, "still playing with one slot left")
	var r := state.tap(16)
	check_eq(_kinds(r).back(), "LOST", "the sixth tap loses")
	check_eq(state.status(), PlayState.LOST, "lost")
	check_eq(state.tray(), PackedInt32Array([18, 21, 23, 13, 16]), "tray D D E E F")
	check_eq(state.open_box(0), Vector2i(0, 1), "A holds 1")
	check_eq(state.open_box(1), Vector2i(1, 0), "B holds 0")
	var free_colors := PackedInt32Array()
	for s: int in 24:
		if state.is_free(s):
			free_colors.append(state.level().screw_colors[s])
	free_colors.sort()
	check_eq(free_colors, PackedInt32Array([2, 3, 4, 4, 5, 5]), "free screws are D E F F G G")


func test_e6_r25_with_one_fitting_free_screw_play_goes_on_and_other_taps_are_refused() -> void:
	var colors := E6_COLORS.duplicate()
	colors[5] = 1
	colors[8] = 5
	var state := _bricks(colors)
	_play(state, E6_TAPS)
	check_eq(state.status(), PlayState.PLAYING, "a free B fits: not lost")
	var before := state.snapshot()
	var r := state.tap(0)
	check(not r.ok and r.reason == TapResult.REFUSED and r.events.is_empty(), "a free D is refused")
	check_eq(state.snapshot(), before, "nothing changed")
	check_eq(state.tray_uses(), 5, "not a tray use")
	check(state.tap(5).ok, "the B can still go")


func test_r25_a_refused_tap_leaves_the_undo_history_alone() -> void:
	var colors := E6_COLORS.duplicate()
	colors[5] = 1
	colors[8] = 5
	var state := _bricks(colors)
	_play(state, E6_TAPS)
	check_eq(state.tap(0).reason, TapResult.REFUSED, "a free D is refused")
	var r := state.undo()
	check(r.ok and r.events[0].screw == 16, "the next undo takes back the last real tap (16), not the refused one")
	check(state.is_on_board(16) and state.is_on_board(0), "16 is back and 0 never left")


func test_r20_the_tray_holds_more_of_the_arriving_color_than_the_box_takes() -> void:
	# House with two C boxes: queue A B C D C. Four C wait in the tray; when C arrives it takes
	# the three leftmost, closes, and D arrives; the fourth C keeps its slot.
	var colors := [0, 0, 0, 3, 2, 2, 3, 3, 2, 1, 2, 1, 1, 2, 2]
	var state := _house(colors, [0, 1, 2, 3, 2])
	_play(state, [13, 4, 5, 8, 9, 11])
	check_eq(state.tray(), PackedInt32Array([13, 4, 5, 8, -1]), "four C in the tray")
	var r := state.tap(12)
	check_eq(_kinds(r), ["SCREW_TO_BOX", "BOX_CLOSED", "BOX_ARRIVED", "TRAY_TO_BOX", "TRAY_TO_BOX", "TRAY_TO_BOX", "BOX_CLOSED", "BOX_ARRIVED"], "three jump, C closes, D arrives: %s" % r.describe())
	var jumps := r.of_kind(LogicEvent.TRAY_TO_BOX)
	if jumps.size() == 3:
		check(jumps[0].slot == 0 and jumps[1].slot == 1 and jumps[2].slot == 2, "slots 0, 1 and 2, in tray order")
	check_eq(state.tray(), PackedInt32Array([-1, -1, -1, 8, -1]), "the fourth C stays in slot 3")
	check_eq(state.open_box(1), Vector2i(3, 0), "D is open at position 1")
	check_eq(state.preview(), PackedInt32Array([2]), "the second C box is next")


func test_4_2_which_calls_work_when() -> void:
	var lost := _lost_bricks()
	check_eq(lost.tap(0).reason, TapResult.NOT_PLAYING, "LOST: tap does nothing")
	check(lost.can_undo(), "LOST: undo is offered")
	var won := _house(E4_COLORS, E4_QUEUE)
	_play(won, E4_SETUP + E4_REST)
	check_eq(won.tap(0).reason, TapResult.NOT_PLAYING, "WON: tap")
	check_eq(won.undo().reason, TapResult.NOT_PLAYING, "WON: undo")
	check_eq(won.use_extra_slot().reason, TapResult.NOT_PLAYING, "WON: extra slot")
	check_eq(won.use_screwdriver(0).reason, TapResult.NOT_PLAYING, "WON: screwdriver")
	check(not won.can_undo(), "WON: no undo")


# Undo (R26 to R29).

func test_r26_undo_restores_the_snapshot_after_every_kind_of_tap() -> void:
	# The house game covers a tray move and a swing (13), falls (4, 5, 3, 14), a box closing
	# with a jump (3), the queue running out (1) and a swing that turns the roof (1).
	var full := E4_SETUP + E4_REST
	var state := _house(E4_COLORS, E4_QUEUE)
	var snaps: Array[Dictionary] = [state.snapshot()]
	for s: int in full:
		state.tap(s)
		snaps.append(state.snapshot())
	check_eq(state.status(), PlayState.WON, "played to the win")
	# Replay to each point, then undo once and compare.
	for i: int in range(1, full.size()):
		var replay := _house(E4_COLORS, E4_QUEUE)
		_play(replay, full.slice(0, i))
		check_eq(replay.snapshot(), snaps[i], "replay to %d" % i)
		var r := replay.undo()
		check(r.ok and r.events[0].kind == LogicEvent.UNDONE and r.events[0].screw == full[i - 1], "undo %d" % i)
		check_eq(replay.snapshot(), snaps[i - 1], "after undoing tap %d (%d)" % [i, full[i - 1]])


func test_r26_undo_after_a_cascade() -> void:
	var state := _house(E5_COLORS, E5_QUEUE)
	_play(state, [13, 4, 5, 8, 9])
	var before := state.snapshot()
	state.tap(11)
	var r := state.undo()
	check_eq(state.snapshot(), before, "the cascade is taken back")
	var moved := r.events[0].screws
	moved.sort()
	check_eq(moved, PackedInt32Array([4, 5, 8, 9, 11, 13]), "UNDONE lists the screw, the three that jumped and the two back in B")


func test_r28_five_undos_in_a_row_go_back_to_the_start() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	var start := state.snapshot()
	_play(state, [13, 4, 5, 8, 9])
	for i: int in 5:
		check(state.undo().ok, "undo %d" % (i + 1))
	check_eq(state.snapshot(), start, "back to the start")
	var r := state.undo()
	check(not r.ok and r.reason == TapResult.NOTHING_TO_UNDO, "a sixth has nothing to undo")
	check_eq(state.helpers_used(), PackedStringArray(["undo"]), "undo is recorded once")


func test_r28_undo_with_nothing_to_take_back_spends_nothing() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	check_eq(state.undo().reason, TapResult.NOTHING_TO_UNDO, "nothing to undo")
	check_eq(state.helpers_used(), PackedStringArray(), "nothing recorded")


func test_r27_undo_keeps_the_extra_slot_and_does_not_refund() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	_play(state, [13])
	state.use_extra_slot()
	check(state.use_screwdriver(6).ok, "screwdriver")
	check(state.undo().ok, "undo the screwdriver")
	check(state.undo().ok, "undo the tap")
	check_eq(state.tray().size(), 6, "the sixth slot stays")
	check(state.extra_slot_used(), "Extra slot is still used")
	check_eq(state.helpers_used(), PackedStringArray(["extra_slot", "screwdriver", "undo"]), "every helper used is still recorded")
	check_eq(state.tray_uses(), 0, "tray uses are restored")
	check(state.is_on_board(6) and state.is_on_board(13), "both screws are back")


func test_r29_undo_after_a_loss_clears_it() -> void:
	var state := _lost_bricks()
	var r := state.undo()
	check_eq(_kinds(r), ["UNDONE", "RESUMED"], "UNDONE then RESUMED")
	check_eq(state.status(), PlayState.PLAYING, "playing again")
	check_eq(r.events[0].screw, 16, "the last tray screw goes back")


# Helpers (R30, R31, R37).

func test_r30_extra_slot_once_per_attempt() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	var r := state.use_extra_slot()
	check_eq(_kinds(r), ["TRAY_EXTENDED"], "TRAY_EXTENDED")
	check_eq(r.events[0].slot, 5, "the sixth slot")
	check_eq(state.tray().size(), 6, "six slots")
	check_eq(state.use_extra_slot().reason, TapResult.ALREADY_USED, "a second time: ALREADY_USED")
	check_eq(state.helpers_used(), PackedStringArray(["extra_slot"]), "recorded once")
	check(not state.can_undo(), "Extra slot cannot be undone")


func test_r30_r37_extra_slot_clears_a_loss() -> void:
	var state := _lost_bricks()
	var r := state.use_extra_slot()
	check_eq(_kinds(r), ["TRAY_EXTENDED", "RESUMED"], "TRAY_EXTENDED then RESUMED")
	check_eq(state.status(), PlayState.PLAYING, "playing")
	check(state.tap(0).ok, "a free D goes to the sixth slot")
	check_eq(state.tray()[5], 0, "there")


func test_r31_screwdriver_takes_a_covered_screw_like_a_tap() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	check_eq(state.tap(6).reason, TapResult.COVERED, "a tap cannot")
	var r := state.use_screwdriver(6)
	check(r.ok and r.events[0].kind == LogicEvent.SCREW_TO_TRAY and r.events[0].slot == 0, "the Screwdriver sends it to its destination")
	check(not state.is_on_board(6), "gone")
	check_eq(state.tray_uses(), 1, "a tray use like any other")
	check_eq(state.helpers_used(), PackedStringArray(["screwdriver"]), "recorded")
	check(state.can_undo(), "it counts for Undo")
	state.undo()
	check(state.is_on_board(6) and not state.is_free(6), "undo puts it back under the roof")


func test_r31_screwdriver_with_nowhere_to_go_is_refused_and_not_spent() -> void:
	var state := _lost_bricks()
	var before := state.snapshot()
	var r := state.use_screwdriver(14)
	check(not r.ok and r.reason == TapResult.REFUSED, "an H has nowhere to go")
	check_eq(state.snapshot(), before, "nothing changed")
	check_eq(state.helpers_used(), PackedStringArray(), "not spent")
	check_eq(state.use_screwdriver(18).reason, TapResult.GONE, "a screw in the tray is GONE")


func test_r37_screwdriver_after_a_loss_resumes_when_it_frees_a_fit() -> void:
	var state := _lost_bricks()
	var r := state.use_screwdriver(6)
	check_eq(_kinds(r), ["SCREW_TO_BOX", "PLANK_FELL", "COVER_CHANGED", "RESUMED"], "RESUMED after the tap's events: %s" % r.describe())
	check_eq(state.status(), PlayState.PLAYING, "playing")
	check(state.is_free(11), "the B it uncovered is free")


func test_r37_screwdriver_or_undo_can_leave_the_board_lost() -> void:
	var state := _lost_bricks()
	var r := state.use_screwdriver(10)
	check_eq(_kinds(r), ["SCREW_TO_BOX", "PLANK_FELL", "COVER_CHANGED", "LOST"], "a fresh LOST: %s" % r.describe())
	check_eq(state.status(), PlayState.LOST, "still lost")
	r = state.undo()
	check_eq(_kinds(r), ["UNDONE", "LOST"], "undoing it is still lost")
	check_eq(state.status(), PlayState.LOST, "lost")
	r = state.undo()
	check_eq(_kinds(r), ["UNDONE", "RESUMED"], "one more undo resumes")


func test_4_2_helpers_used_names_each_helper_once_in_order() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	state.use_screwdriver(13)
	state.undo()
	state.use_screwdriver(13)
	state.undo()
	state.use_extra_slot()
	check_eq(state.helpers_used(), PackedStringArray(["screwdriver", "undo", "extra_slot"]), "each once")


# Events (ARCHITECTURE 4.3).

func test_4_3_events_follow_the_canonical_order_in_random_play() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var order := {LogicEvent.SCREW_TO_BOX: 1, LogicEvent.SCREW_TO_TRAY: 1, LogicEvent.PLANK_SWUNG: 2, LogicEvent.PLANK_FELL: 2, LogicEvent.COVER_CHANGED: 3, LogicEvent.BOX_CLOSED: 4, LogicEvent.BOX_ARRIVED: 4, LogicEvent.TRAY_TO_BOX: 4, LogicEvent.WON: 5, LogicEvent.LOST: 5}
	var actions := 0
	for id: String in Kit.BLUEPRINTS:
		for game: int in 3:
			var level := Kit.random_colors(Kit.blueprint(id), rng.randi_range(2, 5), rng)
			var state := PlayState.start(level)
			while state.status() == PlayState.PLAYING:
				var moves := PackedInt32Array()
				for s: int in level.screw_count():
					if state.is_free(s) and state.destination(s).x != PlayState.NONE:
						moves.append(s)
				var r := state.tap(moves[rng.randi_range(0, moves.size() - 1)])
				actions += 1
				var step := 0
				var closed := false
				for e: LogicEvent in r.events:
					var rank: int = order[e.kind]
					check(rank >= step, "%s: %s out of order in %s" % [id, e.kind_name(), r.describe()])
					step = rank
					if e.kind == LogicEvent.BOX_CLOSED:
						closed = true
					if e.kind == LogicEvent.BOX_ARRIVED or e.kind == LogicEvent.TRAY_TO_BOX:
						check(closed, "%s: %s before a BOX_CLOSED" % [id, e.kind_name()])
				check(r.events[0].kind == LogicEvent.SCREW_TO_BOX or r.events[0].kind == LogicEvent.SCREW_TO_TRAY, "the screw's event comes first")
	check(actions > 100, "%d actions" % actions)


func test_4_3_a_failed_action_has_no_events() -> void:
	var state := _house(E4_COLORS, E4_QUEUE)
	for r: TapResult in [state.tap(6), state.tap(99), state.undo()]:
		check(not r.ok and r.events.is_empty(), "failed with no events")
