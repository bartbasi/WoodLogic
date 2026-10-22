# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name InfoScreen
extends MenuScreen
## Info, "How to play" (docs/UX.md 3.14): the rules in a few lines, what each helper does and
## how stars are earned. Reading material only: nothing animates. The words are UX 3.14's.

## The groups: [heading, [[icon, text], ...]]. An empty icon means no icon. The numbers (free
## helpers, first levels, prices, the level Daily and Relaxed open at) come from Tuning.
static func groups() -> Array:
	var h: Dictionary = Tuning.helpers
	var undo: Dictionary = h["undo"]
	var extra: Dictionary = h["extra_slot"]
	var driver: Dictionary = h["screwdriver"]
	var opens := UiText.opens_after() + "."
	var helpers_group: Array = [
		["undo", "Undo. Takes back your last move. %s free on level %d." % [UiText.count_word(int(undo["free"])), int(undo["first_level"])]],
		["extra_slot", "Extra slot. Adds one more tray slot, once per try. %s free on level %d." % [UiText.count_word(int(extra["free"])), int(extra["first_level"])]],
		["screwdriver", "Screwdriver. Removes any one screw, even a covered one, to where a tap would send it. %s free on level %d." % [UiText.count_word(int(driver["free"])), int(driver["first_level"])]],
		["", "A Screwdriver is not spent if the screw has nowhere to go."],
		["", "Out of a helper? Tap it in a level to buy one with stars: Undo %d, Extra slot %d, Screwdriver %d." % [int(undo["price"]), int(extra["price"]), int(driver["price"])]],
	]
	var gift := UiText.gift_info_line()
	if gift != "":
		helpers_group.append(["", gift])
	helpers_group.append(["", "Using a helper means no Clean star on that try."])
	return [
		["The basics", [
			["", "Tap a free screw to unscrew it."],
			["", "It flies into an open box of its color. If no open box fits, it waits in the tray."],
			["", UiText.tray_line()],
			["", "Three screws fill a box. The box leaves and the next one slides in."],
			["", "A screw under another plank is covered. Free the plank on top first."],
			["", "A plank with no screws falls. A plank with one screw swings."],
			["", "Clear every screw to win. If the tray is full and nothing fits, you are out of room. Retry is free."],
		]],
		["Helpers", helpers_group],
		["Stars", [
			["star", "Cleared. Finish the level."],
			["star", "Fast. Finish within the par time."],
			["star", "Clean. Use the tray no more than the par number of times, with no helpers."],
			["", "Replaying a level only adds stars above your best."],
		]],
		["Other ways to play", [
			["", "Daily. One puzzle a day, the same for everyone. Solve it on days in a row to build a streak. " + opens],
			["", "Relaxed. No clock, no stars, and you can't lose. " + opens],
		]],
	]


func _build_body() -> void:
	for group: Array in groups():
		var p := PanelContainer.new()
		p.theme_type_variation = "Plaque"
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		var h := Label.new()
		h.text = group[0]
		h.theme_type_variation = "ButtonLabel"
		v.add_child(h)
		for entry: Array in group[1]:
			v.add_child(_entry(entry[0], entry[1]))
		p.add_child(v)
		body.add_child(p)
	body.add_child(gap(8.0))


func _entry(icon: String, text: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	if icon != "":
		var iv := IconView.make(icon, 28.0, UiTheme.TEXT_GOLD if icon == "star" else UiTheme.TEXT)
		iv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(iv)
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "BodyLabel"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h
