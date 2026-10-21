# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Checks the ambient music loop and how Audio starts and stops it.

const AudioScript := preload("res://src/audio/audio.gd")


func test_music_loop_is_quiet_and_has_no_seam() -> void:
	var start := Time.get_ticks_usec()
	var music := Synth.build_music(1)
	var ms := float(Time.get_ticks_usec() - start) / 1000.0
	print("    music render time: %.0f ms for %.0f seconds of music (on a worker thread in the game)" % [ms, Synth.MUSIC_SECONDS])
	check_eq(music.size(), int(Synth.MUSIC_SECONDS * Synth.MUSIC_RATE), "loop length in samples")
	var peak := 0.0
	var max_step := 0.0
	for i: int in range(1, music.size()):
		peak = maxf(peak, absf(music[i]))
		max_step = maxf(max_step, absf(music[i] - music[i - 1]))
	check_between(peak, 0.45, 0.51, "music peak")
	# The jump across the loop point must be no bigger than the steps inside the loop.
	var seam := absf(music[0] - music[music.size() - 1])
	check(seam <= max_step * 1.01 + 0.0001, "loop seam %.5f vs largest inner step %.5f" % [seam, max_step])
	check(max_step < 0.1, "no sharp edges inside the music (step %.4f)" % max_step)
	# Never silent: every second has some sound in it.
	for sec: int in int(Synth.MUSIC_SECONDS):
		var loud := 0.0
		for i: int in range(sec * Synth.MUSIC_RATE, (sec + 1) * Synth.MUSIC_RATE):
			loud = maxf(loud, absf(music[i]))
		check(loud > 0.05, "second %d has sound (%.3f)" % [sec, loud])


func test_music_is_the_same_for_one_seed() -> void:
	check(Synth.build_music(3) == Synth.build_music(3), "same seed, same music")


func test_music_stream_loops() -> void:
	var stream := Synth.to_stream(PackedFloat32Array([0.0, 0.1, 0.2, 0.1]), Synth.MUSIC_RATE, true)
	check_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "loop mode")
	check_eq(stream.loop_end, 4, "loop end")


func test_music_follows_the_switch_and_the_background() -> void:
	var audio := add_node(AudioScript.new()) as Node
	# The runner's frames are not real time, so wait on the clock (up to 20 seconds).
	var started := Time.get_ticks_msec()
	while not audio.is_music_playing() and Time.get_ticks_msec() - started < 20000:
		OS.delay_msec(20)
		await frames(1)
	check(audio.is_music_playing(), "music starts by itself once rendered (on by default)")
	check(audio.music_seconds > 0.0, "render time recorded")
	audio.set_music(false)
	check(not audio.is_music_playing(), "music stops at once when switched off")
	audio.set_music(true)
	check(audio.is_music_playing(), "music starts at once when switched on")
	audio.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not audio.is_music_playing(), "music silent in the background")
	audio.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(audio.is_music_playing(), "music resumes")
	audio.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	audio.set_music(false)
	audio.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not audio.is_music_playing(), "music stays off after returning if it was switched off")


func test_nothing_renders_while_music_is_off() -> void:
	var audio := AudioScript.new() as Node
	audio.set_music(false)
	add_node(audio)
	await frames(3)
	check(not audio.is_music_playing(), "no music")
	check_eq(audio._music_task, -1, "no render started with the switch off")
