# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends FlowCase
## Links (docs/ARCHITECTURE.md 11.2): three fixed addresses, the coffee switch, the opener.


func test_the_three_fixed_addresses() -> void:
	check_eq(Links.COFFEE_URL, "https://buymeacoffee.com/playinc", "coffee")
	check_eq(Links.SOURCE_URL, "https://github.com/bartbasi/WoodLogic", "source")
	check_eq(Links.FEEDBACK_ADDRESS, "bartbasi@gmail.com", "feedback")


func test_each_open_hands_one_fixed_address_to_the_opener() -> void:
	Links.opener = func(address: String) -> Variant:
		opened.append(address)
		return OK
	check(Links.open_coffee(), "coffee opened")
	check(Links.open_source(), "source opened")
	check(Links.open_feedback(), "feedback opened")
	check_eq(opened.size(), 3, "three opens")
	check_eq(opened[0], Links.COFFEE_URL, "coffee address")
	check_eq(opened[1], Links.SOURCE_URL, "source address")
	check(opened[2].begins_with("mailto:bartbasi@gmail.com?subject=WoodLogic%20feedback&body="), "the mailto draft: " + opened[2])
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	check(opened[2].contains(version.uri_encode()), "it names the game version")
	check(opened[2].contains("You%20can%20edit%20or%20delete%20this%20line."), "and says it can be edited")


func test_coffee_hidden_opens_nothing() -> void:
	Links.opener = func(address: String) -> Variant:
		opened.append(address)
		return OK
	Links.coffee_hidden_for_tests = 1
	check(not Links.coffee_visible(), "hidden")
	check(not Links.open_coffee(), "refuses")
	check(opened.is_empty(), "nothing opened")
	Links.coffee_hidden_for_tests = 0
	check(Links.coffee_visible(), "forced visible")
	Links.coffee_hidden_for_tests = -1
	check_eq(Links.coffee_visible(), not OS.has_feature("no_coffee"), "follows the export feature")


func test_a_failing_opener_reports_false() -> void:
	Links.opener = func(_address: String) -> Variant: return ERR_UNAVAILABLE
	check(not Links.open_source(), "reported")
