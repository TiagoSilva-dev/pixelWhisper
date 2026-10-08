class_name ShopPage
extends Control
## "Shop" tab: the Premium pack (the only real-money purchase), the free daily gift, what each
## power-up does and costs, and how coins are earned.

var _gift_button: CandyButton
var _gift_label: Label
var _content: VBoxContainer
var _premium_box: VBoxContainer
var _restore_button: Button
var _price_rows: Array[Dictionary] = []   ## {label, coin, cost}: shown as "Free" for Premium players
var _purchasing: bool = false


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

	var head := HBoxContainer.new()
	_content.add_child(head)
	var title := Label.new()
	title.text = "Shop"
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 66)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var coins := CoinPill.new()
	coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(coins)

	var premium_card := CandyPanel.new(AppTheme.PURPLE, 48)
	premium_card.border_width = 0
	premium_card.padding = Vector4(30, 28, 30, 30)
	_content.add_child(premium_card)
	_premium_box = VBoxContainer.new()
	_premium_box.add_theme_constant_override("separation", 18)
	premium_card.add_child(_premium_box)
	_restore_button = Button.new()
	_restore_button.text = "Restore purchases"
	_restore_button.theme_type_variation = &"GhostButton"
	_restore_button.add_theme_font_size_override("font_size", 34)
	_restore_button.pressed.connect(_restore)
	UiFx.press_juice(_restore_button)
	_content.add_child(_restore_button)

	_content.add_child(_gift_card())

	var h := Label.new()
	h.text = "Power-ups"
	h.theme_type_variation = &"HeadingLabel"
	_content.add_child(h)
	_content.add_child(_power_up_row(Icons.Kind.WAND, "Magic wand", "Paints every cell of the selected color that you can see", GameState.COST_WAND))
	_content.add_child(_power_up_row(Icons.Kind.BOMB, "Ink bomb", "Tap a spot: paints the 5x5 square around it", GameState.COST_BOMB))
	_content.add_child(_power_up_row(Icons.Kind.MAGNIFIER, "Magnifier", "Zooms smoothly onto a pixel you are missing", GameState.COST_MAGNIFIER))

	var earn := CandyPanel.new(AppTheme.SURFACE_DIM, 40)
	earn.border_width = 0
	earn.shadow = 0
	earn.padding = Vector4(32, 26, 32, 26)
	_content.add_child(earn)
	var el := Label.new()
	el.text = "Earn coins: finish a picture for the first time (+60) and claim your daily gift (+50)."
	el.theme_type_variation = &"DimLabel"
	el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	earn.add_child(el)

	GameState.wallet_changed.connect(_refresh_gift)
	GameState.entitlements_changed.connect(_refresh_premium)
	Store.state_changed.connect(_refresh_premium)
	_refresh_gift()
	_refresh_premium()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _gift_label != null:
		_refresh_gift()
		_refresh_premium()


# -- Premium pack -----------------------------------------------------------------------------

## Rebuilds the purple card from what the player owns and what the store is asking.
func _refresh_premium() -> void:
	var owned := GameState.premium
	for c in _premium_box.get_children():
		_premium_box.remove_child(c)
		c.queue_free()

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	_premium_box.add_child(head)
	head.add_child(_icon_box(Icons.Kind.DIAMOND, 120))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	head.add_child(col)
	col.add_child(_white_label("Premium is active" if owned else "PixelWhisper Premium", 46, 900, 1.0))
	col.add_child(_white_label("Thank you for supporting PixelWhisper!" if owned else "One-time purchase, yours forever", 28, 700, 0.85))

	for perk in ["Every picture unlocked", "Power-ups are free", "No ads"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		_premium_box.add_child(row)
		row.add_child(_icon_box(Icons.Kind.CHECK, 44))
		row.add_child(_white_label(perk, 34, 800, 1.0))

	if not owned:
		var price := Store.price_text()
		var buy := CandyButton.new(Icons.Kind.DIAMOND, tr("Get Premium") + ("  " + price if price != "" else ""), AppTheme.YELLOW)
		buy.text_color = AppTheme.INK
		buy.font_size = 42
		buy.custom_minimum_size.y = 120
		buy.dimmed = not Store.is_available()
		buy.pressed.connect(_buy_premium)
		_premium_box.add_child(buy)
	_restore_button.visible = not owned

	for r in _price_rows:
		r.label.text = tr("Free") if owned else str(r.cost)
		r.coin.visible = not owned


func _white_label(t: String, size_px: int, weight: int, alpha: float) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_font_override("font", AppTheme.font(weight))
	l.add_theme_color_override("font_color", Color(1, 1, 1, alpha))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _buy_premium() -> void:
	if _purchasing:
		return
	if not Store.is_available():
		UiFx.toast(self, tr("The store is not available right now."), 2.4)
		Feedback.wrong()
		return
	_purchasing = true
	var result: StoreProvider.Result = await Store.buy_premium()
	_purchasing = false
	if not is_inside_tree():
		return
	match result:
		StoreProvider.Result.OK:
			Feedback.win()
			UiFx.toast(self, tr("Premium unlocked. Enjoy!"), 2.6)
		StoreProvider.Result.FAILED:
			UiFx.toast(self, tr("The purchase did not go through. Please try again."), 2.6)
		# CANCELED: the player changed their mind, nothing to say


func _restore() -> void:
	if _purchasing:
		return
	_purchasing = true
	var owned: bool = await Store.restore()
	_purchasing = false
	if is_inside_tree():
		UiFx.toast(self, tr("Purchases restored") if owned else tr("No purchase to restore"), 2.2)


func _gift_card() -> Control:
	var card := CandyPanel.new(AppTheme.SURFACE, 44)
	card.padding = Vector4(28, 26, 28, 28)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	card.add_child(row)
	row.add_child(_icon_box(Icons.Kind.GIFT, 130))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	var t := Label.new()
	t.text = "Daily gift"
	t.theme_type_variation = &"HeadingLabel"
	t.add_theme_font_size_override("font_size", 46)
	col.add_child(t)
	_gift_label = Label.new()
	_gift_label.theme_type_variation = &"DimLabel"
	_gift_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_gift_label)
	_gift_button = CandyButton.new(Icons.Kind.COIN, "Claim", AppTheme.GREEN)
	_gift_button.font_size = 38
	_gift_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_gift_button.pressed.connect(_claim)
	col.add_child(_gift_button)
	return card


func _refresh_gift() -> void:
	var ready := GameState.can_claim_daily_gift()
	_gift_button.dimmed = not ready
	_gift_button.text = "Claim" if ready else "Come back tomorrow"
	_gift_label.text = tr("+%d coins, once a day") % GameState.DAILY_GIFT


func _claim() -> void:
	var n := GameState.claim_daily_gift()
	if n > 0:
		Feedback.wand()
		UiFx.toast(self, tr("+%d coins") % n, 1.8)
	else:
		Feedback.wrong()


func _power_up_row(kind: Icons.Kind, title: String, blurb: String, cost: int) -> Control:
	var card := CandyPanel.new(AppTheme.SURFACE, 40)
	card.padding = Vector4(22, 20, 26, 22)
	card.shadow = 12
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	card.add_child(row)
	row.add_child(_icon_box(kind, 104))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", AppTheme.font(900))
	t.add_theme_font_size_override("font_size", 42)
	col.add_child(t)
	var b := Label.new()
	b.text = blurb
	b.theme_type_variation = &"CaptionLabel"
	b.add_theme_font_size_override("font_size", 28)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(b)
	var price := HBoxContainer.new()
	price.add_theme_constant_override("separation", 8)
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(price)
	var coin := _icon_box(Icons.Kind.COIN, 48)
	price.add_child(coin)
	var pl := Label.new()
	pl.text = str(cost)
	pl.add_theme_font_override("font", AppTheme.font(900))
	pl.add_theme_font_size_override("font_size", 42)
	price.add_child(pl)
	_price_rows.append({"label": pl, "coin": coin, "cost": cost})
	return card


func _icon_box(kind: Icons.Kind, px: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: Icons.draw(c, kind, c.size * 0.5, px * 0.42))
	return c
