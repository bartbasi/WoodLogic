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
const NAMES: Array[String] = ["ratchet", "pop", "clink", "clink_tray", "knock", "knock_dull"]

## Noise state for one build: a small xorshift generator seeded per build, so a seed always
## gives the same samples and no global random state is used.
var _noise_state := 1


static func has_effect(effect: String) -> bool:
	return NAMES.has(effect)


## Builds one effect as float samples in -PEAK .. PEAK. An unknown name returns an empty array
## (the caller reports it).
static func build(effect: String, seed_value: int = 1) -> PackedFloat32Array:
	var synth := Synth.new()
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
		_:
			return out
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
static func to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream


## Writes a stream to a .wav file (for listening tests and tools).
static func save_wav(samples: PackedFloat32Array, path: String) -> Error:
	return to_stream(samples).save_to_wav(path)


# ---- building blocks ----

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
	out.resize(int(seconds * RATE))
	return out


## Adds a damped sine to out starting at start_s. decay_s is the time to fall to 1/e.
func _mode(out: PackedFloat32Array, start_s: float, freq: float, decay_s: float, amp: float, attack_s: float = 0.0006) -> void:
	var first := int(start_s * RATE)
	var count := mini(int(decay_s * 7.0 * RATE), out.size() - first)
	if count <= 0:
		return
	var w := TAU * freq / RATE
	var cs := cos(w)
	var sn := sin(w)
	var c := 1.0
	var s := 0.0
	var fall := exp(-1.0 / (decay_s * RATE))
	var env := amp
	var rise := 1.0 / maxf(1.0, attack_s * RATE)
	for i: int in count:
		var gain := minf(1.0, float(i) * rise)
		out[first + i] += s * env * gain
		var nc := c * cs - s * sn
		s = s * cs + c * sn
		c = nc
		env *= fall


## Adds a short burst of softened noise (a strike). smooth 0 is bright hiss, near 1 is dull thud.
func _burst(out: PackedFloat32Array, start_s: float, length_s: float, amp: float, smooth: float) -> void:
	var first := int(start_s * RATE)
	var count := mini(int(length_s * RATE), out.size() - first)
	var low := 0.0
	var fall := exp(-5.0 / maxf(1.0, length_s * RATE))
	var env := amp
	for i: int in count:
		low = low * smooth + _noise() * (1.0 - smooth)
		out[first + i] += low * env
		env *= fall


## A tone whose pitch glides from f0 to f1 over the length, with a falling envelope.
func _glide(out: PackedFloat32Array, start_s: float, length_s: float, f0: float, f1: float, amp: float) -> void:
	var first := int(start_s * RATE)
	var count := mini(int(length_s * RATE), out.size() - first)
	var phase := 0.0
	for i: int in count:
		var t := float(i) / float(count)
		var f := f0 * pow(f1 / f0, minf(1.0, t * 1.6))
		phase += TAU * f / RATE
		out[first + i] += sin(phase) * amp * exp(-4.0 * t) * minf(1.0, float(i) / 12.0)


# ---- the effects ----

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
