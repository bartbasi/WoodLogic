# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name TitleScreen
extends UiScreen
## The title (docs/UX.md 3.1), Phase 3: the name, Play with the level it continues at, and the
## version. The rest of the buttons come in Phase 4.

signal play_pressed

var level_number := 1
var version_text := ""


static func make(level: int, version: String) -> TitleScreen:
	var s := TitleScreen.new()
	s.level_number = level
	s.version_text = version
	return s


func _build() -> void:
	column.add_child(gap(44.0))
	var name_plaque := plaque("WoodLogic", "DisplayLabel")
	name_plaque.custom_minimum_size.y = 120.0
	column.add_child(name_plaque)
	column.add_child(spacer())
	var play := UiButton.make("Play", UiButton.Kind.PRIMARY, "Level %d" % level_number)
	play.pressed.connect(func() -> void: play_pressed.emit())
	column.add_child(wide(play))
	column.add_child(gap(24.0))
	if version_text != "":
		column.add_child(plaque("Version " + version_text, "CaptionLabel", true))
	column.add_child(gap(24.0))
