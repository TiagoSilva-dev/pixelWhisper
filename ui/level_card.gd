class_name LevelCard
extends GlassPanel
## Gallery card in frosted glass: live thumbnail of the player's progress, title, progress bar
## and color count. Two motion layers drive its look:
##   * entry  - eases in (scale + fade + light sweep) when the gallery builds,
##   * focus  - the gallery sets how far the card is from the "focus line" while scrolling;
##              cards near the top are bright and full size, cards far below dim and shrink.

signal chosen(level_id: String)

const TAP_SLOP := 28.0

var level_id: String = ""

var _thumb: RoundedTexture
var _bar: GlassProgress
var _pct: Label
var _check: Control
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _entry: float = 1.0
var _focus: float = 0.0        ## 0 = at the focus line, 1 = far away
var _press_scale: float = 1.0
var _tween: Tween


func _init() -> void:
	super(Glass.Style.CARD, false)
	padding = Vector4(16, 16, 16, 26)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func setup(entry: Dictionary, level: PixelLevel) -> void:
	level_id = entry.id
	resized.connect(func() -> void: pivot_offset = size * 0.5)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	_thumb = RoundedTexture.new()
	_thumb.radius = 26.0
	_thumb.custom_minimum_size = Vector2(0, 200)
	_thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_thumb)
	_thumb.resized.connect(func() -> void:
		# Keep the thumbnail square: height follows the width the grid gives us.
		if absf(_thumb.custom_minimum_size.y - _thumb.size.x) > 0.5:
			_thumb.custom_minimum_size.y = _thumb.size.x)

	_check = Control.new()
	_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_check.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_check.offset_left = -88.0
	_check.offset_top = 14.0
	_check.offset_right = -14.0
	_check.offset_bottom = 88.0
	_check.draw.connect(_draw_check)
	_thumb.add_child(_check)

	var title := Label.new()
	title.text = entry.title  # an English key: the Label retranslates itself live
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_font_override("font", AppTheme.font(800))
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.97))
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)

	var lbl := Label.new()
	lbl.text = "Progress"
	lbl.theme_type_variation = &"CaptionLabel"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	_bar = GlassProgress.new()
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_bar)

	_pct = Label.new()
	_pct.theme_type_variation = &"CaptionLabel"
	_pct.custom_minimum_size.x = 76
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pct.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_pct)

	var meta := Label.new()
	meta.theme_type_variation = &"CaptionLabel"
	meta.text = tr("%d colors") % level.palette.size()
	meta.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(meta)

	refresh(level)


## Rebuilds the thumbnail and progress from the saved state.
func refresh(level: PixelLevel) -> void:
	var painted := GameState.get_painted(level_id, level.cell_count())
	var ratio := GameState.ratio(level_id)
	var done := GameState.is_completed(level_id)
	# Untouched and finished pictures show their real colors (an enticing gallery); only
	# pictures in progress show the "painted so far" view.
	var img := level.build_target_image() if (done or ratio <= 0.0) else level.build_progress_image(painted)
	_thumb.texture = ImageTexture.create_from_image(img)
	var shown := 1.0 if done else ratio
	_bar.set_value(shown)
	_pct.text = "%d%%" % int(round(shown * 100.0))
	_check.visible = done
	_check.queue_redraw()


# -- motion ---------------------------------------------------------------------------------

## Eases the card in. Call after the gallery has laid out (so the pivot is correct).
func play_entry(delay: float = 0.0) -> void:
	_entry = 0.0
	_apply_visual()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(delay)
	_tween.tween_method(func(v: float) -> void:
		_entry = v
		_apply_visual(), 0.0, 1.0, 0.55)
	_tween.tween_callback(play_sheen.bind(1.0))


## 0 = right at the focus line (bright, full size), 1 = far from it (dim, smaller).
func set_focus(f: float) -> void:
	if absf(f - _focus) < 0.002:
		return
	_focus = f
	_apply_visual()


func _apply_visual() -> void:
	var bright := lerpf(1.0, 0.56, smoothstep(0.0, 1.0, _focus))
	var a := clampf(_entry * 1.4, 0.0, 1.0)
	modulate = Color(bright, bright, bright, a)
	var s := lerpf(1.0, 0.955, smoothstep(0.0, 1.0, _focus)) * lerpf(0.88, 1.0, _entry) * _press_scale
	scale = Vector2.ONE * s


func _draw_check() -> void:
	var c := _check.size * 0.5
	var r := minf(_check.size.x, _check.size.y) * 0.5
	_check.draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.3), true, -1.0, true)
	_check.draw_circle(c, r, AppTheme.MINT, true, -1.0, true)
	_check.draw_arc(c, r - 2.0, PI * 1.1, PI * 1.7, 12, Color(1, 1, 1, 0.55), 3.0, true)
	var u := r * 0.42
	_check.draw_polyline(PackedVector2Array([c + Vector2(-0.9, 0.05) * u, c + Vector2(-0.3, 0.7) * u, c + Vector2(0.95, -0.7) * u]),
			Color("0c2b26"), 7.0, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
			_press_to(0.965, 0.08)
			set_press(1.0)
		else:
			_press_to(1.0, 0.26, true)
			set_press(0.0)
			if _pressing and event.position.distance_to(_press_pos) < TAP_SLOP:
				Feedback.tick()
				play_sheen(0.6)
				chosen.emit(level_id)
			_pressing = false


func _press_to(target: float, duration: float, bouncy: bool = false) -> void:
	var from := _press_scale
	var t := create_tween().set_trans(Tween.TRANS_BACK if bouncy else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float) -> void:
		_press_scale = v
		_apply_visual(), from, target, duration)
