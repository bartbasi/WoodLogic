# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Links
extends RefCounted
## The only place that hands an address to the phone (docs/ARCHITECTURE.md 11.2, CLAUDE.md).
## Exactly three fixed addresses, one constant each, never built from anything the player
## types. Tests replace `opener` so nothing is ever opened.

const FEEDBACK_ADDRESS := "bartbasi@gmail.com"
const SOURCE_URL := "https://github.com/bartbasi/WoodLogic"
const COFFEE_URL := "https://buymeacoffee.com/playinc"
const FEEDBACK_SUBJECT := "WoodLogic feedback"

## Called with the address to open. Empty means OS.shell_open. Tests set it, and the test
## runner clears it before quitting (a lambda left in a static variable crashes on quit).
static var opener: Callable = Callable()
## -1 follows the export feature "no_coffee"; 0 shows the coffee controls, 1 hides them.
## Tests only.
static var coffee_hidden_for_tests: int = -1


## The one switch for every coffee control (UX 1.7): false in an export with the custom
## feature "no_coffee". Controls are not built at all when it is false.
static func coffee_visible() -> bool:
	if coffee_hidden_for_tests >= 0:
		return coffee_hidden_for_tests == 0
	return not OS.has_feature("no_coffee")


## The mailto draft: it names the game version, the phone model and the OS, on a last line
## the player can edit or delete (UX 3.9). Returns false if the phone could not open it.
static func open_feedback() -> bool:
	return _open(feedback_address())


static func open_source() -> bool:
	return _open(SOURCE_URL)


## Opens the coffee page. Refuses (false, nothing opened) when coffee is hidden.
static func open_coffee() -> bool:
	if not coffee_visible():
		return false
	return _open(COFFEE_URL)


## The mailto address text, built only from fixed words and the version and phone facts.
static func feedback_address() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var model := OS.get_model_name()
	if model == "" or model == "GenericDevice":
		model = "an unknown phone"
	var line := "Sent from WoodLogic %s on %s, %s %s. You can edit or delete this line." % [version, model, OS.get_name(), OS.get_version()]
	var body := "\n\n" + line
	return "mailto:%s?subject=%s&body=%s" % [FEEDBACK_ADDRESS, FEEDBACK_SUBJECT.uri_encode(), body.uri_encode()]


static func _open(address: String) -> bool:
	if opener.is_valid():
		var result: Variant = opener.call(address)
		return result == null or (result is int and result == OK)
	return OS.shell_open(address) == OK
