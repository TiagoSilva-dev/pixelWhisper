class_name MockAdScreen
extends CanvasLayer
## A fake full-screen ad for the editor, the Web build and manual testing: a countdown and a close
## button. Like real ones, an interstitial can only be closed once the countdown is over; a rewarded
## video can be closed at any time, but only watching it to the end pays the reward.
##
## It sits on its own CanvasLayer above every screen and swallows all taps.

signal closed(completed: bool)

var _rewarded: bool = false
var _auto_close: bool = false
var _total: float = 3.0
var _left: float = 3.0
var _finished: bool = false
var _bar: CandyProgress
var _status: Label
var _close: CandyButton


## Shows the fake ad and returns once it is closed: true if it played to the end.
static func play(host: Node, rewarded: bool, seconds: float, auto_close: bool = false) -> bool:
	var s := MockAdScreen.new()
	s.layer = 90
	host.get_tree().root.add_child(s)
	s._build(rewarded, seconds, auto_close)
	return await s.closed


func _build(rewarded: bool, seconds: float, auto_close: bool) -> void:
	_rewarded = rewarded
	_auto_close = auto_close
	_total = maxf(seconds, 0.05)
	_left = _total

	var root := Control.new()
	root.theme = AppTheme.get_theme()   # a CanvasLayer between the Window and its children blocks theme inheritance
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("1d1538")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	col.custom_minimum_size.x = 780.0
	center.add_child(col)

	var icon := Control.new()
	icon.custom_minimum_size = Vector2(0, 230)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void: Icons.draw(icon, Icons.Kind.CLAPPER, icon.size * 0.5, 100.0))
	col.add_child(icon)
	col.add_child(_label("Test video ad" if not rewarded else "Test rewarded video", 62, 900, Color.WHITE))
	col.add_child(_label("Simulated ad. Real ads play in the store build.", 34, 700, Color(1, 1, 1, 0.65)))

	_bar = CandyProgress.new()
	_bar.bar_height = 26.0
	_bar.track_color = Color(1, 1, 1, 0.16)
	_bar.fill_color = AppTheme.YELLOW
	_bar.turns_green = false
	col.add_child(_bar)
	_status = _label("", 40, 800, AppTheme.YELLOW)
	col.add_child(_status)

	_close = CandyButton.new(Icons.Kind.CLOSE, "", AppTheme.RED)
	root.add_child(_close)
	_close.anchor_left = 1.0     # pinned to the top-right corner, 40 px in and 110 px down (clear of a camera cut-out)
	_close.anchor_right = 1.0
	_close.offset_left = -144.0
	_close.offset_right = -40.0
	_close.offset_top = 110.0
	_close.offset_bottom = 214.0
	_close.visible = rewarded   # an interstitial cannot be dismissed before its countdown ends
	_close.pressed.connect(_close_pressed)
	_refresh()


func _label(t: String, size_px: int, weight: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_font_override("font", AppTheme.font(weight))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(delta: float) -> void:
	if _finished or _bar == null:
		return
	_left = maxf(0.0, _left - delta)
	if _left <= 0.0:
		_finished = true
		_close.visible = true
		if _auto_close:
			_finish(true)
			return
	_refresh()


func _refresh() -> void:
	_bar.set_value(1.0 - _left / _total)
	if _finished:
		_status.text = tr("Reward earned!") if _rewarded else tr("Ad finished")
	elif _rewarded:
		_status.text = tr("Reward in %d") % ceili(_left)
	else:
		_status.text = tr("Closes in %d") % ceili(_left)


func _close_pressed() -> void:
	_finish(_finished)


func _finish(completed: bool) -> void:
	set_process(false)
	closed.emit(completed)
	queue_free()
