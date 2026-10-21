# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Tokens
extends RefCounted
## The Workshop look's color tokens (docs/DESIGN.md 2) and the type sizes (docs/UX.md 1.3), as
## constants for the Godot Theme and the screens. Every text and plaque pair here is checked at
## 4.5:1 or more, and every meaningful mark at 3:1, by tests/render/test_colors.gd.

# The wall and the board.
const PEGBOARD := Color("7a5a3d")
const PEGBOARD_HOLE := Color("1e120a")
const SHADOW := Color("1a0d05")

# Plaques: every panel that holds text.
const PLAQUE := Color(0.1725, 0.1137, 0.0745, 0.94)  # 2c1d13 at 94 percent
const PLAQUE_SOLID := Color("2c1d13")
const PLAQUE_BORDER := Color(0.8471, 0.6431, 0.2706, 0.55)  # brass at 55 percent
const PLAQUE_RADIUS := 8

# Text.
const TEXT := Color("f7ead4")
const TEXT_DIM := Color("e8d6b8")
const TEXT_GOLD := Color("f3c766")

# Buttons. The lip is the darker block under the face that makes it read as pressable.
const PRIMARY := Color("d8a445")
const PRIMARY_LIP := Color("8a6420")
const PRIMARY_TEXT := Color("2a1708")
const SECONDARY := Color("4b3121")
const SECONDARY_LIP := Color("24160d")
const SECONDARY_TEXT := Color("f7ead4")
const QUIET_LINE := Color(0.8471, 0.6431, 0.2706, 0.6)
const QUIET_TEXT := Color("f7ead4")
const DANGER := Color("8e2a1c")
const DANGER_LIP := Color("4f160e")
const DANGER_TEXT := Color("f7ead4")
const BUTTON_RADIUS := 8
## Pressed: darken the face by this much and scale by PRESSED_SCALE (UX 1.4).
const PRESSED_DARKEN := 0.12
const PRESSED_SCALE := 0.96
const DISABLED_ALPHA := 0.5

# Badges, stars, warnings, focus, veil.
const BADGE := Color("d8a445")
const BADGE_TEXT := Color("2a1708")
const STAR_FACE := Color("e9b23e")
const STAR_RIM := Color("9a6c1c")
const STAR_FACET := Color("f7d77e")
const STAR_MISSED := Color(0.851, 0.706, 0.416, 0.9)  # d9b46a at 90 percent
const WARN := Color("e9a23b")
const WARN_MARK := Color("2a1708")
const FOCUS := Color("f7ead4")
const FOCUS_WIDTH := 3
const VEIL := Color(0.0784, 0.051, 0.0314, 0.62)  # 140d08 at 62 percent
const DIM_DIALOG := Color(0.0784, 0.051, 0.0314, 0.55)  # dialogs dim by 55 percent (UX 1.4)

# The nav dock (UX 1.6).
const DOCK := Color("2c1d13")
const DOCK_TAB_ACTIVE := Color("4b3121")
const DOCK_BAR := Color("d8a445")
const DOCK_ICON := Color("e8d6b8")
const DOCK_ICON_ACTIVE := Color("f7ead4")

# Steel (the tray and the parts that are metal).
const STEEL := Color("a7a39b")
const STEEL_DARK := Color("5f5b55")
const STEEL_EDGE := Color("3c3a36")

# Type sizes in design units (UX 1.3). Nothing smaller than CAPTION.
const SIZE_DISPLAY := 32
const SIZE_HEADING := 24
const SIZE_BUTTON_PRIMARY := 22
const SIZE_BUTTON := 18
const SIZE_TUTORIAL := 18
const SIZE_BODY := 16
const SIZE_SMALL := 14
const SIZE_CAPTION := 13

## Text and plaque pairs the contrast check covers, as [name, text, background]. A translucent
## background is measured blended over the pegboard.
static func text_pairs() -> Array[Array]:
	return [
		["text on plaque", TEXT, PLAQUE],
		["dim text on plaque", TEXT_DIM, PLAQUE],
		["gold text on plaque", TEXT_GOLD, PLAQUE],
		["primary label", PRIMARY_TEXT, PRIMARY],
		["secondary label", SECONDARY_TEXT, SECONDARY],
		["quiet label on plaque", QUIET_TEXT, PLAQUE],
		["danger label", DANGER_TEXT, DANGER],
		["badge number", BADGE_TEXT, BADGE],
		["dock label", DOCK_ICON, DOCK],
		["dock label, active", DOCK_ICON_ACTIVE, DOCK_TAB_ACTIVE],
		["warning mark", WARN_MARK, WARN],
	]


## Meaningful marks that need 3:1, as [name, mark, background].
static func mark_pairs() -> Array[Array]:
	return [
		["missed star outline on plaque", STAR_MISSED, PLAQUE],
		["earned star on plaque", STAR_FACE, PLAQUE],
		["warning outline on steel", WARN_MARK, STEEL],
		["focus ring on pegboard", FOCUS, PEGBOARD],
		["brass button on pegboard", PRIMARY, Color("5a412c")],
		["active tab bar on dock", DOCK_BAR, DOCK],
		["dock icon on dock", DOCK_ICON, DOCK],
	]


## A translucent color laid over the pegboard, as an opaque color, for contrast sums.
static func over_pegboard(c: Color) -> Color:
	var base := Color("5a412c")
	return Color(lerpf(base.r, c.r, c.a), lerpf(base.g, c.g, c.a), lerpf(base.b, c.b, c.a), 1.0)
