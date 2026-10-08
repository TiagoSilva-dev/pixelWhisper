extends Control
## Gallery. The grid scrolls UNDER a frosted-glass header (real backdrop blur), cards react to
## their scroll position (bright and full-size near the top, dimmer/smaller further down) and
## ease in with a light sweep.

signal level_chosen(level_id: String)

const FILTER_ITEMS := [
	{"key": "all", "text": "All"},
	{"key": "progress", "text": "In progress"},
	{"key": "done", "text": "Completed"},
]
const FOCUS_START := 0.34   ## fraction of the view height where cards start to recede
const FOCUS_SPAN := 0.62

@onready var scroll: ScrollContainer = %Scroll
@onready var scroll_margin: MarginContainer = %ScrollMargin
@onready var grid: GridContainer = %Grid
@onready var continue_holder: VBoxContainer = %ContinueHolder
@onready var header_block: MarginContainer = %HeaderBlock
@onready var filters: GlassSegmented = %Filters
@onready var coin_button: IconButton = %CoinButton
@onready var settings_button: IconButton = %SettingsButton
@onready var hint_holder: CenterContainer = %HintHolder

var _filter: String = "all"
var _cards: Array[LevelCard] = []
var _hint: HintPill
var _modal: Modal


func _ready() -> void:
	settings_button.pressed.connect(func() -> void: _open_modal(SettingsModal.new()))
	coin_button.pressed.connect(func() -> void:
		UiFx.toast(self, tr("Finish a picture to earn a magic wand"), 2.2))
	GameState.wallet_changed.connect(_refresh_wallet)
	_refresh_wallet()

	filters.setup(FILTER_ITEMS, _filter)
	filters.selected.connect(_set_filter)

	header_block.resized.connect(_update_inset)
	scroll.get_v_scroll_bar().value_changed.connect(_on_scrolled)
	resized.connect(_update_focus)

	if not GameState.hint_seen:
		_hint = HintPill.new()
		hint_holder.add_child(_hint)

	_rebuild()
	_update_inset.call_deferred()


func handle_back() -> bool:
	if is_instance_valid(_modal):
		_modal.close()
		return true
	return false  # let Main quit the app


func _refresh_wallet() -> void:
	coin_button.badge = str(GameState.wands)
	coin_button.pop()


func _update_inset() -> void:
	# Content starts below the header block; it scrolls up beneath it.
	scroll_margin.add_theme_constant_override("margin_top", int(header_block.size.y) + 34)


func _set_filter(key: String) -> void:
	if key == _filter:
		return
	_filter = key
	_rebuild()


func _matches(level_id: String) -> bool:
	match _filter:
		"progress": return GameState.has_started(level_id) and not GameState.is_completed(level_id)
		"done": return GameState.is_completed(level_id)
		_: return true


func _rebuild() -> void:
	for c in grid.get_children():
		c.queue_free()
	for c in continue_holder.get_children():
		c.queue_free()
	_cards.clear()

	# "Continue": the last picture played if unfinished, otherwise any started one.
	var hero: ContinueCard = null
	if _filter == "all":
		var resume := _resume_candidate()
		if resume != "":
			hero = ContinueCard.new()
			continue_holder.add_child(hero)
			hero.setup(LevelLibrary.get_entry(resume), LevelLibrary.get_level(resume))
			hero.chosen.connect(_on_chosen)

	for e in LevelLibrary.entries:
		if not _matches(e.id):
			continue
		var level := LevelLibrary.get_level(e.id)
		if level == null:
			continue
		var card := LevelCard.new()
		grid.add_child(card)
		card.setup(e, level)
		card.chosen.connect(_on_chosen)
		_cards.append(card)

	if _cards.is_empty() and hero == null:
		var empty := Label.new()
		empty.text = "Nothing here yet"
		empty.theme_type_variation = &"DimLabel"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(empty)

	# Wait for the grid to lay out so pivots/positions are right, then animate in.
	await get_tree().process_frame
	await get_tree().process_frame
	if hero and is_instance_valid(hero):
		hero.play_sheen(1.1)
	for i in _cards.size():
		if is_instance_valid(_cards[i]):
			_cards[i].play_entry(i * 0.045)
	_update_focus()


func _on_scrolled(v: float) -> void:
	_update_focus()
	get_tree().call_group(&"aurora", "set_parallax", v / maxf(size.y, 1.0))
	if scroll.scroll_vertical > 30:
		_dismiss_hint()


## Cards near the top are bright and full-size; the further down, the dimmer and smaller.
func _update_focus() -> void:
	var h := scroll.size.y
	if h <= 1.0:
		return
	var top := scroll.global_position.y
	for c in _cards:
		if not is_instance_valid(c):
			continue
		var n := (c.global_position.y + c.size.y * 0.5 - top) / h
		c.set_focus(clampf((n - FOCUS_START) / FOCUS_SPAN, 0.0, 1.0))


func _on_chosen(level_id: String) -> void:
	_dismiss_hint()
	level_chosen.emit(level_id)


func _dismiss_hint() -> void:
	if _hint != null and is_instance_valid(_hint):
		_hint.dismiss()
		_hint = null
		GameState.set_setting(&"hint_seen", true)


func _resume_candidate() -> String:
	var last := GameState.last_level_id
	if last != "" and GameState.has_started(last) and not GameState.is_completed(last) \
			and LevelLibrary.index_of(last) != -1 and GameState.ratio(last) < 1.0:
		return last
	for e in LevelLibrary.entries:
		if GameState.has_started(e.id) and not GameState.is_completed(e.id) and GameState.ratio(e.id) < 1.0:
			return e.id
	return ""


func _open_modal(m: Modal) -> void:
	_modal = m
	add_child(m)
