# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## The screens' layout (docs/UX.md 1.1, 1.4, 3.1, 3.3, 3.4, 3.5, 7.3) at phone, tall, tablet
## and foldable sizes, in a SubViewport so the size is exact.

## Viewport sizes in design units: base, tall, wide tablet, 1080 x 1200 window, open foldable.
const SIZES: Array[Vector2i] = [Vector2i(360, 640), Vector2i(360, 840), Vector2i(480, 640), Vector2i(576, 640), Vector2i(800, 640)]


func _show(screen: UiScreen, size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	add_node(vp)
	screen.theme = UiTheme.build()
	vp.add_child(screen)
	return vp


func _buttons(node: Node, found: Array[UiButton]) -> void:
	for child: Node in node.get_children():
		if child is UiButton:
			found.append(child)
		_buttons(child, found)


func _screens() -> Dictionary:
	return {
		"title": TitleScreen.make(7, "0.1.0"),
		"pause": PauseScreen.make(7, true, false),
		"clear": ClearScreen.make(7),
		"lost": LostScreen.make(7),
		"lost_first": LostScreen.make(1),
	}


func test_every_button_is_big_enough_and_inside_the_column() -> void:
	for size: Vector2i in SIZES:
		var screens := _screens()
		for screen_name: String in screens:
			var screen: UiScreen = screens[screen_name]
			_show(screen, size)
	await frames(30)
	for node: Node in tree.root.get_children():
		if node is SubViewport:
			var vp := node as SubViewport
			for child: Node in vp.get_children():
				if not child is UiScreen:
					continue
				var screen := child as UiScreen
				var where := "%s at %s" % [screen.get_script().get_global_name(), str(vp.size)]
				var buttons: Array[UiButton] = []
				_buttons(screen, buttons)
				check(not buttons.is_empty(), where + " has buttons")
				var column_rect := Rect2(screen.column.global_position, screen.column.size)
				check(column_rect.size.x <= UiScreen.MAX_COLUMN + 0.5, where + ": the column is at most 480 wide")
				for b: UiButton in buttons:
					var r := b.get_global_rect()
					check(r.size.y >= 47.99, "%s: \"%s\" is %.1f tall" % [where, b.label_text, r.size.y])
					check(r.size.x >= 47.99, "%s: \"%s\" is %.1f wide" % [where, b.label_text, r.size.x])
					check(column_rect.grow(0.5).encloses(r), "%s: \"%s\" %s is inside the column %s" % [where, b.label_text, str(r), str(column_rect)])
					if b.kind == UiButton.Kind.PRIMARY:
						check(r.get_center().y >= vp.size.y / 2.0, "%s: \"%s\" %s is in the bottom half" % [where, b.label_text, str(r)])
						check(r.size.x <= UiScreen.MAX_BUTTON + 0.5, "%s: \"%s\" is at most 320 wide" % [where, b.label_text])
					check(r.end.y <= vp.size.y - 8.0, "%s: \"%s\" %s keeps 8 units above the bottom of %s (screen %s, column %s)" % [where, b.label_text, str(r), str(vp.size), str(screen.size), str(column_rect)])


func test_buttons_are_296_wide_on_a_base_phone() -> void:
	var s := TitleScreen.make(1, "0.1.0")
	_show(s, Vector2i(360, 640))
	await frames(3)
	var play := s.find_button("Play")
	check_between(play.size.x, 295.5, 296.5, "Play width")
	check_between(play.size.y, 71.5, 72.5, "Play height")


func test_the_clear_screen_has_no_stars_and_the_title_has_only_play() -> void:
	var clear := ClearScreen.make(3)
	_show(clear, Vector2i(360, 640))
	var title := TitleScreen.make(3, "0.1.0")
	_show(title, Vector2i(360, 640))
	await frames(3)
	var found: Array[UiButton] = []
	_buttons(title, found)
	check_eq(found.size(), 1, "the title has one button")
	found = []
	_buttons(clear, found)
	check_eq(found.size(), 2, "the clear screen has Next and Replay")


func test_the_out_of_room_sheet_slides_up_and_retry_works_at_once() -> void:
	var lost := LostScreen.make(5)
	_show(lost, Vector2i(360, 640))
	var presses := [0]
	lost.retry_pressed.connect(func() -> void: presses[0] += 1)
	await frames(1)
	var retry := lost.find_button("Retry")
	check(not retry.disabled, "Retry is enabled in the first frame")
	retry.pressed.emit()
	check_eq(presses[0], 1, "Retry works while the sheet slides")
	var start_y := retry.global_position.y
	await frames(30)
	check(retry.global_position.y < start_y, "the sheet moved up")
	# 244 tall, anchored to the bottom: Retry sits in the bottom half.
	check(retry.get_global_rect().get_center().y > 320.0, "Retry is in the bottom half")


func test_text_is_plain() -> void:
	# No em dashes, no double hyphens in any label of any screen.
	var screens := _screens()
	for screen_name: String in screens:
		_show(screens[screen_name], Vector2i(360, 640))
	await frames(3)
	for node: Node in tree.root.get_children():
		if node is SubViewport:
			_check_text(node)


func _check_text(node: Node) -> void:
	for child: Node in node.get_children():
		var text := ""
		if child is Label:
			text = (child as Label).text
		elif child is Button:
			text = (child as Button).text
		check(not text.contains(char(0x2014)) and not text.contains("--"), "plain text: " + text)
		_check_text(child)
