class_name UnlockModal
extends Modal
## Shown when the player taps a Premium picture they do not own yet: the picture behind a lock, and
## two ways in: watch a short rewarded video (opens this one picture for good) or get the Premium
## pack (opens everything). Emits `unlocked` and closes itself when either works.

signal unlocked(level_id: String)

var _entry: Dictionary = {}
var _watch: CandyButton
var _buy: CandyButton
var _busy: bool = false


func present(entry: Dictionary, level: PixelLevel) -> void:
	_entry = entry
	add_header("Premium picture")

	var frame := CandyPanel.new(AppTheme.SURFACE_DIM, 40)
	frame.padding = Vector4(14, 14, 14, 14)
	frame.shadow = 12
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(frame)
	var art := RoundedTexture.new()
	art.radius = 28.0
	art.texture = ImageTexture.create_from_image(level.build_target_image())
	var side := art_side(520.0)
	art.custom_minimum_size = Vector2(side, side)
	frame.add_child(art)
	var badge := Control.new()
	badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func() -> void:
		var r := 46.0
		var c := badge.size - Vector2(r + 14.0, r + 14.0)
		badge.draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.22), true, -1.0, true)
		badge.draw_circle(c, r, Color.WHITE, true, -1.0, true)
		Icons.draw(badge, Icons.Kind.LOCK, c, r * 0.62))
	art.add_child(badge)

	var name_label := Label.new()
	name_label.text = _entry.title
	name_label.theme_type_variation = &"HeadingLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)
	content.add_child(_caption("Watch a short video to paint it, or get Premium to unlock everything.", 34))

	_watch = CandyButton.new(Icons.Kind.CLAPPER, "Watch a video", AppTheme.GREEN)
	_watch.font_size = 42
	_watch.custom_minimum_size.y = 128
	_watch.pressed.connect(_on_watch)
	content.add_child(_watch)
	_buy = CandyButton.new(Icons.Kind.DIAMOND, "Get Premium", AppTheme.PURPLE)
	_buy.font_size = 42
	_buy.custom_minimum_size.y = 128
	_buy.pressed.connect(_on_buy)
	content.add_child(_buy)
	content.add_child(_caption("Premium: every picture, free power-ups, no ads.", 28))

	Ads.availability_changed.connect(_refresh)
	Store.state_changed.connect(_refresh)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _buy != null:
		_refresh()


func _caption(t: String, size_px: int) -> Label:
	var l := Label.new()
	l.text = t
	l.theme_type_variation = &"CaptionLabel"
	l.add_theme_font_size_override("font_size", size_px)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Button faces follow what is possible right now (video loaded? store reachable? a flow running?).
func _refresh() -> void:
	var video := Ads.is_rewarded_ready()
	_watch.text = "Watch a video" if video else "Video unavailable"
	_watch.dimmed = _busy or not video
	var price := Store.price_text()
	_buy.text = tr("Get Premium") + ("  " + price if price != "" else "")
	_buy.dimmed = _busy or not Store.is_available()
	dismiss_on_outside_tap = not _busy


func _set_busy(on: bool) -> void:
	_busy = on
	_refresh()


func _on_watch() -> void:
	if _busy:
		return
	if not Ads.is_rewarded_ready():
		UiFx.toast(self, tr("No video available right now. Try again later."), 2.4)
		Feedback.wrong()
		return
	_set_busy(true)
	var earned := await Ads.show_rewarded()
	if not is_inside_tree():
		return
	_set_busy(false)
	if earned:
		GameState.unlock_level(_entry.id)
		_done()
	else:
		UiFx.toast(self, tr("Watch the whole video to unlock the picture."), 2.4)


func _on_buy() -> void:
	if _busy:
		return
	if not Store.is_available():
		UiFx.toast(self, tr("The store is not available right now."), 2.4)
		Feedback.wrong()
		return
	_set_busy(true)
	var result: StoreProvider.Result = await Store.buy_premium()
	if not is_inside_tree():
		return
	_set_busy(false)
	match result:
		StoreProvider.Result.OK:
			_done()
		StoreProvider.Result.FAILED:
			UiFx.toast(self, tr("The purchase did not go through. Please try again."), 2.6)
		# CANCELED: the player changed their mind, nothing to say


func _done() -> void:
	Feedback.wand()
	unlocked.emit(_entry.id)
	close()
