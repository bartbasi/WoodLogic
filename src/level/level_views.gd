# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelViews
extends RefCounted
## The one place the level scene makes its views and talks to them (docs/ARCHITECTURE.md 7 and
## 10.1 and 11.1): src/render's PlankView, ScrewView, BoxView, TrayView and BoardView.
## The functions take a Node2D and call the renderer's methods on it, so the rest of the level
## scene never names a renderer class.

const SCREW_BOARD := ScrewView.BOARD
const SCREW_WELL := ScrewView.WELL
const SCREW_TRAY := ScrewView.TRAY
## Head diameters per size, in design units, for scaling a board sized head into a well or slot.
const SCREW_DIAMETERS: Array[float] = ScrewView.DIAMETERS


static func make_plank(outline_gu: PackedVector2Array, inner_gu: PackedVector2Array, layer: int, holes_gu: PackedVector2Array, grain_seed: int) -> Node2D:
	var v := PlankView.new()
	v.setup(outline_gu, inner_gu, layer, holes_gu, grain_seed)
	return v


static func make_screw(color: int, size: int) -> Node2D:
	var v := ScrewView.new()
	v.setup(color, size)
	return v


static func make_box(color: int, preview: bool) -> Node2D:
	var v := BoxView.new()
	v.setup(color, preview)
	return v


static func make_tray(slots: int) -> Node2D:
	var v := TrayView.new()
	v.setup(slots)
	return v


## The workbench behind everything: the pegboard over `size` and the back panels on it.
static func make_board(size: Vector2, panels: Array[Rect2]) -> Node2D:
	var v := BoardView.new()
	v.setup(size, panels)
	return v


static func setup_board(board: Node2D, size: Vector2, panels: Array[Rect2]) -> void:
	(board as BoardView).setup(size, panels)


## Draws a plank or the board into its textures. Only while the board is hidden or fading in
## (the stand-in shows until then), never mid play.
static func bake(view: Node2D) -> void:
	var v: Variant = view
	v.bake()


static func is_baked(view: Node2D) -> bool:
	var v: Variant = view
	return v.is_baked()


## Sets a plank up again (after the wood theme changed); it keeps its pose and has to be baked again.
static func reset_plank(plank: Node2D, outline_gu: PackedVector2Array, inner_gu: PackedVector2Array, layer: int, holes_gu: PackedVector2Array, grain_seed: int) -> void:
	(plank as PlankView).setup(outline_gu, inner_gu, layer, holes_gu, grain_seed)


## How much shadow a plank casts, 0 to 1 (the fall's fading shadow).
static func set_shadow(plank: Node2D, amount: float) -> void:
	(plank as PlankView).set_shadow(amount)


## The wiggle of a plank in front of a tapped covered screw.
static func wiggle(plank: Node2D) -> void:
	var v: Variant = plank
	v.wiggle()


static func set_covered(screw: Node2D, covered: bool) -> void:
	var v: Variant = screw
	v.set_covered(covered)


## Screwdriver mode: covered screws show their symbols at full strength.
static func set_bright(screw: Node2D, on: bool) -> void:
	(screw as ScrewView).set_bright(on)


static func set_turn(screw: Node2D, degrees: float) -> void:
	var v: Variant = screw
	v.set_turn(degrees)


static func set_lift(screw: Node2D, amount: float) -> void:
	var v: Variant = screw
	v.set_lift(amount)


## Changes a screw's look in place (for example to a well sized head).
static func resize_screw(screw: Node2D, color: int, size: int) -> void:
	var v: Variant = screw
	v.setup(color, size)


static func set_box_count(box: Node2D, n: int) -> void:
	var v: Variant = box
	v.set_count(n)


static func set_box_lid(box: Node2D, open: float) -> void:
	var v: Variant = box
	v.set_lid(open)


static func close_box(box: Node2D) -> void:
	var v: Variant = box
	v.close()


## Turns a box into the open look (a preview box arriving at an open position) or back.
static func reset_box(box: Node2D, color: int, preview: bool) -> void:
	var v: Variant = box
	v.setup(color, preview)


static func setup_tray(tray: Node2D, slots: int) -> void:
	var v: Variant = tray
	v.setup(slots)


static func set_tray_warning(tray: Node2D, on: bool) -> void:
	var v: Variant = tray
	v.set_warning(on)


static func set_tray_full(tray: Node2D, on: bool) -> void:
	var v: Variant = tray
	v.set_full(on)


## Which tray slots hold a screw (1) or are free (0), so the warning triangle sits in a free slot.
static func set_tray_filled(tray: Node2D, filled: PackedByteArray) -> void:
	var v: Variant = tray
	v.set_filled(filled)
