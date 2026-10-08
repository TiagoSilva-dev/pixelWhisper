class_name HintPill
extends Control
## Floating "tap and start coloring" glass pill at the bottom of the gallery. It bobs gently,
## taps the air with a little hand, and fades away for good on the first interaction.

var _pill: GlassPanel
var _hand: _Hand
var _t: float = 0.0
var _dismissed: bool = false


## Hand-with-ripple glyph drawn from rounded rectangles (no image assets).
class _Hand extends Control:
	var tap: float = 0.0   ## 0..1 animated

	func _init() -> void:
		custom_minimum_size = Vector2(64, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col := Color(1, 1, 1, 0.96)
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.anti_aliasing = true
		var lift := -4.0 * sin(tap * PI)
		# ripple rings above the fingertip
		for i in 2:
			var a := (1.0 - tap) * (0.5 - 0.2 * i)
			draw_arc(Vector2(26, 8 + lift), 8.0 + i * 7.0 + tap * 6.0, PI * 1.15, PI * 1.85, 12, Color(1, 1, 1, a), 2.5, true)
		# index finger
		sb.set_corner_radius_all(6)
		draw_style_box(sb, Rect2(21, 8 + lift, 11, 30))
		# palm
		sb.set_corner_radius_all(13)
		draw_style_box(sb, Rect2(11, 28, 36, 28))
		# other folded fingers
		sb.set_corner_radius_all(5)
		draw_style_box(sb, Rect2(32, 26, 9, 14))
		draw_style_box(sb, Rect2(41, 29, 8, 13))
		# thumb
		draw_set_transform(Vector2(14, 40), -0.5, Vector2.ONE)
		sb.set_corner_radius_all(5)
		draw_style_box(sb, Rect2(-8, -5, 18, 10))
		draw_set_transform(Vector2.ZERO)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_pill = GlassPanel.new(Glass.Style.PILL, true)
	_pill.padding = Vector4(34, 18, 44, 18)
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pill)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_child(row)

	_hand = _Hand.new()
	_hand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_hand)

	var l := Label.new()
	l.text = "Tap and start coloring"
	l.add_theme_font_size_override("font_size", 36)
	l.add_theme_font_override("font", AppTheme.font(700))
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.94))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)

	_pill.resized.connect(_recenter)
	_recenter()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6).set_delay(0.9)


func _recenter() -> void:
	custom_minimum_size = _pill.size
	size = _pill.size


func _process(delta: float) -> void:
	if _dismissed:
		return
	_t += delta
	_pill.position.y = sin(_t * 2.1) * 7.0
	_hand.tap = fposmod(_t * 0.62, 1.0)
	_hand.queue_redraw()


func dismiss() -> void:
	if _dismissed:
		return
	_dismissed = true
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 0.35)
	t.tween_property(_pill, "position:y", 40.0, 0.35)
	t.chain().tween_callback(queue_free)
