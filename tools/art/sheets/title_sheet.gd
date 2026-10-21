# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends Node
## The real title screen (ui-dev's TitleScreen) with the TitleBoard placed in the gap it leaves
## for the decoration, for review shots. The viewport's size divided by 3 is the design size, so
## a 1080 x 1920 capture is the 360 x 640 layout at 3 pixels a unit. SHEET_WOOD picks a wood.
## tools/art/capture.gd renders it.

func _ready() -> void:
	_build.call_deferred()


func _build() -> void:
	var vp := get_viewport() as SubViewport
	var design := Vector2i(roundi(vp.size.x / 3.0), roundi(vp.size.y / 3.0))
	if vp != null:
		vp.size_2d_override = design
		vp.size_2d_override_stretch = true
	if OS.get_environment("SHEET_WOOD") != "":
		Looks.current["wood"] = OS.get_environment("SHEET_WOOD")
	var save: Node = get_tree().root.get_node("Save")
	var progress: Dictionary = save.call("default_progress")
	progress["highest_cleared"] = 12
	progress["star_bank"] = 128
	var ctx := {"next_level": 13, "paused_text": "", "version": "0.1.0", "progress": progress,
		"settings": {"sound": true, "music": false, "symbols": true, "wood": Looks.current["wood"], "metal": "steel",
			"unlocked_wood": PackedStringArray(["oak"]), "unlocked_metal": PackedStringArray(["steel"])},
		"last_band": "medium", "daily_note": "Today's puzzle", "daily_locked": false, "relaxed_locked": false}
	var title: Control = MenuFactory.make("title", ctx)
	title.theme = UiTheme.build()
	add_child(title)
	for i in 3:
		await get_tree().process_frame
	var body: Control = title.get("body")
	var gap: Control = body.get_child(2)
	var rect := gap.get_global_rect()
	var board := TitleBoard.new()
	board.position = rect.position
	board.setup(rect.size)
	add_child(board)
	board.bake()
	print("decoration rect ", rect)
