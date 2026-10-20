# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Saves a picture of each Phase 3 screen at 360 x 640 and 1080 x 1200 to build/shots/ui/.
## Needs a window (headless draws nothing):
##   Godot_v4.7.2-stable_win64.exe --path . -s res://tests/ui/capture_screens.gd
## It only builds screens and reads the viewport: it writes no save files.

const SIZES: Array[Vector2i] = [Vector2i(360, 640), Vector2i(1080, 1200)]
const OUT := "res://build/shots/ui/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var theme := UiTheme.build()
	for size: Vector2i in SIZES:
		root.size = size
		DisplayServer.window_set_size(size)
		await process_frame
		await process_frame
		var screens := {
			"title": TitleScreen.make(12, "0.1.0"),
			"pause": PauseScreen.make(12, true, false),
			"clear": ClearScreen.make(12),
			"lost": LostScreen.make(12),
		}
		for shot_name: String in screens:
			var screen: UiScreen = screens[shot_name]
			var board: Control = null
			if shot_name == "lost":
				board = _fake_board()
				root.add_child(board)
			screen.theme = theme
			root.add_child(screen)
			if screen is ClearScreen:
				(screen as ClearScreen).skip_delay()
			for i: int in 40:
				await process_frame
			var image := root.get_texture().get_image()
			var path := ProjectSettings.globalize_path(OUT) + "%s_%dx%d.png" % [shot_name, size.x, size.y]
			var err := image.save_png(path)
			print("%s %s (%dx%d)" % ["saved" if err == OK else "FAILED", path, image.get_width(), image.get_height()])
			screen.queue_free()
			if board != null:
				board.queue_free()
			await process_frame
	quit()


## Something board-like to sit under the out of room sheet.
func _fake_board() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = Color("6f4a30")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(back)
	for i: int in 5:
		var plank := ColorRect.new()
		plank.color = Color("dcae6c")
		plank.position = Vector2(30 + i * 40, 150 + i * 30)
		plank.size = Vector2(200, 26)
		plank.rotation = 0.3 * float(i - 2)
		c.add_child(plank)
	return c
