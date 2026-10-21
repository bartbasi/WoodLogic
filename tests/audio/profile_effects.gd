# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Prints the build time of each effect.


func _init() -> void:
	for effect: String in Synth.NAMES:
		var t0 := Time.get_ticks_usec()
		var s := Synth.build(effect, 1)
		var t1 := Time.get_ticks_usec()
		Synth.to_stream(s, Synth.rate_of(effect))
		var t2 := Time.get_ticks_usec()
		print("%s: %d samples, build %.1f ms, pack %.1f ms" % [effect, s.size(), (t1 - t0) / 1000.0, (t2 - t1) / 1000.0])
	quit()
