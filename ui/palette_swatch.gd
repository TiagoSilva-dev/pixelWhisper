class_name PaletteSwatch
extends Control
## One color of the palette bar: a numbered disc. The selected one lifts and gets a double ring;
## once every cell of that color is painted the number gives way to a check mark.

signal chosen(index: int)

const DIAMETER := 104.0
const TAP_SLOP := 24.0

var index: int = 0
var color: Color = Color.WHITE
var total: int = 1
var remaining: int = 1
var selected: bool = false

var _lift: float = 0.0       ## 0..1, animated when selected
var _wiggle: float = 0.0
var _check_pop: float = 1.0  ## 0..1, the check mark bounces in when the color completes
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(146, 176)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func setup(i: int, c: Color, cell_count: int, cells_left: int) -> void:
	index = i
	color = c
	total = maxi(cell_count, 1)
	remaining = cells_left
	queue_redraw()


func is_done() -> bool:
	return remaining <= 0


func set_remaining(n: int) -> void:
	var was_done := is_done()
	remaining = n
	if is_done() and not was_done:
		var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_method(func(v: float) -> void:
			_check_pop = v
			queue_redraw(), 0.0, 1.0, 0.45)
	queue_redraw()


func set_selected(v: bool) -> void:
	if v == selected:
		return
	selected = v
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(x: float) -> void:
		_lift = x
		queue_redraw(), _lift, 1.0 if v else 0.0, 0.3)


## "Wrong number" nudge: a quick shake to say "this is the color you were aiming at".
func wiggle() -> void:
	var t := create_tween()
	t.tween_method(func(x: float) -> void:
		_wiggle = sin(x * TAU * 3.0) * (1.0 - x) * 12.0
		queue_redraw(), 0.0, 1.0, 0.4)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
		elif _pressing:
			_pressing = false
			# Only a real tap counts; if the bar scrolled under the finger, it was a drag.
			if event.position.distance_to(_press_pos) < TAP_SLOP:
				chosen.emit(index)


func _draw() -> void:
	var done := is_done()
	var c := Vector2(size.x * 0.5 + _wiggle, size.y * 0.5 + 6.0 - _lift * 10.0)
	var r := DIAMETER * 0.5 * (1.0 + _lift * 0.1)

	draw_circle(c + Vector2(0, 6), r, Color(0.36, 0.27, 0.08, 0.2), true, -1.0, true)
	draw_circle(c, r, color.darkened(0.22) if done else color, true, -1.0, true)
	draw_arc(c, r - 4.0, PI * 1.05, PI * 1.7, 20, Color(1, 1, 1, 0.3), 5.0, true)   # gloss
	draw_arc(c, r - 1.5, 0.0, TAU, 56, Color(0, 0, 0, 0.12), 3.0, true)             # thin edge

	if selected or _lift > 0.01:
		# the double ring: a dark ring hugging the disc, a white gap, a second dark ring outside
		var a := clampf(_lift, 0.0, 1.0)
		draw_arc(c, r + 3.0, 0.0, TAU, 64, Color(AppTheme.INK, a), 5.0, true)
		draw_arc(c, r + 16.0, 0.0, TAU, 64, Color(AppTheme.INK, a), 5.0, true)

	var ink := Color(0.1, 0.08, 0.16) if (color.get_luminance() > 0.55 and not done) else Color.WHITE
	if done:
		Icons.draw(self, Icons.Kind.CHECK, c, r * 0.4 * (0.6 + 0.4 * _check_pop), ink)
	else:
		var f := AppTheme.font(900)
		var text := str(index + 1)
		var fs := 48 if text.length() < 2 else 42
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, Vector2(c.x - tw.x * 0.5, c.y + f.get_ascent(fs) * 0.5 - 4.0), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
