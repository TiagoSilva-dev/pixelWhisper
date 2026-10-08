class_name GalleryPage
extends Control
## "Home" tab: the header (logo, coins, settings), the category carousel and the grid of cards.

signal level_chosen(level_id: String)
signal settings_requested
signal shop_requested

var category: StringName = Categories.ALL

var _grid: GridContainer
var _hero_holder: VBoxContainer
var _scroll: ScrollContainer
var _bar: CategoryBar
var _cards: Array[LevelCard] = []
var _build_id: int = 0   ## bumps on every rebuild so a stale animation callback can tell


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	margin.add_theme_constant_override("margin_top", 26)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	# --- header ---------------------------------------------------------------------------
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	col.add_child(header)
	var logo := GradientTitle.new()
	logo.font_size = 80
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(logo)
	var coins := CoinPill.new()
	coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coins.pressed.connect(func() -> void: shop_requested.emit())
	header.add_child(coins)
	var gear := CandyButton.new(Icons.Kind.GEAR, "", Color("ff6b4a"))
	gear.custom_minimum_size = Vector2(104, 104)
	gear.radius = 32.0
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gear.pressed.connect(func() -> void: settings_requested.emit())
	header.add_child(gear)

	# --- categories ---------------------------------------------------------------------------
	_bar = CategoryBar.new()
	col.add_child(_bar)
	_bar.setup(category)
	_bar.changed.connect(_set_category)

	# --- grid -----------------------------------------------------------------------------------
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	var inset := MarginContainer.new()
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_theme_constant_override("margin_left", 6)
	inset.add_theme_constant_override("margin_right", 6)
	inset.add_theme_constant_override("margin_top", 6)
	inset.add_theme_constant_override("margin_bottom", 40)
	_scroll.add_child(inset)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 28)
	inset.add_child(content)
	_hero_holder = VBoxContainer.new()
	content.add_child(_hero_holder)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 28)
	_grid.add_theme_constant_override("v_separation", 28)
	content.add_child(_grid)

	_rebuild()


func select_category(id: StringName) -> void:
	_bar.select(id)
	_set_category(id)


func _set_category(id: StringName) -> void:
	if id == category:
		return
	category = id
	_scroll.scroll_vertical = 0
	_rebuild()


func _rebuild() -> void:
	_build_id += 1
	for c in _grid.get_children():
		c.queue_free()
	for c in _hero_holder.get_children():
		c.queue_free()
	_cards.clear()

	# "Continue": the last picture played if unfinished, otherwise any started one.
	var hero: ContinueCard = null
	if category == Categories.ALL:
		var resume := _resume_candidate()
		if resume != "":
			hero = ContinueCard.new()
			_hero_holder.add_child(hero)
			hero.setup(LevelLibrary.get_entry(resume), LevelLibrary.get_level(resume))
			hero.chosen.connect(func(id: String) -> void: level_chosen.emit(id))

	for e in LevelLibrary.entries_in(category):
		var level := LevelLibrary.get_level(e.id)
		if level == null:
			continue
		var card := LevelCard.new()
		_grid.add_child(card)
		card.setup(e, level)
		card.chosen.connect(func(id: String) -> void: level_chosen.emit(id))
		_cards.append(card)

	if _cards.is_empty():
		_grid.columns = 1
		var empty := Label.new()
		empty.text = "Anime pictures are coming soon" if category == &"anime" else "Nothing here yet"
		empty.theme_type_variation = &"DimLabel"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(900, 300)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_grid.add_child(empty)
	else:
		_grid.columns = 2

	# Wait for the grid to lay out so pivots/positions are right, then animate in.
	var my_build := _build_id
	await get_tree().process_frame
	await get_tree().process_frame
	if my_build != _build_id:
		return
	for i in _cards.size():
		if is_instance_valid(_cards[i]):
			_cards[i].play_entry(i * 0.04)


func _resume_candidate() -> String:
	var last := GameState.last_level_id
	if last != "" and GameState.has_started(last) and not GameState.is_completed(last) \
			and LevelLibrary.index_of(last) != -1 and GameState.ratio(last) < 1.0:
		return last
	for e in LevelLibrary.entries:
		if GameState.has_started(e.id) and not GameState.is_completed(e.id) and GameState.ratio(e.id) < 1.0:
			return e.id
	return ""
