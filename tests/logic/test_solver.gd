# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The solver (docs/ARCHITECTURE.md 4.4, GDD 6.4 and 8): fewest tray uses, solutions that
## replay in PlayState, the novice policy, determinism, the tutorial designs, and timings.

const Kit := preload("res://tests/logic/kit.gd")
const MAX_STATES := 200000

## Nine screws. A big C disc in front covers one A and one B, so with A and B open first the
## C must wait in the tray once: the answer is 1.
const ONE_TRAY_USE := [
	{"layer": 0, "shape": "disc", "center": [43, 45], "radius": 14, "holes": [[43, 45]], "colors": [2]},
	{"layer": 1, "shape": "disc", "center": [31, 45], "radius": 5, "holes": [[31, 45]], "colors": [0]},
	{"layer": 1, "shape": "disc", "center": [55, 45], "radius": 5, "holes": [[55, 45]], "colors": [1]},
	{"layer": 1, "shape": "disc", "center": [13, 15], "radius": 5, "holes": [[13, 15]], "colors": [0]},
	{"layer": 1, "shape": "disc", "center": [31, 15], "radius": 5, "holes": [[31, 15]], "colors": [0]},
	{"layer": 1, "shape": "disc", "center": [55, 15], "radius": 5, "holes": [[55, 15]], "colors": [1]},
	{"layer": 1, "shape": "disc", "center": [73, 15], "radius": 5, "holes": [[73, 15]], "colors": [1]},
	{"layer": 1, "shape": "disc", "center": [13, 75], "radius": 5, "holes": [[13, 75]], "colors": [2]},
	{"layer": 1, "shape": "disc", "center": [73, 75], "radius": 5, "holes": [[73, 75]], "colors": [2]},
]


func test_solver_one_bar_needs_no_tray() -> void:
	var level := Kit.level([Kit.bar(0, [[20, 45], [66, 45]], 10, [[22, 45], [43, 45], [64, 45]], [0, 0, 0])], [0])
	var r := Solver.solve(level, MAX_STATES)
	check(r.solved and r.complete, "solved and complete")
	check_eq(r.fewest_tray_uses, 0, "fewest tray uses")
	check_eq(r.solution.size(), 3, "three taps")
	check(r.novice_won, "the novice wins")
	check_eq(r.trap, 0.0, "no traps")


func test_solver_a_covering_disc_forces_one_tray_use() -> void:
	var level := Kit.level(ONE_TRAY_USE, [0, 1, 2])
	check(BlueprintValidator.check(level).is_empty(), "the level keeps the blueprint rules: %s" % "; ".join(BlueprintValidator.check(level)))
	var r := Solver.solve(level, MAX_STATES)
	check(r.solved and r.complete, "solved")
	check_eq(r.fewest_tray_uses, 1, "fewest tray uses")
	check_eq(_replay(level, r.solution), 1, "the solution replays with one tray use")
	check_eq(_brute_force(level), 1, "a brute force search agrees")


func test_solver_proves_a_level_unsolvable() -> void:
	var base := Kit.level(ONE_TRAY_USE, [0, 1, 2])
	var errors := PackedStringArray()
	var level := base.with_colors(base.screw_colors, base.queue, errors)
	level.tray_size = 0
	var r := Solver.solve(level, MAX_STATES)
	check(not r.solved, "not solved")
	check(r.complete, "and the search is complete, so it has no solution")
	check_eq(r.fewest_tray_uses, -1, "no tray use count")
	check(not r.novice_won, "the novice loses")
	check_eq(r.trap, 1.0, "every careless playout loses")


func test_solver_stops_at_max_states_at_the_same_point_every_time() -> void:
	var level := Kit.random_colors(Kit.blueprint("lattice"), 7, _rng(3))
	var a := Solver.solve(level, 50)
	var b := Solver.solve(level, 50)
	check(not a.complete, "stopped early")
	check_eq(a.states, b.states, "at the same point")
	check_eq(a.solved, b.solved, "with the same answer")


func test_solver_is_deterministic() -> void:
	for id: String in ["house", "bridge", "rings"]:
		var level := Kit.random_colors(Kit.blueprint(id), 4, _rng(7))
		var a := Solver.solve(level, MAX_STATES)
		var b := Solver.solve(level, MAX_STATES)
		check_eq(a.solution, b.solution, "%s: the same solution" % id)
		check_eq(a.states, b.states, "%s: the same states" % id)
		check_eq(a.trap, b.trap, "%s: the same trap" % id)
		check_eq(a.fewest_tray_uses, b.fewest_tray_uses, "%s: the same fewest tray uses" % id)


func test_solver_agrees_with_a_brute_force_search_over_play_state() -> void:
	var rng := _rng(21)
	var compared := 0
	for id: String in ["house", "sailboat", "windmill", "fish"]:
		for game: int in 3:
			var level := Kit.random_colors(Kit.blueprint(id), 3 + game, rng)
			var started := Time.get_ticks_msec()
			var r := Solver.solve(level, MAX_STATES)
			var best := _brute_force(level)
			check(r.complete, "%s game %d complete" % [id, game])
			check_eq(r.fewest_tray_uses, best, "%s game %d: fewest tray uses" % [id, game])
			print("        %s with %d colors: fewest tray uses %d (brute force %d ms)" % [id, 3 + game, best, Time.get_ticks_msec() - started])
			compared += 1
	for n: int in range(1, 9):
		check_eq(Solver.solve(Kit.tutorial(n), MAX_STATES).fewest_tray_uses, _brute_force(Kit.tutorial(n)), "tutorial %d" % n)
	check_eq(compared, 12, "levels compared")


func test_solver_agrees_with_brute_force_where_the_tray_matters() -> void:
	# Colorings the solver says need the tray, or have no solution. For an answer k, the
	# independent search must fail with k - 1 tray uses and succeed with k. For no solution, it
	# must find no win within 3 tray uses. (Its cost grows fast with the budget, so the test
	# keeps to k of 4 or less.)
	var rng := _rng(77)
	var pressured := 0
	var unsolvable := 0
	var tries := 0
	while (pressured < 12 or unsolvable < 2) and tries < 400:
		tries += 1
		var id: String = ["house", "windmill", "fish", "sailboat", "bridge", "tree", "rings", "bricks"][tries % 8]
		var base := Kit.blueprint(id)
		var level := Kit.random_colors(base, mini(7, int(base.screw_count() / 3.0)), rng)
		var r := Solver.solve(level, MAX_STATES)
		check(r.complete, "%s: complete" % id)
		var started := Time.get_ticks_msec()
		if r.solved and r.fewest_tray_uses >= 1 and r.fewest_tray_uses <= 4 and pressured < 12:
			pressured += 1
			var k := r.fewest_tray_uses
			check(not _reach(PlayState.start(level), k - 1, {}, level.screw_count()), "%s: no win with %d tray uses" % [id, k - 1])
			check(_reach(PlayState.start(level), k, {}, level.screw_count()), "%s: a win with %d tray uses" % [id, k])
			print("        %s: %d colors, fewest tray uses %d, %d states (brute force %d ms)" % [id, level.color_count(), k, r.states, Time.get_ticks_msec() - started])
		elif not r.solved and unsolvable < 2:
			unsolvable += 1
			check(not _reach(PlayState.start(level), 3, {}, level.screw_count()), "%s: no win within 3 tray uses" % id)
			print("        %s: %d colors, no solution, %d states (brute force %d ms)" % [id, level.color_count(), r.states, Time.get_ticks_msec() - started])
	check_eq(pressured, 12, "colorings that need the tray")
	check_eq(unsolvable, 2, "colorings with no solution")


func test_solver_safe_move_rule_never_changes_the_answer() -> void:
	# On every blueprint, random colors from easy to dense: the search with the safe move rule
	# finds the same fewest tray uses as the search without it, and never more states.
	var rng := _rng(404)
	var compared := 0
	var saved := 0
	var total := 0
	for file: String in DirAccess.get_files_at(Kit.BLUEPRINT_DIR):
		if not file.ends_with(".json"):
			continue
		var base := Kit.blueprint(file.get_basename())
		var boxes := int(base.screw_count() / 3.0)
		for colors: int in [mini(3, boxes), mini(5, boxes), mini(7, boxes)]:
			var level := Kit.random_colors(base, colors, rng)
			var with := Solver.search_only(level, 60000, true)
			var without := Solver.search_only(level, 60000, false)
			if with.complete and without.complete:
				compared += 1
				check_eq(with.fewest_tray_uses, without.fewest_tray_uses, "%s with %d colors" % [base.id, colors])
				check(with.states <= without.states, "%s with %d colors: %d states, %d without the rule" % [base.id, colors, with.states, without.states])
				saved += without.states - with.states
				total += without.states
				if with.solved:
					check_eq(_replay(level, with.solution), with.fewest_tray_uses, "%s: the pruned solution replays" % base.id)
			elif without.complete:
				check(false, "%s with %d colors: the rule made the search miss its budget" % [base.id, colors])
	check(compared >= 100, "compared %d levels" % compared)
	print("        %d levels compared; the rule saves %d of %d states (%.0f percent)" % [compared, saved, total, 100.0 * saved / maxi(total, 1)])


func test_solver_general_path_with_three_open_boxes() -> void:
	# The search has a fast path for two open boxes and a general one for other counts
	# (data/tuning.json could change it). Tuning is set only around the calls that read it.
	var rng := _rng(31)
	var compared := 0
	for id: String in ["house", "windmill", "fish", "bridge", "rings"]:
		for colors: int in [4, 5]:
			var level := Kit.random_colors(Kit.blueprint(id), colors, rng)
			Tuning.open_boxes = 3
			var r := Solver.solve(level, MAX_STATES)
			var replay := PlayState.start(level)
			var search := PlayState.start(level)
			Tuning.open_boxes = 2
			check(r.solved and r.complete, "%s with %d colors and three open boxes solved" % [id, colors])
			for t: int in r.solution:
				replay.tap(t)
			check(replay.status() == PlayState.WON and replay.tray_uses() == r.fewest_tray_uses, "%s: the solution replays with three open boxes" % id)
			var k := r.fewest_tray_uses
			if k >= 1:
				check(not _reach(search, k - 1, {}, level.screw_count(), 3), "%s: no win with %d tray uses" % [id, k - 1])
			check(_reach(search, k, {}, level.screw_count(), 3), "%s: a win with %d tray uses" % [id, k])
			compared += 1
	check_eq(Tuning.open_boxes, 2, "Tuning is back to two open boxes")
	check_eq(compared, 10, "levels compared")


func test_solver_solutions_replay_in_play_state_on_every_blueprint() -> void:
	var rng := _rng(5)
	for id: String in Kit.BLUEPRINTS:
		for colors: int in [3, 5]:
			var level := Kit.random_colors(Kit.blueprint(id), colors, rng)
			var r := Solver.solve(level, MAX_STATES)
			check(r.solved and r.complete, "%s with %d colors solved" % [id, colors])
			check_eq(r.solution.size(), level.screw_count(), "%s: one tap per screw" % id)
			check_eq(_replay(level, r.solution), r.fewest_tray_uses, "%s: the replay wins with the fewest tray uses" % id)


func test_6_4_novice_policy_matches_play_state() -> void:
	var rng := _rng(9)
	var wins := 0
	var games := 0
	for id: String in Kit.BLUEPRINTS:
		for colors: int in [2, 4, 6]:
			var level := Kit.random_colors(Kit.blueprint(id), mini(colors, int(level_boxes(id))), rng)
			var r := Solver.solve(level, MAX_STATES)
			var won := _novice(level)
			check_eq(r.novice_won, won, "%s with %d colors" % [id, colors])
			games += 1
			if won:
				wins += 1
	check(games == 30, "games played")
	print("        novice won %d of %d random colorings" % [wins, games])


func level_boxes(id: String) -> float:
	return Kit.blueprint(id).screw_count() / 3.0


func test_8_tutorial_levels_are_solvable_without_the_tray_and_cannot_be_lost() -> void:
	# GDD section 8 and 12 item 15: tray par and par time from the table, no tray use needed,
	# and no reachable losing state.
	var tray_par := [2, 2, 3, 2, 2, 2, 1, 1]
	var par_time := [30, 50, 65, 50, 65, 50, 85, 85]
	var screws := [3, 6, 9, 6, 9, 6, 12, 12]
	for n: int in range(1, 9):
		var level := Kit.tutorial(n)
		check(level != null, "tutorial %d loads" % n)
		if level == null:
			continue
		check_eq(level.screw_count(), screws[n - 1], "tutorial %d screws" % n)
		check_eq(level.tray_par, tray_par[n - 1], "tutorial %d tray par" % n)
		check_eq(level.par_time_s, par_time[n - 1], "tutorial %d par time" % n)
		check_eq(level.par_time_s, Stars.par_time(level.screw_count(), 60), "tutorial %d par time is 10 s plus 6 s a screw" % n)
		var r := Solver.solve(level, MAX_STATES)
		check(r.solved and r.complete, "tutorial %d solved" % n)
		check_eq(r.fewest_tray_uses, 0, "tutorial %d fewest tray uses" % n)
		check_eq(_replay(level, r.solution), 0, "tutorial %d: the solution replays" % n)
		var all := Solver.explore(level, MAX_STATES)
		check(all["complete"], "tutorial %d explored" % n)
		check_eq(all["lost"], 0, "tutorial %d lost states" % n)
		check(r.novice_won, "tutorial %d: the novice wins" % n)
		print("        tutorial %d: %d screws, %d reachable states, %d wins, trap %.2f" % [n, level.screw_count(), all["states"], all["won"], r.trap])


func test_8_tutorial_hints_name_screws_that_are_free_when_pointed_at() -> void:
	# The hand points at screws in order; each must be on the board when its turn comes (the
	# first covered one in level 4 is the wiggle).
	for n: int in range(1, 9):
		var level := Kit.tutorial(n)
		var state := PlayState.start(level)
		for s: int in level.hint:
			check(state.is_on_board(s), "tutorial %d: hint screw %d is on the board" % [n, s])
			if state.is_free(s):
				check(state.tap(s).ok, "tutorial %d: hint screw %d can be tapped" % [n, s])


func test_explore_counts_losses() -> void:
	var base := Kit.level(ONE_TRAY_USE, [0, 1, 2])
	var errors := PackedStringArray()
	var level := base.with_colors(base.screw_colors, base.queue, errors)
	level.tray_size = 0
	var all := Solver.explore(level, MAX_STATES)
	check(all["complete"], "complete")
	check_eq(all["won"], 0, "no wins")
	check(all["lost"] > 0, "some losses")


func test_solver_timing_table_for_the_shipped_blueprints() -> void:
	# Random but valid colors (seeded): 3, 5 and 7 colors (as many as the boxes allow), a few
	# games each, on every blueprint in data/blueprints. Random colors can make a level with no
	# solution, which the generator throws away. Wall-clock times on this PC are for the report
	# only; a mid-range phone runs GDScript several times slower.
	var rng := _rng(2026)
	var games := 4
	var budget := 100000
	var lines := PackedStringArray()
	lines.append("| Blueprint | Screws | Layers | Colors | Solved | No solution | Stopped | Fewest tray uses | Novice wins | Trap (mean) | States (max) | ms (median) | ms (max) |")
	lines.append("|-|-|-|-|-|-|-|-|-|-|-|-|-|")
	var all_ms := PackedInt32Array()
	var files := PackedStringArray()
	for file: String in DirAccess.get_files_at(Kit.BLUEPRINT_DIR):
		if file.ends_with(".json"):
			files.append(file.get_basename())
	files.sort()
	for id: String in files:
		var base := Kit.blueprint(id)
		var boxes := int(base.screw_count() / 3.0)
		for colors: int in _color_counts(boxes):
			var ms := PackedInt32Array()
			var fewest := PackedInt32Array()
			var novice := 0
			var trap := 0.0
			var states := 0
			var unsolvable := 0
			var stopped := 0
			for _g: int in games:
				var level := Kit.random_colors(base, colors, rng)
				var r := Solver.solve(level, budget)
				if r.solved:
					check(r.complete, "%s: a solution found is always proven" % id)
					check_eq(_replay(level, r.solution), r.fewest_tray_uses, "%s: the solution replays" % id)
					fewest.append(r.fewest_tray_uses)
				elif r.complete:
					unsolvable += 1
					check(not r.novice_won, "%s: the novice cannot win a level with no solution" % id)
				else:
					stopped += 1
				ms.append(r.ms)
				all_ms.append(r.ms)
				novice += 1 if r.novice_won else 0
				trap += r.trap
				states = maxi(states, r.states)
			ms.sort()
			fewest.sort()
			var range_text := "%d to %d" % [fewest[0], fewest[-1]] if not fewest.is_empty() else "none"
			lines.append("| %s | %d | %d | %d | %d | %d | %d | %s | %d | %.2f | %d | %d | %d |" % [id, base.screw_count(), base.layer_count(), colors, fewest.size(), unsolvable, stopped, range_text, novice, trap / games, states, ms[games >> 1], ms[-1]])
	all_ms.sort()
	print("")
	for l: String in lines:
		print(l)
	print("        %d solves, %d games per row, max_states %d: median %d ms, 95th percentile %d ms, worst %d ms" % [all_ms.size(), games, budget, all_ms[all_ms.size() >> 1], all_ms[int(all_ms.size() * 0.95)], all_ms[-1]])


func _color_counts(boxes: int) -> Array[int]:
	var out: Array[int] = []
	for c: int in [3, 5, 7]:
		if c <= mini(boxes, 8):
			out.append(c)
	return out


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Plays a solution in PlayState and returns its tray uses, or -1 if it does not win.
func _replay(level: LevelData, solution: PackedInt32Array) -> int:
	var state := PlayState.start(level)
	for s: int in solution:
		if not state.tap(s).ok:
			return -1
	return state.tray_uses() if state.status() == PlayState.WON else -1


## The novice policy (GDD 6.4) played through PlayState's public API.
func _novice(level: LevelData) -> bool:
	var order: Array[int] = []
	for s: int in level.screw_count():
		order.append(s)
	order.sort_custom(func(a: int, b: int) -> bool:
		var pa := level.screw_center(a)
		var pb := level.screw_center(b)
		return pa.y < pb.y if pa.y != pb.y else pa.x < pb.x)
	var state := PlayState.start(level)
	while state.status() == PlayState.PLAYING:
		var pick := -1
		var first := -1
		for s: int in order:
			if not state.is_free(s):
				continue
			if first < 0:
				first = s
			if state.destination(s).x == PlayState.BOX:
				pick = s
				break
		if pick < 0:
			pick = first
		if not state.tap(pick).ok:
			return false
	return state.status() == PlayState.WON


## The fewest tray uses by an independent search over PlayState itself: for budgets 0, 1, 2
## and so on, a depth first search (tap, recurse, undo) for a win with at most that many tray
## uses. Positions are remembered by the board, the boxes and the tray's colors slot by slot,
## so this shares nothing with the solver's model.
func _brute_force(level: LevelData) -> int:
	for budget: int in 13:
		var state := PlayState.start(level)
		if _reach(state, budget, {}, level.screw_count()):
			return budget
	return -1


func _reach(state: PlayState, budget: int, failed: Dictionary, left: int, boxes: int = 2) -> bool:
	var key := _key(state, boxes)
	if failed.get(key, -1) >= budget:
		return false
	for s: int in state.level().screw_count():
		if not state.is_free(s):
			continue
		var dest := state.destination(s)
		if dest.x == PlayState.NONE or (dest.x == PlayState.TRAY and budget == 0):
			continue
		if left == 1:
			# The last screw wins if it goes into a box. (A won game cannot be undone.)
			if dest.x == PlayState.BOX:
				return true
			continue
		state.tap(s)
		var ok := _reach(state, budget - (1 if dest.x == PlayState.TRAY else 0), failed, left - 1, boxes)
		state.undo()
		if ok:
			return true
	failed[key] = budget
	return false


func _key(state: PlayState, boxes: int) -> String:
	var level := state.level()
	var on := 0
	for s: int in level.screw_count():
		if state.is_on_board(s):
			on |= 1 << s
	var parts := PackedStringArray([str(on)])
	for position: int in boxes:
		var box := state.open_box(position)
		parts.append("%d:%d" % [box.x, box.y])
	for s: int in state.tray():
		parts.append(str(level.screw_colors[s]) if s >= 0 else "-")
	return ",".join(parts)
