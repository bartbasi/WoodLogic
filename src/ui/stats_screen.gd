# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name StatsScreen
extends MenuScreen
## Stats (docs/UX.md 3.7): the player's record, kept on the phone only.

var progress: Dictionary = {}


## progress: Save.progress_copy().
static func make(progress_data: Dictionary) -> StatsScreen:
	var s := new()
	s.progress = progress_data
	return s


func _build_body() -> void:
	var stats: Dictionary = progress.get("stats", {})
	var daily: Dictionary = progress.get("daily", {})
	if int(stats.get("cleared", 0)) == 0 and int(daily.get("solved", 0)) == 0:
		body.add_child(text_plaque("Play a few levels and your numbers show up here."))
	body.add_child(group_heading("Levels"))
	body.add_child(value_row("Levels cleared", UiText.number(int(stats.get("cleared", 0)))))
	body.add_child(value_row("Highest level", UiText.number(int(progress.get("highest_cleared", 0)))))
	body.add_child(value_row("Total stars", UiText.number(int(progress.get("stars_earned", 0)))))
	body.add_child(value_row("Three-star levels", UiText.number(int(stats.get("three_star", 0)))))
	body.add_child(group_heading("Daily puzzle"))
	body.add_child(value_row("Current streak", UiText.days(int(daily.get("streak", 0)))))
	body.add_child(value_row("Best streak", UiText.days(int(daily.get("best_streak", 0)))))
	body.add_child(value_row("Daily puzzles solved", UiText.number(int(daily.get("solved", 0)))))
	body.add_child(group_heading("Helpers"))
	body.add_child(value_row("Helpers used", UiText.number(int(stats.get("helpers_used", 0)))))
	body.add_child(group_heading("Times by difficulty"))
	body.add_child(_times_header())
	var time: Dictionary = stats.get("time", {})
	for group: String in Tuning.GROUPS:
		var g: Dictionary = time.get(group, {})
		var n := int(g.get("n", 0))
		var best := int(g.get("best_ms", 0))
		var best_text := UiText.time(best) if n > 0 and best > 0 else "None yet"
		@warning_ignore("integer_division")
		var average_text := UiText.time(int(g.get("total_ms", 0)) / n) if n > 0 else "None yet"
		body.add_child(_times_row(group.capitalize(), best_text, average_text, false))
	var foot := Label.new()
	foot.text = "These numbers stay on this phone."
	foot.theme_type_variation = "SmallLabel"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(foot)


func _times_header() -> Control:
	return _times_row("Band", "Best", "Average", true)


func _times_row(band: String, best: String, average: String, header: bool) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = "Plaque"
	p.custom_minimum_size.y = 40.0 if header else 48.0
	var h := HBoxContainer.new()
	for i: int in 3:
		var l := Label.new()
		l.text = [band, best, average][i]
		l.theme_type_variation = "ButtonLabel" if header else ("BodyLabel" if i == 0 else "ButtonLabel")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	p.add_child(h)
	return p
