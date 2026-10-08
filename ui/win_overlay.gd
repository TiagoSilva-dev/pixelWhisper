class_name WinOverlay
extends Modal
## Shown when the last cell is painted: the finished art in a frame, the coin reward, and what to
## do next (next picture, save the image, watch the time-lapse, go home).

signal next_pressed
signal home_pressed
signal save_pressed
signal timelapse_pressed


func present(level: PixelLevel, coins_awarded: int, has_next: bool, can_replay: bool = true) -> void:
	dismiss_on_outside_tap = false
	card.custom_minimum_size.x = 940.0

	var title := Label.new()
	title.text = "Beautiful!"
	title.add_theme_font_size_override("font_size", 92)
	title.add_theme_font_override("font", AppTheme.font(900))
	title.add_theme_color_override("font_color", AppTheme.PINK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var frame := CandyPanel.new(AppTheme.SURFACE_DIM, 40)
	frame.padding = Vector4(14, 14, 14, 14)
	frame.shadow = 12
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(frame)
	var art := RoundedTexture.new()
	art.radius = 28.0
	art.texture = ImageTexture.create_from_image(level.build_target_image())
	var side := art_side(700.0)
	art.custom_minimum_size = Vector2(side, side)
	frame.add_child(art)

	var name_label := Label.new()
	name_label.text = level.title if level.title != "" else "Beautiful!"
	name_label.theme_type_variation = &"HeadingLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)

	if coins_awarded > 0:
		var chip := CandyPanel.new(Color("fff4cf"), 44)
		chip.border_color = Color("f4d880")
		chip.padding = Vector4(26, 10, 34, 10)
		chip.shadow = 0
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(chip)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		chip.add_child(row)
		var coin := Control.new()
		coin.custom_minimum_size = Vector2(52, 52)
		coin.draw.connect(func() -> void: Icons.draw(coin, Icons.Kind.COIN, coin.size * 0.5, 23.0))
		row.add_child(coin)
		var l := Label.new()
		l.text = "+%d" % coins_awarded
		l.add_theme_color_override("font_color", Color("9a6410"))
		l.add_theme_font_override("font", AppTheme.font(900))
		l.add_theme_font_size_override("font_size", 44)
		row.add_child(l)

	if has_next:
		var next := Button.new()
		next.text = "Next picture"
		next.theme_type_variation = &"PrimaryButton"
		next.pressed.connect(func() -> void: next_pressed.emit())
		UiFx.press_juice(next)
		content.add_child(next)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 20)
	content.add_child(row2)
	row2.add_child(_ghost("Save image", func() -> void: save_pressed.emit()))
	if can_replay:
		row2.add_child(_ghost("Time-lapse", func() -> void: timelapse_pressed.emit()))
	content.add_child(_ghost("Home", func() -> void: home_pressed.emit()))


func _ghost(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"GhostButton"
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 38)
	b.pressed.connect(on_press)
	UiFx.press_juice(b)
	return b
