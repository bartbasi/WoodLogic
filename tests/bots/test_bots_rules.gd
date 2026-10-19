# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The rule checks that run while the bots play, and that they notice a fault: illegal and
## badly timed calls give the right reasons, undo restores the snapshot, event lists keep the
## canonical order (docs/ARCHITECTURE.md 4.3).

## A small fixed set of blueprints, kept small so the suite stays fast.
const FIXED_BLUEPRINTS: Array[String] = ["bricks", "house", "tree", "fish", "windmill", "rings"]


func _fixed_colorings() -> BotLevelSet:
	return BotLevels.colorings(1, 77, 100000, 1, PackedStringArray(FIXED_BLUEPRINTS))


func _merge_reasons(into: Dictionary, r: BotResult) -> void:
	for key: Variant in r.reasons:
		into[key] = int(into.get(key, 0)) + int(r.reasons[key])


func test_chaos_bot_on_the_tutorials_finds_no_violation() -> void:
	var seen: Dictionary = {}
	for entry: BotEntry in BotLevels.tutorials().entries:
		for run: int in 6:
			var r := BotRunner.play(entry, ChaosBot.new(500 + run))
			check_eq(r.violation_count, 0, "%s chaos run %d: %s" % [entry.label, run, str(Array(r.violations))])
			_merge_reasons(seen, r)
	for key: String in ["tap:GONE", "tap:COVERED", "tap:NOT_PLAYING", "undo:NOTHING_TO_UNDO", "undo:NONE", "undo:NOT_PLAYING", "extra_slot:NONE", "extra_slot:ALREADY_USED", "extra_slot:NOT_PLAYING", "screwdriver:NONE", "screwdriver:GONE", "screwdriver:NOT_PLAYING"]:
		check(int(seen.get(key, 0)) > 0, "the chaos bot never made the call %s" % key)


func test_chaos_bot_on_colorings_finds_no_violation() -> void:
	var seen: Dictionary = {}
	for entry: BotEntry in _fixed_colorings().entries:
		for run: int in 6:
			var r := BotRunner.play(entry, ChaosBot.new(900 + run))
			check_eq(r.violation_count, 0, "%s chaos run %d: %s" % [entry.label, run, str(Array(r.violations))])
			_merge_reasons(seen, r)
	for key: String in ["tap:COVERED", "undo:NONE", "extra_slot:NONE", "screwdriver:NONE"]:
		check(int(seen.get(key, 0)) > 0, "the chaos bot never made the call %s" % key)


func test_refused_taps_leave_the_state_alone() -> void:
	# Mash random free screws on a coloring until the tray fills; REFUSED must come up and
	# change nothing (the session checks that after each failed call).
	var refused := 0
	for entry: BotEntry in _fixed_colorings().entries:
		for run: int in 12:
			var session := BotSession.start(entry.level)
			var bot := RandomBot.new(40 + run)
			var guard := 0
			while guard < 600 and bot.step(session):
				guard += 1
			refused += int(session.reason_counts.get("tap:REFUSED", 0))
			check_eq(session.violation_count, 0, "%s run %d: %s" % [entry.label, run, str(Array(session.violations))])
	check(refused > 0, "no random run ever had a tap refused; the check never ran")


func test_undo_after_every_tap_restores_the_snapshot_and_a_retap_repeats_it() -> void:
	# Tap, undo, tap again along each solution: covers undo after a box closes, a plank falls,
	# a plank swings and a cascade. The session compares the snapshot after every undo.
	var entries: Array[BotEntry] = []
	entries.append_array(BotLevels.tutorials().entries)
	entries.append_array(_fixed_colorings().entries)
	var taps := 0
	for entry: BotEntry in entries:
		var session := BotSession.start(entry.level)
		for i: int in entry.solve.solution.size():
			var screw := entry.solve.solution[i]
			var first := session.tap(screw)
			check(first.ok, "%s: tap %d" % [entry.label, screw])
			if i == entry.solve.solution.size() - 1:
				check_eq(session.undo().reason, TapResult.NOT_PLAYING, "%s: undo after the winning tap (R29)" % entry.label)
				break
			var undone := session.undo()
			check(undone.ok, "%s: undo after tap %d" % [entry.label, screw])
			check(session.state.is_free(screw), "%s: screw %d is free again after undo" % [entry.label, screw])
			var second := session.tap(screw)
			check(second.ok, "%s: tap %d again" % [entry.label, screw])
			check_eq(second.describe(), first.describe(), "%s: the same tap gives the same events" % entry.label)
			taps += 1
		check_eq(session.status(), PlayState.WON, "%s: won" % entry.label)
		check_eq(session.violation_count, 0, "%s: %s" % [entry.label, str(Array(session.violations))])
	check(taps > 100, "only %d taps were tried" % taps)


func test_undo_all_the_way_back_gives_the_starting_state() -> void:
	var entries: Array[BotEntry] = []
	entries.append_array(BotLevels.tutorials().entries)
	entries.append_array(_fixed_colorings().entries)
	for entry: BotEntry in entries:
		var session := BotSession.start(entry.level)
		var start := PlayState.start(entry.level).snapshot()
		for screw: int in entry.solve.solution:
			session.tap(screw)
		# Undo is refused after a win; the last tap won, so go back one tap by retrying.
		var won := session.status() == PlayState.WON
		check(won, "%s: won" % entry.label)
		check_eq(session.undo().reason, TapResult.NOT_PLAYING, "%s: undo after a win" % entry.label)
		var fresh := BotSession.start(entry.level)
		var count := entry.solve.solution.size() - 1
		for i: int in count:
			fresh.tap(entry.solve.solution[i])
		for i: int in count:
			check(fresh.undo().ok, "%s: undo %d of %d" % [entry.label, i + 1, count])
		check_eq(fresh.undo().reason, TapResult.NOTHING_TO_UNDO, "%s: undo with nothing left" % entry.label)
		check_eq(var_to_str(fresh.state.snapshot()), var_to_str(start), "%s: the snapshot after undoing everything" % entry.label)
		check_eq(fresh.violation_count, 0, "%s: %s" % [entry.label, str(Array(fresh.violations))])


func test_event_order_checker_accepts_the_canonical_order() -> void:
	var good: Array[PackedInt32Array] = [
		PackedInt32Array([LogicEvent.SCREW_TO_TRAY]),
		PackedInt32Array([LogicEvent.SCREW_TO_BOX, LogicEvent.PLANK_SWUNG, LogicEvent.COVER_CHANGED]),
		PackedInt32Array([LogicEvent.SCREW_TO_BOX, LogicEvent.PLANK_FELL, LogicEvent.BOX_CLOSED, LogicEvent.BOX_ARRIVED, LogicEvent.TRAY_TO_BOX, LogicEvent.TRAY_TO_BOX, LogicEvent.BOX_CLOSED, LogicEvent.BOX_ARRIVED, LogicEvent.WON]),
		PackedInt32Array([LogicEvent.SCREW_TO_BOX, LogicEvent.BOX_CLOSED, LogicEvent.BOX_ARRIVED, LogicEvent.LOST]),
		PackedInt32Array([LogicEvent.SCREW_TO_BOX, LogicEvent.RESUMED]),
	]
	for kinds: PackedInt32Array in good:
		check_eq(BotSession.order_problem(kinds, "tap"), "", "canonical order %s" % str(Array(kinds)))
	check_eq(BotSession.order_problem(PackedInt32Array([LogicEvent.TRAY_EXTENDED]), "extra_slot"), "", "extra slot")
	check_eq(BotSession.order_problem(PackedInt32Array([LogicEvent.TRAY_EXTENDED, LogicEvent.RESUMED]), "extra_slot"), "", "extra slot that clears a loss")
	check_eq(BotSession.order_problem(PackedInt32Array([LogicEvent.UNDONE, LogicEvent.LOST]), "undo"), "", "undo that stays lost")


func test_event_order_checker_rejects_a_wrong_order() -> void:
	var bad: Array[PackedInt32Array] = [
		PackedInt32Array(),
		PackedInt32Array([LogicEvent.PLANK_SWUNG, LogicEvent.SCREW_TO_BOX]),
		PackedInt32Array([LogicEvent.SCREW_TO_BOX, LogicEvent.COVER_CHANGED, LogicEvent.PLANK_FELL]),
		PackedInt32Array([LogicEvent.SCREW_TO_BOX, LogicEvent.WON, LogicEvent.COVER_CHANGED]),
		PackedInt32Array([LogicEvent.SCREW_TO_BOX, LogicEvent.LOST, LogicEvent.WON]),
		PackedInt32Array([LogicEvent.SCREW_TO_TRAY, LogicEvent.BOX_CLOSED, LogicEvent.BOX_ARRIVED]),
		PackedInt32Array([LogicEvent.SCREW_TO_BOX, LogicEvent.BOX_CLOSED]),
		PackedInt32Array([LogicEvent.SCREW_TO_BOX, LogicEvent.BOX_ARRIVED, LogicEvent.BOX_CLOSED]),
		PackedInt32Array([LogicEvent.SCREW_TO_BOX, LogicEvent.BOX_CLOSED, LogicEvent.TRAY_TO_BOX, LogicEvent.BOX_ARRIVED]),
		PackedInt32Array([LogicEvent.SCREW_TO_BOX, LogicEvent.BOX_CLOSED, LogicEvent.BOX_CLOSED, LogicEvent.BOX_ARRIVED]),
		PackedInt32Array([LogicEvent.SCREW_TO_BOX, LogicEvent.PLANK_FELL, LogicEvent.PLANK_SWUNG]),
		PackedInt32Array([LogicEvent.SCREW_TO_BOX, LogicEvent.SCREW_TO_TRAY]),
		PackedInt32Array([LogicEvent.SCREW_TO_BOX, LogicEvent.TRAY_EXTENDED]),
	]
	for kinds: PackedInt32Array in bad:
		check(BotSession.order_problem(kinds, "tap") != "", "should be rejected: %s" % str(Array(kinds)))
	check(BotSession.order_problem(PackedInt32Array([LogicEvent.UNDONE, LogicEvent.RESUMED, LogicEvent.LOST]), "undo") != "", "two status events after undo")
	check(BotSession.order_problem(PackedInt32Array([LogicEvent.RESUMED, LogicEvent.TRAY_EXTENDED]), "extra_slot") != "", "extra slot out of order")
	check(BotSession.order_problem(PackedInt32Array([LogicEvent.TRAY_EXTENDED, LogicEvent.WON]), "extra_slot") != "", "extra slot cannot win")


func test_the_session_notices_a_state_changed_behind_its_back() -> void:
	# If the checks were blind, every other test here would pass for nothing. Change the state
	# without telling the session; its next call must complain.
	var entry: BotEntry = BotLevels.tutorials().entries[1]
	var session := BotSession.start(entry.level)
	session.state.use_extra_slot()
	var free := Bot.free_screws(session)
	session.tap(free[0])
	check(session.violation_count > 0, "an Extra slot opened behind the session's back went unnoticed")
	var other := BotSession.start(entry.level)
	var free_now := Bot.free_screws(other)
	other.state.tap(free_now[0])
	other.undo()
	check(other.violation_count > 0, "an undo of a tap made behind the session's back went unnoticed")


func test_the_perfect_bot_reports_a_solution_that_does_not_play() -> void:
	var entry: BotEntry = BotLevels.tutorials().entries[3]
	var wrong := entry.solve.solution.duplicate()
	wrong.reverse()
	var r := BotRunner.play(entry, PerfectBot.new(wrong))
	check(r.violation_count > 0, "a reversed solution was not flagged")
	check(not r.won, "a reversed solution won")
