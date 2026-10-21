# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Saves a picture of every screen at 360 x 640, 360 x 922 (a Galaxy Z Fold5 folded) and
## 533 x 640 (opened) to build/shots/ui/. Needs a window (headless draws nothing):
##   Godot_v4.7.2-stable_win64.exe --path . -s res://tests/ui/capture_screens.gd
## It only builds screens and reads the viewport: it writes no save files.

const SIZES: Array[Vector2i] = [Vector2i(360, 640), Vector2i(360, 922), Vector2i(533, 640)]
const OUT := "res://build/shots/ui/"


func _initialize() -> void:
	_run.call_deferred()


func _progress(highest: int) -> Dictionary:
	var progress: Dictionary = root.get_node("Save").call("default_progress")
	progress["highest_cleared"] = highest
	progress["star_bank"] = 128
	progress["stars_earned"] = 300
	var levels := {}
	for n: int in range(maxi(1, highest - 40), highest + 1):
		levels[str(n)] = {"stars": 1 + n % 3, "best_ms": 40000, "gen": 4}
	progress["levels"] = levels
	var stats: Dictionary = progress["stats"]
	stats["cleared"] = highest
	stats["three_star"] = 40
	stats["helpers_used"] = 12
	var time: Dictionary = stats["time"]
	time["easy"] = {"n": 12, "total_ms": 480000, "best_ms": 21000}
	time["medium"] = {"n": 30, "total_ms": 1800000, "best_ms": 33000}
	var daily: Dictionary = progress["daily"]
	daily["streak"] = 3
	daily["best_streak"] = 7
	daily["solved"] = 11
	return progress


func _context(highest: int, paused: String) -> Dictionary:
	return {
		"next_level": highest + 1, "paused_text": paused, "version": "0.1.0", "progress": _progress(highest),
		"settings": {"sound": true, "music": false, "symbols": true, "wood": "oak", "metal": "steel", "unlocked_wood": PackedStringArray(["oak", "walnut"]), "unlocked_metal": PackedStringArray(["steel"])},
		"last_band": "medium", "daily_note": "Today's puzzle", "daily_locked": false, "relaxed_locked": false,
	}


## [name, screen, needs a board behind it]
func _shots(coffee: bool) -> Array:
	var ctx := _context(12, "")
	var out: Array = []
	var suffix := "" if coffee else "_nocoffee"
	if coffee:
		for menu_name: String in MenuFactory.NAMES:
			out.append([menu_name, MenuFactory.make(menu_name, ctx), false])
		out.append(["title_paused", MenuFactory.make("title", _context(12, "Level 13, paused")), false])
		out.append(["stats_paused", MenuFactory.make("stats", _context(12, "Level 13, paused")), false])
		var locked := _context(3, "")
		locked["daily_locked"] = true
		locked["relaxed_locked"] = true
		locked["daily_note"] = "Opens after level 8"
		out.append(["title_locked", MenuFactory.make("title", locked), false])
		out.append(["map_near_1", MenuFactory.make("map", _context(0, "")), false])
		out.append(["map_near_150", MenuFactory.make("map", _context(150, "")), false])
		var level := LevelCatalog.get_level(LevelData.NUMBERED, 12, "").level
		out.append(["pause", PauseScreen.make("Level 12", true, false), false])
		out.append(["clear", ClearScreen.make({"kind": LevelData.NUMBERED, "number": 12, "level": level, "stars": Vector3i(1, 1, 0), "elapsed_ms": 40000, "gain": 2, "unlocks": ["Unlocked: Walnut wood"]}), false])
		out.append(["clear_mid", ClearScreen.make({"kind": LevelData.NUMBERED, "number": 12, "level": level, "stars": Vector3i(1, 1, 0), "elapsed_ms": 40000, "gain": 2, "unlocks": ["Unlocked: Walnut wood"]}), false, 38])
		out.append(["clear_daily", ClearScreen.make({"kind": LevelData.DAILY, "number": 20261021, "level": level, "stars": Vector3i(1, 0, 0), "gain": 1, "streak": 3}), false])
		out.append(["clear_relaxed", ClearScreen.make({"kind": LevelData.RELAXED, "number": 4, "level": level}), false])
		out.append(["lost", LostScreen.make({"number": 12, "helpers": []}), true])
		out.append(["lost_helpers_3", LostScreen.make({"number": 12, "helpers": [["undo", 2], ["extra_slot", 1], ["screwdriver", 4]]}), true])
		out.append(["lost_helper_1", LostScreen.make({"number": 12, "helpers": [["undo", 2]]}), true])
		out.append(["stuck", LostScreen.make({"number": 12, "stuck": true}), true])
		out.append(["helper_sheet", HelperSheet.make("undo"), true])
		out.append(["buy_dialog", UiDialog.make("Get Undo?", "Undo costs 4 stars. You have 9. Spend 4 and use it now?", [["Get and use", UiButton.Kind.PRIMARY], ["Not now", UiButton.Kind.SECONDARY]], 1), true])
		out.append(["reset_dialog", UiDialog.make("Erase everything?", "This erases your levels, stars, helpers, streaks and stats on this phone. It cannot be undone. Your settings stay as they are.", [["Keep my progress", UiButton.Kind.PRIMARY], ["Erase everything", UiButton.Kind.DANGER]], 0), true])
	else:
		for menu_name: String in ["title", "settings", "about", "map"]:
			out.append([menu_name, MenuFactory.make(menu_name, ctx), false])
		out.append(["pause", PauseScreen.make("Level 12", true, false), false])
	for shot: Array in out:
		shot[0] = str(shot[0]) + suffix
	return out


func _run() -> void:
	LevelCatalog.load_all()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var theme := UiTheme.build()
	for coffee: bool in [true, false]:
		Links.coffee_hidden_for_tests = 0 if coffee else 1
		for size: Vector2i in SIZES:
			root.size = size
			DisplayServer.window_set_size(size)
			await process_frame
			await process_frame
			for shot: Array in _shots(coffee):
				var screen: UiScreen = shot[1]
				var board: Control = null
				if shot[2]:
					board = _fake_board()
					root.add_child(board)
				screen.theme = theme
				root.add_child(screen)
				var frames_to_wait := 45
				if shot.size() > 3:
					frames_to_wait = int(shot[3])
				for i: int in frames_to_wait:
					await process_frame
				if screen is ClearScreen and shot.size() <= 3:
					(screen as ClearScreen).skip_delay()
					for i: int in 6:
						await process_frame
				var image := root.get_texture().get_image()
				var path := ProjectSettings.globalize_path(OUT) + "%s_%dx%d.png" % [shot[0], size.x, size.y]
				var err := image.save_png(path)
				print("%s %s" % ["saved" if err == OK else "FAILED", path])
				screen.queue_free()
				if board != null:
					board.queue_free()
				await process_frame
	Links.coffee_hidden_for_tests = -1
	quit()


## Something board-like to sit under the sheets and dialogs.
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
