# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name Looks
extends RefCounted
## Wood themes and metal finishes as shader parameters (docs/DESIGN.md 5 and 6), and the
## player's current choice. The app flow sets `current` from the settings at boot and when
## Settings changes; screens and the level scene then rebuild their views. Renderers read only
## `current`, never the save.

## Ids in unlock order (docs/GDD.md 7).
const WOODS: Array[String] = ["oak", "walnut", "maple", "cherry", "ebony"]
const METALS: Array[String] = ["steel", "brass", "copper", "black"]
const DEFAULT_WOOD := "oak"
const DEFAULT_METAL := "steel"

## The player's choice. The app flow replaces it; renderers only read it.
static var current: Dictionary = {"wood": DEFAULT_WOOD, "metal": DEFAULT_METAL, "symbols": true}


## The plank wood and the back board for a theme. Keys: wood_light, wood_dark, edge_color,
## ring_freq, ring_contrast, figure, fiber, pores (the plank grain), and board_light, board_dark,
## board_edge, board_ring_freq, board_ring_contrast, board_figure, board_fiber, board_pores (the
## back board). An unknown id gives oak.
static func wood(id: String) -> Dictionary:
	var walnut_board := {"board_light": Color("6f4a30"), "board_dark": Color("47291a"), "board_edge": Color("3a2215"),
		"board_ring_freq": 0.07, "board_ring_contrast": 0.55, "board_figure": 18.0, "board_fiber": 0.45, "board_pores": 0.12}
	var w: Dictionary
	match id:
		"walnut":
			w = {"wood_light": Color("8a5e3f"), "wood_dark": Color("5e3c26"), "edge_color": Color("4a2f1d"),
				"ring_freq": 0.08, "ring_contrast": 0.6, "figure": 22.0, "fiber": 0.45, "pores": 0.12}
			w.merge({"board_light": Color("3a2a20"), "board_dark": Color("251a12"), "board_edge": Color("1c130d"),
				"board_ring_freq": 0.07, "board_ring_contrast": 0.5, "board_figure": 16.0, "board_fiber": 0.4, "board_pores": 0.1})
		"maple":
			w = {"wood_light": Color("edd5a8"), "wood_dark": Color("d1af7c"), "edge_color": Color("b58f58"),
				"ring_freq": 0.09, "ring_contrast": 0.35, "figure": 12.0, "fiber": 0.3, "pores": 0.0}
			w.merge(walnut_board)
		"cherry":
			w = {"wood_light": Color("c8825a"), "wood_dark": Color("9a5636"), "edge_color": Color("7d4429"),
				"ring_freq": 0.1, "ring_contrast": 0.5, "figure": 14.0, "fiber": 0.35, "pores": 0.08}
			w.merge(walnut_board)
		"ebony":
			w = {"wood_light": Color("3b312c"), "wood_dark": Color("221b18"), "edge_color": Color("1a1412"),
				"ring_freq": 0.16, "ring_contrast": 0.55, "figure": 6.0, "fiber": 0.5, "pores": 0.0}
			w.merge({"board_light": Color("d9bc8c"), "board_dark": Color("b9955f"), "board_edge": Color("94723f"),
				"board_ring_freq": 0.08, "board_ring_contrast": 0.4, "board_figure": 14.0, "board_fiber": 0.3, "board_pores": 0.0})
		_:
			w = {"wood_light": Color("dcae6c"), "wood_dark": Color("a8713a"), "edge_color": Color("8a5a2c"),
				"ring_freq": 0.11, "ring_contrast": 0.7, "figure": 14.0, "fiber": 0.4, "pores": 0.22}
			w.merge(walnut_board)
	w["id"] = id if WOODS.has(id) else DEFAULT_WOOD
	return w


## A metal finish: rim colors, cap gloss and the bright recess floor used on dark caps. Keys:
## metal_light, metal_dark, gloss, spec_power, recess_metal. An unknown id gives steel.
static func metal(id: String) -> Dictionary:
	var m: Dictionary
	match id:
		"brass":
			m = {"metal_light": Color("f6dc93"), "metal_dark": Color("3d2c0b"), "gloss": 0.5, "spec_power": 22.0,
				"recess_metal": Color("f0d690")}
		"copper":
			m = {"metal_light": Color("f3b48a"), "metal_dark": Color("3f1a0b"), "gloss": 0.5, "spec_power": 22.0,
				"recess_metal": Color("f0b892")}
		"black":
			m = {"metal_light": Color("9a9aa0"), "metal_dark": Color("1c1c1f"), "gloss": 0.35, "spec_power": 14.0,
				"recess_metal": Color("c8c8cc")}
		_:
			m = {"metal_light": Color("f4f1ea"), "metal_dark": Color("4c463e"), "gloss": 0.55, "spec_power": 26.0,
				"recess_metal": Color("e6e2da")}
	m["id"] = id if METALS.has(id) else DEFAULT_METAL
	return m


## The current choice, read safely: an id that isn't known reads as the default.
static func current_wood() -> Dictionary:
	return wood(String(current.get("wood", DEFAULT_WOOD)))


static func current_metal() -> Dictionary:
	return metal(String(current.get("metal", DEFAULT_METAL)))


static func symbols_on() -> bool:
	return bool(current.get("symbols", true))
