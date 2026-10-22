# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends QaFlowCase
## Reproductions of the Phase 6 findings in docs/reviews/qa-6.md, kept after the fix round as
## regression tests. H3 (the active tab on the title and the map) and the made-ahead half of H4
## (Previous level, the Daily, the next Relaxed level, Next) now fail hard if they come back. The
## other half of H4, a replay deep in the map, is a wait Bart accepted on 22 October 2026: the
## test prints it with the word "accepted" and only checks that the level does start.
## While a finding is open (STRICT false) _expect only prints "OPEN FINDING" and passes.

const STRICT := false


func _expect(id: String, ok: bool, what: String) -> void:
	if ok:
		return
	if STRICT:
		check(false, "%s: %s" % [id, what])
	else:
		print("        OPEN FINDING %s: %s" % [id, what])


func test_h3_the_active_tab_scrolls_to_the_top_and_does_nothing_else() -> void:
	# UX 1.6. The runner fails any test that logs an error, so a script error from pressing the
	# active tab (the old one on the title: a freed scroll area) fails this test by itself.
	start(9)
	await frames(3)
	check(flow.screen is TitleScreen, "the title is showing")
	tap("Home")
	await frames(2)
	check(flow.screen is TitleScreen and flow.state == AppFlow.State.TITLE, "the Home tab on the title leaves the title as it is")
	for menu_name: String in ["map", "stats", "info", "settings", "about"]:
		flow.show_menu(menu_name)
		await frames(3)
		var tab := menu_name.capitalize()
		var before := flow.screen
		tap(tab)
		await frames(2)
		check(flow.screen == before and flow.state == AppFlow.State.MENU, "the %s tab on the %s screen leaves it as it is" % [tab, menu_name])


func test_h4_levels_made_ahead_start_at_once() -> void:
	# The fix round: the app makes N + 1, N - 1, today's Daily and each Relaxed band's next level
	# in the background (docs/ARCHITECTURE.md 4.4), so they start with no "One moment" screen.
	start_real_at(800)
	check(await level_on(), "level 801 is showing")
	check_eq(scene().get_level().number, 801, "the player's level")
	# Three at a time, at most 3 s each, five or six levels: a generous wait.
	await until(func() -> bool: return false, 14000)
	var started := Time.get_ticks_msec()
	flow.play_number(800)
	var previous_ms := Time.get_ticks_msec() - started
	check_eq(flow.state, AppFlow.State.LEVEL, "Previous level (800) started in the same frame")
	flow.play_number(801)
	started = Time.get_ticks_msec()
	flow.play_number(802)
	check_eq(flow.state, AppFlow.State.LEVEL, "Next (802) started in the same frame")
	flow.play_daily()
	check_eq(flow.state, AppFlow.State.LEVEL, "the Daily started in the same frame")
	for band: String in Tuning.BANDS:
		flow.play_relaxed(band)
		check_eq(flow.state, AppFlow.State.LEVEL, "the next %s Relaxed level started in the same frame" % band)
	print("        made ahead: Previous level took %d ms" % previous_ms)


func test_h4_a_deep_replay_still_waits_and_that_was_accepted() -> void:
	# Accepted by Bart on 22 October 2026: a replay of a level deep in the map is made when asked
	# for, behind "One moment". Measured here so the numbers are on record. It must start.
	var worst := 0
	var detail := PackedStringArray()
	for n: int in [326, 730, 144, 316]:
		start_real_at(800)
		var started := Time.get_ticks_msec()
		flow.play_number(n)
		var ok := await until(func() -> bool: return flow.state == AppFlow.State.LEVEL, 15000)
		var ms := Time.get_ticks_msec() - started
		check(ok, "level %d started" % n)
		detail.append("level %d: %d ms" % [n, ms])
		worst = maxi(worst, ms)
		flow.queue_free()
		await frames(2)
	print("        deep replays made on demand (accepted by Bart, 22 October 2026): %s" % ", ".join(detail))
	check(worst < 15000, "every deep replay started")
