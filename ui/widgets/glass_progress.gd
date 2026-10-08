class_name GlassProgress
extends Control
## Thin glass progress bar: dark inset track, glossy gradient fill that eases to its value.

var value: float = 0.0          ## logical value 0..1
var bar_height: float = 16.0

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
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.28)
	draw_style_box(sb, track)
	sb.bg_color = Color(1, 1, 1, 0.07)
	draw_style_box(sb, track.grow(-1.5))

	if _shown > 0.004:
		var w := maxf(bar_height, size.x * _shown)
		var fill := Rect2(track.position, Vector2(w, bar_height))
		var base := AppTheme.ACCENT.lerp(AppTheme.MINT, smoothstep(0.55, 1.0, _shown))
		sb.bg_color = base
		draw_style_box(sb, fill)
		# gloss: a lighter strip on the top half, rounded the same way
		sb.bg_color = Color(1, 1, 1, 0.30)
		draw_style_box(sb, Rect2(fill.position + Vector2(r * 0.5, 2.0), Vector2(maxf(0.0, w - r), bar_height * 0.34)))
