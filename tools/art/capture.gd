# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Renders a scene into an offscreen SubViewport at phone resolution and saves it as a PNG.
## Needs a windowed run, because headless runs draw nothing:
##   Godot_v4.7.2-stable_win64.exe --path . --resolution 1080x2400 -s res://tools/art/capture.gd -- <scene> <out.png> [WxH] [frames]
## The shot is rendered in a SubViewport of WxH (default 1080x2400), so it does not depend on
## how large a window the desktop allows. The engine keeps --resolution for the window and
## does not pass it on, so give the size again after the scene and file. <out.png> may be
## res:// or a plain path.

const DEFAULT_SIZE := Vector2i(1080, 2400)


func _initialize() -> void:
	_capture.call_deferred()


func _parse_size(text: String) -> Vector2i:
	var parts := text.split("x")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -s res://tools/art/capture.gd -- <scene.tscn> <out.png> [WxH] [frames]")
		quit(2)
		return
	var scene_path: String = args[0]
	var out_path: String = args[1]
	var size := DEFAULT_SIZE
	var frames := 6
	for extra: String in args.slice(2):
		if _parse_size(extra) != Vector2i.ZERO:
			size = _parse_size(extra)
		elif extra.is_valid_int():
			frames = int(extra)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		printerr("could not load ", scene_path)
		quit(1)
		return
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	vp.add_child(packed.instantiate())
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_path) if out_path.begins_with("res://") else out_path
	var err := image.save_png(path)
	if err != OK:
		printerr("could not save ", path, " (error ", err, ")")
		quit(1)
		return
	print("saved %s (%d x %d)" % [path, image.get_width(), image.get_height()])
	quit(0)
