class_name CategoryBar
extends ScrollContainer
## The horizontal carousel of colored category pills (Popular, Animals, Drawings, Anime,
## Premium). Tapping a pill selects it; tapping the selected pill again clears the filter.

signal changed(category: StringName)   ## Categories.ALL when nothing is selected

var _pills: Dictionary = {}            ## category id -> CandyButton
var _current: StringName = Categories.ALL


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	custom_minimum_size.y = 128


func setup(current: StringName) -> void:
	_current = current
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_bottom", 14)   # room for the pills' shadow
	margin.add_theme_constant_override("margin_top", 4)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	for c in Categories.list():
		var pill := CandyButton.new(c.icon, c.title, c.color)
		pill.font_size = 36
		pill.pad_x = 30
		pill.custom_minimum_size.y = 112
		pill.selected = (c.id == current)
		pill.pressed.connect(_on_pill.bind(c.id))
		row.add_child(pill)
		_pills[c.id] = pill


func select(category: StringName) -> void:
	_current = category
	for id in _pills:
		(_pills[id] as CandyButton).selected = (id == category)


func current() -> StringName:
	return _current


func _on_pill(id: StringName) -> void:
	select(Categories.ALL if id == _current else id)
	changed.emit(_current)
