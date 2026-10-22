# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Solver
extends RefCounted
## Proves a level solvable and measures it (docs/ARCHITECTURE.md 4.4, GDD 6.4). Static entry
## points; each call works on its own instance, so any number may run on worker threads.
##
## The state. The screws on the board, the next queue index and the open boxes (color and
## count) say everything: a plank's pose depends only on which of its screws are left, and the
## tray's color counts are what left the board less what went into boxes. Where in the tray a
## screw sits, and which box position holds which box, never change what can happen next (R12
## and R20 only look at colors and counts), so the key keeps the boxes sorted. All of it is
## packed into one int exactly, without hashing, so two different states never share a key.
## The tray's color counts ride along beside the key.
##
## The search. A breadth first search by tray uses (a "0-1 BFS"): every state reachable with
## k tray uses is reached before any that needs k + 1, so the first win found has the fewest
## tray uses, and no state is expanded twice. That is the strongest pruning a lower bound
## could give without a heuristic: nothing that costs more than the best answer is ever looked
## at. Within one tray use count the search goes depth first, so it reaches a win quickly once
## one is possible. Moves are tried in a fixed order (by screw id), and max_states counts
## states, so a search stopped at max_states stops at the same point on every phone.
##
## One safe move is taken without branching. Say every box of a free screw's color has
## already arrived (none is left in the queue), and taking it can never cover anything (its
## plank covers nothing in any pose, or it is the plank's last screw, so the plank falls).
## Then some best solution takes it next, so the search takes it and tries nothing else from
## that state.
##
## The proof rests on two rules, so a change to either must send someone back here:
## - R12 (and R20): a screw goes to the fullest open box of its color, and tray screws jump into
##   a box only when it arrives. So a color's boxes fill in queue order, each with the next
##   three of that color's screws to leave the board.
## - I1 (no tray screw ever matches an open box with room). So a color's tray count is the
##   screws of that color off the board less those in its arrived boxes, at most three each.
## Why the move is safe: number each color's screws from 1 in the order they leave the board.
## By R12, screw k of a color belongs to that color's box number (k + 2) / 3, rounded down,
## and by I1 it costs a tray use exactly when that box has not arrived when it is taken.
## Taking the safe screw early leaves that numbering alone for every other color, and its own
## color's boxes have all arrived, so its color costs nothing either way. A box closes when it
## has arrived and its three screws are out, so moving one screw earlier makes boxes close,
## and later boxes arrive, no later than before. So no screw costs more and the tray never
## holds more. On the board the only change is a plank that covered nothing, or is gone
## sooner. Tests check the answer against a search without this rule and against a brute force
## search over PlayState.
##
## The trap measure. The share of TRAP_PLAYOUTS careless playouts that end lost. A careless
## player taps a random free screw that fits an open box when there is one, and otherwise a
## random free screw, which goes to the tray. The playouts use a RandomNumberGenerator with a
## fixed seed, so the measure is the same everywhere.
##
## The model here mirrors PlayState's rules for speed; tests replay every solution in
## PlayState and compare the two on many random games.

const TRAP_PLAYOUTS := 32
const TRAP_SEED := 20261019
const MOVE_BITS := 6
const MOVE_MASK := 63
## Planks with more holes than this use a slower path for covering (a plank's table holds an
## entry for every subset of its screws).
const TABLE_HOLES := 12
const MAX_KEY_BITS := 56

var _geo: BoardGeometry
var _n: int
var _ob_mask: int
var _colors: PackedInt32Array
var _queue: PackedInt32Array
var _q: int
var _k: int
var _slots: int
var _tray_size: int
## Covering by table: for plank p, _tab[_off[p] + (its screws still on the board, shifted
## down to bit 0)] is the mask of screws it covers.
var _small := PackedInt32Array()
var _big := PackedInt32Array()
var _first := PackedInt32Array()
var _low := PackedInt64Array()
var _off := PackedInt32Array()
var _tab := PackedInt64Array()
## Key layout: on board bits, then the next queue index, then one code per open box
## (0 empty, else 1 + color * slots + count), sorted.
var _qi_mask: int
var _box_shift: int
var _bb: int
var _bm: int
var _code_color := PackedInt32Array()
var _code_count := PackedInt32Array()
var _codes := PackedInt32Array()
## Tray counts: _tb bits per color, then the total at _tt_shift.
var _tb: int
var _tm: int
var _tt_shift: int
var _start_key: int
## Screw ids by smallest y, then smallest x (the novice policy's "topmost").
var _top_order := PackedInt32Array()
## For the safe move: per screw, its plank's screws; the screws whose plank covers nothing in
## any pose; and per next queue index, the screws whose color has no box left in the queue.
var _plank_bits := PackedInt64Array()
var _harmless_mask: int = 0
var _arrived := PackedInt64Array()
var _prune := true
## Checked by _search every GenerationStop.CHECK_EVERY states it expands; null for none.
var _stop: GenerationStop
## Set bits in a byte, highest first: the positions of byte value v are
## _byte_bits[_byte_off[v] .. _byte_off[v + 1] - 1].
var _byte_off := PackedInt32Array()
var _byte_bits := PackedInt32Array()
var _bit_index := {}
## Set by _child: the new tray counts, and whether the screw went to the tray.
var _child_aux: int
var _child_tray: bool


## Solves a level: the fewest tray uses, a solution and where its last tray use falls, the
## novice result and taps (GDD 6.4 and 6.4.1) and the trap measure. With max_tray_uses at 0 or
## more, the search stops (over_cap) once every solution is known to need more than that,
## which is all the generator needs to reject a level.
static func solve(level: LevelData, max_states: int, max_tray_uses: int = -1) -> SolveResult:
	var started := Time.get_ticks_usec()
	var result := SolveResult.new()
	var solver := Solver.new()
	if solver._setup(level):
		solver._search(max_states, result, max_tray_uses)
		solver._measure(result)
	@warning_ignore("integer_division")
	result.ms = (Time.get_ticks_usec() - started) / 1000
	return result


## Only the search for the fewest tray uses (no novice or trap), with or without the safe move
## rule and the cap. For the generator, and for tests and tools that check the rule. stop: once
## it is requested, the search ends as if it had reached max_states (complete false).
static func search_only(level: LevelData, max_states: int, prune: bool = true, max_tray_uses: int = -1, stop: GenerationStop = null) -> SolveResult:
	var started := Time.get_ticks_usec()
	var result := SolveResult.new()
	var solver := Solver.new()
	solver._prune = prune
	solver._stop = stop
	if solver._setup(level):
		solver._search(max_states, result, max_tray_uses)
	@warning_ignore("integer_division")
	result.ms = (Time.get_ticks_usec() - started) / 1000
	return result


## Adds the novice result (novice_won and novice_taps) and the trap measure to a result from
## search_only. With with_trap false, only the novice (one playout instead of
## TRAP_PLAYOUTS + 1; the generator measures the trap only for the level it keeps). Neither
## needs the search: both depend on the coloring alone.
static func measure(level: LevelData, result: SolveResult, with_trap: bool = true) -> void:
	var started := Time.get_ticks_usec()
	var solver := Solver.new()
	if solver._setup(level):
		solver._measure(result, with_trap)
	@warning_ignore("integer_division")
	result.ms += (Time.get_ticks_usec() - started) / 1000


func _measure(result: SolveResult, with_trap: bool = true) -> void:
	result.novice_taps = _playout(null)
	result.novice_won = result.novice_taps == _n
	if not with_trap:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = TRAP_SEED
	var lost := 0
	for _i: int in TRAP_PLAYOUTS:
		if _playout(rng) < _n:
			lost += 1
	result.trap = float(lost) / TRAP_PLAYOUTS


## Every state reachable from the start, for tests: {"states", "won", "lost", "complete"}.
## "lost" counts states where the level is lost (R23).
static func explore(level: LevelData, max_states: int) -> Dictionary:
	var solver := Solver.new()
	var out := {"states": 0, "won": 0, "lost": 0, "complete": false}
	if not solver._setup(level):
		return out
	var seen := {solver._start_key: true}
	var stack := PackedInt64Array([solver._start_key, 0])
	var won := 0
	var lost := 0
	while not stack.is_empty():
		var top := stack.size()
		var key := stack[top - 2]
		var aux := stack[top - 1]
		stack.resize(top - 2)
		var ob := key & solver._ob_mask
		if ob == 0:
			won += 1
			continue
		var loose := solver._free(ob)
		var moved := false
		for s: int in solver._n:
			if loose & (1 << s):
				var child := solver._child(key, aux, s)
				if child < 0:
					continue
				moved = true
				if not seen.has(child):
					seen[child] = true
					stack.append(child)
					stack.append(solver._child_aux)
		if not moved:
			lost += 1
		if seen.size() >= max_states:
			out["states"] = seen.size()
			return out
	out["states"] = seen.size()
	out["won"] = won
	out["lost"] = lost
	out["complete"] = true
	return out


func _setup(level: LevelData) -> bool:
	if level == null or level.geometry == null or not level.has_colors():
		push_error("Solver needs a level with colors and a queue")
		return false
	_geo = level.geometry
	_n = _geo.screw_count
	if _n > BoardGeometry.MAX_SCREWS:
		push_error("Solver: too many screws")
		return false
	_ob_mask = (1 << _n) - 1
	_colors = level.screw_colors
	_queue = level.queue
	_q = _queue.size()
	_k = Tuning.open_boxes
	_slots = Tuning.box_slots
	_tray_size = level.tray_size
	var colors := 1
	for c: int in _colors:
		colors = maxi(colors, c + 1)
	for c: int in _queue:
		colors = maxi(colors, c + 1)
	# Covering tables.
	var planks := _geo.plank_count
	_first.resize(planks)
	_low.resize(planks)
	_off.resize(planks)
	for p: int in planks:
		var holes := _geo.plank_holes[p]
		_first[p] = _geo.plank_first[p]
		if holes > TABLE_HOLES:
			_big.append(p)
			_off[p] = -1
			continue
		_small.append(p)
		_off[p] = _tab.size()
		_low[p] = (1 << holes) - 1
		for m: int in (1 << holes):
			_tab.append(_geo.pose_cover(p, m << _first[p]))
	# Key layout.
	var queue_bits := _bits(_q)
	_qi_mask = (1 << queue_bits) - 1
	_box_shift = _n + queue_bits
	_bb = _bits(colors * _slots)
	_bm = (1 << _bb) - 1
	_tb = _bits(_tray_size)
	_tm = (1 << _tb) - 1
	_tt_shift = colors * _tb
	if _box_shift + _k * _bb > MAX_KEY_BITS or _tt_shift + _tb > 62:
		push_error("Solver: the level is too big for one key")
		return false
	_code_color.resize(_bm + 1)
	_code_count.resize(_bm + 1)
	_code_color.fill(-1)
	_code_count.fill(-1)
	for c: int in colors:
		for count: int in _slots:
			_code_color[1 + c * _slots + count] = c
			_code_count[1 + c * _slots + count] = count
	_codes.resize(_k)
	var next := 0
	for j: int in _k:
		if next < _q:
			_codes[j] = 1 + _queue[next] * _slots
			next += 1
		else:
			_codes[j] = 0
	_start_key = _pack(_ob_mask, next)
	# Topmost first: smallest y, then smallest x.
	var order: Array[int] = []
	for s: int in _n:
		order.append(s)
	var xs := _geo.screw_x
	var ys := _geo.screw_y
	order.sort_custom(func(a: int, b: int) -> bool:
		if ys[a] != ys[b]:
			return ys[a] < ys[b]
		if xs[a] != xs[b]:
			return xs[a] < xs[b]
		return a < b)
	_top_order = PackedInt32Array(order)
	# The safe move.
	_plank_bits.resize(_n)
	for t: int in _n:
		var p := _geo.screw_plank[t]
		_plank_bits[t] = _geo.plank_mask[p]
		var covers := _geo.cover_fixed[p]
		for u: int in range(_geo.plank_first[p], _geo.plank_first[p] + _geo.plank_holes[p]):
			covers |= _geo.cover_hang[u]
		if covers == 0:
			_harmless_mask |= 1 << t
	var last_box := PackedInt32Array()
	last_box.resize(colors)
	last_box.fill(-1)
	for i: int in _q:
		last_box[_queue[i]] = i
	_arrived.resize(_q + 1)
	for qi: int in _q + 1:
		var mask := 0
		for t: int in _n:
			if last_box[_colors[t]] < qi:
				mask |= 1 << t
		_arrived[qi] = mask
	# Bit tables.
	for v: int in 256:
		_byte_off.append(_byte_bits.size())
		for b: int in range(7, -1, -1):
			if v & (1 << b):
				_byte_bits.append(b)
	_byte_off.append(_byte_bits.size())
	for t: int in 63:
		_bit_index[1 << t] = t
	return true


## The layered search described at the top.
## From the start, or from another state (from_key and from_aux, as _child makes them; then the
## solution and last_tray_use are not filled in, and fewest_tray_uses counts from there).
func _search(max_states: int, result: SolveResult, max_tray_uses: int = -1, from_key: int = -1, from_aux: int = 0) -> void:
	var root := _start_key if from_key < 0 else from_key
	var root_aux := 0 if from_key < 0 else from_aux
	# Locals are faster than members in GDScript's inner loops.
	var n := _n
	var ob_mask := _ob_mask
	var qi_mask := _qi_mask
	var box_shift := _box_shift
	var bb := _bb
	var bm := _bm
	var slots := _slots
	var q := _q
	var queue := _queue
	var colors := _colors
	var code_color := _code_color
	var code_count := _code_count
	var tb := _tb
	var tm := _tm
	var tt_shift := _tt_shift
	var tray_size := _tray_size
	var small := _small
	var tab := _tab
	var off := _off
	var first := _first
	var low := _low
	var has_big := not _big.is_empty()
	var prune := _prune
	var arrived := _arrived
	var harmless := _harmless_mask
	var plank_bits := _plank_bits
	var bit_index := _bit_index
	var byte_off := _byte_off
	var byte_bits := _byte_bits
	var bytes := (n + 7) >> 3
	var two := _k == 2
	var stop := _stop
	var pops := 0
	var visited := {root: -1}
	var pending := {}
	var stack := PackedInt64Array([root, root_aux])
	var later := PackedInt64Array()
	var cost := 0
	var win := -1
	if root & ob_mask == 0:
		win = root
	# On the last tray use count the cap allows, tray moves are not followed at all.
	var skipped := false
	while win < 0:
		var last_layer := max_tray_uses >= 0 and cost >= max_tray_uses
		while not stack.is_empty() and win < 0:
			var top := stack.size()
			var key := stack[top - 2]
			var aux := stack[top - 1]
			stack.resize(top - 2)
			var ob := key & ob_mask
			var cover := 0
			for p: int in small:
				cover |= tab[off[p] + ((ob >> first[p]) & low[p])]
			if has_big:
				for p: int in _big:
					cover |= _geo.pose_cover(p, ob & _geo.plank_mask[p])
			var loose := ob & ~cover
			var qi := (key >> n) & qi_mask
			if prune:
				var candidates := loose & arrived[qi]
				if candidates != 0:
					var safe := candidates & harmless
					var rest := candidates & ~harmless
					while rest != 0:
						var b := rest & -rest
						if ob & plank_bits[bit_index[b]] == b:
							safe |= b
						rest ^= b
					if safe != 0:
						loose = safe & -safe
			var bx := key >> box_shift
			var code0 := bx & bm
			var code1 := (bx >> bb) & bm
			var color0 := code_color[code0]
			var color1 := code_color[code1]
			var tray_full := (aux >> tt_shift) >= tray_size
			var link_base := key << MOVE_BITS
			var chunk := bytes - 1
			while chunk >= 0 and win < 0:
				var v := (loose >> (chunk << 3)) & 255
				if v != 0:
					var base := chunk << 3
					for k: int in range(byte_off[v], byte_off[v + 1]):
						var s := base + byte_bits[k]
						var bit := 1 << s
						var child := -1
						var child_aux := aux
						var to_tray := false
						if two:
							var c := colors[s]
							if c == color0 or c == color1:
								var use0 := c == color0 and (c != color1 or code_count[code0] >= code_count[code1])
								var code := code0 if use0 else code1
								var other := code1 if use0 else code0
								var next := qi
								if code_count[code] + 1 < slots:
									code += 1
								else:
									# The box closes; queue boxes arrive and take their tray
									# screws until one is not full.
									code = 0
									while next < q:
										var nc := queue[next]
										next += 1
										var take := mini((child_aux >> (nc * tb)) & tm, slots)
										child_aux -= (take << (nc * tb)) + (take << tt_shift)
										if take < slots:
											code = 1 + nc * slots + take
											break
								child = (ob & ~bit) | (next << n) | ((mini(code, other) | (maxi(code, other) << bb)) << box_shift)
							elif not tray_full:
								child = key & ~bit
								child_aux = aux + (1 << (c * tb)) + (1 << tt_shift)
								to_tray = true
						else:
							child = _child(key, aux, s)
							child_aux = _child_aux
							to_tray = _child_tray
						if child < 0 or visited.has(child):
							continue
						if to_tray:
							if last_layer:
								skipped = true
								continue
							if not pending.has(child):
								pending[child] = link_base | s
								later.append(child)
								later.append(child_aux)
						else:
							visited[child] = link_base | s
							if child & ob_mask == 0:
								win = child
								break
							stack.append(child)
							stack.append(child_aux)
				chunk -= 1
			pops += 1
			if win < 0 and (visited.size() + pending.size() >= max_states or (stop != null and pops % GenerationStop.CHECK_EVERY == 0 and stop.is_requested())):
				result.states = visited.size() + pending.size()
				result.complete = false
				return
		if win >= 0:
			break
		if later.is_empty():
			result.states = visited.size()
			result.complete = true
			result.over_cap = skipped
			return
		cost += 1
		for i: int in range(0, later.size(), 2):
			var key := later[i]
			if not visited.has(key):
				visited[key] = pending[key]
				stack.append(key)
				stack.append(later[i + 1])
		pending.clear()
		later.clear()
	var moves := PackedInt32Array()
	var at := win
	var link: int = visited[at]
	while link >= 0:
		moves.append(link & MOVE_MASK)
		at = link >> MOVE_BITS
		link = visited[at]
	moves.reverse()
	result.solved = true
	result.complete = true
	result.fewest_tray_uses = cost
	if from_key < 0:
		result.solution = moves
		var stats := _tray_stats(moves)
		result.last_tray_use = stats.x
		result.peak_tray = stats.y
	result.states = visited.size() + pending.size()


## The free screws among those on the board (R7, R10).
func _free(ob: int) -> int:
	var cover := 0
	for p: int in _small:
		cover |= _tab[_off[p] + ((ob >> _first[p]) & _low[p])]
	for p: int in _big:
		cover |= _geo.pose_cover(p, ob & _geo.plank_mask[p])
	return ob & ~cover


## The state after taking screw s (R12, R13, R18 to R21), or -1 if it has nowhere to go
## (R25). Sets _child_aux to the new tray counts and _child_tray to whether it went to the
## tray.
func _child(key: int, aux: int, s: int) -> int:
	var c := _colors[s]
	var bx := key >> _box_shift
	var best := -1
	var best_count := -1
	for j: int in _k:
		var code := (bx >> (j * _bb)) & _bm
		_codes[j] = code
		if code != 0 and _code_color[code] == c and _code_count[code] > best_count:
			best = j
			best_count = _code_count[code]
	if best < 0:
		if (aux >> _tt_shift) >= _tray_size:
			return -1
		_child_aux = aux + (1 << (c * _tb)) + (1 << _tt_shift)
		_child_tray = true
		return key & ~(1 << s)
	_child_tray = false
	var qi := (key >> _n) & _qi_mask
	var new_aux := aux
	var code := 0
	if best_count + 1 < _slots:
		code = 1 + c * _slots + best_count + 1
	else:
		# The box closes; queue boxes arrive and take their tray screws until one is not full.
		while qi < _q:
			var next := _queue[qi]
			qi += 1
			var take := mini((new_aux >> (next * _tb)) & _tm, _slots)
			new_aux -= (take << (next * _tb)) + (take << _tt_shift)
			if take < _slots:
				code = 1 + next * _slots + take
				break
	_codes[best] = code
	_child_aux = new_aux
	return _pack((key & _ob_mask) & ~(1 << s), qi)


## Packs a state, sorting the box codes in _codes first.
func _pack(ob: int, qi: int) -> int:
	for i: int in range(1, _k):
		var v := _codes[i]
		var j := i - 1
		while j >= 0 and _codes[j] > v:
			_codes[j + 1] = _codes[j]
			j -= 1
		_codes[j + 1] = v
	var bx := 0
	for j: int in _k:
		bx |= _codes[j] << (j * _bb)
	return ob | (qi << _n) | (bx << _box_shift)


## True if screw s fits an open box.
func _fits(key: int, s: int) -> bool:
	var c := _colors[s]
	var bx := key >> _box_shift
	for j: int in _k:
		var code := (bx >> (j * _bb)) & _bm
		if code != 0 and _code_color[code] == c:
			return true
	return false


## Plays one game to the end and returns the taps it made: the screw count if it won,
## otherwise the taps before the level was lost (the tap after which R23 holds is the last one
## counted). An empty board is a win (R3 and I1 leave nothing in the tray then). With no rng,
## the novice policy (GDD 6.4): the topmost free screw that fits an open box, otherwise the
## topmost free screw. With an rng, the careless player of the trap measure.
func _playout(rng: RandomNumberGenerator, from_key: int = -1, from_aux: int = 0) -> int:
	var key := _start_key if from_key < 0 else from_key
	var aux := 0 if from_key < 0 else from_aux
	var taps := 0
	var fits := PackedInt32Array()
	var others := PackedInt32Array()
	while key & _ob_mask != 0:
		var pick := -1
		if rng == null:
			pick = _novice_pick(key, aux)
			if pick < 0:
				return taps
		else:
			var loose := _free(key & _ob_mask)
			fits.clear()
			others.clear()
			for s: int in _n:
				if loose & (1 << s):
					if _fits(key, s):
						fits.append(s)
					else:
						others.append(s)
			if not fits.is_empty():
				pick = fits[rng.randi_range(0, fits.size() - 1)]
			elif (aux >> _tt_shift) >= _tray_size:
				return taps
			else:
				pick = others[rng.randi_range(0, others.size() - 1)]
		key = _child(key, aux, pick)
		aux = _child_aux
		taps += 1
	return taps


## The novice's tap in this state (GDD 6.4): the topmost free screw that fits an open box,
## otherwise the topmost free screw if the tray has room; -1 when the level is lost (R23).
func _novice_pick(key: int, aux: int) -> int:
	var loose := _free(key & _ob_mask)
	var first := -1
	for s: int in _top_order:
		if loose & (1 << s) == 0:
			continue
		if first < 0:
			first = s
		if _fits(key, s):
			return s
	if (aux >> _tt_shift) >= _tray_size:
		return -1
	return first


## Report only: how forgiving a level is and how far ahead it makes a player think, measured
## along a solution of it (see ProbeResult). Each search is the fewest tray use search from
## that state with max_states, uncapped; a state searched once is not searched again. trials
## random sets of wrong taps per point and count, from a RandomNumberGenerator seeded by
## seed_value, so the same call gives the same answer everywhere.
static func probe(level: LevelData, solution: PackedInt32Array, trials: int, max_states: int, seed_value: int) -> ProbeResult:
	var started := Time.get_ticks_usec()
	var out := ProbeResult.new()
	var solver := Solver.new()
	if solver._setup(level) and solution.size() == solver._n:
		solver._probe(solution, trials, max_states, seed_value, out)
	@warning_ignore("integer_division")
	out.ms = (Time.get_ticks_usec() - started) / 1000
	return out


## For tests and tools: after these taps from the start, can the level still be won? 1 yes, 0
## no (also when a tap is refused or the taps already lost it), -1 not proven within max_states.
static func winnable_after(level: LevelData, taps: PackedInt32Array, max_states: int) -> int:
	var solver := Solver.new()
	if not solver._setup(level):
		return -1
	var key := solver._start_key
	var aux := 0
	for s: int in taps:
		if key & (1 << s) == 0 or solver._free(key & solver._ob_mask) & (1 << s) == 0:
			return 0
		key = solver._child(key, aux, s)
		if key < 0:
			return 0
		aux = solver._child_aux
	return solver._winnable(key, aux, max_states, {}, ProbeResult.new())


func _probe(solution: PackedInt32Array, trials: int, max_states: int, seed_value: int, out: ProbeResult) -> void:
	# The states along the solution: after i taps, keys[i] and auxes[i].
	var keys := PackedInt64Array([_start_key])
	var auxes := PackedInt64Array([0])
	for s: int in solution:
		var key := _child(keys[-1], auxes[-1], s)
		if key < 0:
			return
		keys.append(key)
		auxes.append(_child_aux)
	# Search results by state: 1 winnable, 0 not, -1 not proven. (The key alone is the state:
	# the tray counts follow from it.)
	var known := {}
	var m := ProbeResult.MAX_MISTAKES
	for p: int in ProbeResult.POINTS:
		@warning_ignore("integer_division")
		var at: int = _n * p / ProbeResult.POINTS
		for k: int in range(1, m + 1):
			var rng := RandomNumberGenerator.new()
			rng.seed = Seeds.derive(seed_value, p, k)
			var slot := p * m + k - 1
			for _t: int in trials:
				var answer := _mistake_trial(keys[at], auxes[at], k, rng, max_states, known, out)
				if answer > 0:
					out.won[slot] += 1
				elif answer == 0:
					out.lost[slot] += 1
				elif answer == -1:
					out.unknown[slot] += 1
				else:
					out.skipped[slot] += 1
	# Lookahead: the novice's move along the solution.
	for i: int in solution.size():
		var g := _novice_pick(keys[i], auxes[i])
		if g < 0:
			continue
		out.greedy_states += 1
		if g == solution[i]:
			continue
		out.greedy_differs += 1
		var key := _child(keys[i], auxes[i], g)
		var aux := _child_aux
		var answer := _winnable(key, aux, max_states, known, out)
		if answer == 0:
			out.greedy_fatal += 1
			out.trap_delays.append(_playout(null, key, aux))
		elif answer < 0:
			out.greedy_unknown += 1
	for i: int in auxes.size():
		out.peak_tray = maxi(out.peak_tray, auxes[i] >> _tt_shift)
	# The novice's point of no return: the first state on its path with no win left. The start
	# can be won and a stuck state cannot, and winnability never comes back along a path, so a
	# binary search between them.
	var path_keys := PackedInt64Array([_start_key])
	var path_auxes := PackedInt64Array([0])
	while path_keys[-1] & _ob_mask != 0:
		var g := _novice_pick(path_keys[-1], path_auxes[-1])
		if g < 0:
			break
		path_keys.append(_child(path_keys[-1], path_auxes[-1], g))
		path_auxes.append(_child_aux)
	out.novice_taps = path_keys.size() - 1
	if path_keys[-1] & _ob_mask == 0:
		return
	var lo := 0
	var hi := path_keys.size() - 1
	while hi - lo > 1:
		@warning_ignore("integer_division")
		var mid := (lo + hi) / 2
		var answer := _winnable(path_keys[mid], path_auxes[mid], max_states, known, out)
		if answer == 0:
			hi = mid
		else:
			# Not proven either way counts as winnable, so no_return is an upper bound.
			out.no_return_unknown = out.no_return_unknown or answer < 0
			lo = mid
	out.no_return = hi
	out.hidden = out.novice_taps - hi


## One mistake trial (see ProbeResult): k wrong taps in a row from this state, picked by rng,
## then a search. 1 still winnable, 0 not (or the wrong taps lost the level), -1 not proven,
## -2 skipped (k wrong taps could not be made).
func _mistake_trial(key: int, aux: int, k: int, rng: RandomNumberGenerator, max_states: int, known: Dictionary, out: ProbeResult) -> int:
	var made := 0
	while made < k:
		var loose := _free(key & _ob_mask)
		var fit := false
		var wrong := PackedInt32Array()
		for s: int in _n:
			if loose & (1 << s):
				if _fits(key, s):
					fit = true
				else:
					wrong.append(s)
		var full := (aux >> _tt_shift) >= _tray_size
		if not fit and full:
			return 0
		if not fit or full or wrong.is_empty():
			return -2
		key = _child(key, aux, wrong[rng.randi_range(0, wrong.size() - 1)])
		aux = _child_aux
		made += 1
	return _winnable(key, aux, max_states, known, out)


## Report only: from the state after `at` taps of the solution, `trials` sets of k wrong taps in
## a row, each then searched as in probe. Vector4i(still winnable, not, not proven, skipped).
static func mistakes_at(level: LevelData, solution: PackedInt32Array, at: int, k: int, trials: int, max_states: int, seed_value: int) -> Vector4i:
	var counts := Vector4i()
	var solver := Solver.new()
	if not solver._setup(level) or at < 0 or at > solution.size():
		return counts
	var key := solver._start_key
	var aux := 0
	for i: int in at:
		key = solver._child(key, aux, solution[i])
		if key < 0:
			return counts
		aux = solver._child_aux
	var rng := RandomNumberGenerator.new()
	rng.seed = Seeds.derive(seed_value, at, k)
	var known := {}
	var out := ProbeResult.new()
	for _t: int in trials:
		var answer := solver._mistake_trial(key, aux, k, rng, max_states, known, out)
		if answer > 0:
			counts.x += 1
		elif answer == 0:
			counts.y += 1
		elif answer == -1:
			counts.z += 1
		else:
			counts.w += 1
	return counts


## Report only: the screws in the tray after each tap of these taps (index i: after i + 1 taps);
## stops at the first tap that is not a legal move.
static func tray_loads(level: LevelData, taps: PackedInt32Array) -> PackedInt32Array:
	var loads := PackedInt32Array()
	var solver := Solver.new()
	if not solver._setup(level):
		return loads
	var key := solver._start_key
	var aux := 0
	for s: int in taps:
		key = solver._child(key, aux, s)
		if key < 0:
			break
		aux = solver._child_aux
		loads.append(aux >> solver._tt_shift)
	return loads


## 1 if the level can still be won from this state, 0 if the search proves it cannot, -1 if
## the search stopped at max_states.
func _winnable(key: int, aux: int, max_states: int, known: Dictionary, out: ProbeResult) -> int:
	if known.has(key):
		return known[key]
	var r := SolveResult.new()
	_search(max_states, r, -1, key, aux)
	out.searches += 1
	var answer := 1 if r.solved else (0 if r.complete else -1)
	known[key] = answer
	return answer


## Along these moves from the start: Vector2i(the tap number, from 1, of the last tap that
## sends its screw to the tray, or 0; the most screws in the tray at once, after each tap's
## jumps into arriving boxes).
func _tray_stats(moves: PackedInt32Array) -> Vector2i:
	var key := _start_key
	var aux := 0
	var last := 0
	var peak := 0
	for i: int in moves.size():
		key = _child(key, aux, moves[i])
		aux = _child_aux
		if key < 0:
			return Vector2i(0, peak)
		if _child_tray:
			last = i + 1
		peak = maxi(peak, aux >> _tt_shift)
	return Vector2i(last, peak)


## Bits needed to hold every value from 0 to value (at least 1).
static func _bits(value: int) -> int:
	var b := 1
	while (1 << b) <= value:
		b += 1
	return b
