# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Writes every effect as a .wav file in build/audio/ so you can listen to it. Run:
##   C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/audio/write_wavs.gd


func _init() -> void:
	var dir := ProjectSettings.globalize_path("res://build/audio")
	DirAccess.make_dir_recursive_absolute(dir)
	for effect: String in Synth.NAMES:
		var path := "%s/%s.wav" % [dir, effect]
		var err := Synth.save_wav(Synth.build(effect, 1), path)
		print("%s: %s" % [path, "ok" if err == OK else error_string(err)])
	quit()
