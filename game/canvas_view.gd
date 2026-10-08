class_name CanvasView
extends Control
## The interactive color-by-number canvas.
##
## Rendering: ONE TextureRect with canvas_grid.gdshader draws every cell (see the shader
## header). The CPU only keeps two small images up to date: the per-cell state texture
## (palette index, painted flag, pop animation) and nothing else. No per-cell nodes.
##
## Input: touch (1 finger paints, 2 fingers pan/zoom), mouse (left paints, right/middle/
## space+left pans, wheel zooms) and trackpad gestures. Touch and mouse are handled
## separately; mouse events synthesized from touch (device == DEVICE_ID_EMULATION) are
## ignored here because the real touch events already drive the canvas.

signal cell_painted(cell: int, color_index: int)
signal color_completed(color_index: int)
signal progress_changed(painted: int, total: int)
signal level_completed
signal wrong_tapped(color_index: int)
signal fit_state_changed(is_fit: bool)

const GRID_SHADER := preload("res://shaders/canvas_grid.gdshader")
const MAX_CELL_PX := 96.0
const FIT_MARGIN := 24.0
const PAN_OVERSCROLL := 90.0
const POP_SECONDS := 0.45
const TAP_ARM_MS := 70      ## A lone finger waits this long before painting, so the first
const TAP_SLOP := 8.0       ## finger of a two-finger gesture doesn't leave a stray dot.
const MAX_BURSTS_PER_FRAME := 5
const HINT_SECONDS := 4.0

## Controls floating over the canvas (tool buttons). Presses that start on one of them
## must not paint the cell underneath.
var input_blockers: Array[Control] = []

var level: PixelLevel
var painted: PackedByteArray = PackedByteArray()
var remaining: PackedInt32Array = PackedInt32Array()
var painted_total: int = 0
var selected: int = -1: set = select_color
var input_enabled: bool = true: set = _set_input_enabled

## screen position (in this control) = view_offset + cell * zoom
var zoom: float = 16.0
var view_offset: Vector2 = Vector2.ZERO

var _fit_zoom: float = 8.0
var _is_fit: bool = true
var _view_tween: Tween

var _target_tex: ImageTexture
var _state_img: Image
var _state_tex: ImageTexture
var _state_dirty: bool = false
var _pop_cells: PackedInt32Array = PackedInt32Array()
var _pop_age: PackedFloat32Array = PackedFloat32Array()

var _frame: Panel
var _surface: TextureRect
var _material: ShaderMaterial
var _overlay: Control
var _fx: ParticleFx

# input state
var _touches: Dictionary = {}          # finger index -> local position
var _pending_touch: int = -1           # finger waiting to become a stroke
var _pending_pos: Vector2 = Vector2.ZERO
var _pending_since_ms: int = 0
var _blocked_until_release: bool = false
var _stroke_active: bool = false
var _stroke_last: Vector2i = Vector2i(-1, -1)
var _stroke_wrong_sent: bool = false
var _gesture_center: Vector2 = Vector2.ZERO
var _gesture_dist: float = 0.0
var _gesture_time_ms: int = 0
var _velocity: Vector2 = Vector2.ZERO
var _mouse_painting: bool = false
var _mouse_panning: bool = false
var _space_held: bool = false

var _hint_cell: Vector2i = Vector2i(-1, -1)
var _hint_age: float = 0.0
var _bursts_this_frame: int = 0


class _Overlay extends Control:
	var view: CanvasView

	func _init(v: CanvasView) -> void:
		view = v
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		view._draw_overlay(self)


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_frame = Panel.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.13)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0, 10)
	_frame.add_theme_stylebox_override("panel", sb)
	add_child(_frame)

	_material = ShaderMaterial.new()
	_material.shader = GRID_SHADER
	_material.set_shader_parameter("glyph_tex", GlyphAtlas.get_texture())
	_surface = TextureRect.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_surface.stretch_mode = TextureRect.STRETCH_SCALE
	_surface.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_surface.material = _material
	add_child(_surface)

	_fx = ParticleFx.new()
	add_child(_fx)

	_overlay = _Overlay.new(self)
	add_child(_overlay)

	resized.connect(_on_resized)
	GameState.settings_changed.connect(_apply_settings)
	_apply_settings()
	set_process(true)


# ---------------------------------------------------------------------------------
# Level lifecycle
# ---------------------------------------------------------------------------------

func set_level(lvl: PixelLevel, saved_painted: PackedByteArray) -> void:
	level = lvl
	painted = saved_painted.duplicate()
	painted.resize(lvl.cell_count())
	remaining = lvl.counts.duplicate()
	painted_total = 0
	_pop_cells.clear()
	_pop_age.clear()
	_hint_cell = Vector2i(-1, -1)

	# Cells that were saved as painted but are not paintable (should not happen) are dropped.
	for i in lvl.cell_count():
		var idx := lvl.cells[i]
		if idx == PixelLevel.EMPTY:
			painted[i] = 0
		elif painted[i] != 0:
			remaining[idx] -= 1
			painted_total += 1

	_target_tex = ImageTexture.create_from_image(lvl.build_target_image())
	_state_img = Image.create(lvl.width, lvl.height, false, Image.FORMAT_RGBA8)
	for y in lvl.height:
		for x in lvl.width:
			var i := lvl.index_of(x, y)
			var idx := lvl.cells[i]
			_state_img.set_pixel(x, y, Color8(0 if idx == PixelLevel.EMPTY else idx, 255 if painted[i] != 0 else 0, 0, 255))
	_state_tex = ImageTexture.create_from_image(_state_img)

	_surface.texture = _target_tex
	_material.set_shader_parameter("state_tex", _state_tex)
	_material.set_shader_parameter("grid_size", Vector2(lvl.width, lvl.height))
	_material.set_shader_parameter("reveal", 0.0)
	_material.set_shader_parameter("shine", -1.0)
	selected = -1
	_is_fit = true
	if size.x > 8.0:
		fit_view(false)
	progress_changed.emit(painted_total, lvl.total_paintable)


func is_complete() -> bool:
	return level != null and painted_total >= level.total_paintable


func color_remaining(color_index: int) -> int:
	return remaining[color_index] if color_index >= 0 and color_index < remaining.size() else 0


## First palette index (after `after`, wrapping) that still has unpainted cells, or -1.
func next_unfinished_color(after: int = -1) -> int:
	var n := remaining.size()
	for step in range(1, n + 1):
		var i := (after + step) % n
		if remaining[i] > 0:
			return i
	return -1


func select_color(idx: int) -> void:
	selected = idx
	if _material == null or level == null:
		return
	_material.set_shader_parameter("selected", idx)
	if idx >= 0 and idx < level.palette.size():
		var c := level.palette[idx]
		_material.set_shader_parameter("sel_color", Vector3(c.r, c.g, c.b))


func _apply_settings() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("show_numbers", 1.0 if GameState.show_numbers else 0.0)
	_material.set_shader_parameter("show_grid", 1.0 if GameState.show_grid else 0.0)


func _set_input_enabled(v: bool) -> void:
	input_enabled = v
	if not v:
		cancel_input()


func cancel_input() -> void:
	_touches.clear()
	_pending_touch = -1
	_stroke_active = false
	_mouse_painting = false
	_mouse_panning = false
	_blocked_until_release = false


# ---------------------------------------------------------------------------------
# Painting
# ---------------------------------------------------------------------------------

## Paints one cell if it carries the selected color. Returns true when it did.
func paint_cell(x: int, y: int, silent: bool = false) -> bool:
	if level == null or not level.in_bounds(x, y):
		return false
	var i := level.index_of(x, y)
	var idx := level.cells[i]
	if idx == PixelLevel.EMPTY or painted[i] != 0 or idx != selected:
		return false

	painted[i] = 1
	remaining[idx] -= 1
	painted_total += 1
	_state_img.set_pixel(x, y, Color8(idx, 255, 255, 255))
	_pop_cells.append(i)
	_pop_age.append(0.0)
	_state_dirty = true

	if not silent:
		Feedback.pop()
		Feedback.haptic(30)
		if _bursts_this_frame < MAX_BURSTS_PER_FRAME:
			_bursts_this_frame += 1
			_fx.burst(_cell_center_local(Vector2i(x, y)), level.palette[idx], clampf(zoom / 22.0, 0.55, 2.2))

	if _hint_cell == Vector2i(x, y):
		_hint_cell = Vector2i(-1, -1)

	cell_painted.emit(i, idx)
	progress_changed.emit(painted_total, level.total_paintable)
	if remaining[idx] == 0:
		color_completed.emit(idx)
	if painted_total >= level.total_paintable:
		level_completed.emit()
	return true


## Magic wand: paints up to `count` random cells of the selected color with a short
## staggered cascade. Returns how many cells were queued.
func use_wand(count: int = 40) -> int:
	if level == null or selected < 0:
		return 0
	var pool: Array[int] = []
	for i in level.cell_count():
		if level.cells[i] == selected and painted[i] == 0:
			pool.append(i)
	pool.shuffle()
	var n := mini(count, pool.size())
	for k in n:
		var cell: int = pool[k]
		var color_at_queue := selected
		get_tree().create_timer(k * 0.028).timeout.connect(func() -> void:
			if level != null and selected == color_at_queue:
				paint_cell(cell % level.width, cell / level.width))
	return n


func _paint_line(from: Vector2i, to: Vector2i) -> void:
	# Bresenham, so a fast swipe never leaves gaps between two input events.
	var x0 := from.x
	var y0 := from.y
	var dx := absi(to.x - x0)
	var dy := -absi(to.y - y0)
	var sx := 1 if x0 < to.x else -1
	var sy := 1 if y0 < to.y else -1
	var err := dx + dy
	while true:
		paint_cell(x0, y0)
		if x0 == to.x and y0 == to.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


func _begin_stroke(p: Vector2) -> void:
	_stroke_active = true
	_stroke_last = Vector2i(-1, -1)
	_stroke_wrong_sent = false
	_stroke_to(p, true)


func _stroke_to(p: Vector2, first: bool = false) -> void:
	var cell := _cell_at(p)
	if first and level != null and level.in_bounds(cell.x, cell.y) and not _stroke_wrong_sent:
		var i := level.index_of(cell.x, cell.y)
		var idx := level.cells[i]
		if selected >= 0 and idx != PixelLevel.EMPTY and painted[i] == 0 and idx != selected:
			_stroke_wrong_sent = true
			wrong_tapped.emit(idx)
	if _stroke_last.x >= 0:
		_paint_line(_stroke_last, cell)
	else:
		paint_cell(cell.x, cell.y)
	_stroke_last = cell


func _end_stroke() -> void:
	_stroke_active = false
	_stroke_last = Vector2i(-1, -1)


# ---------------------------------------------------------------------------------
# Hints
# ---------------------------------------------------------------------------------

## Highlights the unpainted cell of the selected color nearest to the middle of the
## screen and glides the camera there. Returns false if nothing is left to hint.
func request_hint() -> bool:
	if level == null or selected < 0 or remaining[selected] <= 0:
		return false
	var centre_cell := (size * 0.5 - view_offset) / zoom
	var best := -1
	var best_d := INF
	for i in level.cell_count():
		if level.cells[i] == selected and painted[i] == 0:
			var p := Vector2(i % level.width + 0.5, i / level.width + 0.5)
			var d := p.distance_squared_to(centre_cell)
			if d < best_d:
				best_d = d
				best = i
	if best < 0:
		return false
	_hint_cell = Vector2i(best % level.width, best / level.width)
	_hint_age = 0.0
	focus_cell(_hint_cell, maxf(zoom, 30.0))
	return true


func focus_cell(cell: Vector2i, target_zoom: float, duration: float = 0.45) -> void:
	var z := clampf(target_zoom, _fit_zoom, MAX_CELL_PX)
	var off := size * 0.5 - (Vector2(cell) + Vector2(0.5, 0.5)) * z
	_is_fit = false
	_animate_view(z, off, duration)


# ---------------------------------------------------------------------------------
# View (pan / zoom)
# ---------------------------------------------------------------------------------

func fit_view(animate: bool = true) -> void:
	if level == null or size.x < 8.0:
		return
	_recompute_fit_zoom()
	var off := (size - Vector2(level.width, level.height) * _fit_zoom) * 0.5
	_is_fit = true
	_animate_view(_fit_zoom, off, 0.38 if animate else 0.0)
	fit_state_changed.emit(true)


func is_fit() -> bool:
	return _is_fit


func zoom_at(local_point: Vector2, factor: float) -> void:
	if level == null:
		return
	var new_zoom := clampf(zoom * factor, _fit_zoom, MAX_CELL_PX)
	var f := new_zoom / zoom
	view_offset = local_point - (local_point - view_offset) * f
	zoom = new_zoom
	_update_fit_flag()
	_apply_view()


func _recompute_fit_zoom() -> void:
	var avail := size - Vector2.ONE * FIT_MARGIN * 2.0
	_fit_zoom = maxf(1.0, minf(avail.x / level.width, avail.y / level.height))


func _update_fit_flag() -> void:
	var now_fit := zoom <= _fit_zoom * 1.03
	if now_fit != _is_fit:
		_is_fit = now_fit
		fit_state_changed.emit(_is_fit)


func _animate_view(z: float, off: Vector2, duration: float) -> void:
	if _view_tween:
		_view_tween.kill()
	_velocity = Vector2.ZERO
	if duration <= 0.0:
		zoom = z
		view_offset = off
		_apply_view()
		return
	var z0 := zoom
	var o0 := view_offset
	_view_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_view_tween.tween_method(func(t: float) -> void:
		zoom = exp(lerpf(log(z0), log(z), t))  # interpolate zoom geometrically: feels linear to the eye
		view_offset = o0.lerp(off, t)
		_apply_view(), 0.0, 1.0, duration)


func _on_resized() -> void:
	if level == null:
		return
	_recompute_fit_zoom()
	if _is_fit:
		zoom = _fit_zoom
		view_offset = (size - Vector2(level.width, level.height) * zoom) * 0.5
	_apply_view()


func _apply_view() -> void:
	if level == null or _surface == null:
		return
	_clamp_view()
	var img := Vector2(level.width, level.height) * zoom
	_surface.position = view_offset
	_surface.size = img
	_frame.position = view_offset - Vector2(6, 6)
	_frame.size = img + Vector2(12, 12)
	_material.set_shader_parameter("cell_px", zoom * _screen_scale())
	_overlay.queue_redraw()


func _clamp_view() -> void:
	var img := Vector2(level.width, level.height) * zoom
	for axis in 2:
		if img[axis] + FIT_MARGIN * 2.0 <= size[axis] + 0.5:
			view_offset[axis] = (size[axis] - img[axis]) * 0.5
		else:
			view_offset[axis] = clampf(view_offset[axis], size[axis] - img[axis] - PAN_OVERSCROLL, PAN_OVERSCROLL)


## Physical pixels per canvas unit (content scale x window scale).
func _screen_scale() -> float:
	var s := get_viewport().get_final_transform().get_scale().x
	return s if s > 0.0 else 1.0


func _cell_at(local: Vector2) -> Vector2i:
	var c := (local - view_offset) / zoom
	return Vector2i(floori(c.x), floori(c.y))


func _cell_center_local(cell: Vector2i) -> Vector2:
	return view_offset + (Vector2(cell) + Vector2(0.5, 0.5)) * zoom


# ---------------------------------------------------------------------------------
# Completion
# ---------------------------------------------------------------------------------

## Plays the "picture finished" reveal (grid dissolves, shine sweep, confetti).
func play_completion() -> void:
	input_enabled = false
	fit_view(true)
	var t := create_tween().set_parallel(true)
	t.tween_method(func(v: float) -> void: _material.set_shader_parameter("reveal", v), 0.0, 1.0, 0.9)
	t.tween_method(func(v: float) -> void: _material.set_shader_parameter("shine", v), -0.2, 1.4, 1.5).set_delay(0.25)
	for k in 3:
		get_tree().create_timer(0.15 + k * 0.28).timeout.connect(func() -> void:
			_fx.confetti(Vector2(size.x * (0.2 + 0.3 * k), -10.0), size.x * 0.5))
	await t.finished


# ---------------------------------------------------------------------------------
# Per-frame work
# ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_bursts_this_frame = 0
	if level == null:
		return

	# Arm a waiting single finger once it has been down long enough.
	if _pending_touch != -1 and Time.get_ticks_msec() - _pending_since_ms >= TAP_ARM_MS:
		_arm_pending()

	# Pop animation per painted cell lives in the B channel of the state texture.
	if not _pop_cells.is_empty():
		var i := 0
		while i < _pop_cells.size():
			_pop_age[i] += delta
			var cell := _pop_cells[i]
			var x := cell % level.width
			var y := cell / level.width
			if _pop_age[i] >= POP_SECONDS:
				_state_img.set_pixel(x, y, Color8(level.cells[cell], 255, 0, 255))
				_pop_cells[i] = _pop_cells[_pop_cells.size() - 1]
				_pop_age[i] = _pop_age[_pop_age.size() - 1]
				_pop_cells.resize(_pop_cells.size() - 1)
				_pop_age.resize(_pop_age.size() - 1)
			else:
				var b := int((1.0 - _pop_age[i] / POP_SECONDS) * 255.0)
				_state_img.set_pixel(x, y, Color8(level.cells[cell], 255, b, 255))
				i += 1
		_state_dirty = true
	if _state_dirty:
		_state_tex.update(_state_img)
		_state_dirty = false

	# Momentum after a two-finger / mouse pan.
	if _velocity.length_squared() > 64.0 and not _mouse_panning and _touches.size() < 2:
		view_offset += _velocity * delta
		_velocity *= exp(-delta * 5.5)
		_apply_view()
	elif _velocity != Vector2.ZERO and _touches.size() < 2:
		_velocity = Vector2.ZERO

	if _hint_cell.x >= 0:
		_hint_age += delta
		if _hint_age > HINT_SECONDS:
			_hint_cell = Vector2i(-1, -1)
		_overlay.queue_redraw()


func _draw_overlay(c: Control) -> void:
	if _hint_cell.x < 0:
		return
	var r := Rect2(view_offset + Vector2(_hint_cell) * zoom, Vector2.ONE * zoom)
	var pulse := 0.5 + 0.5 * sin(_hint_age * 7.0)
	var fade := clampf((HINT_SECONDS - _hint_age) / 0.6, 0.0, 1.0)
	var col := Color(1, 1, 1, (0.55 + 0.45 * pulse) * fade)
	c.draw_rect(r.grow(2.0 + pulse * 3.0), col, false, maxf(2.0, zoom * 0.09))
	c.draw_rect(r.grow(8.0 + pulse * 6.0), Color(1, 0.85, 0.4, 0.35 * fade), false, 2.0)


# ---------------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if level == null or not input_enabled or not is_visible_in_tree():
		return

	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return  # synthesized from touch; the touch handlers already cover it
		if event is InputEventMouseButton:
			_on_mouse_button(event)
		else:
			_on_mouse_motion(event)
	elif event is InputEventMagnifyGesture:
		if _contains(event.position):
			zoom_at(_to_local(event.position), event.factor)
	elif event is InputEventPanGesture:
		if _contains(event.position):
			_cancel_view_tween()
			view_offset -= event.delta * 14.0
			_apply_view()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F: fit_view()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: zoom_at(size * 0.5, 1.25)
			KEY_MINUS, KEY_KP_SUBTRACT: zoom_at(size * 0.5, 0.8)
	if event is InputEventKey and event.keycode == KEY_SPACE:
		_space_held = event.pressed


func _contains(global_pos: Vector2) -> bool:
	if not get_global_rect().has_point(global_pos):
		return false
	for b in input_blockers:
		if is_instance_valid(b) and b.is_visible_in_tree() and b.get_global_rect().has_point(global_pos):
			return false
	return true


func _to_local(global_pos: Vector2) -> Vector2:
	return global_pos - global_position


func _cancel_view_tween() -> void:
	if _view_tween:
		_view_tween.kill()
	_velocity = Vector2.ZERO


# -- touch --------------------------------------------------------------------------

func _on_touch(e: InputEventScreenTouch) -> void:
	var p := _to_local(e.position)
	if e.pressed:
		if not _contains(e.position):
			return
		_cancel_view_tween()
		_touches[e.index] = p
		if _touches.size() == 1 and not _blocked_until_release:
			_pending_touch = e.index
			_pending_pos = p
			_pending_since_ms = Time.get_ticks_msec()
		elif _touches.size() >= 2:
			_pending_touch = -1
			_end_stroke()
			_blocked_until_release = true
			_begin_gesture()
	else:
		if not _touches.has(e.index):
			return
		if _pending_touch == e.index:
			# Quick tap: paint exactly where the finger was.
			_arm_pending(p)
		_touches.erase(e.index)
		if _stroke_active and _touches.is_empty():
			_end_stroke()
		if _touches.size() >= 2:
			_begin_gesture()
		if _touches.is_empty():
			_blocked_until_release = false


func _arm_pending(at: Vector2 = Vector2.INF) -> void:
	if _pending_touch == -1:
		return
	var pos := _pending_pos if at == Vector2.INF else at
	_pending_touch = -1
	_begin_stroke(pos)


func _on_drag(e: InputEventScreenDrag) -> void:
	if not _touches.has(e.index):
		return
	var p := _to_local(e.position)
	_touches[e.index] = p

	if _touches.size() >= 2:
		_update_gesture()
		return
	if _pending_touch == e.index:
		if p.distance_to(_pending_pos) < TAP_SLOP:
			return
		_arm_pending()  # starts the stroke at the original touch point, so no cells are skipped
	if _stroke_active and not _blocked_until_release:
		_stroke_to(p)


func _begin_gesture() -> void:
	var pts := _touches.values()
	if pts.size() < 2:
		return
	_gesture_center = (pts[0] + pts[1]) * 0.5
	_gesture_dist = maxf((pts[0] as Vector2).distance_to(pts[1]), 1.0)
	_gesture_time_ms = Time.get_ticks_msec()
	_velocity = Vector2.ZERO


func _update_gesture() -> void:
	var pts := _touches.values()
	var center: Vector2 = (pts[0] + pts[1]) * 0.5
	var dist := maxf((pts[0] as Vector2).distance_to(pts[1]), 1.0)
	var now := Time.get_ticks_msec()
	var dt := maxf((now - _gesture_time_ms) / 1000.0, 0.001)

	zoom_at(_gesture_center, dist / _gesture_dist)
	var pan := center - _gesture_center
	view_offset += pan
	_apply_view()
	_velocity = _velocity.lerp(pan / dt, 0.4)

	_gesture_center = center
	_gesture_dist = dist
	_gesture_time_ms = now


# -- mouse --------------------------------------------------------------------------

func _on_mouse_button(e: InputEventMouseButton) -> void:
	var p := _to_local(e.position)
	match e.button_index:
		MOUSE_BUTTON_LEFT:
			if e.pressed and _contains(e.position):
				_cancel_view_tween()
				if _space_held:
					_mouse_panning = true
				else:
					_mouse_painting = true
					_begin_stroke(p)
			elif not e.pressed:
				_mouse_painting = false
				_mouse_panning = false
				_end_stroke()
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if e.pressed and _contains(e.position):
				_cancel_view_tween()
				_mouse_panning = true
			elif not e.pressed:
				_mouse_panning = false
		MOUSE_BUTTON_WHEEL_UP:
			if e.pressed and _contains(e.position):
				_cancel_view_tween()
				zoom_at(p, 1.0 + 0.14 * e.factor)
		MOUSE_BUTTON_WHEEL_DOWN:
			if e.pressed and _contains(e.position):
				_cancel_view_tween()
				zoom_at(p, 1.0 / (1.0 + 0.14 * e.factor))


func _on_mouse_motion(e: InputEventMouseMotion) -> void:
	if _mouse_panning:
		view_offset += e.relative
		_apply_view()
	elif _mouse_painting:
		_stroke_to(_to_local(e.position))
