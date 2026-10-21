# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name QaFlowCase
extends FlowCase
## Helpers for the Phase 4 edge case suites: the app flow over the REAL level scene, playing a
## level by its solver solution, reading what was saved. Links never open anything (FlowCase
## records the addresses) and Save is the runner's temporary one.


## Starts the app over the real level scene with `cleared` numbered levels already won.
func start_real(cleared: int = 0, today: String = "2026-10-21", met: bool = true) -> void:
	Links.opener = func(address: String) -> Variant:
		opened.append(address)
		return OK
	var save := save_node()
	save.erase_all()
	for n: int in range(1, cleared + 1):
		var level := LevelCatalog.get_level(LevelData.NUMBERED, n, "").level
		save.record_win(level, 9000, Vector3i(1, 1, 1))
	if met:
		for h: String in ["undo", "extra_slot", "screwdriver"]:
			if cleared + 1 >= int(Tuning.helpers[h]["first_level"]):
				save.mark_helper_met(h, int(Tuning.helpers[h]["free"]))
	flow = FLOW.instantiate() as AppFlow
	flow.today_override = today
	flow.quit_handler = func() -> void: quit_calls += 1
	add_node(flow)


func scene() -> LevelScene:
	return flow.level_scene as LevelScene


## Waits until a level is on the screen (pressing Play on the title if that is where the app
## starts) and puts the scene in instant mode (no animation). Times out after 8 s.
func level_on() -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 8000:
		if flow.state == AppFlow.State.TITLE and flow.screen != null and flow.screen.find_button("Play") != null:
			flow.screen.find_button("Play").pressed.emit()
		if flow.state == AppFlow.State.LEVEL and scene() != null:
			scene().set_instant(true)
			await frames(3)
			return true
		OS.delay_msec(10)
		await tree.process_frame
	return false

## The solver's solution for the level on the screen.
func solution() -> PackedInt32Array:
	return Solver.solve(scene().get_level(), 400000).solution


## Taps the first `count` screws of the solution through the scene (all of them when -1).
func play_taps(count: int = -1) -> void:
	var sol := solution()
	var upto := sol.size() if count < 0 else mini(count, sol.size())
	for i: int in upto:
		scene().tap_screw(sol[i])
		await frames(1)


## The rule state of the level on the screen, as text.
func state_text() -> String:
	return var_to_str(scene().get_state().snapshot())


## Real (wall clock) milliseconds pass, a frame at a time.
func wait_ms(ms: int) -> void:
	# Sleep the thread: spinning frames for the wall time would burn the runner's game time
	# budget (it counts frames, and an idle frame takes microseconds).
	OS.delay_msec(maxi(0, ms))
	await tree.process_frame



## Every node of a class under `root` (by script class name).
func nodes_of(root: Node, script_class: String) -> Array[Node]:
	var out: Array[Node] = []
	_collect(root, script_class, out)
	return out


func _collect(node: Node, script_class: String, out: Array[Node]) -> void:
	var script: Script = node.get_script()
	if script != null and script.get_global_name() == script_class:
		out.append(node)
	for child: Node in node.get_children():
		_collect(child, script_class, out)


## Every label or button text under `root`, lower case, joined.
func all_text(root: Node) -> String:
	var parts := PackedStringArray()
	_texts(root, parts)
	return "\n".join(parts).to_lower()


func _texts(node: Node, parts: PackedStringArray) -> void:
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child: Node in node.get_children():
		_texts(child, parts)


## FlowCase.until, but sleeping a little between frames: a bare frame loop runs tens of
## thousands of frames a second and eats the runner's game time budget (1800 s, counted in
## frames, for the whole run) while a worker thread makes a level.
func until(condition: Callable, timeout_ms: int = 20000) -> bool:
	var started := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - started > timeout_ms:
			return false
		OS.delay_msec(10)
		await tree.process_frame
	return true
