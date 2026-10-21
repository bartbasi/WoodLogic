# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name BotReport
extends RefCounted
## Turns BotRecords into the tables the designer reads and the CSV the difficulty chart is
## drawn from.

const GROUP_ORDER: Array[String] = ["Tutorial", "Easy", "Medium", "Hard", "Expert"]
const BOTS: Array[String] = ["perfect", "novice", "random"]
## Per bot, in the CSV: these columns, each prefixed with the bot's name.
const BOT_COLUMNS: Array[String] = ["games", "win_rate", "loss_rate", "taps", "failed_calls", "tray_uses", "peak_tray", "worst_peak", "near_full", "stars", "stars0", "stars1", "stars2", "stars3", "cleared", "fast", "clean", "time_s"]


static func csv_header() -> String:
	var cols: Array[String] = ["source", "label", "group", "tier", "tier_basis", "number", "blueprint", "screws", "colors", "layers", "planks", "tray_par", "par_time_s", "fewest_tray_uses", "solver_states", "solver_ms", "trap", "solver_novice_won"]
	for bot: String in BOTS:
		for column: String in BOT_COLUMNS:
			cols.append("%s_%s" % [bot, column])
	cols.append("problems")
	return ",".join(cols)


static func csv_row(record: BotRecord) -> String:
	var e := record.entry
	var cells: Array[String] = [
		e.source, _csv(e.label), e.group, str(e.tier), "given" if e.tier_given else "estimated", str(e.number),
		_csv(e.blueprint), str(e.screws()), str(e.level.color_count()), str(e.level.layer_count()),
		str(e.level.planks.size()), str(e.level.tray_par), str(e.level.par_time_s),
		str(e.solve.fewest_tray_uses), str(e.solve.states), str(e.solve.ms), "%.3f" % e.solve.trap,
		"1" if e.solve.novice_won else "0",
	]
	for bot: String in BOTS:
		var s := record.bot(bot)
		cells.append_array([
			str(s.games), "%.3f" % s.win_rate(), "%.3f" % (float(s.losses) / maxi(s.games, 1)), "%.2f" % s.mean_taps(), "%.2f" % s.mean_failed(),
			"%.2f" % s.mean_tray_uses(), "%.2f" % s.mean_peak(), str(s.worst_peak),
			"%.2f" % s.mean_near_full(), "%.2f" % s.mean_stars(),
			"%.3f" % s.star_share(0), "%.3f" % s.star_share(1), "%.3f" % s.star_share(2), "%.3f" % s.star_share(3),
			"%.3f" % (float(s.sum_cleared) / maxi(s.games, 1)), "%.3f" % (float(s.sum_fast) / maxi(s.games, 1)),
			"%.3f" % (float(s.sum_clean) / maxi(s.games, 1)), "%.1f" % s.mean_time_s(),
		])
	cells.append(str(record.problems.size() + record.mismatches.size()))
	return ",".join(cells)


static func csv(records: Array[BotRecord]) -> String:
	var lines := PackedStringArray([csv_header()])
	for r: BotRecord in records:
		lines.append(csv_row(r))
	return "\n".join(lines) + "\n"


static func _csv(text: String) -> String:
	if text.contains(",") or text.contains("\""):
		return "\"" + text.replace("\"", "\"\"") + "\""
	return text


# ---------------------------------------------------------------------------------------
# Tables
# ---------------------------------------------------------------------------------------

## The records grouped: `by` is "band" (Tutorial, Easy, ...), "tier" or "blueprint". Returns
## an ordered Array of [key, Array[BotRecord]].
static func group(records: Array[BotRecord], by: String) -> Array:
	var buckets: Dictionary = {}
	for r: BotRecord in records:
		var key := _key(r, by)
		if not buckets.has(key):
			buckets[key] = [] as Array[BotRecord]
		var list: Array[BotRecord] = buckets[key]
		list.append(r)
	var keys: Array = buckets.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _order(a, by) < _order(b, by))
	var out: Array = []
	for k: Variant in keys:
		out.append([k, buckets[k]])
	return out


static func _key(r: BotRecord, by: String) -> String:
	match by:
		"kind":
			return "relaxed " + r.entry.level.band if r.entry.source == "relaxed" else r.entry.source
		"tier":
			return "tutorial" if r.entry.tier == 0 else ("tier %02d%s" % [r.entry.tier, "" if r.entry.tier_given else "*"])
		"blueprint":
			return r.entry.blueprint
		_:
			return r.entry.group


static func _order(key: String, by: String) -> String:
	if by == "band":
		var i := GROUP_ORDER.find(key)
		return "%02d" % (i if i >= 0 else 99)
	return key


static func pooled(records: Array, bot: String) -> BotStats:
	var total := BotStats.new()
	for r: BotRecord in records:
		total.merge(r.bot(bot))
	return total


static func _mean(values: Array, field: String) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for r: BotRecord in values:
		match field:
			"screws":
				sum += r.entry.screws()
			"colors":
				sum += r.entry.level.color_count()
			"fewest":
				sum += r.entry.solve.fewest_tray_uses
			"trap":
				sum += r.entry.solve.trap
			"novice_policy":
				sum += 1.0 if r.entry.solve.novice_won else 0.0
	return sum / values.size()


static func _row(cells: Array, widths: Array[int]) -> String:
	var parts := PackedStringArray()
	for i: int in cells.size():
		var text := str(cells[i])
		parts.append(text.rpad(widths[i]) if i == 0 else text.lpad(widths[i]))
	return "  ".join(parts)


static func _table(title: String, header: Array, rows: Array, widths: Array[int]) -> String:
	var lines := PackedStringArray([title, _row(header, widths)])
	var rule := PackedStringArray()
	for w: int in widths:
		rule.append("-".repeat(w))
	lines.append("  ".join(rule))
	for row: Variant in rows:
		lines.append(_row(row, widths))
	return "\n".join(lines) + "\n"


static func _pct(x: float) -> String:
	return "%.0f%%" % (x * 100.0)


## All the tables, as one text.
static func tables(records: Array[BotRecord], by: String) -> String:
	var groups := group(records, by)
	var out := ""
	var w_key := 12
	for g: Variant in groups:
		w_key = maxi(w_key, String((g as Array)[0]).length())
	# 1. The levels and win rates.
	var rows_a: Array = []
	var rows_b: Array = []
	var rows_c: Array = []
	var rows_d: Array = []
	var all_records: Array = []
	all_records.append_array(records)
	var list: Array = groups.duplicate()
	list.append(["ALL", all_records])
	for g: Variant in list:
		var key: String = (g as Array)[0]
		var recs: Array = (g as Array)[1]
		var p := pooled(recs, "perfect")
		var n := pooled(recs, "novice")
		var r := pooled(recs, "random")
		rows_a.append([key, recs.size(), "%.1f" % _mean(recs, "screws"), "%.1f" % _mean(recs, "colors"), "%.2f" % _mean(recs, "fewest"), "%.2f" % _mean(recs, "trap"), _pct(_mean(recs, "novice_policy")), _pct(p.win_rate()), _pct(n.win_rate()), _pct(r.win_rate()), r.games])
		rows_b.append([key, "%.2f / %d" % [p.mean_peak(), p.worst_peak], "%.2f / %d" % [n.mean_peak(), n.worst_peak], "%.2f / %d" % [r.mean_peak(), r.worst_peak], "%.2f" % n.mean_near_full(), "%.2f" % r.mean_near_full(), "%.2f" % n.mean_tray_uses(), "%.2f" % r.mean_tray_uses()])
		for bot_stats: Array in [["perfect", p], ["novice", n], ["random", r]]:
			var s: BotStats = bot_stats[1]
			rows_c.append([key if bot_stats[0] == "perfect" else "", bot_stats[0], _pct(s.star_share(0)), _pct(s.star_share(1)), _pct(s.star_share(2)), _pct(s.star_share(3)), "%.2f" % s.mean_stars(), _pct(float(s.sum_fast) / maxi(s.games, 1)), _pct(float(s.sum_clean) / maxi(s.games, 1))])
		rows_d.append([key, "%.1f" % p.mean_taps(), "%.1f" % n.mean_taps(), "%.1f" % r.mean_taps(), "%.1f" % r.mean_failed(), "%.0f" % p.mean_time_s(), "%.0f" % n.mean_time_s(), "%.0f" % r.mean_time_s()])
	out += _table("Win rate (levels = how many levels; random plays each level several times)",
		[by, "levels", "screws", "colors", "fewest tray", "trap", "novice policy", "perfect", "novice", "random", "random games"],
		rows_a, [w_key, 6, 6, 6, 11, 5, 13, 7, 7, 7, 12])
	out += "\n" + _table("Tray pressure (peak slots in use at once: mean / worst; near full = actions that left at most 1 free slot)",
		[by, "perfect peak", "novice peak", "random peak", "novice near full", "random near full", "novice tray uses", "random tray uses"],
		rows_b, [w_key, 12, 12, 12, 16, 16, 16, 16])
	out += "\n" + _table("Stars (share of games that ended with 0, 1, 2 or 3 stars; fast and clean = share that earned that star)",
		[by, "bot", "0", "1", "2", "3", "mean", "fast", "clean"],
		rows_c, [w_key, 7, 5, 5, 5, 5, 5, 5, 5])
	out += "\n" + _table("Taps and simulated time (random taps = successful taps before the end; failed = refused picks)",
		[by, "perfect taps", "novice taps", "random taps", "random failed", "perfect s", "novice s", "random s"],
		rows_d, [w_key, 12, 11, 11, 13, 9, 8, 8])
	return out
