class_name CandyProgress
extends Control
## Rounded progress bar: soft inset track and a glossy fill that eases to its value.

var value: float = 0.0          ## logical value 0..1
var bar_height: float = 18.0:
	set(v):
		bar_height = v
		custom_minimum_size.y = v
		queue_redraw()
var track_color: Color = Color(0.0, 0.0, 0.0, 0.1):
	set(v):
		track_color = v
		queue_redraw()
var fill_color: Color = AppTheme.PINK:
	set(v):
		fill_color = v
		queue_redraw()
var fill_done_color: Color = AppTheme.MINT:       ## the fill turns this color as it approaches 100%
	set(v):
		fill_done_color = v
		queue_redraw()
var turns_green: bool = true

var _shown: float = 0.0         ## what is on screen (eases toward `value`)
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(40, bar_height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func set_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	_shown = value
	if _tween:
		_tween.kill()
	queue_redraw()


func animate_to(v: float, duration: float = 0.5) -> void:
	var from := _shown
	value = clampf(v, 0.0, 1.0)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(x: float) -> void:
		_shown = x
		queue_redraw(), from, value, duration)


func _draw() -> void:
	var r := bar_height * 0.5
	var track := Rect2(Vector2(0, (size.y - bar_height) * 0.5), Vector2(size.x, bar_height))
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(r))
	sb.anti_aliasing = true
	sb.bg_color = track_color
	draw_style_box(sb, track)

	if _shown > 0.004:
		var w := maxf(bar_height, size.x * _shown)
		var fill := Rect2(track.position, Vector2(w, bar_height))
		sb.bg_color = fill_color.lerp(fill_done_color, smoothstep(0.9, 1.0, _shown)) if turns_green else fill_color
		draw_style_box(sb, fill)
		# gloss: a lighter strip on the top half, rounded the same way
		sb.bg_color = Color(1, 1, 1, 0.32)
		draw_style_box(sb, Rect2(fill.position + Vector2(r * 0.5, 2.0), Vector2(maxf(0.0, w - r), bar_height * 0.34)))
