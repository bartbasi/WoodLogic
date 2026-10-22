# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends QaFlowCase
## A fuzz of the whole app flow over the real level scene: random presses on whatever buttons
## the current screen has, Back, losing and regaining focus, starting levels from anywhere, taps
## on the board, window resizes. After every action the flow must be in a known state with a
## screen or a level showing, and progress may only grow (the one erase button is never
## pressed). The runner fails the test on any engine or script error.

const SKIP_LABELS: Array[String] = ["Erase everything"]


func _buttons(root_node: Node) -> Array[UiButton]:
	var out: Array[UiButton] = []
	if root_node == null:
		return out
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is UiButton:
			var b := node as UiButton
			if b.is_visible_in_tree() and not b.disabled and not SKIP_LABELS.has(b.label_text):
				out.append(b)
	return out


func _check_state(step: int, last_highest: int) -> int:
	var known := [AppFlow.State.TITLE, AppFlow.State.MENU, AppFlow.State.LOADING, AppFlow.State.LEVEL, AppFlow.State.PAUSE, AppFlow.State.CLEAR, AppFlow.State.LOST]
	check(known.has(flow.state), "step %d: the flow is in state %d" % [step, flow.state])
	match flow.state:
		AppFlow.State.TITLE, AppFlow.State.MENU, AppFlow.State.PAUSE, AppFlow.State.CLEAR, AppFlow.State.LOST, AppFlow.State.LOADING:
			check(flow.screen != null, "step %d: state %d has a screen" % [step, flow.state])
		AppFlow.State.LEVEL:
			check(flow.level_scene != null and flow.level_scene.visible, "step %d: a level is showing" % step)
	var highest: int = save_node().highest_cleared()
	check(highest >= last_highest, "step %d: progress went from %d back to %d" % [step, last_highest, highest])
	check(int(save_node().next_level()) >= 1, "step %d: next level at least 1" % step)
	return highest


func _fuzz(seed_value: int, steps: int) -> void:
	start_real(22)
	for h: String in ["undo", "extra_slot", "screwdriver"]:
		save_node().add_helper(h, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sizes: Array[Vector2i] = [Vector2i(360, 640), Vector2i(360, 800), Vector2i(360, 922), Vector2i(533, 640), Vector2i(480, 640)]
	var highest := int(save_node().highest_cleared())
	var seen := {}
	for step: int in steps:
		var roll := rng.randf()
		var kind := "idle"
		if roll < 0.5:
			var list := _buttons(flow.overlay) if flow.overlay != null else _buttons(flow.screen)
			if not list.is_empty():
				var b := list[rng.randi_range(0, list.size() - 1)]
				kind = "press " + b.label_text
				b.pressed.emit()
			elif flow.state == AppFlow.State.LEVEL and flow.level_scene != null:
				kind = "tap"
				var n := (flow.level_scene as LevelScene).get_level().screw_count()
				(flow.level_scene as LevelScene).tap_screw(rng.randi_range(0, n - 1))
		elif roll < 0.62:
			kind = "back"
			back()
		elif roll < 0.70 and flow.state == AppFlow.State.LEVEL:
			kind = "tap"
			var n2 := (flow.level_scene as LevelScene).get_level().screw_count()
			(flow.level_scene as LevelScene).tap_screw(rng.randi_range(0, n2 - 1))
		elif roll < 0.76:
			kind = "focus out and in"
			flow.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			flow.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		elif roll < 0.82:
			kind = "play a level"
			flow.play_number(rng.randi_range(1, 40))
		elif roll < 0.86:
			kind = "daily"
			flow.play_daily()
		elif roll < 0.89:
			kind = "relaxed"
			flow.play_relaxed(["easy", "medium", "hard"][rng.randi_range(0, 2)])
		elif roll < 0.93:
			kind = "resize"
			tree.root.size = sizes[rng.randi_range(0, sizes.size() - 1)]
		elif roll < 0.97:
			kind = "menu"
			flow.show_menu(["title", "map", "stats", "info", "settings", "about", "relaxed"][rng.randi_range(0, 6)])
		else:
			kind = "to title"
			flow.quit_to_title()
		seen[kind.split(" ")[0]] = int(seen.get(kind.split(" ")[0], 0)) + 1
		# Let a level that is being made arrive, without spinning thousands of frames.
		if flow.state == AppFlow.State.LOADING:
			await until(func() -> bool: return flow.state != AppFlow.State.LOADING, 8000)
		else:
			await frames(rng.randi_range(0, 2))
		highest = _check_state(step, highest)
	tree.root.size = Vector2i(360, 640)
	print("        fuzz seed %d: %s" % [seed_value, str(seen)])
	check(seen.size() >= 6, "the fuzz made many kinds of move: %s" % str(seen))


func test_fuzz_one() -> void:
	await _fuzz(101, 350)


func test_fuzz_two() -> void:
	await _fuzz(202, 350)


func test_fuzz_three() -> void:
	await _fuzz(303, 500)
