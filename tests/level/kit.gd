# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends RefCounted
## Helpers the level suites share: making a scene, and comparing what the scene shows with the
## logic model.

const SCENE := "res://src/level/level_scene.tscn"
## How far a drawn point may be from the logic's, in grid units. The logic rounds to 1/1024.
const TOLERANCE := 0.02


## A level scene in the tree, laid out for a 360 x 640 screen, playing `level`.
static func make_scene(test: TestCase, level: LevelData, instant: bool) -> LevelScene:
	var scene := (load(SCENE) as PackedScene).instantiate() as LevelScene
	test.add_node(scene)
	scene.set_layout_size(Vector2(360.0, 640.0))
	scene.set_instant(instant)
	scene.play(level, false)
	return scene


## The level with this number as the app flow gets it: the tutorial file or the generator.
static func numbered(n: int) -> GeneratedLevel:
	return LevelCatalog.get_level(LevelData.NUMBERED, n, "")


## The first numbered level of a tier at or after `from`.
static func level_of_tier(tier: int, from: int) -> int:
	var n := from
	while Tuning.tier_for_level(n) != tier:
		n += 1
	return n


## Every way the scene's picture differs from the model. Empty when they agree (ARCHITECTURE 5.3).
## With `settled` false only what the view believes is compared (where each screw is meant to
## be, what the boxes and tray hold), not where things are drawn right now, so it also works
## while screws are still in the air.
static func mismatches(scene: LevelScene, settled: bool = true) -> PackedStringArray:
	var out := PackedStringArray()
	var state := scene.get_state()
	var level := scene.get_level()
	var snap := scene.debug_snapshot()
	var tray := state.tray()
	var screws: Dictionary = snap["screws"]
	var places: Dictionary = snap["places"]
	var covered: Dictionary = snap["covered"]
	var shown: Dictionary = snap["shown"]
	var wells: Array = snap["well_centers"]
	var slots: Array = snap["slot_centers"]
	for s: int in level.screw_count():
		var at: Vector2 = screws[s]
		var want_place := "closed"
		var want_at := at
		if state.is_on_board(s):
			want_place = "board"
			want_at = level.screw_center(s)
			if covered[s] == state.is_free(s):
				out.append("screw %d is drawn %s but is %s" % [s, "covered" if covered[s] else "free", "free" if state.is_free(s) else "covered"])
		elif tray.has(s):
			want_place = "tray"
			want_at = slots[tray.find(s)]
		else:
			for pos: int in wells.size():
				var inside := state.box_screws(pos)
				if inside.has(s):
					want_place = "box"
					want_at = (wells[pos] as Array)[inside.find(s)]
		if places[s] != want_place:
			out.append("screw %d is placed in the %s, the model says %s" % [s, places[s], want_place])
		elif settled and want_place != "closed" and at.distance_to(want_at) > TOLERANCE:
			out.append("screw %d is drawn at %s, expected %s" % [s, str(at), str(want_at)])
		if settled and shown[s] != (want_place != "closed"):
			out.append("screw %d visible = %s in the %s" % [s, str(shown[s]), want_place])
	var planks: Dictionary = snap["planks"]
	var planks_shown: Dictionary = snap["planks_shown"]
	for p: int in level.planks.size():
		var fallen := state.plank_state(p) == PlayState.FALLEN
		if not settled:
			continue
		if planks_shown[p] == fallen:
			out.append("plank %d visible = %s but its state is %d" % [p, str(planks_shown[p]), state.plank_state(p)])
			continue
		if fallen:
			continue
		var drawn: PackedVector2Array = planks[p]
		var want := state.plank_outline(p)
		if drawn.size() != want.size():
			out.append("plank %d outline has %d points, expected %d" % [p, drawn.size(), want.size()])
			continue
		for i: int in drawn.size():
			if drawn[i].distance_to(want[i]) > TOLERANCE:
				out.append("plank %d vertex %d is at %s, expected %s" % [p, i, str(drawn[i]), str(want[i])])
				break
	var boxes: Array = snap["boxes"]
	for pos: int in boxes.size():
		var box: Dictionary = boxes[pos]
		if box["color"] != state.open_box(pos).x:
			out.append("box %d color %d, expected %d" % [pos, box["color"], state.open_box(pos).x])
		if box["screws"] != state.box_screws(pos):
			out.append("box %d holds %s, expected %s" % [pos, str(box["screws"]), str(state.box_screws(pos))])
		if settled and box["shown"] != (state.open_box(pos).x >= 0):
			out.append("box %d shown = %s" % [pos, str(box["shown"])])
	if snap["preview"] != state.preview():
		out.append("preview %s, expected %s" % [str(snap["preview"]), str(state.preview())])
	if snap["tray"] != tray:
		out.append("tray %s, expected %s" % [str(snap["tray"]), str(tray)])
	if snap["fixes"] != 0:
		out.append("the safety net had to correct the view %d times" % snap["fixes"])
	return out


## Plays a level with random taps on free screws until it is won or lost, with no scene. Returns
## the taps tried (refused ones included, they change nothing; covered screws are never tapped)
## and how it ended.
static func random_game(level: LevelData, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var state := PlayState.start(level)
	var taps := PackedInt32Array()
	while state.status() == PlayState.PLAYING and taps.size() < 400:
		var free: Array[int] = []
		for s: int in level.screw_count():
			if state.is_free(s):
				free.append(s)
		var pick: int = free[rng.randi_range(0, free.size() - 1)]
		taps.append(pick)
		state.tap(pick)
	return {"taps": taps, "status": state.status()}


## A level and a tap list that ends in a loss, found by playing the stored levels at random.
static func find_loss() -> Dictionary:
	for tier: int in [10, 9, 8, 7]:
		for g: GeneratedLevel in LevelCatalog.fallback[tier - 1]:
			for seed_value: int in 40:
				var game := random_game(g.level, seed_value)
				if game["status"] == PlayState.LOST:
					return {"level": g.level, "taps": game["taps"]}
	return {}


## Waits (in frames) until the scene has no animation left, up to `limit` frames.
static func settle(test: TestCase, scene: LevelScene, limit: int = 600) -> int:
	var used := 0
	while scene.debug_snapshot()["busy"] > 0 and used < limit:
		await test.frames(1)
		used += 1
	return used


## A stored level whose best play uses the tray, with its solution.
static func tray_level() -> GeneratedLevel:
	for tier: int in [7, 8, 9, 10]:
		for g: GeneratedLevel in LevelCatalog.fallback[tier - 1]:
			if g.solve.fewest_tray_uses > 0:
				return g
	return null
