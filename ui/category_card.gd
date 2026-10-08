class_name CategoryCard
extends Control
## A big colored tile of the "Explore Categories" page: large icon, name and picture count.

signal pressed

const TAP_SLOP := 28.0

var color: Color = AppTheme.PURPLE
var icon: Icons.Kind = Icons.Kind.STAR
var title: String = ""
var count: int = 0

var _press_pos: Vector2 = Vector2.ZERO
var _down: bool = false
var _tween: Tween


func _init(p_icon: Icons.Kind, p_title: String, p_color: Color, p_count: int) -> void:
	icon = p_icon
	title = p_title
	color = p_color
	count = p_count
	custom_minimum_size = Vector2(0, 290)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _draw() -> void:
	var lip := 10.0
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(44)
	sb.anti_aliasing = true
	sb.bg_color = AppTheme.lip(color)
	sb.shadow_color = AppTheme.SHADOW
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 6)
	draw_style_box(sb, Rect2(0, lip, size.x, size.y - lip))
	sb.shadow_size = 0
	sb.bg_color = color
	sb.set_border_width_all(5)
	sb.border_color = Color(1, 1, 1, 0.85)
	var face := Rect2(0, 0, size.x, size.y - lip)
	draw_style_box(sb, face)
	var gloss := StyleBoxFlat.new()
	gloss.bg_color = Color(1, 1, 1, 0.16)
	gloss.set_corner_radius_all(30)
	gloss.anti_aliasing = true
	draw_style_box(gloss, Rect2(24, 12, size.x - 48, face.size.y * 0.3))

	var room := face.size.y - 128.0   # the space between the top border and the title
	var u := minf(minf(size.x * 0.17, 82.0), room * 0.5 / Icons.COLOR_SPAN)
	Icons.draw(self, icon, Vector2(size.x * 0.5, 20.0 + room * 0.5), u)
	var f := AppTheme.font(900)
	var t := tr(title)
	var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var cx := (size.x - tw) * 0.5
	draw_string(f, Vector2(cx, face.size.y - 62.0 + 3.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0, 0, 0, 0.18))
	draw_string(f, Vector2(cx, face.size.y - 62.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
	var sub := tr("%d pictures") % count
	var sf := AppTheme.font(800)
	var sw := sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 27).x
	draw_string(sf, Vector2((size.x - sw) * 0.5, face.size.y - 22.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color(1, 1, 1, 0.85))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_press_pos = event.position
			Feedback.tick()
			_scale_to(0.96, 0.07, false)
		elif _down:
			_down = false
			_scale_to(1.0, 0.24, true)
			if event.position.distance_to(_press_pos) < TAP_SLOP:
				pressed.emit()
	elif event is InputEventMouseMotion and _down and event.position.distance_to(_press_pos) > TAP_SLOP * 2.0:
		_down = false
		_scale_to(1.0, 0.2, false)


func _scale_to(target: float, duration: float, bouncy: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK if bouncy else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * target, duration)
