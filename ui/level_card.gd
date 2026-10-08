class_name LevelCard
extends CandyPanel
## Gallery card: the picture on a vivid color, and under it a colored strip with the title, the
## progress bar with its % and the number of colors. The thumbnail shows the player's progress
## (or the finished/untouched picture in full color).
##
## Motion: it eases in (scale + fade) when the gallery builds and squishes when pressed.

signal chosen(level_id: String)

const TAP_SLOP := 28.0

var level_id: String = ""

var _thumb: RoundedTexture
var _bar: CandyProgress
var _pct: Label
var _meta: Label
var _color_count: int = 0
var _badges: Control
var _done: bool = false
var _premium: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _tween: Tween


func _init() -> void:
	super(AppTheme.SURFACE, 44)
	padding = Vector4(8, 8, 8, 8)
	shadow = 18
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func setup(entry: Dictionary, level: PixelLevel) -> void:
	level_id = entry.id
	_premium = entry.get("premium", false)
	resized.connect(func() -> void: pivot_offset = size * 0.5)

	var h: int = absi(level_id.hash())
	var back: Color = AppTheme.CARD_BACKS[h % AppTheme.CARD_BACKS.size()]
	var strip: Color = AppTheme.CARD_STRIPS[(h / 8) % AppTheme.CARD_STRIPS.size()]

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	# --- picture on a vivid background ---------------------------------------------------
	var top := PanelContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", _strip_box(back, true))
	col.add_child(top)
	_thumb = RoundedTexture.new()
	_thumb.radius = 22.0
	_thumb.custom_minimum_size = Vector2(0, 200)
	_thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_thumb)
	_thumb.resized.connect(func() -> void:
		# Keep the thumbnail square: height follows the width the grid gives us.
		if absf(_thumb.custom_minimum_size.y - _thumb.size.x) > 0.5:
			_thumb.custom_minimum_size.y = _thumb.size.x)

	_badges = Control.new()
	_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badges.set_anchors_preset(Control.PRESET_FULL_RECT)
	_badges.draw.connect(_draw_badges)
	_thumb.add_child(_badges)

	# --- info strip ------------------------------------------------------------------------
	var info := PanelContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_stylebox_override("panel", _strip_box(strip, false))
	col.add_child(info)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(v)

	var title := Label.new()
	title.text = entry.title  # an English key: the Label retranslates itself live
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_font_override("font", AppTheme.font(900))
	title.add_theme_color_override("font_color", Color.WHITE)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	row.add_child(_small_label("Progress"))
	_bar = CandyProgress.new()
	_bar.bar_height = 16.0
	_bar.track_color = Color(0, 0, 0, 0.26)
	_bar.fill_color = Color.WHITE
	_bar.fill_done_color = AppTheme.YELLOW
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_bar)
	_pct = _small_label("0%")
	_pct.custom_minimum_size.x = 70
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_pct)

	_meta = _small_label("")
	_color_count = level.palette.size()
	_meta.text = tr("%d colors") % _color_count
	v.add_child(_meta)

	refresh(level)


func _notification(what: int) -> void:
	# "%d colors" is a format string, so it can't retranslate by itself like a plain key does.
	if what == NOTIFICATION_TRANSLATION_CHANGED and _meta != null:
		_meta.text = tr("%d colors") % _color_count


func _small_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_font_override("font", AppTheme.font(800))
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _strip_box(color: Color, is_top: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.anti_aliasing = true
	var r := 34
	if is_top:
		sb.corner_radius_top_left = r
		sb.corner_radius_top_right = r
		sb.set_content_margin_all(16)
	else:
		sb.corner_radius_bottom_left = r
		sb.corner_radius_bottom_right = r
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		sb.content_margin_top = 14
		sb.content_margin_bottom = 16
	return sb


## Rebuilds the thumbnail and progress from the saved state.
func refresh(level: PixelLevel) -> void:
	var painted := GameState.get_painted(level_id, level.cell_count())
	var ratio := GameState.ratio(level_id)
	_done = GameState.is_completed(level_id)
	# Untouched and finished pictures show their real colors (an enticing gallery); only
	# pictures in progress show the "painted so far" view.
	var img := level.build_target_image() if (_done or ratio <= 0.0) else level.build_progress_image(painted)
	_thumb.texture = ImageTexture.create_from_image(img)
	var shown := 1.0 if _done else ratio
	_bar.set_value(shown)
	_pct.text = "%d%%" % int(round(shown * 100.0))
	_badges.queue_redraw()


func _draw_badges() -> void:
	var s := _badges.size
	if _done:
		var r := 34.0
		var c := Vector2(s.x - r - 12.0, r + 12.0)
		_badges.draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.22), true, -1.0, true)
		_badges.draw_circle(c, r, Color.WHITE, true, -1.0, true)
		_badges.draw_circle(c, r - 5.0, AppTheme.GREEN, true, -1.0, true)
		Icons.draw(_badges, Icons.Kind.CHECK, c, r * 0.46, Color.WHITE)
	if _premium:
		var r2 := 30.0
		var c2 := Vector2(r2 + 12.0, r2 + 12.0)
		_badges.draw_circle(c2 + Vector2(0, 3), r2, Color(0, 0, 0, 0.22), true, -1.0, true)
		_badges.draw_circle(c2, r2, Color.WHITE, true, -1.0, true)
		Icons.draw(_badges, Icons.Kind.DIAMOND, c2, r2 * 0.6)


# -- motion ---------------------------------------------------------------------------------

## Eases the card in. Call after the gallery has laid out (so the pivot is correct).
func play_entry(delay: float = 0.0) -> void:
	pivot_offset = size * 0.5
	scale = Vector2.ONE * 0.88
	modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_delay(delay)
	_tween.tween_property(self, "modulate:a", 1.0, 0.3).set_delay(delay).set_trans(Tween.TRANS_LINEAR)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
			_press_to(0.965, 0.08, false)
		else:
			_press_to(1.0, 0.26, true)
			if _pressing and event.position.distance_to(_press_pos) < TAP_SLOP:
				Feedback.tick()
				chosen.emit(level_id)
			_pressing = false
	elif event is InputEventMouseMotion and _pressing and event.position.distance_to(_press_pos) > TAP_SLOP * 2.0:
		_pressing = false
		_press_to(1.0, 0.2, false)


func _press_to(target: float, duration: float, bouncy: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK if bouncy else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * target, duration)
