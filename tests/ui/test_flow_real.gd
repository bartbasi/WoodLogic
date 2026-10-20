# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## A smoke test of the app flow with the real level scene (src/level/level_scene.tscn).

const FLOW := preload("res://src/ui/app_flow.tscn")


func test_the_real_level_scene_plays_level_1_and_pauses() -> void:
	tree.root.get_node("Save").call("erase_all")
	var flow := FLOW.instantiate() as AppFlow
	flow.quit_handler = func() -> void: pass
	add_node(flow)
	var started := Time.get_ticks_msec()
	while flow.state != AppFlow.State.LEVEL and Time.get_ticks_msec() - started < 15000:
		await tree.process_frame
	check_eq(flow.state, AppFlow.State.LEVEL, "level 1 is on")
	check(flow.level_scene is LevelScene, "the real level scene is used")
	await frames(10)
	flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check_eq(flow.state, AppFlow.State.PAUSE, "Back pauses")
	flow.screen.find_button("Retry").pressed.emit()
	check_eq(flow.state, AppFlow.State.LEVEL, "Retry returns to the level")
	await frames(5)
	flow.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check_eq(flow.state, AppFlow.State.PAUSE, "focus loss pauses")
	flow.screen.find_button("Resume").pressed.emit()
	check_eq(flow.state, AppFlow.State.LEVEL, "Resume returns to the level")
	await frames(5)
