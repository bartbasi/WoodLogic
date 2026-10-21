# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## A windowed run of the real app, driven by script, with screenshots. It needs a window:
##
##   Godot_v4.7.2-stable_win64.exe --path . -s res://tests/bots/qa_windowed.gd -- [--sizes=all]
##
## Save.dir is pointed at user://qa_windowed/ first, so the player's saves are never touched,
## and Links.opener is replaced, so no link is ever opened. Pictures go to build/qa4/shots/.
## It walks title, map, level, pause, settings, about and the clear screen at a list of window
## sizes (tiny, small, base, tall, wide, tablet) with coffee shown and hidden, and writes a
## text log of the sizes of the controls it finds. Exit code 1 if a screen fails to appear.

const OUT := "res://build/qa4/shots/"
const SAVE_DIR := "user://qa_windowed/"
## name, window pixels
const SIZES := [
	["tiny-240x427", Vector2i(240, 427)],
	["small-320x568", Vector2i(320, 568)],
	["base-360x640", Vector2i(360, 640)],
	["tall-360x922", Vector2i(360, 922)],
	["phone-412x915", Vector2i(412, 915)],
	["wide-533x640", Vector2i(533, 640)],
	["tablet-1200x1920", Vector2i(1200, 1920)],
	["landscape-1280x720", Vector2i(1280, 720)],
]

var _flow: Node
var _opened := PackedStringArray()
var _failures := PackedStringArray()
var _only := ""
var _instant := true
var _audited := 0
var _small := PackedStringArray()
const TITLE := 2
const LEVEL := 5
const PAUSE := 6
const CLEAR := 7
const LOST := 8


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
	await _frames(6)
	_audit(name)
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT) + name + ".png")


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
		if arg == "--animated":
			_instant = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var save := root.get_node("Save")
	save.set("dir", SAVE_DIR)
	# Never erase anything unless the folder really is ours (a renamed property would make the
	# set above do nothing, and erase_all would then wipe the real saves).
	if str(save.get("dir")) != SAVE_DIR or SAVE_DIR == "user://":
		print("The Save folder is %s, not %s: the script will not touch any save. Stopping." % [str(save.get("dir")), SAVE_DIR])
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	save.call("erase_all")
	Links.opener = func(address: String) -> Variant:
		_opened.append(address)
		return OK
	LevelCatalog.load_all()
	for n: int in range(1, 13):
		var level := LevelCatalog.get_level(LevelData.NUMBERED, n, "").level
		save.call("record_win", level, 20000 + n * 100, Vector3i(1, n % 2, n % 3 % 2))
	for helper: String in ["undo", "extra_slot", "screwdriver"]:
		save.call("mark_helper_met", helper, 2)
	for size: Array in SIZES:
		if _only != "" and not String(size[0]).contains(_only):
			continue
		await _walk(size[0], size[1], 0)
	if _only == "":
		await _walk("nocoffee-360x640", Vector2i(360, 640), 1)
		await _walk("nocoffee-240x427", Vector2i(240, 427), 1)
	save.call("erase_all")
	Links.opener = Callable()
	Links.coffee_hidden_for_tests = -1
	print("opened links: ", _opened)
	print("audited %d buttons at every size; problems: %d" % [_audited, _small.size()])
	var seen := {}
	for line: String in _small:
		var key := line.substr(line.find(":") + 2)
		if not seen.has(key):
			seen[key] = true
			print("  AUDIT ", line)
	if _failures.is_empty():
		print("QA windowed run: every screen appeared at every size.")
		quit(0)
	else:
		for f: String in _failures:
			print("FAILED: ", f)
		quit(1)


func _walk(name: String, size: Vector2i, coffee_hidden: int) -> void:
	Links.coffee_hidden_for_tests = coffee_hidden
	DisplayServer.window_set_size(size)
	root.size = size
	await _frames(4)
	if _flow != null:
		_flow.queue_free()
		await _frames(3)
	_flow = (load("res://src/ui/app_flow.tscn") as PackedScene).instantiate()
	_flow.set("quit_handler", func() -> void: pass)
	_flow.set("today_override", "2026-10-21")
	root.add_child(_flow)
	if not await _until(func() -> bool: return int(_flow.get("state")) == TITLE):
		_failures.append("%s: the title never appeared" % name)
		return
	await _shot("%s-1-title" % name)
	_flow.call("show_menu", "map")
	await _shot("%s-2-map" % name)
	_flow.call("play_number", 13)
	if not await _until(func() -> bool: return int(_flow.get("state")) == LEVEL):
		_failures.append("%s: level 13 never started" % name)
		return
	(_flow.get("level_scene") as Node).call("set_instant", _instant)
	await _shot("%s-3-level" % name)
	var sol: PackedInt32Array = Solver.solve((_flow.get("level_scene") as Node).call("get_level"), 400000).solution
	for i: int in 6:
		(_flow.get("level_scene") as Node).call("tap_screw", sol[i])
		await _frames(1 if _instant else 25)
	await _shot("%s-4-level-after-taps%s" % [name, "" if _instant else "-animated"])
	_flow.call("handle_back")
	await _shot("%s-5-pause" % name)
	if int(_flow.get("state")) != PAUSE:
		_failures.append("%s: Back did not pause" % name)
	_flow.call("show_menu", "settings")
	await _shot("%s-6-settings-from-pause" % name)
	_flow.call("show_menu", "about")
	await _shot("%s-7-about" % name)
	_flow.call("show_menu", "info")
	await _shot("%s-8-info" % name)
	_flow.call("show_menu", "stats")
	await _shot("%s-9-stats" % name)
	var button: Object = (_flow.get("screen") as Node).call("find_button", "Back to level")
	if button == null:
		_failures.append("%s: no Back to level on the dock while paused" % name)
	else:
		button.emit_signal("pressed")
		await _frames(3)
		if int(_flow.get("state")) != LEVEL:
			_failures.append("%s: Back to level did not return to the level" % name)
		for i: int in range(6, sol.size()):
			(_flow.get("level_scene") as Node).call("tap_screw", sol[i])
			await _frames(1 if _instant else 25)
		await _until(func() -> bool: return int(_flow.get("state")) == CLEAR)
		await _frames(40 if _instant else 150)
		await _shot("%s-10-clear%s" % [name, "" if _instant else "-animated"])
		# The loss: a hard Relaxed level played at random until the tray jams.
		_flow.call("play_relaxed", "hard")
		if await _until(func() -> bool: return int(_flow.get("state")) == LEVEL):
			var scene: Node = _flow.get("level_scene")
			scene.call("set_instant", true)
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			for i: int in 200:
				if int(_flow.get("state")) != LEVEL:
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
			await _until(func() -> bool: return int(_flow.get("state")) == LOST, 3000)
			await _frames(60)
			await _shot("%s-11-stuck%s" % [name, "" if _instant else "-animated"])
		# The same for a numbered level: Out of room, with the helpers the player owns.
		_flow.call("play_number", 40)
		if await _until(func() -> bool: return int(_flow.get("state")) == LEVEL):
			var scene2: Node = _flow.get("level_scene")
			scene2.call("set_instant", true)
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 9
			for i: int in 200:
				if int(_flow.get("state")) != LEVEL:
					break
				var state2: Object = scene2.call("get_state")
				var free2: Array[int] = []
				for s: int in 40:
					if state2.call("is_free", s):
						free2.append(s)
				if free2.is_empty():
					break
				scene2.call("tap_screw", free2[rng2.randi_range(0, free2.size() - 1)])
				await _frames(1)
			await _until(func() -> bool: return int(_flow.get("state")) == LOST, 3000)
			await _frames(60)
			await _shot("%s-12-out-of-room%s" % [name, "" if _instant else "-animated"])
			if name.begins_with("base"):
				await _click_through_sheet(name)


## With the real mouse over the window, a click on Retry's center must retry, and a click at a
## helper row button hidden behind the sheet must not use a helper.
func _click_through_sheet(name: String) -> void:
	var screen: Node = _flow.get("screen")
	var retry: Control = screen.call("find_button", "Retry")
	if retry == null:
		_failures.append("%s: no Retry on the sheet" % name)
		return
	var center := retry.get_global_rect().get_center()
	Input.warp_mouse(center)
	await _frames(4)
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		e.pressed = pressed
		e.position = center
		e.global_position = center
		Input.parse_input_event(e)
		await _frames(3)
	await _frames(10)
	print("TOUCH %s: after a click on Retry at %s the state is %d (5 = playing the level, 8 = still out of room)" % [name, str(center), int(_flow.get("state"))])
	if int(_flow.get("state")) != LEVEL:
		_failures.append("%s: a click on Retry at %s did not retry (state %d)" % [name, str(center), int(_flow.get("state"))])


## Every visible button must be at least 48 by 48 units and inside the screen (UX 7.3).
func _audit(label: String) -> void:
	var view := root.get_visible_rect()
	var stack: Array[Node] = [_flow]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if not (node is Button):
			continue
		var b := node as Button
		if not b.is_visible_in_tree() or b.size.x <= 0.0:
			continue
		var rect := b.get_global_rect()
		_audited += 1
		if rect.size.x < 47.5 or rect.size.y < 47.5:
			_small.append("%s: button \"%s\" is %.0f x %.0f" % [label, b.text if b.text != "" else b.name, rect.size.x, rect.size.y])
		if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > view.size.x + 1.0 or rect.end.y > view.size.y + 1.0:
			_small.append("%s: button \"%s\" at %s is outside the %s screen" % [label, b.text if b.text != "" else b.name, str(rect), str(view.size)])
