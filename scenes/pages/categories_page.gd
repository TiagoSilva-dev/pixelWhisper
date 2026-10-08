class_name CategoriesPage
extends Control
## "Categories" tab: "Explore Categories", a search box, and a big colored tile per category
## (plus "All pictures"). Typing in the box swaps the tiles for matching pictures.

signal category_chosen(category: StringName)
signal level_chosen(level_id: String)

var _tiles: GridContainer
var _results: GridContainer
var _search: LineEdit
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	margin.add_theme_constant_override("margin_top", 40)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	margin.add_child(col)

	var title := Label.new()
	title.text = "Explore Categories"
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 66)
	col.add_child(title)

	_search = LineEdit.new()
	_search.placeholder_text = "Search"
	_search.clear_button_enabled = true
	_search.add_theme_stylebox_override("normal", AppTheme.box(AppTheme.SURFACE, 44, Vector4(44, 22, 44, 22), 4, AppTheme.STROKE))
	_search.add_theme_stylebox_override("focus", AppTheme.box(AppTheme.SURFACE, 44, Vector4(44, 22, 44, 22), 4, AppTheme.PURPLE))
	_search.text_changed.connect(_on_search)
	col.add_child(_search)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	var inset := MarginContainer.new()
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_theme_constant_override("margin_left", 6)
	inset.add_theme_constant_override("margin_right", 6)
	inset.add_theme_constant_override("margin_top", 8)
	inset.add_theme_constant_override("margin_bottom", 40)
	_scroll.add_child(inset)
	var stack := VBoxContainer.new()
	inset.add_child(stack)

	_tiles = GridContainer.new()
	_tiles.columns = 2
	_tiles.add_theme_constant_override("h_separation", 26)
	_tiles.add_theme_constant_override("v_separation", 30)
	stack.add_child(_tiles)
	_results = GridContainer.new()
	_results.columns = 2
	_results.add_theme_constant_override("h_separation", 28)
	_results.add_theme_constant_override("v_separation", 28)
	_results.visible = false
	stack.add_child(_results)

	for c in Categories.list():
		_add_tile(c.id, c.icon, c.title, c.color)
	_add_tile(Categories.ALL, Icons.Kind.STACK, "All pictures", AppTheme.PINK)


func _add_tile(id: StringName, icon: Icons.Kind, title: String, color: Color) -> void:
	var tile := CategoryCard.new(icon, title, color, LevelLibrary.entries_in(id).size())
	tile.pressed.connect(func() -> void: category_chosen.emit(id))
	_tiles.add_child(tile)


func _on_search(text: String) -> void:
	var q := text.strip_edges().to_lower()
	_tiles.visible = q == ""
	_results.visible = q != ""
	for c in _results.get_children():
		c.queue_free()
	if q == "":
		return
	var found := 0
	for e in LevelLibrary.entries:
		var names := [tr(e.title).to_lower(), String(e.title).to_lower(), tr(String(e.category).capitalize()).to_lower()]
		var hit := false
		for n in names:
			if (n as String).contains(q):
				hit = true
		if not hit:
			continue
		var level := LevelLibrary.get_level(e.id)
		if level == null:
			continue
		var card := LevelCard.new()
		_results.add_child(card)
		card.setup(e, level)
		card.chosen.connect(func(id: String) -> void: level_chosen.emit(id))
		found += 1
	if found == 0:
		var none := Label.new()
		none.text = "Nothing here yet"
		none.theme_type_variation = &"DimLabel"
		_results.add_child(none)
