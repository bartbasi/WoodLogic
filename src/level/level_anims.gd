# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name LevelAnims
extends RefCounted
## The motions the level scene plays (UX 6.1, DESIGN.md 9). Each is a LevelAnim: timed, stepped
## by the scene, and never read by any rule.

const EASE_OUT_CUBIC := 0
const EASE_IN_CUBIC := 1
const EASE_OUT_BACK := 2
const EASE_SINE := 3


## Draws a view last among its siblings, so it is above them. Draw order in the level scene is
## tree order (no z_index anywhere), so nothing in it depends on an absolute z.
static func raise(view: Node2D) -> void:
	var parent := view.get_parent()
	if parent != null:
		parent.move_child(view, parent.get_child_count() - 1)


## An animation that only calls `what` after `wait` seconds.
static func after(wait: float, what: Callable) -> LevelAnim:
	var a := LevelAnim.new()
	a.delay = wait
	a.on_done = what
	return a


## A screw leaving its place for another: turn and rise, fly in an arc, land with a small pop.
## `unscrew` is 0 for a hop (a tray screw jumping into a new box).
class Flight extends LevelAnim:
	var view: Node2D
	var p0 := Vector2.ZERO
	var p1 := Vector2.ZERO
	var s0 := 1.0
	var s1 := 1.0
	var unscrew := 0.22
	var flight := 0.35
	var settle := 0.15
	var arc := 50.0
	var turn_dir := -1.0
	var on_pop := Callable()
	var on_land := Callable()
	var _popped := false
	var _landed := false

	func _init(screw_view: Node2D, from: Vector2, to: Vector2, from_scale: float, to_scale: float, wait: float, unscrew_time: float, flight_time: float) -> void:
		view = screw_view
		p0 = from
		p1 = to
		s0 = from_scale
		s1 = to_scale
		delay = wait
		unscrew = unscrew_time
		flight = flight_time
		duration = unscrew + flight + settle

	## Seconds from now until the screw lands.
	func landing_in() -> float:
		return maxf(0.0, delay + unscrew + flight - _t)

	func _begin() -> void:
		LevelAnims.raise(view)

	func _apply(local: float) -> void:
		var peak := s0 * (1.15 if unscrew > 0.0 else 1.0)
		if local < unscrew:
			var e := LevelAnim.in_out_sine(local / unscrew)
			var dip := 0.06 * sin(PI * minf(local / 0.12, 1.0))
			view.position = p0
			view.scale = Vector2.ONE * s0 * (1.0 + 0.15 * e - dip)
			LevelViews.set_lift(view, e)
			LevelViews.set_turn(view, turn_dir * 540.0 * e)
			if not _popped and local >= 0.12:
				_popped = true
				if on_pop.is_valid():
					on_pop.call()
		elif local < unscrew + flight:
			var q := (local - unscrew) / flight
			var e := LevelAnim.out_cubic(q)
			view.position = p0.lerp(p1, e) + Vector2(0.0, -arc * 4.0 * q * (1.0 - q))
			view.scale = Vector2.ONE * lerpf(peak, s1, e)
			LevelViews.set_lift(view, 1.0 if unscrew > 0.0 else 0.5)
			var spun := 540.0 if unscrew > 0.0 else 0.0
			LevelViews.set_turn(view, turn_dir * (spun + (540.0 if unscrew > 0.0 else 360.0) * q))
		else:
			if not _landed:
				_landed = true
				if on_land.is_valid():
					on_land.call()
			var q := clampf((local - unscrew - flight) / settle, 0.0, 1.0)
			view.position = p1
			view.scale = Vector2.ONE * s1 * (1.0 + 0.15 * sin(PI * q))
			LevelViews.set_lift(view, (1.0 if unscrew > 0.0 else 0.5) * (1.0 - LevelAnim.in_out_sine(q)))
			LevelViews.set_turn(view, 0.0)

	func _end() -> void:
		view.position = p1
		view.scale = Vector2.ONE * s1
		LevelViews.set_lift(view, 0.0)
		LevelViews.set_turn(view, 0.0)
		if not _landed:
			_landed = true
			if on_land.is_valid():
				on_land.call()
		super._end()

	func _release() -> void:
		on_pop = Callable()
		on_land = Callable()


## A plank swinging about its last screw to the logic's rest angle: a damped swing with a little
## overshoot (DESIGN.md 9). The rest angle is the logic's; this only shows the way there.
class Swing extends LevelAnim:
	const OMEGA := 8.7965
	const ZETA := 0.5
	var slot: LevelPlankSlot
	var about := Vector2.ZERO
	var from_angle := 0.0
	var rest := 0.0

	func _init(plank_slot: LevelPlankSlot, pivot: Vector2, start_angle: float, rest_angle: float) -> void:
		slot = plank_slot
		about = pivot
		from_angle = start_angle
		rest = rest_angle
		duration = 0.9

	func _apply(local: float) -> void:
		var damped := OMEGA * sqrt(1.0 - ZETA * ZETA)
		var swing := exp(-ZETA * OMEGA * local) * cos(damped * local)
		var fade := 1.0 - smoothstep(0.6, 0.9, local)
		slot.pose(about, rest + (from_angle - rest) * swing * fade)

	func _end() -> void:
		slot.pose(about, rest)
		super._end()

	func _release() -> void:
		slot = null


## A plank with no screws left: it hangs a moment, then drops off the board turning a little.
## Looks only. Nothing reads where it is.
class Fall extends LevelAnim:
	var slot: LevelPlankSlot
	var about := Vector2.ZERO
	var from_angle := 0.0
	var spin := 60.0
	var drift := 0.0
	var gravity := 2400.0
	var on_leave := Callable()

	func _init(plank_slot: LevelPlankSlot, pivot: Vector2, start_angle: float, hang: float) -> void:
		slot = plank_slot
		about = pivot
		from_angle = start_angle
		delay = hang
		duration = 0.8

	func _begin() -> void:
		# Last among the planks: above the others, still below every screw (GDD V1).
		LevelAnims.raise(slot.view)
		if on_leave.is_valid():
			on_leave.call()

	func _apply(local: float) -> void:
		var r := deg_to_rad(from_angle + spin * local)
		slot.view.rotation = r
		slot.view.position = about - about.rotated(r) + Vector2(drift * local, 0.5 * gravity * local * local)
		slot.view.modulate.a = 1.0 - smoothstep(0.55, 0.8, local)
		# The shadow fades out over the first 200 ms as the plank leaves the board (DESIGN.md 8).
		LevelViews.set_shadow(slot.view, 1.0 - smoothstep(0.0, 0.2, local))

	func _end() -> void:
		slot.view.visible = false
		slot.view.modulate.a = 1.0
		super._end()

	func _release() -> void:
		slot = null
		on_leave = Callable()


## Calls `callback.call(p)` with p running from 0 to 1 over the duration (ease already applied
## by the caller if wanted). The generic motion: shakes, nudges, fades.
class Timed extends LevelAnim:
	var callback := Callable()

	func _init(wait: float, seconds: float, what: Callable) -> void:
		delay = wait
		duration = seconds
		callback = what

	func _apply(local: float) -> void:
		if callback.is_valid():
			callback.call(local / duration if duration > 0.0 else 1.0)

	func _release() -> void:
		callback = Callable()


## Moves some nodes together by `shift` from where they are when it starts, and fades them to
## `alpha_end`. A box leaving with its screws; a box sliding in.
class GroupMove extends LevelAnim:
	var nodes: Array[Node2D] = []
	var shift := Vector2.ZERO
	var easing := 0
	var alpha_end := 1.0
	var hide_at_end := false
	var _bases := PackedVector2Array()
	var _alpha0 := PackedFloat32Array()

	func _init(group: Array[Node2D], by: Vector2, wait: float, seconds: float, ease_kind: int) -> void:
		nodes = group
		shift = by
		delay = wait
		duration = seconds
		easing = ease_kind

	func _begin() -> void:
		_bases.resize(nodes.size())
		_alpha0.resize(nodes.size())
		for i: int in nodes.size():
			if is_instance_valid(nodes[i]):
				_bases[i] = nodes[i].position
				_alpha0[i] = nodes[i].modulate.a

	func _apply(local: float) -> void:
		var q := clampf(local / duration, 0.0, 1.0) if duration > 0.0 else 1.0
		var e := q
		match easing:
			LevelAnims.EASE_OUT_CUBIC:
				e = LevelAnim.out_cubic(q)
			LevelAnims.EASE_IN_CUBIC:
				e = LevelAnim.in_cubic(q)
			LevelAnims.EASE_OUT_BACK:
				e = LevelAnim.out_back(q)
			LevelAnims.EASE_SINE:
				e = LevelAnim.in_out_sine(q)
		for i: int in nodes.size():
			if not is_instance_valid(nodes[i]):
				continue
			nodes[i].position = _bases[i] + shift * e
			nodes[i].modulate.a = lerpf(_alpha0[i], alpha_end, q)

	func _end() -> void:
		if hide_at_end:
			for n: Node2D in nodes:
				if is_instance_valid(n):
					n.visible = false
		super._end()

	func _release() -> void:
		nodes = []
