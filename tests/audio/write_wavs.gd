# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Writes every effect and the music as .wav files in build/audio/ so you can listen. The command
## is in the audio-dev report and in tools/test.sh style: Godot console, headless, this script with -s.


func _init() -> void:
	var dir := ProjectSettings.globalize_path("res://build/audio")
	DirAccess.make_dir_recursive_absolute(dir)
	for effect: String in Synth.NAMES:
		var path := "%s/%s.wav" % [dir, effect]
		var err := Synth.save_wav(Synth.build(effect, 1), path, Synth.rate_of(effect))
		print("%s: %s" % [path, "ok" if err == OK else error_string(err)])
	# Music: one 32 second loop, and the loop played twice (64 seconds) to hear the seam.
	var music := Synth.build_music(1)
	Synth.save_wav(music, dir + "/music_loop.wav", Synth.MUSIC_RATE)
	var twice := music.duplicate()
	twice.append_array(music)
	var err := Synth.save_wav(twice, dir + "/music_64s.wav", Synth.MUSIC_RATE)
	print("%s/music_64s.wav: %s" % [dir, "ok" if err == OK else error_string(err)])
	quit()
