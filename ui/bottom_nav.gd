class_name BottomNav
extends CandyPanel
## The fixed five-tab bar of the hub: Home, Categories, Diary, Shop, Profile. The active tab sits
## in a soft blue rounded highlight that slides between tabs.

signal tab_selected(id: StringName)

const TABS: Array[Dictionary] = [
	{"id": &"home", "label": "Home", "icon": Icons.Kind.HOME},
	{"id": &"categories", "label": "Categories", "icon": Icons.Kind.STACK},
	{"id": &"diary", "label": "Diary", "icon": Icons.Kind.CALENDAR},
	{"id": &"shop", "label": "Shop", "icon": Icons.Kind.SHOP},
	{"id": &"profile", "label": "Profile", "icon": Icons.Kind.USER},
]

var _tabs: Array[NavTab] = []
var _current: StringName = &"home"
var _highlight: Control
var _row: HBoxContainer
var _tween: Tween


class NavTab extends Control:
	signal tapped(id: StringName)
	var id: StringName
	var label: String
	var icon: Icons.Kind
	var active: bool = false:
		set(v):
			active = v
			queue_redraw()
	var _lift: float = 0.0
	var _press_pos: Vector2 = Vector2.ZERO
	var _down: bool = false

	func _init(p_id: StringName, p_label: String, p_icon: Icons.Kind) -> void:
		id = p_id
		label = p_label
		icon = p_icon
		custom_minimum_size = Vector2(0, 132)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSLATION_CHANGED:
			queue_redraw()

	func bounce() -> void:
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
			.tween_method(func(v: float) -> void:
				_lift = v
				queue_redraw(), 1.0, 0.0, 0.42)

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 50.0)
		var lift := -12.0 * _lift
		Icons.draw(self, icon, c + Vector2(0, lift), 36.0 + (4.0 if active else 0.0), AppTheme.BLUE)
		var f := AppTheme.font(900 if active else 800)
		var t := tr(label)
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(f, Vector2((size.x - tw) * 0.5, 112.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 28,
				AppTheme.INK if active else AppTheme.INK_DIM)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_down = true
				_press_pos = event.position
			elif _down:
				_down = false
				if event.position.distance_to(_press_pos) < 30.0:
					tapped.emit(id)


func _init() -> void:
	super(AppTheme.SURFACE, 52)
	flat_bottom = true
	padding = Vector4(18, 14, 18, 10)
	shadow = 22


func _ready() -> void:
	super()
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 132)   # a plain Control reports no minimum size of its own
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_highlight = Control.new()
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.draw.connect(func() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = AppTheme.SKY_SOFT
		sb.set_corner_radius_all(36)
		sb.anti_aliasing = true
		_highlight.draw_style_box(sb, Rect2(Vector2.ZERO, _highlight.size)))
	holder.add_child(_highlight)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(_row)
	for t in TABS:
		var tab := NavTab.new(t.id, t.label, t.icon)
		tab.tapped.connect(_on_tapped)
		_row.add_child(tab)
		_tabs.append(tab)
	_row.resized.connect(func() -> void: _place_highlight(false))
	_place_highlight.call_deferred(false)
	set_current(_current, false)


func current() -> StringName:
	return _current


func set_current(id: StringName, animate: bool = true) -> void:
	_current = id
	for t in _tabs:
		t.active = (t.id == id)
	_place_highlight(animate)
	if animate:
		for t in _tabs:
			if t.id == id:
				t.bounce()


func _on_tapped(id: StringName) -> void:
	if id == _current:
		return
	Feedback.tick()
	set_current(id)
	tab_selected.emit(id)


func _place_highlight(animate: bool) -> void:
	for t in _tabs:
		if t.id == _current:
			var r := Rect2(t.position + Vector2(8, 4), t.size - Vector2(16, 8))
			if _tween:
				_tween.kill()
			if animate and _highlight.size.x > 1.0:
				_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_tween.tween_property(_highlight, "position", r.position, 0.34)
				_tween.tween_property(_highlight, "size", r.size, 0.34)
			else:
				_highlight.position = r.position
				_highlight.size = r.size
			return
