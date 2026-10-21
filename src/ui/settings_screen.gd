# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name SettingsScreen
extends MenuScreen
## Settings (docs/UX.md 3.8): Sound, Music, Colorblind symbols, Wood, Metal and Reset progress.
## Changes apply in the same frame; the app flow saves them.

signal sound_toggled(on: bool)
signal music_toggled(on: bool)
signal symbols_toggled(on: bool)
signal look_changed(wood: String, metal: String)
signal reset_requested

var info: Dictionary = {}
var wood_id := "oak"
var metal_id := "steel"
var _wood_swatches: Array[Swatch] = []
var _metal_swatches: Array[Swatch] = []
var _wood_caption: Label
var _metal_caption: Label


## info: sound, music, symbols (bool); wood, metal (the chosen ids); unlocked_wood and
## unlocked_metal (PackedStringArray); best_streak and highest_cleared (int).
static func make(settings: Dictionary) -> SettingsScreen:
	var s := new()
	s.info = settings
	s.wood_id = str(settings.get("wood", "oak"))
	s.metal_id = str(settings.get("metal", "steel"))
	return s


func _build_body() -> void:
	var sound := ToggleRow.make_row("Sound", "Taps, clinks and wood knocks", bool(info.get("sound", true)))
	sound.tick_when_off = false
	sound.switched.connect(func(on: bool) -> void: sound_toggled.emit(on))
	body.add_child(sound)
	var music := ToggleRow.make_row("Music", "Quiet background tones", bool(info.get("music", true)))
	music.switched.connect(func(on: bool) -> void: music_toggled.emit(on))
	body.add_child(music)
	var symbols := ToggleRow.make_row("Colorblind symbols", "A shape on every screw and box", bool(info.get("symbols", true)), 64.0)
	symbols.switched.connect(func(on: bool) -> void: symbols_toggled.emit(on))
	body.add_child(symbols)
	body.add_child(_picker("Wood", "wood"))
	body.add_child(_picker("Metal", "metal"))
	var reset := UiButton.make("Reset progress", UiButton.Kind.DANGER, "Erase levels, stars, helpers and stats", 56.0)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func() -> void: reset_requested.emit())
	body.add_child(reset)
	body.add_child(gap(8.0))


## The entries of data/tuning.json's unlocks for one kind, in file order.
static func entries(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u: Dictionary in Tuning.unlocks:
		if u.get("what") == kind:
			out.append(u)
	return out


func _picker(title: String, kind: String) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = "Plaque"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var heading_label := Label.new()
	heading_label.text = title
	heading_label.theme_type_variation = "ButtonLabel"
	v.add_child(heading_label)
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	var chosen := wood_id if kind == "wood" else metal_id
	var open_ids: PackedStringArray = info.get("unlocked_" + kind, PackedStringArray(["oak" if kind == "wood" else "steel"]))
	var list := _wood_swatches if kind == "wood" else _metal_swatches
	for u: Dictionary in entries(kind):
		var id := str(u["id"])
		var sw := Swatch.make_swatch(id, id == chosen, not open_ids.has(id))
		sw.pressed.connect(_on_swatch.bind(kind, id))
		strip.add_child(sw)
		list.append(sw)
	v.add_child(strip)
	var caption := Label.new()
	caption.text = chosen.capitalize()
	caption.theme_type_variation = "SmallLabel"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.y = 20.0
	v.add_child(caption)
	if kind == "wood":
		_wood_caption = caption
	else:
		_metal_caption = caption
	p.add_child(v)
	return p


func _on_swatch(kind: String, id: String) -> void:
	var caption := _wood_caption if kind == "wood" else _metal_caption
	var list := _wood_swatches if kind == "wood" else _metal_swatches
	var swatch: Swatch = null
	for sw: Swatch in list:
		if sw.id == id:
			swatch = sw
	if swatch == null:
		return
	if swatch.locked:
		caption.text = caption_for(id, kind)
		UiScreen.shake(swatch)
		var audio := get_node_or_null("/root/Audio")
		if audio != null:
			audio.call("play", "knock_dull")
		return
	if kind == "wood":
		wood_id = id
	else:
		metal_id = id
	for sw: Swatch in list:
		sw.selected = sw.id == id
		sw.queue_redraw()
	caption.text = id.capitalize()
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.call("play", "tick")
	look_changed.emit(wood_id, metal_id)


## The caption for a locked swatch: how to unlock it (UX 3.8).
static func caption_for(id: String, kind: String) -> String:
	for u: Dictionary in entries(kind):
		if str(u["id"]) == id:
			if u.has("best_streak"):
				return "%s. Reach a %d day daily streak to unlock." % [id.capitalize(), int(u["best_streak"])]
			return "%s. Clear level %d to unlock." % [id.capitalize(), int(u.get("level", 0))]
	return id.capitalize()
