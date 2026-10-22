# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name RetryPlayer
extends RefCounted
## A person who knows a good line but slips. It follows the solver's plan until its first wrong
## tap (a screw it did not mean to take), and after that plays "plan guided": the earliest
## screw of the plan that is free and fits an open box, else the earliest free one. It never
## uses a helper. After a loss it retries the same level, slipping less each time (it has seen
## what went wrong). Through PlayState's public API only; with a BotSession every action is
## also checked against the rules.
##
## This is a lower bound on a thoughtful person's recovery: a person re-plans from the new
## position, and this bot only re-orders the old plan.


## One try. `plan` is Solver.solve's solution. `forced` is the exact number of wrong taps, at
## random positions (use -1 to slip by chance instead: `slip_rate` is the chance per tap).
## With `to_tray` a wrong tap picks a free screw that goes to the tray when there is one (a
## needless tray use, the "wrong move" of GDD 6.8); otherwise any free screw but the planned one.
## Returns {won, lost, wrong, taps, peak}.
static func try_once(level: LevelData, plan: PackedInt32Array, rng: RandomNumberGenerator, forced: int, slip_rate: float, to_tray: bool, session: BotSession = null) -> Dictionary:
	var state: PlayState = session.state if session != null else PlayState.start(level)
	var n := level.screw_count()
	var at := {}
	if forced > 0:
		var positions: Array[int] = []
		for i: int in n:
			positions.append(i)
		for k: int in mini(forced, n):
			var j := rng.randi_range(k, positions.size() - 1)
			var t := positions[k]
			positions[k] = positions[j]
			positions[j] = t
			at[positions[k]] = true
	var taps := 0
	var wrong := 0
	var slipped := false
	var peak := 0
	var guard := 0
	while state.status() == PlayState.PLAYING and guard < n * 8:
		guard += 1
		var screw := -1
		var is_wrong := false
		var wants_slip := at.has(taps) if forced >= 0 else rng.randf() < slip_rate
		if wants_slip:
			screw = _wrong_screw(state, plan, rng, n, to_tray)
			is_wrong = screw >= 0
		if screw < 0:
			screw = _planned(state, plan, n) if not slipped else _guided(state, plan, n)
		if screw < 0:
			screw = _guided(state, plan, n)
		if screw < 0:
			break
		var ok := false
		if session != null:
			ok = session.tap(screw).ok
		else:
			ok = state.tap(screw).ok
		if not ok:
			# A tap that went nowhere (refused): take a screw that can go somewhere instead.
			screw = _guided(state, plan, n)
			if screw < 0:
				break
			ok = session.tap(screw).ok if session != null else state.tap(screw).ok
			if not ok:
				break
			is_wrong = false
		taps += 1
		if is_wrong:
			wrong += 1
			slipped = true
		var used := 0
		for s: int in state.tray():
			if s >= 0:
				used += 1
		peak = maxi(peak, used)
	return {"won": state.status() == PlayState.WON, "lost": state.status() == PlayState.LOST, "wrong": wrong, "taps": taps, "peak": peak}


## The next screw of the plan still on the board.
static func _planned(state: PlayState, plan: PackedInt32Array, _n: int) -> int:
	for s: int in plan:
		if state.is_on_board(s):
			return s
	return -1


## Plan guided: the earliest plan screw that is free and fits an open box, else the earliest
## free one that has somewhere to go.
static func _guided(state: PlayState, plan: PackedInt32Array, n: int) -> int:
	var first_free := -1
	for s: int in plan:
		if not state.is_free(s):
			continue
		var dest := state.destination(s)
		if dest.x == PlayState.BOX:
			return s
		if dest.x == PlayState.TRAY and first_free < 0:
			first_free = s
	if first_free >= 0:
		return first_free
	for s: int in n:
		if state.is_free(s) and state.destination(s).x != PlayState.NONE:
			return s
	return -1


static func _wrong_screw(state: PlayState, plan: PackedInt32Array, rng: RandomNumberGenerator, n: int, to_tray: bool) -> int:
	var planned := _planned(state, plan, n)
	var tray_bound: Array[int] = []
	var any: Array[int] = []
	for s: int in n:
		if s == planned or not state.is_free(s):
			continue
		var dest := state.destination(s)
		if dest.x == PlayState.NONE:
			continue
		any.append(s)
		if dest.x == PlayState.TRAY:
			tray_bound.append(s)
	var pool := tray_bound if (to_tray and not tray_bound.is_empty()) else any
	if pool.is_empty():
		return -1
	return pool[rng.randi_range(0, pool.size() - 1)]


## Plays one level as a person with this profile until it wins or runs out of tries. `profile`:
## "wrong" (the expected wrong taps in the first try), "decay" (the factor per retry). Returns
## {tries, won, wrong}; tries is max_tries when it never won.
static func play_until_win(level: LevelData, plan: PackedInt32Array, seed_value: int, profile: Dictionary, max_tries: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := float(level.screw_count())
	var wrong_total := 0
	for k: int in max_tries:
		var expected := float(profile["wrong"]) * pow(float(profile["decay"]), k)
		var r := try_once(level, plan, rng, -1, expected / n, false)
		wrong_total += int(r["wrong"])
		if bool(r["won"]):
			return {"tries": k + 1, "won": true, "wrong": wrong_total}
	return {"tries": max_tries, "won": false, "wrong": wrong_total}


## A person who thinks one move ahead and does not know the solution. Each tap it scores the
## free screws: one that completes an open box 100, one that fits an open box 60, one that has
## to wait in the tray but whose color is a box shown in the preview 30 (the slot comes back
## soon), any other tray screw 0 (it may sit there a long time). It taps a best scoring screw,
## chosen at random among ties, so every try is different. `slip_rate` is the chance per tap of
## a random free screw instead. Returns {won, lost, wrong, taps, peak}.
static func try_heuristic(level: LevelData, rng: RandomNumberGenerator, slip_rate: float, session: BotSession = null) -> Dictionary:
	var state: PlayState = session.state if session != null else PlayState.start(level)
	var n := level.screw_count()
	var taps := 0
	var slips := 0
	var peak := 0
	var guard := 0
	while state.status() == PlayState.PLAYING and guard < n * 8:
		guard += 1
		var free: Array[int] = []
		for s: int in n:
			if state.is_free(s) and state.destination(s).x != PlayState.NONE:
				free.append(s)
		if free.is_empty():
			break
		var pick := -1
		var slipped := rng.randf() < slip_rate
		if slipped:
			pick = free[rng.randi_range(0, free.size() - 1)]
		else:
			var preview := state.preview()
			var best := -9999
			var tied: Array[int] = []
			for s: int in free:
				var dest := state.destination(s)
				var color := level.screw_colors[s]
				var score := 0
				if dest.x == PlayState.BOX:
					var box := state.open_box(dest.y)
					score = 100 if box.y == 2 else 60
				elif preview.has(color):
					score = 30
				if score > best:
					best = score
					tied.clear()
				if score == best:
					tied.append(s)
			pick = tied[rng.randi_range(0, tied.size() - 1)]
		var ok := session.tap(pick).ok if session != null else state.tap(pick).ok
		if not ok:
			break
		taps += 1
		slips += 1 if slipped else 0
		var used := 0
		for s: int in state.tray():
			if s >= 0:
				used += 1
		peak = maxi(peak, used)
	return {"won": state.status() == PlayState.WON, "lost": state.status() == PlayState.LOST, "wrong": slips, "taps": taps, "peak": peak}


## Plays until it wins, as `try_heuristic`, slipping `profile["wrong"]` times in a first try on
## average and `profile["decay"]` times as much after each loss. Returns {tries, won, wrong}.
static func heuristic_until_win(level: LevelData, seed_value: int, profile: Dictionary, max_tries: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := float(level.screw_count())
	var wrong_total := 0
	for k: int in max_tries:
		var expected := float(profile["wrong"]) * pow(float(profile["decay"]), k)
		var r := try_heuristic(level, rng, expected / n)
		wrong_total += int(r["wrong"])
		if bool(r["won"]):
			return {"tries": k + 1, "won": true, "wrong": wrong_total}
	return {"tries": max_tries, "won": false, "wrong": wrong_total}


## The thinker's choice among the free screws that can go somewhere (see try_heuristic).
static func _heuristic_pick(state: PlayState, level: LevelData, rng: RandomNumberGenerator, n: int) -> int:
	var preview := state.preview()
	var best := -9999
	var tied: Array[int] = []
	for s: int in n:
		if not state.is_free(s):
			continue
		var dest := state.destination(s)
		if dest.x == PlayState.NONE:
			continue
		var score := 0
		if dest.x == PlayState.BOX:
			score = 100 if state.open_box(dest.y).y == 2 else 60
		elif preview.has(level.screw_colors[s]):
			score = 30
		if score > best:
			best = score
			tied.clear()
		if score == best:
			tied.append(s)
	return tied[rng.randi_range(0, tied.size() - 1)] if not tied.is_empty() else -1


## A person of a given skill: each tap it sees the planned move with chance `skill` and
## otherwise plays like the thinker. Skill 0 is the thinker, skill 1 the plan. It never slips.
## Returns {won, lost, taps, peak}.
static func try_mixed(level: LevelData, plan: PackedInt32Array, rng: RandomNumberGenerator, skill: float, session: BotSession = null) -> Dictionary:
	var state: PlayState = session.state if session != null else PlayState.start(level)
	var n := level.screw_count()
	var taps := 0
	var peak := 0
	var deviated := false
	var guard := 0
	while state.status() == PlayState.PLAYING and guard < n * 8:
		guard += 1
		var planned := _planned(state, plan, n) if not deviated else _guided(state, plan, n)
		var pick := planned
		if rng.randf() >= skill or planned < 0:
			pick = _heuristic_pick(state, level, rng, n)
			if pick != planned:
				deviated = true
		if pick < 0:
			break
		var ok := session.tap(pick).ok if session != null else state.tap(pick).ok
		if not ok:
			break
		taps += 1
		var used := 0
		for s: int in state.tray():
			if s >= 0:
				used += 1
		peak = maxi(peak, used)
	return {"won": state.status() == PlayState.WON, "lost": state.status() == PlayState.LOST, "taps": taps, "peak": peak}


## A person who starts with no idea of the solution (the thinker) and learns the level: after
## each loss it sees the planned move on `delta` more of the taps (skill 0, delta, 2 delta, ...,
## up to 1). It never slips. Returns {tries, won}; tries is max_tries when it never won.
static func learning_until_win(level: LevelData, plan: PackedInt32Array, seed_value: int, delta: float, max_tries: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for k: int in max_tries:
		var r := try_mixed(level, plan, rng, minf(1.0, delta * k))
		if bool(r["won"]):
			return {"tries": k + 1, "won": true}
	return {"tries": max_tries, "won": false}
