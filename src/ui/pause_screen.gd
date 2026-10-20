# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name PauseScreen
extends UiScreen
## Pause (docs/UX.md 3.3). It covers the board completely, so thinking time does not help the
## speed star. Resume, Retry, Sound, Music and Quit to title.

signal resume_pressed
signal retry_pressed
signal quit_pressed
signal sound_toggled(on: bool)
signal music_toggled(on: bool)

var level_number := 1
var sound_on := true
var music_on := true
var _sound: UiButton
var _music: UiButton


static func make(level: int, sound: bool, music: bool) -> PauseScreen:
	var s := PauseScreen.new()
	s.level_number = level
	s.sound_on = sound
	s.music_on = music
	return s


func _build() -> void:
	column.add_child(gap(56.0))
	column.add_child(plaque("Paused", "HeadingLabel"))
	column.add_child(plaque("Level %d" % level_number, "BodyLabel", true))
	column.add_child(spacer())
	var resume := UiButton.make("Resume", UiButton.Kind.PRIMARY)
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	column.add_child(wide(resume))
	var retry := UiButton.make("Retry", UiButton.Kind.SECONDARY)
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	column.add_child(wide(retry))
	_sound = UiButton.make(_toggle_text("Sound", sound_on), UiButton.Kind.SECONDARY)
	_sound.pressed.connect(_on_sound)
	_music = UiButton.make(_toggle_text("Music", music_on), UiButton.Kind.SECONDARY)
	_music.pressed.connect(_on_music)
	column.add_child(row(_sound, _music))
	var quit := UiButton.make("Quit to title", UiButton.Kind.SECONDARY)
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	column.add_child(wide(quit))
	column.add_child(gap(16.0))


static func _toggle_text(what: String, on: bool) -> String:
	return "%s: %s" % [what, "On" if on else "Off"]


func _on_sound() -> void:
	sound_on = not sound_on
	_sound.set_label(_toggle_text("Sound", sound_on))
	sound_toggled.emit(sound_on)


func _on_music() -> void:
	music_on = not music_on
	_music.set_label(_toggle_text("Music", music_on))
	music_toggled.emit(music_on)
