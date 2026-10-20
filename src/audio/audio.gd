# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends Node
## The Audio autoload (docs/ARCHITECTURE.md 8 and 10.2). Every sound is made in code by Synth.
## Effects are built once at startup into AudioStreamWAV buffers and played from a small pool
## of players, so several can sound at once. Persisting the switches is the app flow's job.

const POOL_SIZE := 8
## Effects with several clicks or hits get two differently seeded buffers, and each play picks
## one at random, so the timing varies from play to play. The others get one, to keep the
## startup build fast.
const VARIANT_EFFECTS: Array[String] = ["ratchet", "knock"]
const VARIANTS := 2
## Random change to the pitch and loudness of each play.
const PITCH_JITTER := 0.04
const VOLUME_JITTER_DB := 1.5
const MIN_PITCH := 0.25
const MAX_PITCH := 4.0

## Seconds the last build of all buffers took (read by tests and logs).
var build_seconds := 0.0
## How many plays have been sent to a player since startup, and the name of the last one.
var play_count := 0
var last_played := ""

var _sound_on := true
var _music_on := true
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _rng := RandomNumberGenerator.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_release_players()


func _exit_tree() -> void:
	_release_players()


## Stops and frees every player and lets go of the streams, so nothing is still playing at quit.
func _release_players() -> void:
	if _players.is_empty():
		return
	for player: AudioStreamPlayer in _players:
		player.stop()
		player.stream = null
		player.free()
	_players.clear()
	_streams.clear()
	# A sound cut off at quit can still show in the engine's exit report. That is harmless.


func _ready() -> void:
	_rng.randomize()
	_build_all(1)
	for i: int in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_add_limiter()


## Plays one effect by name (the table in docs/ARCHITECTURE.md 10.2). pitch multiplies the
## effect's pitch; volume_db is clamped to 0 or below so a sound never goes past full scale.
func play(effect: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not Synth.has_effect(effect):
		push_error("Audio.play: unknown effect '%s'" % effect)
		return
	if not _sound_on:
		return
	var variants: Array = _streams.get(effect, [])
	if variants.is_empty():
		return
	play_count += 1
	last_played = effect
	if _players.is_empty():
		return
	var player := _free_player()
	player.stream = variants[_rng.randi() % variants.size()] as AudioStream
	player.pitch_scale = clampf(pitch * (1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER)), MIN_PITCH, MAX_PITCH)
	player.volume_db = minf(volume_db, 0.0) + _rng.randf_range(-VOLUME_JITTER_DB, 0.0)
	player.play()


## Sound effects on or off. With sound off, play() does nothing.
func set_sound(on: bool) -> void:
	_sound_on = on
	if not on:
		for player: AudioStreamPlayer in _players:
			player.stop()


## Music on or off. Phase 3 only stores the switch; the music comes in Phase 4.
func set_music(on: bool) -> void:
	_music_on = on


func is_sound_on() -> bool:
	return _sound_on


func is_music_on() -> bool:
	return _music_on


## Builds every effect (VARIANTS buffers each) and returns how long it took, in seconds.
func _build_all(seed_value: int) -> float:
	var start := Time.get_ticks_usec()
	_streams.clear()
	for effect: String in Synth.NAMES:
		var variants: Array[AudioStreamWAV] = []
		for v: int in (VARIANTS if VARIANT_EFFECTS.has(effect) else 1):
			variants.append(Synth.to_stream(Synth.build(effect, seed_value + v * 7919)))
		_streams[effect] = variants
	build_seconds = float(Time.get_ticks_usec() - start) / 1000000.0
	return build_seconds


## A player that is not playing, or else the next one in turn (round robin, so a sound is cut
## when all are busy).
func _free_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			return player
	_next_player = (_next_player + 1) % _players.size()
	return _players[_next_player]


## Several sounds at once can add up past full scale, so the Master bus gets a limiter.
func _add_limiter() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	for i: int in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(bus, limiter)
