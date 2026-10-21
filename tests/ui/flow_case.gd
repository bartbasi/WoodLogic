# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name FlowCase
extends TestCase
## Shared helpers for the app flow tests: start the app over a fake level scene, wait for
## states, tap buttons. Links never open anything: the opener records addresses instead.

const FLOW := preload("res://src/ui/app_flow.tscn")
const FAKE_SCENE := "res://tests/ui/fake_level_scene.tscn"

var flow: AppFlow
var quit_calls := 0
var opened := PackedStringArray()


func cleanup() -> void:
	Links.opener = Callable()
	Links.coffee_hidden_for_tests = -1
	await super.cleanup()


func save_node() -> Node:
	return tree.root.get_node("Save")


## Starts the app with the saved progress cleared, then `cleared` numbered levels won in order
## (so Play continues at cleared + 1). `today` fixes the Daily's date.
func start(cleared: int = 0, today: String = "2026-10-21") -> void:
	Links.opener = func(address: String) -> Variant:
		opened.append(address)
		return OK
	var save := save_node()
	save.erase_all()
	for n: int in range(1, cleared + 1):
		var level := LevelCatalog.get_level(LevelData.NUMBERED, n, "").level
		save.record_win(level, 9000, Vector3i(1, 1, 1))
	boot(today)


func boot(today: String = "2026-10-21") -> void:
	flow = FLOW.instantiate() as AppFlow
	flow.level_scene_path = FAKE_SCENE
	flow.today_override = today
	flow.quit_handler = func() -> void: quit_calls += 1
	add_node(flow)


func until(condition: Callable, timeout_ms: int = 20000) -> bool:
	var started := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - started > timeout_ms:
			return false
		await tree.process_frame
	return true


func in_state(s: AppFlow.State) -> bool:
	return await until(func() -> bool: return flow.state == s)


func fake() -> FakeLevelScene:
	return flow.level_scene as FakeLevelScene


## Taps a button on the current screen (or the overlay when `on_overlay`).
func tap(label: String, on_overlay: bool = false) -> void:
	var host: UiScreen = flow.overlay if on_overlay else flow.screen
	var b := host.find_button(label)
	check(b != null, "the screen has a button \"%s\"" % label)
	if b != null:
		check(not b.disabled, "\"%s\" can be tapped" % label)
		b.pressed.emit()


func back() -> void:
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)


## Waits past the 500 ms the clear screen keeps its buttons off.
func past_clear_delay() -> void:
	await frames(40)


## Plays level 1 of a first launch up to the level screen.
func start_level_1() -> void:
	start()
	await in_state(AppFlow.State.LEVEL)
