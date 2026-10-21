# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Synth
extends RefCounted
## Builds the sound effects as sample arrays, in code (docs/ARCHITECTURE.md 10.2). Nothing here
## touches the audio device, so tests can build and measure every effect. Each effect is a few
## damped sine "modes" (the way a struck piece of wood or metal rings) plus a short burst of
## noise for the strike. Everything runs at 22050 Hz mono so building stays quick on a phone.

const RATE := 22050
## Every effect is scaled so its loudest sample lands here, leaving headroom below full scale.
const PEAK := 0.7
const NAMES: Array[String] = [
	"ratchet", "pop", "clink", "clink_tray", "knock", "knock_dull",
	"lid", "tick", "creak", "chime", "star", "lose", "unlock", "tap", "undo", "wood_pop",
]
## Dull, low sounds are made at half the rate, which halves their build time.
const LOW_RATE := 11025
const LOW_RATE_NAMES: Array[String] = ["knock", "knock_dull", "creak", "lose", "tap", "wood_pop", "chime", "star", "unlock", "tick", "lid", "undo"]
## The music is soft and low, so it is rendered at a low rate too.
const MUSIC_RATE := 8000
## The music loop's peak (the player lowers it further) and length in seconds.
const MUSIC_PEAK := 0.5
const MUSIC_SECONDS := 32.0

## Noise state for one build: a small xorshift generator seeded per build, so a seed always
## gives the same samples and no global random state is used.
var _noise_state := 1
var _rate := RATE


## The sample rate an effect is built at.
static func rate_of(effect: String) -> int:
	return LOW_RATE if LOW_RATE_NAMES.has(effect) else RATE


static func has_effect(effect: String) -> bool:
	return NAMES.has(effect)


## Builds one effect as float samples in -PEAK .. PEAK. An unknown name returns an empty array
## (the caller reports it).
static func build(effect: String, seed_value: int = 1) -> PackedFloat32Array:
	var synth := Synth.new()
	synth._rate = rate_of(effect)
	synth._noise_state = (seed_value * 2654435761 + 12345) & 0x7fffffff
	if synth._noise_state == 0:
		synth._noise_state = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	match effect:
		"ratchet":
			out = synth._ratchet(rng)
		"pop":
			out = synth._pop(rng)
		"clink":
			out = synth._clink(rng)
		"clink_tray":
			out = synth._clink_tray(rng)
		"knock":
			out = synth._knock(rng)
		"knock_dull":
			out = synth._knock_dull(rng)
		"lid":
			out = synth._lid(rng)
		"tick":
			out = synth._tick(rng)
		"creak":
			out = synth._creak(rng)
		"chime":
			out = synth._chime(rng)
		"star":
			out = synth._star(rng)
		"lose":
			out = synth._lose(rng)
		"unlock":
			out = synth._unlock(rng)
		"tap":
			out = synth._tap(rng)
		"undo":
			out = synth._undo(rng)
		"wood_pop":
			out = synth._wood_pop(rng)
		_:
			return out
	# A very short fade at the very end, so a cut-off tail can never click.
	var fade := mini(out.size(), int(0.008 * synth._rate))
	for i: int in fade:
		out[out.size() - 1 - i] *= float(i) / float(fade)
	return normalized(out)


## Scales samples so the loudest one is PEAK.
static func normalized(samples: PackedFloat32Array) -> PackedFloat32Array:
	var loudest := 0.0
	for s: float in samples:
		loudest = maxf(loudest, absf(s))
	if loudest <= 0.0:
		return samples
	var gain := PEAK / loudest
	for i: int in samples.size():
		samples[i] *= gain
	return samples


## Packs float samples into a 16 bit mono AudioStreamWAV.
static func to_stream(samples: PackedFloat32Array, rate: int = RATE, looped: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


## Writes samples to a .wav file (for listening tests and tools).
static func save_wav(samples: PackedFloat32Array, path: String, rate: int = RATE) -> Error:
	return to_stream(samples, rate).save_to_wav(path)


# building blocks

func _noise() -> float:
	# xorshift on 31 bits, returns -1 .. 1.
	var x := _noise_state
	x ^= (x << 13) & 0x7fffffff
	x ^= x >> 17
	x ^= (x << 5) & 0x7fffffff
	_noise_state = x
	return float(x) / 1073741823.5 - 1.0


func _blank(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * _rate))
	return out


## Adds a damped sine to out starting at start_s. decay_s is the time to fall to 1/e.
func _mode(out: PackedFloat32Array, start_s: float, freq: float, decay_s: float, amp: float, attack_s: float = 0.0006) -> void:
	var first := int(start_s * _rate)
	var count := mini(int(decay_s * 5.0 * _rate), out.size() - first)
	if count <= 0:
		return
	# A damped rotation: each step turns (c, s) by the angle and shrinks it, so s is a decaying sine.
	var w := TAU * freq / _rate
	var fall := exp(-1.0 / (decay_s * _rate))
	var cs := cos(w) * fall
	var sn := sin(w) * fall
	var c := amp
	var s := 0.0
	var attack := mini(count, int(attack_s * _rate))
	var rise := 1.0 / maxf(1.0, float(attack))
	for i: int in attack:
		out[first + i] += s * float(i) * rise
		var nc := c * cs - s * sn
		s = s * cs + c * sn
		c = nc
	for i: int in range(attack, count):
		out[first + i] += s
		var nc := c * cs - s * sn
		s = s * cs + c * sn
		c = nc


## Adds a short burst of softened noise (a strike). smooth 0 is bright hiss, near 1 is dull thud.
func _burst(out: PackedFloat32Array, start_s: float, length_s: float, amp: float, smooth: float) -> void:
	var first := int(start_s * _rate)
	var count := mini(int(length_s * _rate), out.size() - first)
	var low := 0.0
	var fall := exp(-5.0 / maxf(1.0, length_s * _rate))
	var env := amp
	for i: int in count:
		low = low * smooth + _noise() * (1.0 - smooth)
		out[first + i] += low * env
		env *= fall


## A tone whose pitch glides from f0 to f1 over the length, with a falling envelope.
func _glide(out: PackedFloat32Array, start_s: float, length_s: float, f0: float, f1: float, amp: float) -> void:
	var first := int(start_s * _rate)
	var count := mini(int(length_s * _rate), out.size() - first)
	var phase := 0.0
	for i: int in count:
		var t := float(i) / float(count)
		var f := f0 * pow(f1 / f0, minf(1.0, t * 1.6))
		phase += TAU * f / _rate
		out[first + i] += sin(phase) * amp * exp(-4.0 * t) * minf(1.0, float(i) / 12.0)


# the effects

## Five quick clicks of a ratchet pawl, each a little higher and a little uneven in time.
func _ratchet(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.26)
	var t := 0.004
	for k: int in 5:
		var lift := 1.0 + 0.035 * float(k) + rng.randf_range(-0.02, 0.02)
		var amp := 0.75 + 0.1 * float(k) + rng.randf_range(-0.05, 0.05)
		_burst(out, t, 0.006, amp * 0.9, 0.35)
		_mode(out, t, 2300.0 * lift, 0.006, amp * 0.5, 0.0003)
		_mode(out, t, 980.0 * lift, 0.012, amp * 0.45, 0.0003)
		_mode(out, t, 4100.0 * lift, 0.004, amp * 0.18, 0.0002)
		t += 0.040 + rng.randf_range(-0.004, 0.004)
	return out


## A bright pop: a quick downward glide, a bright tick at the start and a little air.
func _pop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.16)
	_glide(out, 0.0, 0.11, 1500.0 * rng.randf_range(0.97, 1.03), 420.0, 0.8)
	_mode(out, 0.0, 2600.0, 0.01, 0.25, 0.0003)
	_burst(out, 0.0, 0.012, 0.5, 0.2)
	return out


## A metal clink: a sharp strike over three inharmonic rings that die away at different speeds.
func _clink(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.42)
	var base := 2650.0 * rng.randf_range(0.98, 1.02)
	_burst(out, 0.0, 0.004, 0.6, 0.1)
	_mode(out, 0.0, base, 0.11, 0.6, 0.0002)
	_mode(out, 0.0, base * 1.504, 0.075, 0.4, 0.0002)
	_mode(out, 0.0, base * 2.41, 0.05, 0.28, 0.0002)
	_mode(out, 0.0, base * 3.77, 0.025, 0.14, 0.0002)
	_mode(out, 0.0, base * 0.52, 0.04, 0.25, 0.0002)
	return out


## The tray clink: lower, shorter and duller, with a soft thud under it.
func _clink_tray(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.22)
	var base := 1450.0 * rng.randf_range(0.98, 1.02)
	_burst(out, 0.0, 0.006, 0.45, 0.6)
	_mode(out, 0.0, base, 0.035, 0.6, 0.0004)
	_mode(out, 0.0, base * 1.62, 0.02, 0.3, 0.0004)
	_mode(out, 0.0, base * 2.7, 0.012, 0.12, 0.0004)
	_mode(out, 0.0, 330.0, 0.03, 0.5, 0.001)
	return out


## A hollow wooden knock of a plank hitting something: low body modes, a woody tick and one
## fainter bounce a moment later.
func _knock(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.42)
	var base := 175.0 * rng.randf_range(0.97, 1.03)
	for hit: int in 2:
		var t := 0.0 if hit == 0 else 0.11 + rng.randf_range(-0.01, 0.01)
		var a := 1.0 if hit == 0 else 0.35
		_burst(out, t, 0.008, 0.5 * a, 0.7)
		_mode(out, t, base, 0.075, 0.9 * a, 0.0008)
		_mode(out, t, base * 2.35, 0.05, 0.5 * a, 0.0006)
		_mode(out, t, base * 4.1, 0.03, 0.28 * a, 0.0005)
		_mode(out, t, base * 6.4, 0.015, 0.12 * a, 0.0004)
	return out


## A soft dull knock: one low, quickly damped thump, like a knuckle on a thick board.
func _knock_dull(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.14)
	var base := 140.0 * rng.randf_range(0.97, 1.03)
	_burst(out, 0.0, 0.006, 0.4, 0.85)
	_mode(out, 0.0, base, 0.022, 0.9, 0.001)
	_mode(out, 0.0, base * 2.2, 0.012, 0.3, 0.001)
	return out


## A box lid shutting: a short wooden slap with a tiny scrape before it.
func _lid(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.3)
	var base := 250.0 * rng.randf_range(0.97, 1.03)
	_burst(out, 0.0, 0.05, 0.12, 0.5)
	var t := 0.045
	_burst(out, t, 0.01, 0.6, 0.6)
	_mode(out, t, base, 0.05, 0.9, 0.0008)
	_mode(out, t, base * 2.5, 0.03, 0.45, 0.0006)
	_mode(out, t, base * 4.6, 0.015, 0.2, 0.0005)
	_mode(out, t, 1900.0, 0.008, 0.18, 0.0003)
	return out


## A soft clock tick: two short damped tones, quiet and rounded.
func _tick(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.1)
	var f := rng.randf_range(0.98, 1.02)
	_mode(out, 0.0, 1750.0 * f, 0.008, 0.7, 0.0008)
	_mode(out, 0.0, 880.0 * f, 0.016, 0.5, 0.001)
	_burst(out, 0.0, 0.004, 0.1, 0.8)
	return out


## A soft creak: a slow stick and slip pulse train pushed through a resonance, so it sounds like
## wood fibres rubbing, swelling and fading.
func _creak(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.5)
	var n := out.size()
	var phase := 0.0
	var f0 := rng.randf_range(58.0, 72.0)
	# Two pole resonator near 650 Hz.
	var w := TAU * 650.0 / _rate
	var r := 0.96
	var a1 := 2.0 * r * cos(w)
	var a2 := -r * r
	var y1 := 0.0
	var y2 := 0.0
	var wobble := 0.0
	for i: int in n:
		var t := float(i) / float(n)
		wobble = wobble * 0.995 + _noise() * 0.02
		var f := f0 * (1.0 + 0.5 * t + wobble)
		phase += f / _rate
		if phase >= 1.0:
			phase -= 1.0
		var src := (phase * 2.0 - 1.0) * 0.5 + _noise() * 0.15
		var y := src + a1 * y1 + a2 * y2
		y2 = y1
		y1 = y
		var env := sin(PI * t)
		out[i] = y * env * env
	return out


## A short rising chime for a cleared level: four bell notes up a major arpeggio, ending on a
## longer ring.
func _chime(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.85)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	for k: int in notes.size():
		var t := maxf(0.0, 0.11 * float(k) + rng.randf_range(-0.004, 0.004))
		var last := k == notes.size() - 1
		var f := notes[k]
		var decay := 0.22 if last else 0.12
		_mode(out, t, f, decay, 0.7, 0.002)
		_mode(out, t, f * 2.0, decay * 0.5, 0.18, 0.002)
	return out


## One bell note for a star popping in; the caller raises the pitch for each star.
func _star(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.45)
	var f := 880.0 * rng.randf_range(0.99, 1.01)
	_mode(out, 0.0, f, 0.14, 0.7, 0.002)
	_mode(out, 0.0, f * 2.0, 0.07, 0.2, 0.002)
	_mode(out, 0.0, f * 2.76, 0.03, 0.08, 0.002)
	_burst(out, 0.0, 0.004, 0.08, 0.5)
	return out


## A soft falling tone for a loss: a warm tone sliding down about a fifth, fading out.
func _lose(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.8)
	var n := out.size()
	var f0 := 392.0 * rng.randf_range(0.99, 1.01)
	var phase := 0.0
	for i: int in n:
		var t := float(i) / float(n)
		var f := f0 * pow(0.62, minf(1.0, t * 1.3))
		phase += TAU * f / _rate
		var env := minf(1.0, float(i) / (0.03 * _rate)) * exp(-3.2 * t)
		out[i] = (sin(phase) + 0.3 * sin(phase * 2.0)) * env
	return out


## An unlock sparkle: two quick high bell notes, the second higher.
func _unlock(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.6)
	var f := rng.randf_range(0.99, 1.01)
	_mode(out, 0.0, 1174.7 * f, 0.1, 0.6, 0.001)
	_mode(out, 0.0, 2349.0 * f, 0.04, 0.12, 0.001)
	_mode(out, 0.07, 1760.0 * f, 0.16, 0.7, 0.001)
	_mode(out, 0.07, 3520.0 * f, 0.06, 0.12, 0.001)
	_mode(out, 0.07, 4200.0 * f, 0.03, 0.05, 0.001)
	return out


## A faint wooden tap, very short and dull (the caller plays it quietly).
func _tap(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.07)
	var f := rng.randf_range(0.96, 1.04)
	_burst(out, 0.0, 0.004, 0.4, 0.85)
	_mode(out, 0.0, 420.0 * f, 0.009, 0.8, 0.0008)
	_mode(out, 0.0, 980.0 * f, 0.005, 0.25, 0.0006)
	return out


## The ratchet played backwards and softer, for an undo.
func _undo(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.2)
	var t := 0.01
	for k: int in 4:
		var lift := 1.0 - 0.03 * float(k)
		_burst(out, t, 0.006, 0.8, 0.4)
		_mode(out, t, 2000.0 * lift, 0.006, 0.5, 0.0003)
		_mode(out, t, 900.0 * lift, 0.012, 0.45, 0.0003)
		t += 0.036 + rng.randf_range(-0.003, 0.003)
	# Reverse, with a short fade at the start so the swell does not click.
	var n := out.size()
	var rev := PackedFloat32Array()
	rev.resize(n)
	for i: int in n:
		rev[i] = out[n - 1 - i] * minf(1.0, float(i) / 40.0)
	return rev


## A small wooden pop for the extra slot: a short downward glide with a hollow body tone.
func _wood_pop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _blank(0.14)
	var f := rng.randf_range(0.97, 1.03)
	_glide(out, 0.0, 0.09, 760.0 * f, 300.0, 0.7)
	_mode(out, 0.0, 520.0 * f, 0.03, 0.4, 0.001)
	_burst(out, 0.0, 0.006, 0.25, 0.7)
	return out


# the music

## Renders the music loop: slow soft chords with a few sparse bell notes, at MUSIC_RATE. Notes
## that run past the end wrap round to the start, so the loop has no seam. Takes a second or
## more, so the game calls it on a worker thread.
static func build_music(seed_value: int = 1) -> PackedFloat32Array:
	var synth := Synth.new()
	synth._rate = MUSIC_RATE
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var total := int(MUSIC_SECONDS * MUSIC_RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	# One envelope shared by every pad note: a slow swell in, a held middle, a long fade out.
	var chord_len := MUSIC_SECONDS / 4.0
	var note_len := int((chord_len + 3.5) * MUSIC_RATE)
	var env := PackedFloat32Array()
	env.resize(note_len)
	var rise := 2.2 * MUSIC_RATE
	var hold := chord_len * MUSIC_RATE
	for i: int in note_len:
		var e := 1.0
		if float(i) < rise:
			var x := float(i) / rise
			e = x * x * (3.0 - 2.0 * x)
		elif float(i) > hold:
			var y := minf(1.0, (float(i) - hold) / (float(note_len) - hold))
			e = 0.5 + 0.5 * cos(PI * y)
		env[i] = e
	# Four chords, each as three low notes (Hz). C, A minor, F, G: calm and open.
	var chords: Array = [
		[130.81, 196.0, 329.63],
		[110.0, 164.81, 261.63],
		[87.31, 130.81, 220.0],
		[98.0, 146.83, 246.94],
	]
	for c: int in 4:
		var start := int(float(c) * chord_len * MUSIC_RATE)
		var notes: Array = chords[c]
		for v: int in notes.size():
			var f: float = notes[v]
			var amp := 0.32 if v < 2 else 0.2
			synth._pad_voice(out, env, start, f, amp)
			# A slightly detuned twin gives a slow, gentle shimmer.
			synth._pad_voice(out, env, start, f * 1.004, amp * 0.6)
	# Sparse bells from a pentatonic scale, never two close together.
	var scale: Array[float] = [523.25, 587.33, 659.25, 783.99, 880.0]
	var when := 2.5
	while when < MUSIC_SECONDS - 3.0:
		var bell_freq: float = scale[rng.randi() % scale.size()]
		synth._bell(out, int(when * MUSIC_RATE), bell_freq, 0.12 + rng.randf() * 0.06)
		when += 4.5 + rng.randf() * 3.5
	var loudest := 0.0
	for s: float in out:
		loudest = maxf(loudest, absf(s))
	if loudest > 0.0:
		var gain := MUSIC_PEAK / loudest
		for i: int in total:
			out[i] *= gain
	return out


## Adds one pad note (a sine shaped by env) at start, wrapping past the end of out.
func _pad_voice(out: PackedFloat32Array, env: PackedFloat32Array, start: int, freq: float, amp: float) -> void:
	var n := out.size()
	var w := TAU * freq / _rate
	var cs := cos(w)
	var sn := sin(w)
	var c := 1.0
	var s := 0.0
	var idx := start
	for i: int in env.size():
		out[idx] += s * env[i] * amp
		var nc := c * cs - s * sn
		s = s * cs + c * sn
		c = nc
		idx += 1
		if idx >= n:
			idx -= n


## Adds one soft bell note (a slow decaying sine), wrapping past the end of out.
func _bell(out: PackedFloat32Array, start: int, freq: float, amp: float) -> void:
	var n := out.size()
	var length := int(4.0 * _rate)
	var w := TAU * freq / _rate
	var fall := exp(-1.0 / (1.1 * _rate))
	var env := amp
	var idx := start
	for i: int in length:
		var gain := minf(1.0, float(i) / (0.02 * _rate))
		out[idx] += sin(w * float(i)) * env * gain
		env *= fall
		idx += 1
		if idx >= n:
			idx -= n
