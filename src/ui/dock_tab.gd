# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name DockTab
extends UiButton
## One tab of the nav dock (UX 1.6): an icon above a caption, 56 x 52 at least. The active tab
## shows three signals so it is never color alone: a raised plaque, a 3 unit bar above the
## label, and a bold label.

var tab := ""
var active := false
var _bold := UiTheme.bold_font()


static func make_tab(tab_id: String, label: String, is_active: bool) -> DockTab:
	var t := new()
	t.tab = tab_id
	t.label_text = label
	t.active = is_active
	t.kind = UiButton.Kind.QUIET
	t.custom_minimum_size = Vector2(56.0, 52.0)
	t.theme_type_variation = "FlatButton"
	t.focus_mode = Control.FOCUS_ALL
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.tooltip_text = label
	return t


func _draw() -> void:
	var ink := UiTheme.TEXT if active else UiTheme.TEXT_DIM
	if active:
		draw_style_box(UiTheme.raised_box(), Rect2(2.0, 1.0, size.x - 4.0, size.y - 2.0))
		draw_rect(Rect2(size.x / 2.0 - 12.0, 3.0, 24.0, 3.0), UiTheme.PRIMARY)
	UiIcons.draw(self, tab, Vector2(size.x / 2.0, 20.0), 22.0, ink)
	var font: Font = _bold if active else ThemeDB.fallback_font
	draw_string(font, Vector2(0.0, size.y - 8.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.SIZE_CAPTION, ink)
