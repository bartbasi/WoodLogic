# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name UiText
extends RefCounted
## Small text helpers shared by the screens.


## 1234 becomes "1,234" (UX 3.7).
static func number(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	for i: int in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if n < 0 else "") + out


## Milliseconds as "m:ss" (rounded down to whole seconds).
static func time(ms: int) -> String:
	@warning_ignore("integer_division")
	var total := maxi(0, ms) / 1000
	@warning_ignore("integer_division")
	return "%d:%02d" % [total / 60, total % 60]


## Seconds as "m:ss" (a par time).
static func seconds(s: int) -> String:
	return time(s * 1000)


static func days(n: int) -> String:
	return "1 day" if n == 1 else "%s days" % number(n)


## "Easy", "Medium" ...
static func band_name(band: String) -> String:
	return band.capitalize()


## 2 as "Two" (a small count at the start of a sentence), larger numbers as digits.
static func count_word(n: int) -> String:
	var words: Array[String] = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]
	return words[n] if n >= 0 and n < words.size() else str(n)


## "Opens after level 8", the level from Tuning.
static func opens_after() -> String:
	return "Opens after level %d" % Tuning.modes_open_after_level


## The tray size of numbered level n, from the data: the tutorial keeps the starting size,
## later levels take their tier's.
static func tray_for(n: int) -> int:
	if n <= Tuning.tutorial_levels:
		return Tuning.tray_size
	return Tuning.tier(Tuning.tier_for_level(n)).tray


## [[size, first level], ...]: each time the tray gets smaller than it has been, in level order.
static func tray_steps(last_level: int = 400) -> Array:
	var out := []
	var current := Tuning.tray_size
	for n: int in range(1, last_level + 1):
		var t := tray_for(n)
		if t < current:
			current = t
			out.append([t, n])
	return out


## Info's tray line, built from the data: "The tray starts with 5 slots. It shrinks to 4 from
## level 12 and to 3 from level 21."
static func tray_line() -> String:
	var text := "The tray starts with %d slots." % Tuning.tray_size
	var steps := tray_steps()
	for i: int in steps.size():
		var step: Array = steps[i]
		text += (" It shrinks to %d from level %d" if i == 0 else " and to %d from level %d") % [step[0], step[1]]
	if not steps.is_empty():
		text += "."
	return text


## "2 Undos and 1 Extra slot" for a gift's helper counts.
static func gift_helpers(counts: Dictionary) -> String:
	var parts := PackedStringArray()
	for h: String in ["undo", "extra_slot", "screwdriver"]:
		var n := int(counts.get(h, 0))
		if n <= 0:
			continue
		var name_text: String = {"undo": "Undo", "extra_slot": "Extra slot", "screwdriver": "Screwdriver"}[h]
		parts.append("%d %s%s" % [n, name_text, "" if n == 1 else "s"])
	return " and ".join(parts)


## "level 50 and level 100" (a list of gift levels).
static func gift_levels(levels: Array) -> String:
	var parts := PackedStringArray()
	for l: Variant in levels:
		parts.append("level %d" % int(l))
	if parts.size() <= 1:
		return "".join(parts)
	var last := parts[parts.size() - 1]
	parts.remove_at(parts.size() - 1)
	return "%s and %s" % [", ".join(parts), last]


## The Info gift line, or "" when the data has no gifts.
static func gift_info_line() -> String:
	if Tuning.gifts.is_empty():
		return ""
	var levels := []
	for g: Dictionary in Tuning.gifts:
		levels.append(g["level"])
	return "Reach %s for a gift each time: %s." % [gift_levels(levels), gift_helpers(Tuning.gifts[0])]
