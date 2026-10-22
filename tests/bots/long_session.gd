# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## A very long session: the real app flow and the real level scene, a "quick player" who solves
## every level with the solver's solution and presses Next, from level 1 to level N, with a pause
## and a tour of the menus every 100 levels. It watches memory and node counts, and fails on
## growth that follows the number of levels played.
##
##   godot --headless --path . -s res://tests/bots/long_session.gd -- [--levels=1000] [--every=50]
##
## Save.dir is pointed at user://qa_long/ and checked before anything is erased; Links.opener is
## replaced and cleared before quitting. Exit code 1 if a level did not start or did not clear,
## or the counts grew; 2 for a bad option.

var _levels := 1000
var _every := 50
var _flow: Node
var _samples: Array[Dictionary] = []
var _failures := PackedStringArray()
## Names of the engine monitors read at each sample.
var _monitors := {}


func _initialize() -> void:
	_run.call_deferred()


func _parse() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		var value := parts[1] if parts.size() > 1 else ""
		match parts[0]:
			"--levels":
				if not value.is_valid_int() or value.to_int() < 10 or value.to_int() > 5000:
					print("--levels needs a whole number from 10 to 5000")
					return false
				_levels = value.to_int()
			"--every":
				if not value.is_valid_int() or value.to_int() < 5 or value.to_int() > 1000:
					print("--every needs a whole number from 5 to 1000")
					return false
				_every = value.to_int()
			_:
				print("Unknown option ", arg)
				return false
	return true


func _state() -> int:
	return int(_flow.get("state"))


func _scene() -> Node:
	return _flow.get("level_scene") as Node


func _until(condition: Callable, timeout_ms: int) -> bool:
	var started := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - started > timeout_ms:
			return false
		await process_frame
	return true


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _sample(level: int) -> void:
	var tree_nodes := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		tree_nodes += 1
		stack.append_array(node.get_children())
	_samples.append({
		"level": level,
		"static_mb": float(OS.get_static_memory_usage()) / 1048576.0,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"tree_nodes": tree_nodes,
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"ms": Time.get_ticks_msec(),
		"progress_bytes": FileAccess.get_file_as_string("user://qa_long/progress.json").length(),
	})


func _run() -> void:
	if not _parse():
		quit(2)
		return
	var save := root.get_node("Save")
	save.set("dir", "user://qa_long/")
	if str(save.get("dir")) != "user://qa_long/":
		print("The Save folder is %s, not user://qa_long/: the script will not touch any save. Stopping." % str(save.get("dir")))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("user://qa_long/")
	save.call("erase_all")
	Links.opener = func(_address: String) -> Variant: return OK
	LevelCatalog.load_all()
	_flow = (load("res://src/ui/app_flow.tscn") as PackedScene).instantiate()
	_flow.set("quit_handler", func() -> void: pass)
	_flow.set("today_override", "2026-10-23")
	root.add_child(_flow)
	var started := Time.get_ticks_msec()
	var slowest := 0
	var slowest_level := 0
	await _sample(0)
	for n: int in range(1, _levels + 1):
		var level_started := Time.get_ticks_msec()
		# Level n is on the screen (the first launch goes straight into level 1).
		if not await _until(func() -> bool: return _state() == 5, 30000):
			_failures.append("level %d did not start (state %d)" % [n, _state()])
			break
		while _flow.get("overlay") != null:
			var sheet: Object = (_flow.get("overlay") as Node).call("find_button", "Got it")
			if sheet == null:
				break
			sheet.emit_signal("pressed")
			await _frames(2)
		var scene := _scene()
		var level: LevelData = scene.call("get_level")
		if level.number != n:
			_failures.append("expected level %d but level %d is on the screen" % [n, level.number])
			break
		scene.call("set_instant", true)
		var solution := Solver.solve(level, 3000000).solution
		for s: int in solution:
			scene.call("tap_screw", s)
			await process_frame
		if not await _until(func() -> bool: return _state() == 7, 15000):
			_failures.append("level %d was not cleared (state %d)" % [n, _state()])
			break
		await _frames(40)
		if n % 100 == 0:
			await _tour()
		else:
			var next: Object = (_flow.get("screen") as Node).call("find_button", "Next")
			if next == null:
				_failures.append("level %d: no Next on the clear screen" % n)
				break
			next.emit_signal("pressed")
		var took := Time.get_ticks_msec() - level_started
		if took > slowest:
			slowest = took
			slowest_level = n
		if n % _every == 0:
			await _sample(n)
	var wall := Time.get_ticks_msec() - started
	_report(wall, slowest, slowest_level)
	save.call("erase_all")
	Links.opener = Callable()
	# Close the app the way the game does (waits for its level jobs), then free it.
	_flow.call("quit")
	_flow.queue_free()
	await process_frame
	await process_frame
	quit(1 if not _failures.is_empty() else 0)


## The menus and a pause, as a player does now and then. It ends on the next level (Play), so
## the loop does not press Next after it.
func _tour() -> void:
	_flow.call("show_menu", "title")
	await _frames(3)
	for menu_name: String in ["map", "stats", "info", "settings", "about", "title"]:
		_flow.call("show_menu", menu_name)
		await _frames(3)
	var play: Object = (_flow.get("screen") as Node).call("find_button", "Play")
	if play != null:
		play.emit_signal("pressed")
		await _until(func() -> bool: return _state() == 5, 30000)
		_flow.call("handle_back")
		await _frames(3)
		var resume: Object = (_flow.get("screen") as Node).call("find_button", "Resume")
		if resume != null:
			resume.emit_signal("pressed")
			await _frames(3)


func _mean(rows: Array[Dictionary], key: String) -> float:
	var total := 0.0
	for r: Dictionary in rows:
		total += float(r[key])
	return total / maxf(rows.size(), 1.0)


func _report(wall: int, slowest: int, slowest_level: int) -> void:
	print("Long session: %d levels in %.0f s (%.0f ms a level, slowest %d ms at level %d)" % [_levels, wall / 1000.0, float(wall) / _levels, slowest, slowest_level])
	print("level   static MB   engine nodes   tree nodes   objects   orphans   resources   progress.json bytes")
	for r: Dictionary in _samples:
		print("%5d   %9.1f   %12d   %10d   %7d   %7d   %9d   %19d" % [r["level"], r["static_mb"], r["nodes"], r["tree_nodes"], r["objects"], r["orphans"], r["resources"], r["progress_bytes"]])
	# Growth: the second half of the samples against the first quarter after the start.
	if _samples.size() >= 8:
		var early: Array[Dictionary] = _samples.slice(2, 5)
		var late: Array[Dictionary] = _samples.slice(_samples.size() - 3)
		for key: String in ["nodes", "tree_nodes", "objects", "orphans", "resources"]:
			var a := _mean(early, key)
			var b := _mean(late, key)
			print("%-10s early %.0f, late %.0f" % [key, a, b])
			if b > a * 1.5 + 50.0:
				_failures.append("%s grew from %.0f to %.0f over the session" % [key, a, b])
		var mb_a := _mean(early, "static_mb")
		var mb_b := _mean(late, "static_mb")
		print("static memory early %.1f MB, late %.1f MB" % [mb_a, mb_b])
		if mb_b > mb_a * 1.5 + 50.0:
			_failures.append("static memory grew from %.1f MB to %.1f MB" % [mb_a, mb_b])
	for f: String in _failures:
		print("FAILED: ", f)
	if _failures.is_empty():
		print("Nothing grew with the number of levels played.")
