class_name GlassSegmented
extends Control
## Glass segmented control. A light "knob" slides (with a little overshoot) to the chosen
## segment while the labels cross-fade between light and dark text as it passes under them.

signal selected(key: String)

const BAR_H := 92.0
const INSET := 8.0
const PAD_X := 40.0
const FONT_SIZE := 36
const TAP_SLOP := 24.0

var _items: Array[Dictionary] = []     # {key, text}
var _current: int = 0
var _rects: Array[Rect2] = []          # segment rects (x/width; full height)
var _knob: Rect2 = Rect2()
var _mat: ShaderMaterial
var _knob_layer: _Layer
var _label_layer: _Layer
var _tween: Tween
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false


class _Layer extends Control:
	var owner_ctl: GlassSegmented
	var kind: String

	func _init(o: GlassSegmented, k: String) -> void:
		owner_ctl = o
		kind = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if kind == "knob":
			owner_ctl._paint_knob(self)
		else:
			owner_ctl._paint_labels(self)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_knob_layer = _Layer.new(self, "knob")
	add_child(_knob_layer)
	_label_layer = _Layer.new(self, "labels")
	add_child(_label_layer)


func _ready() -> void:
	GameState.settings_changed.connect(_rebuild_material)
	resized.connect(_refresh)
	_rebuild_material()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not _items.is_empty():
		_layout_items()


## items: [{"key": "all", "text": "All"}, ...] (text is an English translation key)
func setup(items: Array, current_key: String) -> void:
	_items.clear()
	for it in items:
		_items.append(it)
	_current = 0
	for i in _items.size():
		if _items[i].key == current_key:
			_current = i
	_layout_items()
	_knob = _knob_rect_for(_current)
	_repaint()


func current_key() -> String:
	return _items[_current].key if not _items.is_empty() else ""


func select_key(key: String, emit: bool = true) -> void:
	for i in _items.size():
		if _items[i].key == key:
			_select(i, emit)
			return


func _layout_items() -> void:
	var f := AppTheme.font(800)
	_rects.clear()
	var x := INSET
	for it in _items:
		var tw := f.get_string_size(tr(it.text), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var w := ceilf(tw) + PAD_X * 2.0
		_rects.append(Rect2(x, 0.0, w, BAR_H))
		x += w
	custom_minimum_size = Vector2(x + INSET, BAR_H)
	_knob = _knob_rect_for(_current)
	_repaint()


func _knob_rect_for(i: int) -> Rect2:
	if i < 0 or i >= _rects.size():
		return Rect2()
	var r := _rects[i]
	return Rect2(r.position.x, INSET, r.size.x, BAR_H - INSET * 2.0)


func _select(i: int, emit: bool) -> void:
	if i == _current:
		return
	var from := _knob
	_current = i
	var to := _knob_rect_for(i)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(t: float) -> void:
		_knob = Rect2(from.position.lerp(to.position, t), from.size.lerp(to.size, t))
		_repaint(), 0.0, 1.0, 0.46)
	if emit:
		selected.emit(_items[i].key)


func _rebuild_material() -> void:
	_mat = Glass.make_material(true)
	material = _mat
	_refresh()


func _refresh() -> void:
	if _mat != null:
		Glass.configure(_mat, size, Glass.Style.PILL)
	queue_redraw()


func _repaint() -> void:
	queue_redraw()
	if _knob_layer:
		_knob_layer.queue_redraw()
		_label_layer.queue_redraw()


func _draw() -> void:
	if _mat != null:
		Glass.draw_quad(self, size, Glass.Style.PILL)


func _paint_knob(ci: Control) -> void:
	if _knob.size.x <= 0.0:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("ddd2ff")
	sb.set_corner_radius_all(int(_knob.size.y * 0.5))
	sb.anti_aliasing = true
	sb.shadow_color = Color(0.45, 0.3, 0.95, 0.38)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 4)
	ci.draw_style_box(sb, _knob)
	# glossy top highlight
	var g := StyleBoxFlat.new()
	g.bg_color = Color(1, 1, 1, 0.55)
	g.set_corner_radius_all(int(_knob.size.y * 0.3))
	g.anti_aliasing = true
	ci.draw_style_box(g, Rect2(_knob.position + Vector2(_knob.size.y * 0.35, 4.0), Vector2(maxf(0.0, _knob.size.x - _knob.size.y * 0.7), _knob.size.y * 0.3)))


func _paint_labels(ci: Control) -> void:
	var f := AppTheme.font(800)
	var dark := Color("2b2058")
	var light := Color(1, 1, 1, 0.82)
	for i in _items.size():
		var r := _rects[i]
		var overlap := clampf((minf(r.end.x, _knob.end.x) - maxf(r.position.x, _knob.position.x)) / r.size.x, 0.0, 1.0)
		var t := tr(_items[i].text)
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var pos := Vector2(r.position.x + (r.size.x - tw) * 0.5, BAR_H * 0.5 + f.get_ascent(FONT_SIZE) * 0.5 - f.get_descent(FONT_SIZE) * 0.35)
		ci.draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, light.lerp(dark, overlap))
		# thin divider between two inactive neighbours
		if i > 0:
			var near_knob := maxf(_overlap_with(i - 1), _overlap_with(i))
			var a := 0.2 * (1.0 - near_knob)
			if a > 0.01:
				ci.draw_line(Vector2(r.position.x, BAR_H * 0.3), Vector2(r.position.x, BAR_H * 0.7), Color(1, 1, 1, a), 2.0, true)


func _overlap_with(i: int) -> float:
	var r := _rects[i]
	return clampf((minf(r.end.x, _knob.end.x) - maxf(r.position.x, _knob.position.x)) / r.size.x, 0.0, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
		elif _pressing:
			_pressing = false
			if event.position.distance_to(_press_pos) < TAP_SLOP:
				for i in _rects.size():
					if _rects[i].has_point(Vector2(event.position.x, BAR_H * 0.5)):
						Feedback.tick()
						_select(i, true)
						break
