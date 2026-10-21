# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name AboutScreen
extends MenuScreen
## About (docs/UX.md 3.9): what WoodLogic is and who made it, Send feedback, Source code,
## Supporting WoodLogic with the coffee button, Privacy, License and Credits. The wording of
## the fixed statements is CLAUDE.md's. With coffee hidden the whole Supporting block is left
## out and Privacy uses its store build wording.

signal feedback_pressed
signal source_pressed
signal license_pressed
signal credits_pressed

const WHAT := "WoodLogic is a free screw puzzle. It was made by Play, Inc. and designed by Bart Basi."
const SUPPORTING := "WoodLogic is free, with no ads and no tracking, and it always will be. If you'd like to support more games like it, you can buy me a coffee. Never expected, always appreciated."
const PRIVACY := "WoodLogic collects nothing: no ads, no tracking, no internet. The Buy me a coffee button only opens a web page in your phone's browser, and the game itself sends nothing."
const PRIVACY_NO_COFFEE := "WoodLogic collects nothing: no ads, no tracking, no internet. The game itself sends nothing."
const ATTRIBUTION := "Based on WoodLogic, designed and written by Bart Basi, with assistance from Claude. Copyright 2026 Play, Inc."

var version_text := ""


static func make(version: String) -> AboutScreen:
	var s := new()
	s.version_text = version
	return s


func _build_body() -> void:
	var what := PanelContainer.new()
	what.theme_type_variation = "Plaque"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var name_label := Label.new()
	name_label.text = "WoodLogic"
	name_label.theme_type_variation = "HeadingLabel"
	v.add_child(name_label)
	if version_text != "":
		var version := Label.new()
		version.text = "Version " + version_text
		version.theme_type_variation = "SmallLabel"
		v.add_child(version)
	v.add_child(_body_label(WHAT))
	what.add_child(v)
	body.add_child(what)
	body.add_child(_link_button("Send feedback", "Opens a draft in your email app. You can edit it first.", 76.0, feedback_pressed))
	body.add_child(_link_button("Source code", "Opens github.com/bartbasi/WoodLogic in your browser.", 76.0, source_pressed))
	if Links.coffee_visible():
		var support := PanelContainer.new()
		support.theme_type_variation = "Plaque"
		var sv := VBoxContainer.new()
		sv.add_theme_constant_override("separation", 8)
		var sh := Label.new()
		sh.text = "Supporting WoodLogic"
		sh.theme_type_variation = "ButtonLabel"
		sv.add_child(sh)
		sv.add_child(_body_label(SUPPORTING))
		var coffee := UiButton.make("Buy me a coffee", UiButton.Kind.SECONDARY, "Opens a web page in your browser.", 64.0)
		coffee.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		coffee.pressed.connect(func() -> void: coffee_pressed.emit())
		var cup := IconView.make("cup", 24.0, UiTheme.TEXT)
		cup.position = Vector2(12.0, 20.0)
		coffee.add_child(cup)
		sv.add_child(coffee)
		support.add_child(sv)
		body.add_child(support)
	var privacy := PanelContainer.new()
	privacy.theme_type_variation = "Plaque"
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	var ph := Label.new()
	ph.text = "Privacy"
	ph.theme_type_variation = "ButtonLabel"
	pv.add_child(ph)
	pv.add_child(_body_label(PRIVACY if Links.coffee_visible() else PRIVACY_NO_COFFEE))
	privacy.add_child(pv)
	body.add_child(privacy)
	body.add_child(_link_button("License", "", 56.0, license_pressed))
	body.add_child(_link_button("Credits", "", 56.0, credits_pressed))
	var attribution := Label.new()
	attribution.text = ATTRIBUTION
	attribution.theme_type_variation = "SmallLabel"
	attribution.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attribution.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(attribution)
	body.add_child(gap(8.0))


func _body_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "BodyLabel"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _link_button(label: String, note: String, height: float, sig: Signal) -> UiButton:
	var b := UiButton.make(label, UiButton.Kind.SECONDARY, note, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: sig.emit())
	return b
