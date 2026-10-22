# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MenuScreen
extends UiScreen
## The menu frame (docs/UX.md 1.6): a header, a body that scrolls, the game row and the nav
## dock, inside the usual column. The title, the progress map, Stats, Info, Settings, About,
## License, Credits and Relaxed setup all use it; subclasses fill `body`.

signal tab_pressed(tab: String)
signal game_pressed
signal coffee_pressed

const TABS := [["home", "Home"], ["map", "Map"], ["stats", "Stats"], ["info", "Info"], ["settings", "Settings"], ["about", "About"]]

var heading := ""
## The dock tab that is active.
var active_tab := "home"
## This screen shows the coffee chip in its header (it is still left out when coffee is off).
var chip := true
## The game row ("Play" or "Back to level") above the dock.
var game_row := true
## "" when no level is paused, else the note under "Back to level", such as "Level 7, paused".
var paused_text := ""
var next_level := 1
## The title shows the star bank at the left of the header instead of a heading.
var star_bank := -1
## False for a screen that lays its body out itself (the title, the map).
var use_scroll := true
var body := VBoxContainer.new()
var scroll := ScrollContainer.new()
var _game_button: UiButton


## Copies the facts every menu screen needs from the app flow.
func configure(tab: String, text: String, has_chip: bool, has_game_row: bool, next: int, paused: String) -> void:
	active_tab = tab
	heading = text
	chip = has_chip
	game_row = has_game_row
	next_level = next
	paused_text = paused


func _build() -> void:
	column.add_child(_make_header())
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if use_scroll:
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.add_child(body)
		column.add_child(scroll)
	else:
		scroll.free()
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(body)
	_build_body()
	if game_row:
		_game_button = UiButton.make("Back to level" if paused_text != "" else "Play", UiButton.Kind.PRIMARY, paused_text if paused_text != "" else "Level %d" % next_level, 56.0)
		_game_button.pressed.connect(func() -> void: game_pressed.emit())
		column.add_child(wide(_game_button))
	column.add_child(_make_dock())
	column.add_child(gap(4.0))


## Subclasses add their content to `body`.
func _build_body() -> void:
	pass


func _make_header() -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size.y = 56.0
	h.add_theme_constant_override("separation", 8)
	if star_bank >= 0:
		var c := StarChip.make(star_bank)
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(c)
	elif heading != "":
		var p := plaque(heading, "HeadingLabel", true)
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(p)
	h.add_child(spacer_h())
	if chip and Links.coffee_visible():
		var chip_button := CoffeeChip.make_chip()
		chip_button.pressed.connect(func() -> void: coffee_pressed.emit())
		h.add_child(chip_button)
	return h


func _make_dock() -> Control:
	var dock := HBoxContainer.new()
	dock.add_theme_constant_override("separation", 0)
	dock.custom_minimum_size.y = 52.0
	for entry: Array in TABS:
		var tab_id: String = entry[0]
		var tab := DockTab.make_tab(tab_id, entry[1], tab_id == active_tab)
		tab.pressed.connect(_on_tab.bind(tab_id))
		dock.add_child(tab)
	return dock


func _on_tab(tab_id: String) -> void:
	if tab_id == active_tab:
		scroll_to_top()
		return
	tab_pressed.emit(tab_id)


func scroll_to_top() -> void:
	# The title and the map have no scroll area (it was freed).
	if use_scroll:
		scroll.scroll_vertical = 0


## Flexible width for a header row.
func spacer_h() -> Control:
	var c := gap(0.0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## A full width plaque row with a label on the left and a value on the right (Stats).
func value_row(label_text: String, value_text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Plaque"
	p.custom_minimum_size.y = 48.0
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.theme_type_variation = "BodyLabel"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var v := Label.new()
	v.text = value_text
	v.theme_type_variation = "ButtonLabel"
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	h.add_child(v)
	p.add_child(h)
	return p


## A group heading on a slim plaque.
func group_heading(text: String) -> PanelContainer:
	var p := plaque(text, "ButtonLabel", false)
	return p


## A paragraph of body text on a plaque.
func text_plaque(text: String, variation: String = "BodyLabel") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Plaque"
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(l)
	return p
