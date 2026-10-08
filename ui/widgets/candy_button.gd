class_name CandyButton
extends Control
## The one pressable widget of the game: a flat, saturated face with a darker "lip" under it, an
## optional vector icon and an optional label. Pressing squishes it, sinks the face onto the
## lip and fires a soft tick. Used for back/hint/settings buttons, category pills and dialogs.
##
## Everything is drawn in `_draw()` (no child nodes), so a screen full of them costs nothing.

signal pressed

enum Layout { ICON_ONLY, ICON_LEFT }

const TAP_SLOP := 26.0

@export var icon: Icons.Kind = Icons.Kind.NONE:
	set(v):
		icon = v
		_changed()
@export var text: String = "":
	set(v):
		text = v
		_changed()
@export var color: Color = AppTheme.PINK:
	set(v):
		color = v
		queue_redraw()
@export var text_color: Color = Color.WHITE:
	set(v):
		text_color = v
		queue_redraw()
@export var icon_color: Color = Color.WHITE:
	set(v):
		icon_color = v
		queue_redraw()
@export var font_size: int = 40:
	set(v):
		font_size = v
		_changed()
@export var radius: float = -1.0:               ## corner radius in px; negative = fully round
	set(v):
		radius = v
		queue_redraw()
@export var pad_x: float = 34.0:
	set(v):
		pad_x = v
		_changed()
@export var pad_y: float = 20.0:
	set(v):
		pad_y = v
		_changed()
@export var icon_scale: float = 1.0:            ## 1.0 = the icon fills about 60% of the face height
	set(v):
		icon_scale = v
		queue_redraw()
@export var selected: bool = false:             ## white ring around the face (active category, tab...)
	set(v):
		selected = v
		queue_redraw()
@export var dimmed: bool = false:
	set(v):
		dimmed = v
		modulate.a = 0.5 if v else 1.0

var layout: Layout = Layout.ICON_LEFT

var _down: bool = false
var _sink: float = 0.0           ## 0..1: how far the face has sunk onto the lip
var _press_pos: Vector2 = Vector2.ZERO
var _tween: Tween


func _init(p_icon: Icons.Kind = Icons.Kind.NONE, p_text: String = "", p_color: Color = AppTheme.PINK) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	icon = p_icon
	text = p_text
	color = p_color
	layout = Layout.ICON_ONLY if p_text == "" else Layout.ICON_LEFT


func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_changed()


func _changed() -> void:
	layout = Layout.ICON_ONLY if text == "" else Layout.ICON_LEFT
	update_minimum_size()
	queue_redraw()


func _lip_px() -> float:
	return clampf(minf(size.x, size.y) * 0.075, 5.0, 11.0)


func _face_rect() -> Rect2:
	var lip := _lip_px()
	return Rect2(0.0, _sink * (lip - 2.0), size.x, size.y - lip)


func _get_minimum_size() -> Vector2:
	if layout == Layout.ICON_ONLY:
		return Vector2(0, 0)
	var f := AppTheme.font(900)
	var tw := f.get_string_size(tr(text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var h := ceilf(f.get_height(font_size)) + pad_y * 2.0 + 8.0
	var icon_w := (h * 0.62 + 14.0) if icon != Icons.Kind.NONE else 0.0
	return Vector2(ceilf(tw) + icon_w + pad_x * 2.0, h)


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var lip := _lip_px()
	var face := _face_rect()
	var r := radius if radius >= 0.0 else face.size.y * 0.5
	r = minf(r, minf(face.size.x, face.size.y) * 0.5)

	# soft drop shadow + lip
	var back := Rect2(0.0, lip, size.x, size.y - lip)
	var sb := StyleBoxFlat.new()
	sb.bg_color = AppTheme.lip(color)
	sb.set_corner_radius_all(int(r))
	sb.anti_aliasing = true
	sb.shadow_color = AppTheme.SHADOW
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 5)
	draw_style_box(sb, back)

	# face
	var fb := StyleBoxFlat.new()
	fb.bg_color = color
	fb.set_corner_radius_all(int(r))
	fb.anti_aliasing = true
	if selected:
		fb.set_border_width_all(5)
		fb.border_color = Color.WHITE
	draw_style_box(fb, face)
	# glossy highlight on the top half
	var gloss := StyleBoxFlat.new()
	gloss.bg_color = Color(1, 1, 1, 0.2)
	gloss.set_corner_radius_all(int(maxf(r * 0.6, 2.0)))
	gloss.anti_aliasing = true
	draw_style_box(gloss, Rect2(face.position + Vector2(r * 0.55, 5.0), Vector2(maxf(0.0, face.size.x - r * 1.1), face.size.y * 0.3)))

	var c := face.get_center()
	if layout == Layout.ICON_ONLY:
		if icon != Icons.Kind.NONE:
			Icons.draw(self, icon, c, minf(face.size.x, face.size.y) * 0.3 * icon_scale, icon_color)
		return

	var f := AppTheme.font(900)
	var label := tr(text)
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var u := face.size.y * 0.31 * icon_scale
	var gap := 14.0
	var icon_w := (u * 2.0 + gap) if icon != Icons.Kind.NONE else 0.0
	var x := c.x - (icon_w + tw) * 0.5
	if icon != Icons.Kind.NONE:
		Icons.draw(self, icon, Vector2(x + u, c.y), u, icon_color)
		x += icon_w
	var base_y := c.y + (f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5
	draw_string(f, Vector2(x, base_y + 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.18))
	draw_string(f, Vector2(x, base_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func _gui_input(event: InputEvent) -> void:
	# No accept_event(): the STOP filter already keeps the press from reaching other controls,
	# while a drag that starts on a pill can still scroll the carousel it sits in.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_press_pos = event.position
			Feedback.tick()
			_animate_press(1.0, 0.07, false)
		elif _down:
			_down = false
			_animate_press(0.0, 0.24, true)
			if Rect2(Vector2.ZERO, size).has_point(event.position) and event.position.distance_to(_press_pos) < TAP_SLOP:
				pressed.emit()
	elif event is InputEventMouseMotion and _down and event.position.distance_to(_press_pos) > TAP_SLOP * 2.0:
		_down = false          # the finger is dragging (scrolling a list): un-press without firing
		_animate_press(0.0, 0.2, false)


func _animate_press(target: float, duration: float, bouncy: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_BACK if bouncy else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * lerpf(1.0, 0.94, target), duration)
	_tween.tween_method(func(v: float) -> void:
		_sink = v
		queue_redraw(), _sink, target, duration)


## Attention bounce, e.g. when a counter changes.
func pop() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * 1.14, 0.1)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.26)
