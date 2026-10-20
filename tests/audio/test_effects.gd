# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Checks the synthesized effects and the Audio service (docs/ARCHITECTURE.md 10.2).

const AudioScript := preload("res://src/audio/audio.gd")


func _peak(samples: PackedFloat32Array) -> float:
	var p := 0.0
	for s: float in samples:
		p = maxf(p, absf(s))
	return p


func test_every_effect_builds_a_sensible_buffer() -> void:
	for effect: String in Synth.NAMES:
		var samples := Synth.build(effect, 1)
		var seconds := float(samples.size()) / float(Synth.RATE)
		check_between(seconds, 0.1, 0.6, "%s length in seconds" % effect)
		check(_peak(samples) > 0.3, "%s is audible" % effect)
		# The tail must have faded out, so there is no click at the end.
		var tail := 0.0
		for i: int in range(samples.size() - 20, samples.size()):
			tail = maxf(tail, absf(samples[i]))
		check(tail < 0.01, "%s ends quietly (%.4f)" % [effect, tail])


func test_peak_stays_below_full_scale() -> void:
	for effect: String in Synth.NAMES:
		for seed_value: int in [1, 2, 3, 99, 7919, 123456]:
			var peak := _peak(Synth.build(effect, seed_value))
			check(peak <= 0.75, "%s seed %d peak %.3f" % [effect, seed_value, peak])
		var stream := Synth.to_stream(Synth.build(effect, 5))
		check(stream.data.size() == Synth.build(effect, 5).size() * 2, "%s packs to 16 bit" % effect)


func test_same_seed_same_samples() -> void:
	for effect: String in Synth.NAMES:
		check(Synth.build(effect, 42) == Synth.build(effect, 42), "%s repeats for one seed" % effect)
		check(Synth.build(effect, 42) != Synth.build(effect, 43), "%s differs between seeds" % effect)


func test_effects_differ_from_each_other() -> void:
	var seen: Array[PackedFloat32Array] = []
	for effect: String in Synth.NAMES:
		var samples := Synth.build(effect, 1)
		for other: PackedFloat32Array in seen:
			check(samples != other, "%s is its own sound" % effect)
		seen.append(samples)


func test_unknown_name_is_not_an_effect() -> void:
	# The lookup is tested without calling play(), because play() logs the error and the runner
	# fails any test that logs one.
	check(not Synth.has_effect("nonsense"), "unknown name rejected")
	check(Synth.build("nonsense", 1).is_empty(), "unknown name builds nothing")
	for effect: String in Synth.NAMES:
		check(Synth.has_effect(effect), "%s is known" % effect)


func test_sound_off_plays_nothing() -> void:
	var audio := add_node(AudioScript.new()) as Node
	audio.set_sound(false)
	audio.play("clink")
	check_eq(audio.play_count, 0, "plays with sound off")
	audio.set_sound(true)
	audio.play("clink")
	check_eq(audio.play_count, 1, "plays with sound on")
	check_eq(audio.last_played, "clink", "last played")


func test_switches_are_stored_and_default_on() -> void:
	var audio := add_node(AudioScript.new()) as Node
	check(audio.is_sound_on() and audio.is_music_on(), "both on by default")
	audio.set_music(false)
	check(not audio.is_music_on(), "music off")
	check(audio.is_sound_on(), "sound unaffected by music switch")


func test_pitch_and_volume_extremes_do_not_fail() -> void:
	var audio := add_node(AudioScript.new()) as Node
	for effect: String in Synth.NAMES:
		audio.play(effect, 1.3, -12.0)
		audio.play(effect, 0.85)
		audio.play(effect, 100.0, 40.0)
	check_eq(audio.play_count, Synth.NAMES.size() * 3, "plays counted")


func test_build_time_is_sane() -> void:
	var audio := add_node(AudioScript.new()) as Node
	var best := 1.0
	for i: int in 3:
		best = minf(best, audio._build_all(1))
	var one_variant_ms := 0.0
	var start := Time.get_ticks_usec()
	for effect: String in Synth.NAMES:
		Synth.to_stream(Synth.build(effect, 1))
	one_variant_ms = float(Time.get_ticks_usec() - start) / 1000.0
	print("    audio build time: %.1f ms for all %d buffers, %.1f ms for one buffer each" % [best * 1000.0, Synth.NAMES.size() + AudioScript.VARIANT_EFFECTS.size(), one_variant_ms])
	# The 50 ms target is checked by reading the printed number above. A wall-clock limit that
	# tight would flake when several test runs share the PC, so this only fails when something
	# has gone badly wrong.
	check(best < 0.25, "build took %.1f ms" % (best * 1000.0))
