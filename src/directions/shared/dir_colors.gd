# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name DirColors
extends RefCounted
## The proposed screw colors and their symbols, shared by all three Phase 1 directions.
## Picked so the closest pair under protanopia, deuteranopia and tritanopia (Machado 2009
## simulation, OKLab distance) stays at 0.07 or more; confusable pairs get very different
## symbols. The full check script comes in Phase 4.

enum Sym { TRIANGLE, SQUARE, STAR, CIRCLE, DIAMOND, CROSS, RING, BAR, MOON }

const NAMES: Array[String] = ["red", "orange", "yellow", "green", "sky", "blue", "purple", "pink", "white"]
const SYMBOL_NAMES: Array[String] = ["triangle", "square", "star", "circle", "diamond", "cross", "ring", "bar", "moon"]

const COLORS: Array[Color] = [
	Color("#e5331e"),  # red
	Color("#f5922a"),  # orange
	Color("#f9d63a"),  # yellow
	Color("#2f875a"),  # green
	Color("#4bc4ed"),  # sky
	Color("#1e45b8"),  # blue
	Color("#8454d9"),  # purple
	Color("#e062a6"),  # pink
	Color("#f7f2ea"),  # white
]

## Symbol for each color, by index into COLORS.
const SYMBOLS: Array[int] = [
	Sym.TRIANGLE, Sym.SQUARE, Sym.STAR, Sym.CIRCLE, Sym.DIAMOND, Sym.CROSS, Sym.RING, Sym.BAR, Sym.MOON,
]

const RED := 0
const ORANGE := 1
const YELLOW := 2
const GREEN := 3
const SKY := 4
const BLUE := 5
const PURPLE := 6
const PINK := 7
const WHITE := 8


static func color(index: int) -> Color:
	return COLORS[index]


static func symbol(index: int) -> int:
	return SYMBOLS[index]


## Dark or light ink that reads on top of the color (for printed symbols on boxes).
static func ink(index: int) -> Color:
	return Color("#1d1a17") if luminance(COLORS[index]) > 0.2 else Color("#fbf7f0")


## Relative luminance (WCAG), from linear light.
static func luminance(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b
