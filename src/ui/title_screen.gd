# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name TitleScreen
extends MenuScreen
## The title (docs/UX.md 3.1): the star bank and the coffee chip in the header, the name, Play
## (or "Back to level" while a level is paused), Daily and Relaxed, and the dock with Home
## active. The decoration between the name and Play is the graphic designer's.

signal play_pressed
signal daily_pressed
signal relaxed_pressed

var level_number := 1
var version_text := ""
var daily_note := "Today's puzzle"
var daily_locked := false
var relaxed_locked := false
var play_button: UiButton
var daily_button: UiButton
var relaxed_button: UiButton
var board: TitleBoard
var _deco: Control
var _board_size := Vector2.ZERO


## info may hold: paused_text, bank, daily_note, daily_locked, relaxed_locked.
static func make(level: int, version: String, info: Dictionary = {}) -> TitleScreen:
	var s := new()
	s.level_number = level
	s.version_text = version
	s.next_level = level
	s.paused_text = str(info.get("paused_text", ""))
	s.star_bank = int(info.get("bank", 0))
	s.daily_note = UiText.opens_after() if bool(info.get("daily_locked", false)) else str(info.get("daily_note", "Today's puzzle"))
	s.daily_locked = bool(info.get("daily_locked", false))
	s.relaxed_locked = bool(info.get("relaxed_locked", false))
	s.active_tab = "home"
	s.chip = true
	s.game_row = false
	s.use_scroll = false
	return s


func _build_body() -> void:
	body.add_theme_constant_override("separation", 8)
	var name_plaque := plaque("WoodLogic", "DisplayLabel")
	name_plaque.custom_minimum_size.y = 120.0
	body.add_child(gap(8.0))
	body.add_child(name_plaque)
	_deco = Control.new()
	_deco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.clip_contents = true
	_deco.custom_minimum_size.y = 40.0
	_deco.resized.connect(_place_board)
	body.add_child(_deco)
	if paused_text != "":
		play_button = UiButton.make("Back to level", UiButton.Kind.PRIMARY, paused_text)
	else:
		play_button = UiButton.make("Play", UiButton.Kind.PRIMARY, "Level %d" % level_number)
	play_button.pressed.connect(func() -> void: play_pressed.emit())
	body.add_child(wide(play_button))
	daily_button = _mode_button("Daily", daily_note, daily_locked)
	daily_button.pressed.connect(func() -> void: daily_pressed.emit())
	relaxed_button = _mode_button("Relaxed", UiText.opens_after() if relaxed_locked else "No clock", relaxed_locked)
	relaxed_button.pressed.connect(func() -> void: relaxed_pressed.emit())
	body.add_child(row(daily_button, relaxed_button))
	if version_text != "":
		body.add_child(plaque("Version " + version_text, "CaptionLabel", true))


## A secondary button with a note, drawn locked (a padlock and a dimmed fill) when locked. A
## locked button still answers a tap, so the player is told why.
func _mode_button(label: String, note: String, locked: bool) -> UiButton:
	var b := UiButton.make(label, UiButton.Kind.SECONDARY, note, 56.0)
	if locked:
		# A dimmed fill; the text and the padlock stay at full contrast.
		b.add_theme_stylebox_override("normal", UiTheme.button_box(UiTheme.SECONDARY, UiTheme.SECONDARY_LIP, 0.35))
		b.add_theme_stylebox_override("hover", UiTheme.button_box(UiTheme.SECONDARY, UiTheme.SECONDARY_LIP, 0.35))
		var lock := IconView.make("padlock", 20.0, UiTheme.TEXT)
		lock.position = Vector2(10.0, 8.0)
		b.add_child(lock)
		# Next to the label (not the note): left of the label's first letter.
		var label_w := UiTheme.bold_font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_BUTTON).x
		b.resized.connect(func() -> void: lock.position.x = (b.size.x - label_w) / 2.0 - 26.0)
	return b


## The decorative board fills the space between the name and Play: at most 360 wide, centered,
## with 12 units kept clear above Play. It is decoration only and takes no touches. It is drawn
## again when the space changes size; the wood and metal come from Looks.current when the
## title is built (the title is built again after Settings).
func _place_board() -> void:
	var room := Vector2(minf(_deco.size.x, 360.0), _deco.size.y - 12.0)
	if room.x < 80.0 or room.y < 80.0:
		if board != null:
			board.visible = false
		return
	if board == null:
		board = TitleBoard.new()
		_deco.add_child(board)
	board.visible = true
	board.position = Vector2((_deco.size.x - room.x) / 2.0, 0.0)
	if room != _board_size:
		_board_size = room
		board.setup(room)
		board.bake()
