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
const VARIANT_EFFECTS: Array[String] = ["ratchet"]
const VARIANTS := 2
## Random change to the pitch and loudness of each play.
const PITCH_JITTER := 0.04
const VOLUME_JITTER_DB := 1.5
const MIN_PITCH := 0.25
const MAX_PITCH := 4.0
## The music sits well under the effects (which peak near -3 dBFS): its loop peaks at -6 dBFS
## and the player lowers it by this much more.
const MUSIC_DB := -14.0
const MUSIC_FADE_START_DB := -50.0

## Seconds the last build of all buffers took (read by tests and logs).
var build_seconds := 0.0
## How many plays have been sent to a player since startup, and the name of the last one.
var play_count := 0
var last_played := ""

## Tests set this to false before adding the node, so no music thread starts.
var render_music := true
## Seconds the music render took on its thread.
var music_seconds := 0.0
signal music_ready

var _suspended := false
var _music_player: AudioStreamPlayer
var _music_stream: AudioStreamWAV
var _music_task := -1
var _music_pos := 0.0
var _fade: Tween
var _sound_on := true
var _music_on := true
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _rng := RandomNumberGenerator.new()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			_release_players()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_set_suspended(true)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_set_suspended(false)


func _exit_tree() -> void:
	_release_players()


## Pauses (or resumes) every sound while the app is in the background. UX 4.3.
func _set_suspended(on: bool) -> void:
	if on == _suspended:
		return
	_suspended = on
	if on:
		# Short effects are simply cut. The music remembers where it was.
		for player: AudioStreamPlayer in _players:
			player.stop()
		if _music_player != null and _music_player.playing:
			_music_pos = _music_player.get_playback_position()
			_music_player.stop()
	_update_music()


func is_suspended() -> bool:
	return _suspended


## Stops and frees every player and lets go of the streams, so nothing is still playing at quit.
func _release_players() -> void:
	# The music thread must finish before its result is let go of.
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
	if _music_player != null and is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
		_music_player.free()
		_music_player = null
	_music_stream = null
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
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_add_limiter()
	# The music renders on a worker thread, and only once the music is wanted.
	_start_music_render.call_deferred()


## Plays one effect by name (the table in docs/ARCHITECTURE.md 10.2). pitch multiplies the
## effect's pitch; volume_db is clamped to 0 or below so a sound never goes past full scale.
func play(effect: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not Synth.has_effect(effect):
		push_error("Audio.play: unknown effect '%s'" % effect)
		return
	if not _sound_on or _suspended:
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


## Music on or off. It follows the switch at once: off stops it, on starts it (after a short
## fade in) as soon as the loop has been rendered.
func set_music(on: bool) -> void:
	_music_on = on
	if on:
		_start_music_render()
	_update_music()


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
			variants.append(Synth.to_stream(Synth.build(effect, seed_value + v * 7919), Synth.rate_of(effect)))
		_streams[effect] = variants
	build_seconds = float(Time.get_ticks_usec() - start) / 1000000.0
	return build_seconds


## Starts rendering the music loop on a worker thread, once, if the music is wanted. Nothing
## is rendered while the switch is off.
func _start_music_render() -> void:
	if not render_music or not _music_on or _music_stream != null or _music_task >= 0:
		return
	if _music_player == null:
		return
	_music_task = WorkerThreadPool.add_task(_render_music, false, "WoodLogic music")


## Runs on the worker thread. The loop is rendered and packed there, so the main thread only
## receives the finished stream.
func _render_music() -> void:
	var start := Time.get_ticks_usec()
	var stream := Synth.to_stream(Synth.build_music(1), Synth.MUSIC_RATE, true)
	music_seconds = float(Time.get_ticks_usec() - start) / 1000000.0
	_music_rendered.call_deferred(stream)


func _music_rendered(stream: AudioStreamWAV) -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
	if _music_player == null:
		return
	_music_stream = stream
	music_ready.emit()
	_update_music()


## Plays or stops the music to match the switch, the app state and whether it is rendered.
func _update_music() -> void:
	if _music_player == null:
		return
	if not _music_on or _music_stream == null:
		_music_pos = 0.0
		if _music_player.playing:
			_music_player.stop()
		if _fade != null:
			_fade.kill()
		return
	if _suspended:
		return
	if not _music_player.playing:
		_music_player.stream = _music_stream
		_music_player.volume_db = MUSIC_FADE_START_DB
		_music_player.play(_music_pos)
		_music_pos = 0.0
		if is_inside_tree():
			if _fade != null:
				_fade.kill()
			_fade = create_tween()
			_fade.tween_property(_music_player, "volume_db", MUSIC_DB, 1.5)
		else:
			_music_player.volume_db = MUSIC_DB


func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing


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
