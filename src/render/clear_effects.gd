# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name ClearEffects
extends Node2D
## The level clear celebration (docs/ARCHITECTURE.md 11.1, docs/UX.md 3.4, docs/DESIGN.md 9): the
## veil fades in, the three stars pop one by one (earned ones stamped brass, missed ones an
## outline that settles), oak shavings curl out from the star row and fall, and a few motes of
## sawdust drift in the lamp light. Everything is at rest by 1.6 s. Nothing flashes: stars grow,
## they never brighten, and every piece fades over at least 120 ms. The clear screen draws its
## text and buttons on top; this draws behind them. Design units, from its own origin.

signal finished

const DURATION := 1.6
const VEIL_SECONDS := 0.25
## When each star starts (UX 3.4) and how long its pop takes.
const STAR_TIMES: Array[float] = [0.35, 0.65, 0.95]
const POP_SECONDS := 0.2
const SHAVINGS := 14
const MOTES := 30

var _area := Rect2(0, 0, 360, 640)
var _stars: Array[Vector2] = []
var _earned: Array[bool] = [true, true, false]
var _star_radius := 36.0
var _t := 0.0
var _playing := false
var _shavings: Array[Dictionary] = []
var _motes: Array[Dictionary] = []


## `area` is what the veil covers; `stars` are the three star centers and `radius` their size
## (UX 3.4: 72 across); `earned` says which are filled.
func setup(area: Rect2, stars: Array[Vector2], earned: Array[bool], radius: float = 36.0) -> void:
	_area = area
	_stars = stars.duplicate()
	_earned = earned.duplicate()
	_star_radius = radius
	_make_particles()
	_t = 0.0
	queue_redraw()


## Starts the celebration from the beginning.
func play() -> void:
	if _shavings.is_empty():
		_make_particles()
	_t = 0.0
	_playing = true
	set_process(true)
	queue_redraw()


## Jumps to the resting end: veil and stars in place, particles gone. Emits `finished`.
func skip() -> void:
	_t = DURATION
	_end()


func is_playing() -> bool:
	return _playing


func _ready() -> void:
	set_process(_playing)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DURATION:
		_t = DURATION
		_end()


func _end() -> void:
	var was := _playing
	_playing = false
	set_process(false)
	queue_redraw()
	if was or _t >= DURATION:
		finished.emit()


func _make_particles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	_shavings.clear()
	_motes.clear()
	var center := _area.get_center()
	if not _stars.is_empty():
		center = (_stars[0] + _stars[_stars.size() - 1]) * 0.5
	for i in SHAVINGS:
		var a := -PI * 0.5 + rng.randf_range(-1.2, 1.2)
		_shavings.append({"from": center + Vector2(rng.randf_range(-110, 110), rng.randf_range(-10, 10)),
			"v": Vector2(cos(a), sin(a)) * rng.randf_range(140, 260), "spin": rng.randf_range(-6, 6),
			"r": rng.randf_range(9, 15), "a0": rng.randf_range(0, TAU), "delay": rng.randf_range(0.3, 0.6),
			"tone": rng.randf_range(0.9, 1.08)})
	for i in MOTES:
		_motes.append({"p": Vector2(rng.randf_range(_area.position.x, _area.end.x), rng.randf_range(_area.position.y, _area.position.y + _area.size.y * 0.7)),
			"r": rng.randf_range(0.8, 1.8), "drift": rng.randf_range(4, 14), "alpha": rng.randf_range(0.15, 0.4)})


func _draw() -> void:
	var veil := clampf(_t / VEIL_SECONDS, 0.0, 1.0)
	draw_rect(_area, Color(Tokens.VEIL, Tokens.VEIL.a * veil))
	if _playing:
		_draw_particles()
	for i in _stars.size():
		var start: float = STAR_TIMES[mini(i, STAR_TIMES.size() - 1)]
		var p := clampf((_t - start) / POP_SECONDS, 0.0, 1.0)
		if p <= 0.0:
			continue
		var earned: bool = _earned[i] if i < _earned.size() else false
		if earned:
			draw_star_earned(self, _stars[i], _star_radius * _back_out(p), minf(1.0, p * 1.67))
		else:
			draw_star_missed(self, _stars[i], _star_radius * lerpf(1.1, 1.0, p), p)


func _draw_particles() -> void:
	for s: Dictionary in _shavings:
		var t := _t - float(s["delay"])
		if t <= 0.0:
			continue
		var life := DURATION - float(s["delay"])
		var fade := clampf(t / 0.12, 0.0, 1.0) * clampf((life - t) / 0.3, 0.0, 1.0)
		var pos: Vector2 = Vector2(s["from"]) + Vector2(s["v"]) * t + Vector2(0, 420.0) * t * t * 0.5
		_shaving(pos, float(s["r"]), float(s["a0"]) + float(s["spin"]) * t, float(s["tone"]), fade)
	for m: Dictionary in _motes:
		var fade := clampf(_t / 0.3, 0.0, 1.0) * clampf((DURATION - _t) / 0.4, 0.0, 1.0)
		var pos: Vector2 = Vector2(m["p"]) + Vector2(sin(_t * 1.3 + float(m["drift"])) * 3.0, -float(m["drift"]) * _t)
		draw_circle(pos, float(m["r"]), Color(1.0, 0.85, 0.55, float(m["alpha"]) * fade), true, -1.0, true)


## A pop with a small overshoot (up to 1.12, then 1).
static func _back_out(p: float) -> float:
	var c := 2.2
	var q := p - 1.0
	return 1.0 + (c + 1.0) * q * q * q + c * q * q


## A brass star stamped from sheet: a dark rim, a lit face and creased facets (DESIGN.md 2).
static func draw_star_earned(ci: CanvasItem, c: Vector2, r: float, alpha: float = 1.0) -> void:
	if r <= 0.5:
		return
	ci.draw_colored_polygon(Icons.star_points(c + Vector2(r * 0.05, r * 0.1), r), Color(0, 0, 0, 0.4 * alpha))
	ci.draw_colored_polygon(Icons.star_points(c, r), Color(Tokens.STAR_RIM, alpha))
	var inner := Icons.star_points(c, r * 0.86)
	ci.draw_colored_polygon(inner, Color(Tokens.STAR_FACE, alpha))
	var center := c + Vector2(0, r * 0.06)
	for j in range(0, 10, 2):
		var lit := 0.85 if j < 4 else 0.25
		ci.draw_colored_polygon(PackedVector2Array([center, inner[j], inner[(j + 1) % 10]]), Color(Tokens.STAR_FACET, lit * alpha))


## A star not earned: an outline with a faint inner mark (UX 1.4), so it differs in shape.
static func draw_star_missed(ci: CanvasItem, c: Vector2, r: float, alpha: float = 1.0) -> void:
	var col := Color(Tokens.STAR_MISSED, Tokens.STAR_MISSED.a * alpha)
	var pts := Icons.star_points(c, r * 0.94)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, maxf(2.0, r * 0.085), true)
	var inner := Icons.star_points(c, r * 0.4)
	inner.append(inner[0])
	ci.draw_polyline(inner, Color(col, col.a * 0.45), maxf(1.2, r * 0.05), true)


## A curled ribbon of oak shaving, wide where it was cut and tapering as it rolls up.
func _shaving(c: Vector2, r: float, a0: float, tone: float, alpha: float) -> void:
	var oak := Looks.wood("oak")
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var steps := 18
	for j in steps:
		var t := j / float(steps - 1)
		var a := a0 + t * TAU * 1.15
		var rr := r * (1.0 - 0.6 * t)
		var p := c + Vector2(cos(a), sin(a) * 0.62) * rr
		var tangent := Vector2(-sin(a), cos(a) * 0.62).normalized()
		var n := Vector2(-tangent.y, tangent.x)
		var w := r * 0.42 * (1.0 - 0.75 * t)
		left.append(p + n * w * 0.5)
		right.append(p - n * w * 0.5)
	var poly := left.duplicate()
	var back := right.duplicate()
	back.reverse()
	poly.append_array(back)
	var face: Color = Color(oak["wood_light"]).lightened(0.12)
	draw_colored_polygon(poly, Color(face.r * tone, face.g * tone, face.b * tone, alpha))
	draw_polyline(left, Color(oak["wood_dark"], 0.9 * alpha), 1.2, true)
	draw_polyline(right, Color(oak["edge_color"], 0.8 * alpha), 1.0, true)
