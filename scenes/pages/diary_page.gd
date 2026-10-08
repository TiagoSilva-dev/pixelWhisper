class_name DiaryPage
extends Control
## "Diary" tab: a month calendar with the days you painted highlighted, your streak, and your
## pictures grouped into "In progress" and "Completed".

signal level_chosen(level_id: String)

const MONTHS: Array[String] = ["January", "February", "March", "April", "May", "June", "July",
		"August", "September", "October", "November", "December"]
const WEEKDAYS: Array[String] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

var _month_offset: int = 0
var _content: VBoxContainer


## One calendar day: a filled green disc if you painted that day, a pink ring for today.
class DayCell extends Control:
	var day: int = 0
	var painted: bool = false
	var today: bool = false

	func _init(p_day: int, p_painted: bool, p_today: bool) -> void:
		day = p_day
		painted = p_painted
		today = p_today
		custom_minimum_size = Vector2(0, 92)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		if painted:
			draw_circle(c + Vector2(0, 3), r, AppTheme.lip(AppTheme.GREEN), true, -1.0, true)
			draw_circle(c, r, AppTheme.GREEN, true, -1.0, true)
		if today:
			draw_arc(c, r + 4.0, 0.0, TAU, 40, AppTheme.PINK, 5.0, true)
		var f := AppTheme.font(900 if (painted or today) else 700)
		var t := str(day)
		var fs := 34
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(c.x - tw * 0.5, c.y + f.get_ascent(fs) * 0.5 - 4.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color.WHITE if painted else AppTheme.INK)


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


## Called by the hub every time the tab is shown, so the diary is never stale.
func activate() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in _content.get_children():
		c.queue_free()

	# --- title + streak ---------------------------------------------------------------------
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	_content.add_child(head)
	var title := Label.new()
	title.text = "Diary"
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 66)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var streak := CandyPanel.new(AppTheme.SURFACE, 44)
	streak.padding = Vector4(18, 8, 26, 8)
	streak.shadow = 10
	streak.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(streak)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 10)
	streak.add_child(srow)
	srow.add_child(_icon_box(Icons.Kind.FLAME, 56))
	var sl := Label.new()
	sl.text = str(GameState.streak_days())
	sl.add_theme_font_override("font", AppTheme.font(900))
	sl.add_theme_font_size_override("font_size", 44)
	srow.add_child(sl)

	_content.add_child(_calendar())

	# --- pictures ---------------------------------------------------------------------------------
	var in_progress: Array[Dictionary] = []
	var done: Array[Dictionary] = []
	for e in LevelLibrary.entries:
		if GameState.is_completed(e.id):
			done.append(e)
		elif GameState.has_started(e.id):
			in_progress.append(e)
	_section("In progress", in_progress)
	_section("Completed", done)
	if in_progress.is_empty() and done.is_empty():
		var hint := Label.new()
		hint.text = "Paint something to start your diary"
		hint.theme_type_variation = &"DimLabel"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(hint)


func _section(heading: String, entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	var l := Label.new()
	l.text = heading
	l.theme_type_variation = &"HeadingLabel"
	_content.add_child(l)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 28)
	_content.add_child(grid)
	for e in entries:
		var level := LevelLibrary.get_level(e.id)
		if level == null:
			continue
		var card := LevelCard.new()
		grid.add_child(card)
		card.setup(e, level)
		card.chosen.connect(func(id: String) -> void: level_chosen.emit(id))


func _calendar() -> Control:
	var info := _month_info(_month_offset)
	var card := CandyPanel.new(AppTheme.SURFACE, 44)
	card.padding = Vector4(24, 22, 24, 26)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var nav := HBoxContainer.new()
	v.add_child(nav)
	var prev := CandyButton.new(Icons.Kind.BACK, "", AppTheme.BLUE)
	prev.custom_minimum_size = Vector2(92, 92)
	prev.pressed.connect(_shift_month.bind(-1))
	nav.add_child(prev)
	var name_label := Label.new()
	name_label.text = "%s %d" % [tr(MONTHS[info.month - 1]), info.year]
	name_label.theme_type_variation = &"HeadingLabel"
	name_label.add_theme_font_size_override("font_size", 46)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav.add_child(name_label)
	var next := CandyButton.new(Icons.Kind.NEXT, "", AppTheme.BLUE)
	next.custom_minimum_size = Vector2(92, 92)
	next.pressed.connect(_shift_month.bind(1))
	nav.add_child(next)

	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for wd in WEEKDAYS:
		var l := Label.new()
		l.text = wd
		l.theme_type_variation = &"CaptionLabel"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
	for i in info.first_weekday:
		var gap := Control.new()
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(gap)
	var today := GameState.today()
	for d in range(1, info.days + 1):
		var key := "%04d-%02d-%02d" % [info.year, info.month, d]
		grid.add_child(DayCell.new(d, GameState.has_activity_on(key), key == today))
	return card


func _shift_month(delta: int) -> void:
	_month_offset = clampi(_month_offset + delta, -24, 0)
	_rebuild()


## {year, month (1-12), first_weekday (0 = Sunday), days} of the month `offset` months from now.
func _month_info(offset: int) -> Dictionary:
	var now := Time.get_datetime_dict_from_system(false)
	var index: int = now.year * 12 + (now.month - 1) + offset
	var y := index / 12
	var m := index % 12 + 1
	var first := Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var leap := (y % 4 == 0 and y % 100 != 0) or y % 400 == 0
	var lengths := [31, 29 if leap else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return {
		"year": y, "month": m,
		"first_weekday": Time.get_datetime_dict_from_unix_time(int(first)).weekday,
		"days": lengths[m - 1],
	}


func _icon_box(kind: Icons.Kind, px: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: Icons.draw(c, kind, c.size * 0.5, px * 0.44))
	return c
