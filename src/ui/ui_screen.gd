# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name UiScreen
extends Control
## Base of every screen outside the level. It fills the viewport, draws the full bleed
## background, and keeps one column of content inside the safe area plus a 12 unit margin,
## no wider than 480 units and centered (docs/UX.md 1.1 and 1.2). Controls registered with
## wide() are as wide as buttons should be: 296 on a 360 wide screen, at most 320.

const MAX_COLUMN := 480.0
const MARGIN := 12.0
const FADE_S := 0.15
const MAX_BUTTON := 320.0

var column := VBoxContainer.new()
var background := ColorRect.new()
## Screens fade in over 150 ms (UX 1.5).
var fade_in := true
## A screen with a solid background hides what is under it; a sheet does not.
var opaque := true
var _wide: Array[Control] = []


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Belt and braces with the app flow's canvas layer: above any z inside a level scene.
	z_index = 1000
	background.color = UiTheme.PEGBOARD
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)


func _ready() -> void:
	if opaque:
		add_child(background)
	else:
		background.free()
	add_child(column)
	_build()
	resized.connect(_layout)
	_layout()
	if fade_in:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, FADE_S)


## Subclasses add their content to `column` here.
func _build() -> void:
	pass


## The area the column fills, in this screen's own coordinates.
func _content_rect() -> Rect2:
	var ins := UiScreen.insets(self)
	var left := ins.x + MARGIN
	var top := ins.y + MARGIN
	var right := ins.z + MARGIN
	var bottom := ins.w + MARGIN
	var avail := maxf(0.0, size.x - left - right)
	var w := minf(avail, MAX_COLUMN)
	return Rect2(left + (avail - w) / 2.0, top, w, maxf(0.0, size.y - top - bottom))


func _layout() -> void:
	var r := _content_rect()
	# Anchors and offsets, not a fixed size, so the column shrinks back when text that
	# wrapped at first settles (a container only ever grows to its minimum size).
	column.anchor_left = 0.0
	column.anchor_top = 0.0
	column.anchor_right = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = r.position.x
	column.offset_top = r.position.y
	column.offset_right = r.end.x - size.x
	column.offset_bottom = r.end.y - size.y
	var bw := clampf(r.size.x - 40.0, minf(r.size.x, 200.0), MAX_BUTTON)
	for c: Control in _wide:
		c.custom_minimum_size.x = bw


## Registers a control (a button or a row of buttons) to be as wide as buttons should be.
func wide(c: Control) -> Control:
	_wide.append(c)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c


## A solid panel behind text (UX 1.3: text never sits on bare wood). It fills the column's
## width and wraps long text, or with `shrink` it hugs one line.
func plaque(text: String, variation: String, shrink: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Plaque"
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if shrink:
		p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(l)
	return p


func gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Flexible space that takes whatever height is left.
func spacer() -> Control:
	var c := gap(0.0)
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## Two buttons side by side, 8 apart, filling the button width.
func row(a: Button, b: Button) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for button: Button in [a, b]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(button)
	wide(h)
	return h


## One effect through the Audio autoload, found by node so a script run with -s still loads
## this class. Does nothing if there is no Audio (or sound is off: Audio decides).
func play_sound(effect: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.call("play", effect, pitch, volume_db)


## Nudges a control 4 units sideways twice (200 ms): a locked thing was tapped.
static func shake(c: Control) -> void:
	var x := c.position.x
	var t := c.create_tween()
	t.tween_property(c, "position:x", x + 4.0, 0.05)
	t.tween_property(c, "position:x", x - 4.0, 0.05)
	t.tween_property(c, "position:x", x + 4.0, 0.05)
	t.tween_property(c, "position:x", x, 0.05)


## The button with this label, or null. For tests.
func find_button(label: String) -> UiButton:
	return _find(self, label)


func _find(node: Node, label: String) -> UiButton:
	for child: Node in node.get_children():
		if child is UiButton and (child as UiButton).label_text == label:
			return child
		var found := _find(child, label)
		if found != null:
			return found
	return null


## Safe area insets in viewport units as (left, top, right, bottom). Zero off a phone, where
## the display's safe area is in screen coordinates and means nothing for a window.
static func insets(node: Control) -> Vector4:
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return Vector4.ZERO
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return Vector4.ZERO
	var k := node.get_viewport().get_visible_rect().size.x / float(win.x)
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	return Vector4(
		clampf(float(safe.position.x) * k, 0.0, 96.0),
		clampf(float(safe.position.y) * k, 0.0, 96.0),
		clampf(float(screen.x - safe.end.x) * k, 0.0, 96.0),
		clampf(float(screen.y - safe.end.y) * k, 0.0, 96.0))
