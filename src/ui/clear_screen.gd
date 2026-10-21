# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name ClearScreen
extends UiScreen
## Level clear (docs/UX.md 3.4): the heading, three stars with what each one asks, the stars
## gained, unlock notes, and Next (or Done, or Another) and Replay. ClearEffects draws the
## stars (popping at 350, 650 and 950 ms); the buttons fade in from 350 ms and can be tapped from 500 ms, so a late tap on
## the last screw can not skip the screen. Nothing flashes.

## The big button: Next, Done (daily) or Another (Relaxed).
signal next_pressed
## The second button: Replay, or Done on a Relaxed clear.
signal replay_pressed

const SHOW_FROM_S := 0.35
const TAPPABLE_FROM_S := 0.5
const STAR_TIMES: Array[float] = [0.35, 0.65, 0.95]

## NUMBERED (or TUTORIAL), DAILY or RELAXED, from LevelData.
var kind := LevelData.NUMBERED
var level_number := 1
var level: LevelData
## (cleared, fast, clean) as 0 or 1 each.
var stars := Vector3i(1, 0, 0)
var elapsed_ms := 0
## Stars added to the bank by this clear.
var gain := 0
var streak := 0
## Plain lines such as "Unlocked: Walnut wood".
var unlock_notes: Array[String] = []
var _age := 0.0
var _next: UiButton
var _replay: UiButton
var _cells: Array[Control] = []
var _effects: ClearEffects
var _started := false


## info: kind, number, level (LevelData), stars (Vector3i), elapsed_ms, gain, streak, unlocks
## (Array of String).
static func make(info: Dictionary) -> ClearScreen:
	var s := new()
	s.kind = int(info.get("kind", LevelData.NUMBERED))
	s.level_number = int(info.get("number", 1))
	s.level = info.get("level")
	s.stars = info.get("stars", Vector3i(1, 0, 0))
	s.elapsed_ms = int(info.get("elapsed_ms", 0))
	s.gain = int(info.get("gain", 0))
	s.streak = int(info.get("streak", 0))
	for note: Variant in info.get("unlocks", []):
		s.unlock_notes.append(str(note))
	return s


func _build() -> void:
	var relaxed := kind == LevelData.RELAXED
	var daily := kind == LevelData.DAILY
	column.add_child(gap(28.0))
	var heading := "Level %d cleared" % level_number
	if relaxed:
		heading = "Nicely done"
	elif daily:
		heading = "Daily puzzle solved"
	column.add_child(plaque(heading, "HeadingLabel"))
	if not relaxed:
		column.add_child(gap(12.0))
		column.add_child(_star_row())
		column.add_child(_captions())
		column.add_child(plaque(_summary(), "HeadingLabel", true))
		if daily:
			column.add_child(plaque("Streak: %s" % UiText.days(streak), "BodyLabel", true))
	for note: String in unlock_notes:
		column.add_child(plaque(note, "BodyLabel"))
	column.add_child(spacer())
	var big := "Next"
	var big_note := "Level %d" % (level_number + 1)
	var second := "Replay"
	if relaxed:
		big = "Another"
		big_note = ""
		second = "Done"
	elif daily:
		big = "Done"
		big_note = ""
	_next = UiButton.make(big, UiButton.Kind.PRIMARY, big_note)
	_next.pressed.connect(func() -> void: next_pressed.emit())
	column.add_child(wide(_next))
	_replay = UiButton.make(second, UiButton.Kind.SECONDARY, "", 48.0)
	_replay.pressed.connect(func() -> void: replay_pressed.emit())
	column.add_child(wide(_replay))
	column.add_child(gap(16.0))
	for b: UiButton in [_next, _replay]:
		b.disabled = true
		b.modulate.a = 0.0


func _summary() -> String:
	if gain <= 0:
		return "No new stars this time"
	return "+1 star" if gain == 1 else "+%d stars" % gain


## Three empty 72 x 72 cells where the stars go: ClearEffects draws the stars over them.
func _star_row() -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 24)
	for i: int in 3:
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(72.0, 72.0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cells.append(cell)
		h.add_child(cell)
	return h


func _captions() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	var earned_fast := stars.y == 1
	var fast_detail := "Within %s" % UiText.seconds(level.par_time_s if level != null else 0)
	if earned_fast:
		fast_detail += "\nYours %s" % UiText.time(elapsed_ms)
	var par := level.tray_par if level != null else 0
	var clean_detail := "No tray, no helpers"
	if par == 1:
		clean_detail = "Tray once or never, no helpers"
	elif par >= 2:
		clean_detail = "Tray %d times or fewer, no helpers" % par
	var columns := [["Cleared", "Every screw is out"], ["Fast", fast_detail], ["Clean", clean_detail]]
	for c: Array in columns:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 2)
		var l := Label.new()
		l.text = c[0]
		l.theme_type_variation = "ButtonLabel"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var d := Label.new()
		d.text = c[1]
		d.theme_type_variation = "CaptionLabel"
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		v.add_child(d)
		h.add_child(v)
	return h


## Starts the celebration once the layout has settled: ClearEffects needs the star centers.
## The chime plays with the screen, a star note with each earned star (rising a little for
## each), and the unlock sound when there is an unlock note.
func _start() -> void:
	_started = true
	play_sound("chime")
	if kind == LevelData.RELAXED:
		return
	_effects = ClearEffects.new()
	add_child(_effects)
	move_child(_effects, 1)
	var centers: Array[Vector2] = []
	for cell: Control in _cells:
		centers.append(cell.global_position - global_position + cell.size / 2.0)
	var earned: Array[bool] = [stars.x == 1, stars.y == 1, stars.z == 1]
	_effects.setup(Rect2(Vector2.ZERO, size), centers, earned, 36.0)
	_effects.play()
	var pitch := 1.0
	for i: int in 3:
		if earned[i]:
			var note := pitch
			get_tree().create_timer(ClearEffects.STAR_TIMES[i]).timeout.connect(func() -> void: play_sound("star", note))
			pitch *= 1.12
	if not unlock_notes.is_empty():
		get_tree().create_timer(0.5).timeout.connect(func() -> void: play_sound("unlock"))


## A tap on the screen (not on a button) skips the rest of the celebration.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and _effects != null:
		_effects.skip()


func _process(delta: float) -> void:
	if not _started and (_cells.is_empty() or _cells[0].size.x > 1.0):
		# One frame after the layout, so the star cells have their places.
		_started = true
		_start.call_deferred()
	_age += delta
	var a := clampf((_age - SHOW_FROM_S) / (TAPPABLE_FROM_S - SHOW_FROM_S), 0.0, 1.0)
	for b: UiButton in [_next, _replay]:
		b.modulate.a = a
	if _age >= TAPPABLE_FROM_S:
		for b: UiButton in [_next, _replay]:
			b.disabled = false
		set_process(false)


## Shows the buttons and the stars at once (screenshots).
func skip_delay() -> void:
	_age = TAPPABLE_FROM_S
	if _effects != null:
		_effects.skip()
