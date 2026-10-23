# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Makes the Google Play store graphics from the game itself, into build/store/ (ignored by git).
## Needs a window, because headless runs draw nothing. Use tools/build/make_store_graphics.sh,
## which runs this three times:
##   -s res://tools/build/store_graphics.gd -- feature      (window 1024x500)
##   -s res://tools/build/store_graphics.gd -- screenshots  (window 1080x1920)
## `feature` writes feature-1024x500.png (24-bit, no alpha, as Play asks) and copies the app icon
## (icons/icon-512.png, made by tools/art/app_icon.gd) to icon-512.png. `screenshots` walks the
## real app with a scratch save (user://store_shots/, never the player's own), with Links.opener
## replaced so no link opens, and writes phone-1.png and up.

const OUT := "res://build/store/"
const SAVE_DIR := "user://store_shots/"
const FEATURE := Vector2i(1024, 500)
const SHOT := Vector2i(1080, 1920)
const TITLE := 2
const LEVEL := 5
const CLEAR := 7

var _flow: Node
var _shots := 0


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


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var mode := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = args[0]
	if mode == "feature":
		await _feature()
	elif mode == "screenshots":
		await _screenshots()
	else:
		printerr("usage: -s res://tools/build/store_graphics.gd -- feature|screenshots")
		_end(2)


func _save(image: Image, name: String) -> bool:
	image.convert(Image.FORMAT_RGB8)
	var path := ProjectSettings.globalize_path(OUT) + name
	var err := image.save_png(path)
	print("%s %s (%d x %d)" % ["saved" if err == OK else "FAILED", path, image.get_width(), image.get_height()])
	if err != OK:
		return false
	return true


## The 1024x500 feature graphic: the title screen's windmill board on a back board, and the name.
func _feature() -> void:
	if root.size != FEATURE:
		printerr("the feature graphic needs --resolution %dx%d (the window is %s)" % [FEATURE.x, FEATURE.y, root.size])
		_end(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED  # one unit is one pixel here
	var icon := Image.load_from_file(ProjectSettings.globalize_path("res://icons/icon-512.png"))
	if not _save(icon, "icon-512.png"):
		_end(1)
		return
	var theme := UiTheme.build()
	var scene := Control.new()
	scene.theme = theme
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene)
	var back := Node2D.new()
	scene.add_child(back)
	var panel := PlankView.new()
	back.add_child(panel)
	panel.setup_panel(Rect2(-20, -20, FEATURE.x + 40, FEATURE.y + 40), 0.0, 77)
	panel.bake()
	var board := TitleBoard.new()
	scene.add_child(board)
	board.position = Vector2(48, 50)
	board.setup(Vector2(420, 400))
	board.bake()
	board.set_turning(false)
	var name_label := Label.new()
	name_label.theme_type_variation = "DisplayLabel"
	name_label.text = "WoodLogic"
	name_label.add_theme_font_size_override("font_size", 84)
	name_label.position = Vector2(500, 170)
	scene.add_child(name_label)
	var tag := Label.new()
	tag.theme_type_variation = "HeadingLabel"
	tag.text = "A free screw puzzle in wood"
	tag.add_theme_font_size_override("font_size", 30)
	tag.position = Vector2(506, 290)
	scene.add_child(tag)
	await _frames(60)
	await RenderingServer.frame_post_draw
	if not _save(root.get_texture().get_image(), "feature-1024x500.png"):
		_end(1)
		return
	_end(0)


func _shot(name: String) -> bool:
	await _frames(8)
	_shots += 1
	return _save(root.get_texture().get_image(), name)


func _screenshots() -> void:
	var save := root.get_node("Save")
	save.set("dir", SAVE_DIR)
	if str(save.get("dir")) != SAVE_DIR:
		print("The Save folder is not %s: stopping, so no real save is touched." % SAVE_DIR)
		_end(1)
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	save.call("erase_all")
	Links.opener = func(_address: String) -> Variant: return OK
	Links.coffee_hidden_for_tests = 0
	LevelCatalog.load_all()
	for n: int in range(1, 20):
		var done := LevelCatalog.get_level(LevelData.NUMBERED, n, "").level
		save.call("record_win", done, 20000 + n * 100, Vector3i(1, n % 2, n % 3 % 2))
	for helper: String in ["undo", "extra_slot", "screwdriver"]:
		save.call("mark_helper_met", helper, 2)
	DisplayServer.window_set_size(SHOT)
	root.size = SHOT
	await _frames(4)
	_flow = (load("res://src/ui/app_flow.tscn") as PackedScene).instantiate()
	_flow.set("quit_handler", func() -> void: pass)
	_flow.set("today_override", "2026-10-22")
	root.add_child(_flow)
	if not await _until(func() -> bool: return int(_flow.get("state")) == TITLE):
		printerr("the title never appeared")
		_end(1)
		return
	await _frames(120)
	if not await _shot("phone-1.png"):
		_end(1)
		return
	_flow.call("play_number", 20)
	if not await _until(func() -> bool: return int(_flow.get("state")) == LEVEL):
		printerr("the level never started")
		_end(1)
		return
	var scene: Node = _flow.get("level_scene")
	scene.call("set_instant", true)
	await _frames(30)
	if not await _shot("phone-2.png"):
		_end(1)
		return
	var solution: PackedInt32Array = Solver.solve(scene.call("get_level"), 400000).solution
	for i: int in solution.size() / 2:
		scene.call("tap_screw", solution[i])
		await _frames(2)
	await _frames(30)
	_age_clock(scene, 21000)
	if not await _shot("phone-3.png"):
		_end(1)
		return
	_age_clock(scene, 41000)
	for i: int in range(solution.size() / 2, solution.size()):
		scene.call("tap_screw", solution[i])
		await _frames(2)
	await _until(func() -> bool: return int(_flow.get("state")) == CLEAR)
	await _frames(150)
	if not await _shot("phone-4.png"):
		_end(1)
		return
	_flow.call("show_menu", "map")
	await _frames(60)
	if not await _shot("phone-5.png"):
		_end(1)
		return
	_flow.call("show_menu", "settings")
	await _frames(30)
	if not await _shot("phone-6.png"):
		_end(1)
		return
	save.call("erase_all")
	Links.opener = Callable()
	Links.coffee_hidden_for_tests = -1
	_end(0)


## Moves the level clock on to `ms` (the taps here come much faster than a person plays), so
## the clock and the clear screen show a believable time. The clock is the scene's own object.
func _age_clock(scene: Node, ms: int) -> void:
	var clock: Object = scene.get("_clock")
	if clock != null and bool(clock.get("started")):
		clock.set("_accumulated", ms)


## The one way out. Puts everything this script changed back, then quits with `code`: the link
## opener and the coffee switch are restored, and the scratch save folder is emptied (only when
## Save really points at it).
func _end(code: int) -> void:
	Links.opener = Callable()
	Links.coffee_hidden_for_tests = -1
	var save := root.get_node_or_null("Save")
	if save != null and str(save.get("dir")) == SAVE_DIR:
		save.call("erase_all")
	quit(code)
