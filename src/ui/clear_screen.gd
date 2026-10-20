# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name ClearScreen
extends UiScreen
## Level clear (docs/UX.md 3.4), Phase 3: the heading, Next and Replay, and no stars yet.
## Next and Replay fade in from 350 ms and can be tapped from 500 ms, so a late tap on the
## last screw can't skip the screen.

signal next_pressed
signal replay_pressed

const SHOW_FROM_S := 0.35
const TAPPABLE_FROM_S := 0.5

var level_number := 1
var _age := 0.0
var _next: UiButton
var _replay: UiButton


static func make(level: int) -> ClearScreen:
	var s := ClearScreen.new()
	s.level_number = level
	return s


func _build() -> void:
	column.add_child(gap(44.0))
	column.add_child(plaque("Level %d cleared" % level_number, "HeadingLabel"))
	column.add_child(spacer())
	_next = UiButton.make("Next", UiButton.Kind.PRIMARY, "Level %d" % (level_number + 1))
	_next.pressed.connect(func() -> void: next_pressed.emit())
	column.add_child(wide(_next))
	_replay = UiButton.make("Replay", UiButton.Kind.SECONDARY, "", 48.0)
	_replay.pressed.connect(func() -> void: replay_pressed.emit())
	column.add_child(wide(_replay))
	column.add_child(gap(16.0))
	for b: UiButton in [_next, _replay]:
		b.disabled = true
		b.modulate.a = 0.0


func _process(delta: float) -> void:
	_age += delta
	var a := clampf((_age - SHOW_FROM_S) / (TAPPABLE_FROM_S - SHOW_FROM_S), 0.0, 1.0)
	for b: UiButton in [_next, _replay]:
		b.modulate.a = a
	if _age >= TAPPABLE_FROM_S:
		for b: UiButton in [_next, _replay]:
			b.disabled = false
		set_process(false)


## Shows the buttons at once (screenshots).
func skip_delay() -> void:
	_age = TAPPABLE_FROM_S
