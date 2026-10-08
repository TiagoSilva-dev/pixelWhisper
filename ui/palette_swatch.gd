class_name PaletteSwatch
extends Control
## One color of the palette bar: the color disc with its number, a progress ring around
## it, and a check mark once every cell of that color is painted.

signal chosen(index: int)

const DIAMETER := 118.0
const TAP_SLOP := 24.0

var index: int = 0
var color: Color = Color.WHITE
var total: int = 1
var remaining: int = 1
var selected: bool = false

var _lift: float = 0.0       ## 0..1, animated when selected
var _shown_frac: float = 0.0 ## animated progress 0..1
var _wiggle: float = 0.0
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(150, 188)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func setup(i: int, c: Color, cell_count: int, cells_left: int) -> void:
	index = i
	color = c
	total = maxi(cell_count, 1)
	remaining = cells_left
	_shown_frac = _fraction()
	queue_redraw()


func _fraction() -> float:
	return 1.0 - float(remaining) / float(total)


func set_remaining(n: int) -> void:
	remaining = n
	var target := _fraction()
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float) -> void:
		_shown_frac = v
		queue_redraw(), _shown_frac, target, 0.25)


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
	var done := remaining <= 0
	var c := Vector2(size.x * 0.5 + _wiggle, size.y * 0.5 + 10.0 - _lift * 12.0)
	var r := DIAMETER * 0.5 * (1.0 + _lift * 0.13)

	if selected or _lift > 0.01:
		draw_circle(c, r + 22.0, Color(1, 1, 1, 0.10 * _lift), true, -1.0, true)
	draw_circle(c + Vector2(0, 6), r, Color(0, 0, 0, 0.35), true, -1.0, true)

	var disc := color.darkened(0.25) if done and not selected else color
	draw_circle(c, r, disc, true, -1.0, true)
	draw_arc(c, r - 3.0, PI * 1.05, PI * 1.75, 20, Color(1, 1, 1, 0.22), 5.0, true)  # gloss

	# progress ring
	var rr := r + 11.0
	draw_arc(c, rr, 0.0, TAU, 64, Color(1, 1, 1, 0.12), 6.0, true)
	if _shown_frac > 0.003:
		var ring := AppTheme.MINT if done else Color.WHITE
		draw_arc(c, rr, -PI * 0.5, -PI * 0.5 + TAU * _shown_frac, 64, ring, 6.0, true)
	if selected:
		draw_arc(c, r + 3.0, 0.0, TAU, 64, Color.WHITE, 4.0, true)

	var ink := Color(0.1, 0.08, 0.16) if color.get_luminance() > 0.55 else Color.WHITE
	if done:
		var u := r * 0.34
		var pts := PackedVector2Array([c + Vector2(-0.9, 0.05) * u, c + Vector2(-0.3, 0.7) * u, c + Vector2(0.95, -0.7) * u])
		draw_polyline(pts, ink, 8.0, true)
		for p in pts:
			draw_circle(p, 4.0, ink, true, -1.0, true)
	else:
		var f := AppTheme.font(900)
		var text := str(index + 1)
		var fs := 50 if text.length() < 2 else 44
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, Vector2(c.x - tw.x * 0.5, c.y + f.get_ascent(fs) * 0.5 - 4.0), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
