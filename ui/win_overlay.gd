class_name WinOverlay
extends Modal
## Shown when the last cell is painted: the finished art in a glass frame, the reward, and what
## to do next.

signal next_pressed
signal home_pressed
signal save_pressed


func present(level: PixelLevel, wand_awarded: bool, has_next: bool) -> void:
	dismiss_on_outside_tap = false
	card.custom_minimum_size.x = 940.0

	var title := GlowLabel.new()
	title.text = "Beautiful!"
	title.font_size = 92
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(title)

	var frame := GlassPanel.new(Glass.Style.CARD, false)
	frame.padding = Vector4(14, 14, 14, 14)
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

	if wand_awarded:
		var chip := GlassPanel.new(Glass.Style.PILL, false)
		chip.padding = Vector4(30, 10, 30, 10)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(chip)
		var l := Label.new()
		l.text = "+1 " + tr("Magic wand")
		l.add_theme_color_override("font_color", AppTheme.AMBER)
		l.add_theme_font_size_override("font_size", 34)
		chip.add_child(l)

	if has_next:
		var next := Button.new()
		next.text = "Next picture"
		next.theme_type_variation = &"PrimaryButton"
		next.pressed.connect(func() -> void: next_pressed.emit())
		UiFx.press_juice(next)
		content.add_child(next)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	content.add_child(row)
	var save := Button.new()
	save.text = "Save image"
	save.theme_type_variation = &"GhostButton"
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(func() -> void: save_pressed.emit())
	UiFx.press_juice(save)
	row.add_child(save)
	var home := Button.new()
	home.text = "Home"
	home.theme_type_variation = &"GhostButton"
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.pressed.connect(func() -> void: home_pressed.emit())
	UiFx.press_juice(home)
	row.add_child(home)
