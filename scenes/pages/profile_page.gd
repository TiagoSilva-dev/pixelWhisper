class_name ProfilePage
extends Control
## "Profile" tab: your avatar, your numbers, and a shortcut to the settings.

signal settings_requested

var _content: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 50)
	scroll.add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 26)
	margin.add_child(_content)
	_rebuild()


func activate() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in _content.get_children():
		c.queue_free()

	var who := VBoxContainer.new()
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_theme_constant_override("separation", 14)
	_content.add_child(who)
	var avatar := Control.new()
	avatar.custom_minimum_size = Vector2(240, 240)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.draw.connect(func() -> void:
		avatar.draw_circle(avatar.size * 0.5 + Vector2(0, 8), 118.0, AppTheme.SHADOW, true, -1.0, true)
		avatar.draw_circle(avatar.size * 0.5, 118.0, Color.WHITE, true, -1.0, true)
		Icons.draw(avatar, Icons.Kind.USER, avatar.size * 0.5, 104.0))
	who.add_child(avatar)
	var name_label := Label.new()
	name_label.text = "Artist"
	name_label.theme_type_variation = &"TitleLabel"
	name_label.add_theme_font_size_override("font_size", 62)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_child(name_label)
	if GameState.premium:
		var chip := CandyPanel.new(Color("efe5ff"), 40)
		chip.border_color = Color("cdb8ff")
		chip.shadow = 0
		chip.padding = Vector4(22, 8, 30, 8)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		who.add_child(chip)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		chip.add_child(row)
		var gem := Control.new()
		gem.custom_minimum_size = Vector2(46, 46)
		gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gem.draw.connect(func() -> void: Icons.draw(gem, Icons.Kind.DIAMOND, gem.size * 0.5, 20.0))
		row.add_child(gem)
		var tag := Label.new()
		tag.text = "Premium member"
		tag.add_theme_font_override("font", AppTheme.font(900))
		tag.add_theme_font_size_override("font_size", 34)
		tag.add_theme_color_override("font_color", AppTheme.PURPLE)
		row.add_child(tag)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	_content.add_child(grid)
	grid.add_child(_stat(Icons.Kind.TROPHY, str(GameState.completed_count()), "Pictures finished", AppTheme.PURPLE))
	grid.add_child(_stat(Icons.Kind.BRUSH, str(GameState.total_painted()), "Pixels painted", AppTheme.ORANGE))
	grid.add_child(_stat(Icons.Kind.FLAME, str(GameState.streak_days()), "Day streak", AppTheme.RED))
	grid.add_child(_stat(Icons.Kind.COIN, str(GameState.coins), "Coins", AppTheme.YELLOW))

	var settings := CandyButton.new(Icons.Kind.GEAR, "Settings", AppTheme.BLUE)
	settings.font_size = 42
	settings.custom_minimum_size.y = 128
	settings.pressed.connect(func() -> void: settings_requested.emit())
	_content.add_child(settings)

	# MIT notices of the icon sets (full text: assets/icons/LICENSES.md)
	var credits := Label.new()
	credits.theme_type_variation = &"DimLabel"
	credits.text = "Icons: Fluent Emoji (Microsoft) and Phosphor Icons, MIT license"
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_theme_font_size_override("font_size", 28)
	_content.add_child(credits)


func _stat(kind: Icons.Kind, value: String, caption: String, accent: Color) -> Control:
	var card := CandyPanel.new(AppTheme.SURFACE, 40)
	card.padding = Vector4(20, 26, 20, 24)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.shadow = 12
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(0, 76)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		icon.draw_circle(Vector2(icon.size.x * 0.5, 38.0), 36.0, Color(accent, 0.16), true, -1.0, true)
		Icons.draw(icon, kind, Vector2(icon.size.x * 0.5, 38.0), 31.0, accent))
	v.add_child(icon)
	var n := Label.new()
	n.text = value
	n.add_theme_font_override("font", AppTheme.font(900))
	n.add_theme_font_size_override("font_size", 58)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var c := Label.new()
	c.text = caption
	c.theme_type_variation = &"CaptionLabel"
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	return card
