# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Saves pictures of the clear screen with the gift plaque and of Info with the new tray and
## gift lines, at 360 x 640, to build/shots-gifts/. Needs a window:
##   Godot_v4.7.2-stable_win64.exe --path . -s res://tests/ui/capture_gifts.gd
## It writes no save files. If the data has no gifts yet, it shows the planned two in memory.

const OUT := "res://build/shots-gifts/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	LevelCatalog.load_all()
	if Tuning.gifts.is_empty():
		var planned: Array[Dictionary] = [{"level": 50, "undo": 2, "extra_slot": 1, "screwdriver": 0}, {"level": 100, "undo": 2, "extra_slot": 1, "screwdriver": 0}]
		Tuning.gifts = planned
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(360, 640)
	DisplayServer.window_set_size(Vector2i(360, 640))
	var theme := UiTheme.build()
	var level := LevelCatalog.get_level(LevelData.NUMBERED, 49, "").level
	var progress: Dictionary = root.get_node("Save").call("default_progress")
	var ctx := {"next_level": 50, "paused_text": "", "version": "0.1.0", "progress": progress, "settings": {}, "last_band": "", "daily_note": "", "daily_locked": false, "relaxed_locked": false}
	var shots := {
		"clear_gift": ClearScreen.make({"kind": LevelData.NUMBERED, "number": 49, "level": level, "stars": Vector3i(1, 1, 0), "elapsed_ms": 40000, "gain": 2, "gifts": ["A gift for reaching level 50: 2 Undos and 1 Extra slot."]}),
		"clear_gift_and_unlock": ClearScreen.make({"kind": LevelData.NUMBERED, "number": 49, "level": level, "stars": Vector3i(1, 1, 1), "elapsed_ms": 40000, "gain": 3, "unlocks": ["Unlocked: Maple wood"], "gifts": ["A gift for reaching level 50: 2 Undos and 1 Extra slot."]}),
		"info_tray": MenuFactory.make("info", ctx),
		"info_gift": MenuFactory.make("info", ctx),
	}
	for shot_name: String in shots:
		var screen: UiScreen = shots[shot_name]
		screen.theme = theme
		root.add_child(screen)
		for i: int in 60:
			await process_frame
		if screen is ClearScreen:
			(screen as ClearScreen).skip_delay()
			for i: int in 6:
				await process_frame
		if screen is MenuScreen:
			# Scroll to the Helpers group so the new lines are in the picture.
			(screen as MenuScreen).scroll.scroll_vertical = 40 if shot_name == "info_tray" else 560
			await process_frame
			await process_frame
		var image := root.get_texture().get_image()
		var path := ProjectSettings.globalize_path(OUT) + "%s_360x640.png" % shot_name
		print("%s %s" % ["saved" if image.save_png(path) == OK else "FAILED", path])
		screen.queue_free()
		await process_frame
	quit()
