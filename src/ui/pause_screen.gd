# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name PauseScreen
extends UiScreen
## Pause (docs/UX.md 3.3). It covers the board completely, so thinking time does not help the
## speed star. Resume, Retry, Sound, Music, Settings, Quit to title, and the coffee chip.

signal resume_pressed
signal retry_pressed
signal quit_pressed
signal settings_pressed
signal coffee_pressed
signal sound_toggled(on: bool)
signal music_toggled(on: bool)

## "Level 7", "Daily" or "Relaxed, Easy".
var level_line := "Level 1"
var sound_on := true
var music_on := true
var _sound: UiButton
var _music: UiButton
var _sound_icon: IconView
var _music_icon: IconView


static func make(line: String, sound: bool, music: bool) -> PauseScreen:
	var s := new()
	s.level_line = line
	s.sound_on = sound
	s.music_on = music
	return s


func _build() -> void:
	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 48.0
	var fill := gap(0.0)
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	if Links.coffee_visible():
		var chip := CoffeeChip.make_chip()
		chip.pressed.connect(func() -> void: coffee_pressed.emit())
		top.add_child(chip)
	column.add_child(top)
	column.add_child(gap(40.0))
	column.add_child(plaque("Paused", "HeadingLabel"))
	column.add_child(plaque(level_line, "BodyLabel", true))
	column.add_child(spacer())
	var resume := UiButton.make("Resume", UiButton.Kind.PRIMARY)
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	column.add_child(wide(resume))
	var retry := UiButton.make("Retry", UiButton.Kind.SECONDARY)
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	column.add_child(wide(retry))
	_sound = UiButton.make(_toggle_text("Sound", sound_on), UiButton.Kind.SECONDARY)
	_sound.pressed.connect(_on_sound)
	_sound_icon = _add_icon(_sound, "speaker" if sound_on else "speaker_off")
	_music = UiButton.make(_toggle_text("Music", music_on), UiButton.Kind.SECONDARY)
	_music.pressed.connect(_on_music)
	_music_icon = _add_icon(_music, "note" if music_on else "note_off")
	column.add_child(row(_sound, _music))
	var settings := UiButton.make("Settings", UiButton.Kind.SECONDARY)
	settings.pressed.connect(func() -> void: settings_pressed.emit())
	var quit := UiButton.make("Quit to title", UiButton.Kind.SECONDARY)
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	column.add_child(row(settings, quit))
	column.add_child(gap(16.0))


static func _toggle_text(what: String, on: bool) -> String:
	return "%s: %s" % [what, "On" if on else "Off"]


func _add_icon(button: UiButton, icon: String) -> IconView:
	button.pad_left(30.0)
	var iv := IconView.make(icon, 22.0, UiTheme.TEXT)
	iv.position = Vector2(8.0, 15.0)
	button.add_child(iv)
	return iv


func _on_sound() -> void:
	sound_on = not sound_on
	_sound.set_label(_toggle_text("Sound", sound_on))
	_sound_icon.set_icon("speaker" if sound_on else "speaker_off")
	sound_toggled.emit(sound_on)
	if sound_on:
		play_sound("tick")


func _on_music() -> void:
	music_on = not music_on
	_music.set_label(_toggle_text("Music", music_on))
	_music_icon.set_icon("note" if music_on else "note_off")
	music_toggled.emit(music_on)
	play_sound("tick")
