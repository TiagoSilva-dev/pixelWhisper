class_name PowerUpButton
extends Control
## A power-up slot: illustrated icon, two-line name and its price in coins. It dims when the
## wallet can't pay for it, and shows a pulsing ring while it is "armed" (waiting for a tap on
## the canvas, like the ink bomb).

signal pressed

const TAP_SLOP := 26.0

var kind: Icons.Kind = Icons.Kind.WAND
var label: String = ""
var cost: int = 0:
	set(v):
		cost = v
		queue_redraw()
var armed: bool = false:
	set(v):
		armed = v
		set_process(v)
		queue_redraw()

var _down: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _tween: Tween
var _t: float = 0.0


func _init(p_kind: Icons.Kind = Icons.Kind.WAND, p_label: String = "", p_cost: int = 0) -> void:
	kind = p_kind
	label = p_label
	cost = p_cost
	custom_minimum_size = Vector2(140, 204)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	set_process(false)


func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	GameState.wallet_changed.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func affordable() -> bool:
	return GameState.coins >= cost


func _draw() -> void:
	var lip := 8.0
	var face := Rect2(0, 0, size.x, size.y - lip)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(34)
	sb.anti_aliasing = true
	sb.bg_color = Color("e2d8b8")
	sb.shadow_color = AppTheme.SHADOW
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 5)
	draw_style_box(sb, Rect2(0, lip, size.x, size.y - lip))
	sb.shadow_size = 0
	sb.bg_color = Color.WHITE
	if armed:
		var pulse := 0.5 + 0.5 * sin(_t * 8.0)
		sb.set_border_width_all(6)
		sb.border_color = AppTheme.ORANGE.lerp(AppTheme.YELLOW, pulse)
	draw_style_box(sb, face)

	var c := Vector2(size.x * 0.5, 54.0)
	Icons.draw(self, kind, c, 32.0, Color("3ea6ff"))
	if not (affordable() or armed):
		draw_circle(c, 46.0, Color(1, 1, 1, 0.55), true, -1.0, true)  # washes the icon out on a white card

	var f := AppTheme.font(800)
	draw_multiline_string(f, Vector2(8, 110), tr(label), HORIZONTAL_ALIGNMENT_CENTER, size.x - 16.0, 23, 2, AppTheme.INK)

	# price chip
	var chip := Rect2(Vector2(size.x * 0.5 - 50.0, size.y - lip - 42.0), Vector2(100, 32))
	var cb := StyleBoxFlat.new()
	cb.set_corner_radius_all(16)
	cb.anti_aliasing = true
	cb.bg_color = AppTheme.SURFACE_DIM if affordable() else Color("ffe0e0")
	draw_style_box(cb, chip)
	Icons.draw(self, Icons.Kind.COIN, chip.position + Vector2(20, 16), 12.0)
	var pf := AppTheme.font(900)
	var price_col := AppTheme.INK if affordable() else AppTheme.RED
	draw_string(pf, chip.position + Vector2(38, 24), str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, price_col)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_press_pos = event.position
			Feedback.tick()
			_squish(0.93, 0.07, false)
			accept_event()
		elif _down:
			_down = false
			_squish(1.0, 0.24, true)
			if Rect2(Vector2.ZERO, size).has_point(event.position) and event.position.distance_to(_press_pos) < TAP_SLOP:
				pressed.emit()
			accept_event()


func _squish(target: float, duration: float, bouncy: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK if bouncy else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * target, duration)


func pop() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * 1.14, 0.1)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.26)


func wiggle() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(x: float) -> void:
		rotation = sin(x * TAU * 3.0) * (1.0 - x) * 0.09, 0.0, 1.0, 0.4)
	_tween.tween_callback(func() -> void: rotation = 0.0)
