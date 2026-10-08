extends Control
## Root scene: owns the background, the fade transition and which screen is showing.
##
## Layout rules for "portrait everywhere":
##  - The UI is authored for 1080x1920 and uses containers/anchors only, so it stretches
##    to any portrait phone (including 20:9 and foldables).
##  - On windows wider than a phone (desktop / web), the screens live in a centered
##    phone-shaped column and the extra width just shows the background.
##  - Display cutouts and gesture bars are respected via DisplayServer's safe area.

const HOME := preload("res://scenes/Home.tscn")
const GAME := preload("res://scenes/Game.tscn")
const MAX_ASPECT_W_OVER_H := 0.64   ## widest the column may get relative to the height (9:16 = 0.5625)
const OUT_SEC := 0.16
const IN_SEC := 0.38

@onready var host: Control = %ScreenHost

var _current: Control
var _switching: bool = false


func _ready() -> void:
	# Theme on the Window so every Control (modals, toasts) inherits it.
	get_window().theme = AppTheme.get_theme()
	get_tree().root.min_size = Vector2i(360, 640)

	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	show_home(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()


func _on_back() -> void:
	if _current != null and _current.has_method("handle_back") and _current.handle_back():
		return
	get_tree().quit()


# -- layout -----------------------------------------------------------------------

func _layout() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return
	var col_w := minf(s.x, s.y * MAX_ASPECT_W_OVER_H)
	var side := (s.x - col_w) * 0.5
	var m := _safe_margins()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.offset_left = side + m.x
	host.offset_top = m.y
	host.offset_right = -(side + m.z)
	host.offset_bottom = -m.w


## (left, top, right, bottom) insets in canvas units for notches / gesture bars.
func _safe_margins() -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var win := Vector2(DisplayServer.window_get_size())
	if win.x < 1.0 or safe.size.x <= 0:
		return Vector4.ZERO
	var k := size / win  # window pixels -> canvas units
	return Vector4(
		maxf(0.0, safe.position.x) * k.x,
		maxf(0.0, safe.position.y) * k.y,
		maxf(0.0, screen.x - safe.end.x) * k.x,
		maxf(0.0, screen.y - safe.end.y) * k.y)


# -- screens ----------------------------------------------------------------------

func show_home(immediate: bool = false) -> void:
	await _swap(_make_home, immediate)


func open_level(level_id: String) -> void:
	if level_id == "":
		show_home()
		return
	await _swap(_make_game, false, level_id)


func _make_home() -> Control:
	var h: Control = HOME.instantiate()
	h.level_chosen.connect(open_level)
	return h


func _make_game() -> Control:
	var g: Control = GAME.instantiate()
	g.home_requested.connect(show_home)
	g.level_requested.connect(open_level)
	return g


func _swap(make: Callable, immediate: bool, level_id: String = "") -> void:
	if _switching:
		return
	_switching = true
	if _current != null and not immediate:
		# The old screen sinks back and fades...
		_current.pivot_offset = _current.size * 0.5
		var out := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		out.tween_property(_current, "modulate:a", 0.0, OUT_SEC)
		out.tween_property(_current, "scale", Vector2.ONE * 0.97, OUT_SEC)
		await out.finished
	if _current != null:
		_current.queue_free()
		await get_tree().process_frame
	_current = make.call()
	if not immediate:
		_current.modulate.a = 0.0
	host.add_child(_current)
	if level_id != "" and _current.has_method("start"):
		_current.start(level_id)
	if not immediate:
		# ...and the new one rises into place with a little overshoot.
		await get_tree().process_frame
		_current.pivot_offset = _current.size * 0.5
		_current.scale = Vector2.ONE * 1.03
		var inn := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		inn.tween_property(_current, "scale", Vector2.ONE, IN_SEC)
		inn.tween_property(_current, "modulate:a", 1.0, IN_SEC * 0.7).set_trans(Tween.TRANS_SINE)
		await inn.finished
	_switching = false
