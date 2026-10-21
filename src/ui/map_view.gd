# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MapView
extends Control
## The scrolling trail of the progress map (docs/UX.md 3.6). Level 1 is at the bottom and
## higher levels are above. Positions come from MapMath, about 20 MapNodeView views are recycled
## (the levels in view take the pool nodes in turn), a drag scrolls with momentum, and a short touch is
## a tap that MapMath turns into a level number. It opens centered on the next level.

## A cleared level or the next one was tapped.
signal level_chosen(level: int)
## A locked level was tapped; `next` is the level the player has to clear first.
signal locked_tapped(next: int)

const TAP_MOVE := 10.0
const TAP_MS := 300
## Momentum decays by this much per second: a fast flick (3000 units a second) travels about
## 1500 units.
const FRICTION := 2.0

var highest := 0
var levels: Dictionary = {}
var scroll := 0.0
## How many times a node view was set up (redrawn) so far; a test counts them.
var setup_calls := 0
var _pool: Array[MapNodeView] = []
var _fade_overlay: Control
var _velocity := 0.0
var _touching := false
var _down_pos := Vector2.ZERO
var _down_ms := 0
var _moved := false
var _last_y := 0.0
var _last_ms := 0
var _pressed_node: MapNodeView
var _goto_tween: Tween
var _goto: UiButton
var _goto_icon: IconView
var _first_layout := true


## levels: the Save's progress "levels" dictionary (level number text to a record).
static func make(highest_cleared: int, level_records: Dictionary) -> MapView:
	var v := new()
	v.highest = highest_cleared
	v.levels = level_records
	v.clip_contents = true
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


func _ready() -> void:
	resized.connect(_on_resized)
	_goto = UiButton.make("Go to level", UiButton.Kind.QUIET, "", 48.0)
	_goto.custom_minimum_size = Vector2(140.0, 48.0)
	_goto.visible = false
	_goto.pressed.connect(scroll_to_next)
	_goto_icon = IconView.make("arrow_up", 20.0, UiTheme.TEXT)
	_goto_icon.position = Vector2(8.0, 14.0)
	_goto.add_child(_goto_icon)
	_fade_overlay = _FadeOverlay.new()
	add_child(_fade_overlay)
	add_child(_goto)
	_on_resized()


func _on_resized() -> void:
	if _first_layout and size.y > 0.0:
		_first_layout = false
		scroll = MapMath.scroll_for(highest + 1, highest, size.y)
	scroll = clampf(scroll, 0.0, _max_scroll())
	_goto.position = Vector2((size.x - 140.0) / 2.0, size.y - 56.0)
	_refresh()


func _max_scroll() -> float:
	return maxf(0.0, MapMath.content_height(highest, size.y) - size.y)


func _center_x() -> float:
	return size.x / 2.0


func _lane_step() -> float:
	return minf(MapMath.LANE_STEP, maxf(60.0, (size.x - 96.0) / 2.0))


## Puts the pool nodes on the levels in view. Called whenever the scroll changes.
func _refresh() -> void:
	if size.y <= 0.0:
		return
	var span := MapMath.visible_levels(scroll, size.y, highest)
	var count := span.y - span.x + 1
	while _pool.size() < count:
		var fresh := MapNodeView.new()
		fresh.visible = false
		fresh.set_meta("level", 0)
		add_child(fresh)
		_pool.append(fresh)
		if _fade_overlay != null:
			move_child(_fade_overlay, -1)
		move_child(_goto, -1)
	# Nodes whose level left the view are freed for reuse; the others keep their level, so
	# scrolling only moves them (a node is set up, and so redrawn, only when it gets a new
	# level).
	for node: MapNodeView in _pool:
		var held := int(node.get_meta("level", 0))
		if held != 0 and (held < span.x or held > span.y):
			node.set_meta("level", 0)
			node.visible = false
			if node == _pressed_node:
				_pressed_node = null
	for level: int in range(span.x, span.y + 1):
		var node := _node_for(level)
		if node == null:
			for candidate: MapNodeView in _pool:
				if int(candidate.get_meta("level", 0)) == 0:
					node = candidate
					break
			var state := MapMath.state_of(level, highest)
			var stars := 0
			if state == MapMath.CLEARED:
				var rec: Dictionary = levels.get(str(level), {})
				stars = int(rec.get("stars", 0))
			node.setup(level, state, stars, MapMath.is_hard(level))
			setup_calls += 1
			node.set_meta("level", level)
			node.visible = true
		node.position = center_of(level)
	_update_goto()
	queue_redraw()


func _update_goto() -> void:
	var y := MapMath.node_y(highest + 1, highest, size.y) - scroll
	# More than half a body height out of view.
	var out := y < -size.y / 2.0 or y > size.y + size.y / 2.0
	_goto.visible = out
	if out:
		_goto.set_label("Go to level %d" % (highest + 1))
		_goto_icon.set_icon("arrow_up" if y < 0.0 else "arrow_down")


func scroll_to_next() -> void:
	var target := MapMath.scroll_for(highest + 1, highest, size.y)
	if _goto_tween != null:
		_goto_tween.kill()
	_velocity = 0.0
	_goto_tween = create_tween()
	_goto_tween.tween_method(_set_scroll, scroll, target, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_scroll(v: float) -> void:
	scroll = clampf(v, 0.0, _max_scroll())
	_refresh()


## The trail between nodes: solid up to the next node, dashed beyond it (MapTrail).
func _draw() -> void:
	if size.y <= 0.0:
		return
	var span := MapMath.visible_levels(scroll, size.y, highest)
	for n: int in range(span.x, span.y):
		MapTrail.draw_segment(self, center_of(n), center_of(n + 1), n + 1 <= highest + 1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_touch(mb.position)
			else:
				_end_touch(mb.position)
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_set_scroll(scroll + (-60.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 60.0))
	elif event is InputEventMouseMotion and _touching:
		_move_touch((event as InputEventMouseMotion).position)
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		pass


func _begin_touch(pos: Vector2) -> void:
	if _goto_tween != null:
		_goto_tween.kill()
	_touching = true
	_moved = false
	_velocity = 0.0
	_down_pos = pos
	_last_y = pos.y
	_down_ms = Time.get_ticks_msec()
	_last_ms = _down_ms
	var n := _level_at(pos)
	_pressed_node = _node_for(n) if n > 0 else null
	if _pressed_node != null:
		_pressed_node.set_pressed(true)


func _move_touch(pos: Vector2) -> void:
	if not _moved and pos.distance_to(_down_pos) >= TAP_MOVE:
		_moved = true
		_drop_pressed()
	if _moved:
		var now := Time.get_ticks_msec()
		var dy := pos.y - _last_y
		var dt := maxf(0.001, float(now - _last_ms) / 1000.0)
		_velocity = lerpf(_velocity, -dy / dt, 0.5)
		_set_scroll(scroll - dy)
	_last_y = pos.y
	_last_ms = Time.get_ticks_msec()


func _end_touch(pos: Vector2) -> void:
	if not _touching:
		return
	_touching = false
	var elapsed := Time.get_ticks_msec() - _down_ms
	var tapped := not _moved and elapsed < TAP_MS
	_drop_pressed()
	if tapped:
		tap(pos)
	elif _moved:
		set_process(true)


func _drop_pressed() -> void:
	if _pressed_node != null:
		_pressed_node.set_pressed(false)
		_pressed_node = null


## A tap at a point of this control (also used by tests): chooses a level or nudges a locked
## one.
func tap(pos: Vector2) -> void:
	var n := _level_at(pos)
	if n <= 0:
		return
	if MapMath.state_of(n, highest) == MapMath.LOCKED:
		var node := _node_for(n)
		if node != null:
			_nudge(node)
		locked_tapped.emit(highest + 1)
	else:
		level_chosen.emit(n)


func _level_at(pos: Vector2) -> int:
	return MapMath.level_at(pos.x, pos.y + scroll, _center_x(), highest, size.y, _lane_step())


func _node_for(n: int) -> MapNodeView:
	for node: MapNodeView in _pool:
		if node.visible and int(node.get_meta("level", 0)) == n:
			return node
	return null


## A locked node nudges 4 units sideways twice (200 ms).
func _nudge(node: Node2D) -> void:
	var x := node.position.x
	var t := node.create_tween()
	t.tween_property(node, "position:x", x + 4.0, 0.05)
	t.tween_property(node, "position:x", x - 4.0, 0.05)
	t.tween_property(node, "position:x", x + 4.0, 0.05)
	t.tween_property(node, "position:x", x, 0.05)


## The fade over the top 64 units of the body (UX 3.6): the trail ends softly, not at an edge.
class _FadeOverlay extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		MapTrail.draw_fade(self, Rect2(0.0, 0.0, size.x, MapMath.FADE), UiTheme.PEGBOARD)


## The screen position of level n's center, for tests.
func center_of(n: int) -> Vector2:
	return Vector2(MapMath.lane_x(n, _center_x(), _lane_step()), MapMath.node_y(n, highest, size.y) - scroll)


func pool_size() -> int:
	return _pool.size()


func _process(delta: float) -> void:
	if _touching:
		return
	_set_scroll(scroll + _velocity * delta)
	_velocity *= exp(-FRICTION * delta)
	if absf(_velocity) < 8.0 or scroll <= 0.0 or scroll >= _max_scroll():
		_velocity = 0.0
		set_process(false)
