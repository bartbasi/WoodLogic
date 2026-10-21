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
