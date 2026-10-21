# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LicenseScreen
extends MenuScreen
## The License page (docs/UX.md 3.10): the attribution line, a plain summary, then the NOTICE
## and LICENSE files word for word, read from the files that ship with the game so the text
## can never drift from the repository.

const SUMMARY := "WoodLogic is free software. You can use it, study it, share it and change it under the GNU General Public License version 3, with a few added terms. The added terms ask you to keep the line above, to mark changed versions as changed, and not to present them as the original or as made or endorsed by Play, Inc. or Bart Basi. They give no rights to the name WoodLogic or its icon."
const MISSING := "This copy of the game does not carry the file. It is in the source code at github.com/bartbasi/WoodLogic."


static func make() -> LicenseScreen:
	return new()


func _build_body() -> void:
	body.add_child(text_plaque(AboutScreen.ATTRIBUTION))
	body.add_child(text_plaque(SUMMARY, "SmallLabel"))
	body.add_child(group_heading("Additional terms"))
	body.add_child(big_text(read_file("res://NOTICE")))
	body.add_child(group_heading("GNU General Public License, version 3"))
	body.add_child(big_text(read_file("res://LICENSE")))
	body.add_child(gap(8.0))


static func read_file(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	return text if text != "" else MISSING


## Long legal text on a plaque in Small type, one wrapped RichTextLabel so it stays cheap.
func big_text(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Plaque"
	var r := RichTextLabel.new()
	r.bbcode_enabled = false
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.selection_enabled = false
	r.add_theme_font_size_override("normal_font_size", UiTheme.SIZE_SMALL)
	r.add_theme_color_override("default_color", UiTheme.TEXT)
	r.add_theme_constant_override("line_separation", 5)
	r.text = text
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(r)
	return p
