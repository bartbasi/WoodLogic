# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Draws the app icon in code and writes its PNG files into icons/ (a windowed run; headless
## draws nothing):
##   Godot_v4.7.2-stable_win64.exe --path . -s res://tools/art/app_icon.gd
## Files: icon-192.png (the launcher icon), icon-512.png (the store listing), and the adaptive
## icon's three 432 x 432 layers: adaptive-background.png, adaptive-foreground.png and
## adaptive-monochrome.png.

const SCENE := "res://tools/art/sheets/app_icon.gd"
const OUTPUTS: Array[Array] = [
	["icon-192.png", "full", 192],
	["icon-512.png", "full", 512],
	["adaptive-background.png", "background", 432],
	["adaptive-foreground.png", "foreground", 432],
	["adaptive-monochrome.png", "monochrome", 432],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := ProjectSettings.globalize_path("res://icons")
	DirAccess.make_dir_recursive_absolute(dir)
	var script := load(SCENE) as GDScript
	var viewports: Array[SubViewport] = []
	for out: Array in OUTPUTS:
		var vp := SubViewport.new()
		vp.size = Vector2i(int(out[2]), int(out[2]))
		vp.transparent_bg = out[1] != "full" and out[1] != "background"
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var node: Node2D = script.new()
		node.set("part", out[1])
		vp.add_child(node)
		viewports.append(vp)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var status := 0
	for i in OUTPUTS.size():
		var path := dir.path_join(String(OUTPUTS[i][0]))
		var err := viewports[i].get_texture().get_image().save_png(path)
		if err != OK:
			printerr("could not save ", path)
			status = 1
		else:
			print("saved ", path)
	quit(status)
