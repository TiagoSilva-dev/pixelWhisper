class_name ToggleSwitch
extends Control
## iOS-style switch with an animated knob. Emits `toggled(on)` when the user flips it.

signal toggled(on: bool)

var on: bool = false:
	set = set_on

var _t: float = 0.0  ## 0 = off, 1 = on (animated)
var _tween: Tween


func _init(initial: bool = false) -> void:
	on = initial
	custom_minimum_size = Vector2(150, 84)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func set_on(v: bool) -> void:
	if v == on:
		return
	on = v
	if is_inside_tree():
		_animate()
	else:
		_t = 1.0 if on else 0.0


## Sets the state without animation or signal (used when building the UI).
func set_on_silent(v: bool) -> void:
	on = v
	_t = 1.0 if v else 0.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		on = not on
		Feedback.tick()
		toggled.emit(on)
		accept_event()


func _animate() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(v: float) -> void:
		_t = v
		queue_redraw(), _t, 1.0 if on else 0.0, 0.28)


func _draw() -> void:
	var r := size.y * 0.5
	var track := AppTheme.STROKE.lerp(AppTheme.MINT, clampf(_t, 0.0, 1.0))
	draw_circle(Vector2(r, r), r, track, true, -1.0, true)
	draw_circle(Vector2(size.x - r, r), r, track, true, -1.0, true)
	draw_rect(Rect2(r, 0, size.x - 2.0 * r, size.y), track)
	var kx := lerpf(r, size.x - r, _t)
	var kr := r - 8.0
	draw_circle(Vector2(kx, r + 3.0), kr, Color(0, 0, 0, 0.25), true, -1.0, true)
	draw_circle(Vector2(kx, r), kr, Color.WHITE, true, -1.0, true)
