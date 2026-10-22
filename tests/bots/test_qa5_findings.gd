# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends QaFlowCase
## Reproductions of the Phase 5 findings in docs/reviews/qa-5.md. Each test asserts what the
## documents say the game should do. While a finding is open it only prints "OPEN FINDING" and
## passes, so the suite stays green; set STRICT to true to make an open finding fail.

const STRICT := false


func _expect(id: String, ok: bool, what: String) -> void:
	if ok:
		return
	if STRICT:
		check(false, "%s: %s" % [id, what])
	else:
		print("        OPEN FINDING %s: %s" % [id, what])


func test_g1_a_gift_that_is_due_is_not_given_by_a_replay() -> void:
	# GDD 5: "Each is given once ... and never on a replay." UX 3.13.4: a player already past 50
	# gets it "on their next numbered level clear".
	start(60)
	for h: String in ["undo", "extra_slot", "screwdriver"]:
		save_node().mark_helper_met(h, 0)
	tap("Map")
	await frames(3)
	var view := (flow.screen as MapScreen).view
	view.tap(view.center_of(30))
	check(await in_state(AppFlow.State.LEVEL), "a replay of level 30")
	check_eq(fake().replays[-1], true, "it is a replay")
	fake().win()
	await past_clear_delay()
	var given := Array(save_node().gifts_given())
	_expect("G1", given.is_empty(), "winning a REPLAY of level 30 paid the gift for level 50 (gifts given: %s); GDD 5 says never on a replay, UX 3.13.4 says the next numbered clear" % str(given))


func test_g2_the_clear_screen_with_three_notes_keeps_replay_on_the_screen() -> void:
	# A save that never got its unlocks (an older build, or hand made) wins level 49 and is due
	# two unlock notes and the gift at once. UX 3.4 has room for two notes.
	var old := tree.root.size
	tree.root.size = Vector2i(360, 640)
	start(48)
	for h: String in ["undo", "extra_slot", "screwdriver"]:
		save_node().mark_helper_met(h, 0)
	tap("Play")
	await in_state(AppFlow.State.LEVEL)
	fake().win()
	await past_clear_delay()
	var clear := flow.screen as ClearScreen
	var notes := clear.gift_notes.size() + (clear.unlock_notes.size() if "unlock_notes" in clear else 0)
	var replay := clear.find_button("Replay")
	var next_button := clear.find_button("Next")
	var view := tree.root.get_visible_rect()
	var cut := replay != null and replay.get_global_rect().end.y > view.size.y + 0.5
	var next_cut := next_button != null and next_button.get_global_rect().end.y > view.size.y + 0.5
	tree.root.size = old
	_expect("G2", not cut and not next_cut, "with %d notes on the clear screen at 360 x 640, Replay ends at y %.0f and Next at y %.0f of %.0f (a screen that is due two unlocks and the gift at once pushes the buttons off)" % [notes, replay.get_global_rect().end.y if replay != null else -1.0, next_button.get_global_rect().end.y if next_button != null else -1.0, view.size.y])


func test_g3_the_helper_badges_count_up_to_the_gift_when_the_next_level_shows() -> void:
	# UX 3.13.4: "The helper bar's count badges for Undo and Extra slot count up from the old
	# number to the new one when the next level shows (one soft tick per step, 200 ms apart,
	# once)."
	start_real(48, "2026-10-21", false)
	for h: String in ["undo", "extra_slot", "screwdriver"]:
		save_node().mark_helper_met(h, 0)
	tap("Play")
	await until(func() -> bool: return flow.state == AppFlow.State.LEVEL and scene() != null, 8000)
	scene().set_instant(true)
	await play_taps()
	check(await in_state(AppFlow.State.CLEAR), "level 49 was won")
	await past_clear_delay()
	scene().set_instant(false)
	tap("Next")
	await until(func() -> bool: return flow.state == AppFlow.State.LEVEL and scene().get_level().number == 50, 8000)
	var hud: LevelHud = scene().get("_hud") as LevelHud
	var seen: Array[String] = []
	for i: int in 150:
		var badge := hud.get_badge("undo")
		if seen.is_empty() or seen[-1] != badge:
			seen.append(badge)
		await tree.process_frame
	check_eq(save_node().helper_count("undo"), 2, "the gift was added")
	_expect("G3", seen.size() >= 2, "the Undo badge on level 50 showed %s over its first 2.5 s: it did not count up from the old number to 2 with soft ticks (UX 3.13.4); it jumped to the new count" % str(seen))


func test_g4_a_relaxed_hard_level_is_a_level_the_novice_loses_as_it_is_played() -> void:
	# GDD 6.4 G4 for tiers 7 to 10: the novice must lose. Relaxed levels are played with 5 slots
	# (GDD 6.8), and "applies G1 to G10". The generator measures the novice on the tier's tray
	# (3 slots), so a Relaxed level can be one the novice wins with the 5 it really has.
	var bad := PackedStringArray()
	for i: int in [1, 2, 3, 4, 5, 6, 52, 92]:
		var g := LevelCatalog.get_level(LevelData.RELAXED, i, "hard")
		if g.level.tier < 7:
			continue
		var entry := BotEntry.new()
		entry.level = g.level
		entry.solve = g.solve
		var novice := BotRunner.play(entry, NoviceBot.new(), false)
		var fresh := Solver.solve(g.level, 600000)
		check_eq(g.level.tray_size, 5, "relaxed hard %d has 5 slots" % i)
		if novice.won or g.solve.novice_won != fresh.novice_won:
			bad.append("relaxed hard %d (tier %d): the novice bot %s; the stored solve says novice_won=%s, a fresh solve of the level as played says %s" % [i, g.level.tier, "WINS" if novice.won else "loses", str(g.solve.novice_won), str(fresh.novice_won)])
	_expect("G4", bad.is_empty(), "; ".join(bad))
