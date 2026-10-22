# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## A windowed run of the Phase 5 screens, driven by script, with screenshots (needs a window):
##
##   Godot_v4.7.2-stable_win64.exe --path . -s res://tests/bots/qa_windowed5.gd
##
## The tray at 5, 4 and 3 slots, the closing and the shrink line when Next arrives at level 12,
## the closing at level 21, the gift plaque on the clear screen of level 49, and a full 3 slot
## tray, at 360 x 640, 412 x 915 and 360 x 922. Save.dir is pointed at user://qa_windowed5/ and
## checked before anything is erased; Links.opener is replaced. Pictures: build/qa5/shots/.

const OUT := "res://build/qa5/shots/"
const SAVE_DIR := "user://qa_windowed5/"
const SIZES := [["base", Vector2i(360, 640)], ["phone", Vector2i(412, 915)], ["tall", Vector2i(360, 922)]]
const TITLE := 2
const LEVEL := 5
const CLEAR := 7
const LOST := 8

var _flow: Node
var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _until(condition: Callable, timeout_ms: int = 15000) -> bool:
	var started := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - started > timeout_ms:
			return false
		await process_frame
	return true


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT) + name + ".png")


func _state() -> int:
	return int(_flow.get("state"))


func _scene() -> Node:
	return _flow.get("level_scene") as Node


func _win_level() -> void:
	var scene := _scene()
	scene.call("set_instant", true)
	var sol: PackedInt32Array = Solver.solve(scene.call("get_level"), 400000).solution
	for s: int in sol:
		scene.call("tap_screw", s)
		await _frames(1)
	scene.call("set_instant", false)


func _boot(cleared: int, size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	root.size = size
	await _frames(3)
	if _flow != null:
		_flow.queue_free()
		await _frames(3)
	var save := root.get_node("Save")
	save.call("erase_all")
	for n: int in range(1, cleared + 1):
		var level := LevelCatalog.get_level(LevelData.NUMBERED, n, "").level
		save.call("record_win", level, 20000, Vector3i(1, 1, 1))
	for helper: String in ["undo", "extra_slot", "screwdriver"]:
		save.call("mark_helper_met", helper, 2)
	_flow = (load("res://src/ui/app_flow.tscn") as PackedScene).instantiate()
	_flow.set("quit_handler", func() -> void: pass)
	_flow.set("today_override", "2026-10-22")
	root.add_child(_flow)
	await _until(func() -> bool: return _state() == TITLE)


func _press_play() -> void:
	var button: Object = (_flow.get("screen") as Node).call("find_button", "Play")
	button.emit_signal("pressed")
	await _until(func() -> bool: return _state() == LEVEL)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var save := root.get_node("Save")
	save.set("dir", SAVE_DIR)
	if str(save.get("dir")) != SAVE_DIR or SAVE_DIR == "user://":
		print("The Save folder is %s, not %s: the script will not touch any save. Stopping." % [str(save.get("dir")), SAVE_DIR])
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	Links.opener = func(_address: String) -> Variant: return OK
	LevelCatalog.load_all()
	for pair: Array in SIZES:
		var tag: String = pair[0]
		var size: Vector2i = pair[1]
		# Level 11 (5 slots), then Next to 12 (the closing and the line), 13.
		await _boot(10, size)
		await _press_play()
		await _frames(30)
		await _shot("%s-1-level11-tray5" % tag)
		await _win_level()
		await _until(func() -> bool: return _state() == CLEAR)
		await _frames(40)
		(( _flow.get("screen") as Node).call("find_button", "Next") as Object).emit_signal("pressed")
		await _until(func() -> bool: return _state() == LEVEL)
		await _frames(8)
		await _shot("%s-2-level12-closing-a" % tag)
		await _frames(14)
		await _shot("%s-3-level12-closing-b" % tag)
		await _frames(120)
		await _shot("%s-4-level12-shrink-line" % tag)
		# Level 21 (3 slots) straight from the title: the tray simply appears.
		await _boot(20, size)
		await _press_play()
		await _frames(60)
		await _shot("%s-5-level21-tray3" % tag)
		# The gift: clear level 49.
		await _boot(48, size)
		await _press_play()
		await _win_level()
		await _until(func() -> bool: return _state() == CLEAR)
		await _frames(90)
		await _shot("%s-6-clear49-gift" % tag)
		# A full 3 slot tray: random free screws until the tray jams.
		await _boot(30, size)
		await _press_play()
		var scene := _scene()
		scene.call("set_instant", true)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4
		for attempt: int in 40:
			for i: int in 60:
				if _state() != LEVEL:
					break
				var state: Object = scene.call("get_state")
				var free: Array[int] = []
				for s: int in 40:
					if state.call("is_free", s):
						free.append(s)
				if free.is_empty():
					break
				scene.call("tap_screw", free[rng.randi_range(0, free.size() - 1)])
				await _frames(1)
			if _state() == LOST:
				break
			if _state() == LEVEL:
				scene.call("retry")
		await _frames(60)
		await _shot("%s-7-out-of-room-tray3" % tag)
	save.call("erase_all")
	print("QA windowed 5 done: pictures in build/qa5/shots/")
	# A lambda left in a static variable crashes the engine on quit.
	Links.opener = Callable()
	quit(0)
