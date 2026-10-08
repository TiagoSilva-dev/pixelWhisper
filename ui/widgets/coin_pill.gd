class_name CoinPill
extends CandyPanel
## "(coin) 250": the wallet in a rounded card. Follows `GameState.coins` by itself and counts
## up / down to the new value; tapping it emits `pressed` (the gallery uses it to open the shop).

signal pressed

var _label: Label
var _icon: _CoinIcon
var _shown: int = 0
var _tween: Tween
var _press_pos: Vector2 = Vector2.ZERO
var _down: bool = false


class _CoinIcon extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(56, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Icons.draw(self, Icons.Kind.COIN, size * 0.5, minf(size.x, size.y) * 0.46)


func _init() -> void:
	super(AppTheme.SURFACE, 44)
	padding = Vector4(14, 8, 28, 8)
	shadow = 10
	border_width = 4
	mouse_filter = Control.MOUSE_FILTER_STOP

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = _CoinIcon.new()
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	_label = Label.new()
	_label.add_theme_font_override("font", AppTheme.font(900))
	_label.add_theme_font_size_override("font_size", 42)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.custom_minimum_size.x = 84
	row.add_child(_label)


func _ready() -> void:
	super()
	_shown = GameState.coins
	_label.text = str(_shown)
	GameState.wallet_changed.connect(_on_wallet_changed)
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _on_wallet_changed() -> void:
	var target := GameState.coins
	if _tween:
		_tween.kill()
	var from := _shown
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(v: float) -> void:
		_shown = int(round(v))
		_label.text = str(_shown), float(from), float(target), 0.45)
	var bump := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bump.tween_property(self, "scale", Vector2.ONE * 1.12, 0.1)
	bump.tween_property(self, "scale", Vector2.ONE, 0.25)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_press_pos = event.position
		elif _down:
			_down = false
			if event.position.distance_to(_press_pos) < 26.0:
				Feedback.tick()
				pressed.emit()
