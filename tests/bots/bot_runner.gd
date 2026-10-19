# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BotRunner
extends RefCounted
## Plays levels with the bots. Everything is seeded, so a run can be repeated exactly.

## Calls a bot may make per screw before the runner gives up (a loop guard).
const STEP_CAP_PER_SCREW := 200


## One attempt by one bot. Null if the level cannot be started.
static func play(entry: BotEntry, bot: Bot, deep: bool = true) -> BotResult:
	var session := BotSession.start(entry.level, deep)
	if session == null:
		return null
	var guard := 0
	var cap := STEP_CAP_PER_SCREW * entry.level.screw_count() + 500
	while guard < cap and bot.step(session):
		guard += 1
	if guard >= cap:
		session.note_problem("the bot made %d calls without finishing: a loop?" % cap)
	var r := BotResult.new()
	r.bot = bot.bot_name
	r.won = session.status() == PlayState.WON
	r.lost = session.status() == PlayState.LOST
	r.taps = session.taps
	r.failed_calls = session.failed_calls
	r.tray_uses = session.state.tray_uses()
	r.peak_tray = session.peak_tray
	r.near_full = session.near_full
	r.elapsed_ms = session.taps * bot.tap_ms
	r.stars = Stars.award(entry.level, r.won, r.elapsed_ms, r.tray_uses, session.state.helpers_used())
	r.violations = session.violations
	r.violation_count = session.violation_count
	r.reasons = session.reason_counts
	return r


## All three bots on one level: the perfect bot once (if the level is solved), the novice bot
## once, and the random bot `random_runs` times. The first `deep_random_runs` random runs and
## the others use the independent covering test only as `deep` says.
static func play_entry(entry: BotEntry, random_runs: int, random_seed: int, deep: bool = true, deep_random_runs: int = 1) -> BotRecord:
	var record := BotRecord.new()
	record.entry = entry
	if entry.solve != null and entry.solve.solved:
		var perfect := play(entry, PerfectBot.new(entry.solve.solution), deep)
		_file(record, perfect)
		if not perfect.won:
			record.mismatches.append("%s: the perfect bot did not win" % entry.label)
		elif perfect.tray_uses != entry.solve.fewest_tray_uses:
			record.mismatches.append("%s: the perfect bot used the tray %d times, the solver says %d" % [entry.label, perfect.tray_uses, entry.solve.fewest_tray_uses])
	var novice := play(entry, NoviceBot.new(), deep)
	_file(record, novice)
	if entry.solve != null and novice.won != entry.solve.novice_won:
		record.mismatches.append("%s: the novice bot %s but Solver.novice_won is %s" % [entry.label, "won" if novice.won else "lost", str(entry.solve.novice_won)])
	for i: int in random_runs:
		var bot := RandomBot.new(random_seed + entry.seed_base * 7919 + i * 104729)
		_file(record, play(entry, bot, deep and i < deep_random_runs))
	return record


static func _file(record: BotRecord, r: BotResult) -> void:
	record.bot(r.bot).add(r)
	for v: String in r.violations:
		record.problems.append("%s, %s bot: %s" % [record.entry.label, r.bot, v])
