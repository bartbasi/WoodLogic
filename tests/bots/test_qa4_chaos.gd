# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends QaFlowCase
## The real level scene with animation ON, hit with everything at once: taps on any screw
## (covered, gone, refused, in the air), the three helpers and the Screwdriver mode, Pause and
## Resume and Retry in the middle of animations, a resize in the middle of a move, and Back from
## the flow. The picture must agree with the rules once it settles, and nothing may log an error
## (the runner fails the test if one is). ARCHITECTURE 5.3 and UX 6.

const Kit := preload("res://tests/level/kit.gd")


var _seen: Dictionary = {}


func _count(key: String) -> void:
	_seen[key] = int(_seen.get(key, 0)) + 1


func _hud() -> LevelHud:
	return scene().get("_hud") as LevelHud


func _touch(p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = p
	e.pressed = pressed
	scene().call("_gui_input", e)


func _press(id: String) -> void:
	var p := _hud().target_of(id).get_center()
	_touch(p, true)
	_touch(p, false)


func _chaos(level_number: int, seed_value: int, actions: int) -> void:
	start_real(level_number - 1)
	var save := save_node()
	for h: String in ["undo", "extra_slot", "screwdriver"]:
		save.add_helper(h, 3)
	check(await level_on(), "level %d is on" % level_number)
	scene().set_instant(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sizes: Array[Vector2] = [Vector2(360.0, 640.0), Vector2(412.0, 915.0), Vector2(360.0, 922.0), Vector2(533.0, 640.0), Vector2(320.0, 568.0)]
	var n := scene().get_level().screw_count()
	for i: int in actions:
		if flow.state != AppFlow.State.LEVEL and flow.state != AppFlow.State.PAUSE:
			# Won or lost: start over, as a player would.
			if flow.state == AppFlow.State.CLEAR:
				back()
				await frames(2)
				tap("Play")
				if not await level_on():
					return
				scene().set_instant(false)
			elif flow.state == AppFlow.State.LOST:
				tap("Retry")
				await frames(2)
			else:
				await frames(2)
			continue
		if flow.state == AppFlow.State.PAUSE:
			if rng.randf() < 0.5:
				tap("Resume")
			else:
				back()
			await frames(rng.randi_range(0, 2))
			continue
		var roll := rng.randf()
		if roll < 0.55:
			var r := scene().tap_screw(rng.randi_range(0, n - 1))
			_count("tap " + TapResult.REASON_NAMES[r.reason])
		elif roll < 0.62:
			_press("undo")
			_count("press undo")
		elif roll < 0.67:
			_press("extra_slot")
			_count("press extra_slot")
		elif roll < 0.72:
			_press("screwdriver")
			_count("press screwdriver")
		elif roll < 0.80 and scene().get("_driver"):
			var s := rng.randi_range(0, n - 1)
			scene().tap_at(scene().get_layout().gu_to_scene(scene().get_level().screw_center(s)))
			_count("driver tap")
		elif roll < 0.84:
			back()
		elif roll < 0.88:
			scene().hold_clock(true)
			await frames(rng.randi_range(0, 3))
			scene().hold_clock(false)
		elif roll < 0.92:
			scene().retry()
			_count("retry")
		elif roll < 0.96:
			scene().set_layout_size(sizes[rng.randi_range(0, sizes.size() - 1)])
			_count("resize")
		else:
			scene().tap_at(Vector2(rng.randf_range(0.0, 360.0), rng.randf_range(100.0, 560.0)))
		await frames(rng.randi_range(0, 3))
		var found := Kit.mismatches(scene(), false)
		check(found.is_empty(), "level %d action %d: the picture disagrees with the rules in flight: %s" % [level_number, i, str(Array(found).slice(0, 2))])
	# Let everything land, then compare exactly.
	if flow.state == AppFlow.State.PAUSE:
		tap("Resume")
	await frames(240)
	if flow.state == AppFlow.State.LEVEL:
		var settled := Kit.mismatches(scene(), true)
		check(settled.is_empty(), "level %d: settled, the picture disagrees with the rules: %s" % [level_number, str(Array(settled).slice(0, 3))])
	print("        chaos level %d: %s" % [level_number, str(_seen)])
	check(int(_seen.get("tap NONE", 0)) > 20, "level %d: some taps were accepted (%s)" % [level_number, str(_seen)])
	check(int(_seen.get("press undo", 0)) + int(_seen.get("press extra_slot", 0)) + int(_seen.get("press screwdriver", 0)) > 5, "level %d: the helpers were pressed" % level_number)


func test_chaos_on_an_easy_level() -> void:
	await _chaos(9, 11, 160)


func test_chaos_on_a_helper_level() -> void:
	await _chaos(25, 12, 160)


func test_chaos_on_a_hard_level() -> void:
	await _chaos(40, 13, 160)
