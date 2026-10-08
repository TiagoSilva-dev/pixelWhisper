class_name GlowLabel
extends Control
## Single-line title with a soft neon halo. The halo is the same text drawn on concentric
## rings in a translucent color (cheap, resolution-independent "blur"); it is only redrawn
## when something changes.

@export var text: String = "":
	set(v):
		text = v
		_changed()
@export var font_size: int = 78:
	set(v):
		font_size = v
		_changed()
@export var weight: int = 900:
	set(v):
		weight = v
		_changed()
@export var color: Color = AppTheme.TEXT:
	set(v):
		color = v
		queue_redraw()
@export var glow_color: Color = Color(1.0, 0.52, 0.86, 1.0):
	set(v):
		glow_color = v
		queue_redraw()
@export var glow: float = 1.0:
	set(v):
		glow = v
		queue_redraw()

const RINGS := [[9.0, 18, 0.034], [6.0, 14, 0.055], [3.5, 10, 0.085], [1.8, 8, 0.12]]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_changed()


func _changed() -> void:
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	var f := AppTheme.font(weight)
	var s := f.get_string_size(tr(text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return Vector2(ceilf(s.x) + 20.0, ceilf(f.get_height(font_size)) + 12.0)


func _draw() -> void:
	var f := AppTheme.font(weight)
	var t := tr(text)
	var origin := Vector2(10.0, 6.0 + f.get_ascent(font_size))
	if glow > 0.0:
		for ring in RINGS:
			var r: float = ring[0]
			var n: int = ring[1]
			var a: float = ring[2] * glow
			for i in n:
				draw_string(f, origin + Vector2.from_angle(i * TAU / n) * r, t,
						HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(glow_color, a))
	draw_string(f, origin + Vector2(0, 3), t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.25))
	draw_string(f, origin, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
