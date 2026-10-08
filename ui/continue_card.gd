class_name ContinueCard
extends GlassPanel
## Wide "pick up where you left off" glass card shown above the gallery grid.

signal chosen(level_id: String)

var level_id: String = ""


func _init() -> void:
	super(Glass.Style.PANEL, false)
	padding = Vector4(22, 22, 36, 22)


func setup(entry: Dictionary, level: PixelLevel) -> void:
	level_id = entry.id

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	add_child(row)

	var thumb := RoundedTexture.new()
	thumb.radius = 30.0
	thumb.custom_minimum_size = Vector2(290, 290)
	var painted := GameState.get_painted(level_id, level.cell_count())
	thumb.texture = ImageTexture.create_from_image(level.build_progress_image(painted))
	row.add_child(thumb)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	row.add_child(col)

	var cap := Label.new()
	cap.text = "Continue"
	cap.theme_type_variation = &"CaptionLabel"
	cap.add_theme_color_override("font_color", AppTheme.ACCENT)
	col.add_child(cap)

	var title := Label.new()
	title.text = entry.title
	title.theme_type_variation = &"HeadingLabel"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 16)
	col.add_child(bar_row)
	var bar := GlassProgress.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(bar)
	bar.set_value(GameState.ratio(level_id))
	var pct := Label.new()
	pct.theme_type_variation = &"CaptionLabel"
	pct.text = "%d%%" % int(round(GameState.ratio(level_id) * 100.0))
	bar_row.add_child(pct)

	var play := Button.new()
	play.text = "Play"
	play.theme_type_variation = &"PrimaryButton"
	play.pressed.connect(func() -> void: chosen.emit(level_id))
	UiFx.press_juice(play)
	col.add_child(play)
