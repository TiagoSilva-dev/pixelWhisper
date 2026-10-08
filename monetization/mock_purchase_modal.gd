class_name MockPurchaseModal
extends Modal
## A fake "confirm purchase" sheet standing in for the store's own (Google Play / App Store) in
## the editor, the Web build and manual testing. Nothing is ever charged.

signal decided(bought: bool)

var _decided: bool = false


## Asks the player and returns true if they pressed Buy. Closing the sheet any other way is "no".
static func ask(host: Node, price: String) -> bool:
	var layer := CanvasLayer.new()
	layer.layer = 90     # above every dialog of the game
	host.get_tree().root.add_child(layer)
	var m := MockPurchaseModal.new()
	m.theme = AppTheme.get_theme()   # a CanvasLayer between the Window and its children blocks theme inheritance
	layer.add_child(m)
	m.present(price)
	m.closed.connect(layer.queue_free)
	return await m.decided


func present(price: String) -> void:
	dismiss_on_outside_tap = true
	add_header("Test purchase")

	var item := Label.new()
	item.text = "PixelWhisper Premium"
	item.theme_type_variation = &"HeadingLabel"
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(item)
	var cost := Label.new()
	cost.text = price
	cost.add_theme_font_size_override("font_size", 72)
	cost.add_theme_font_override("font", AppTheme.font(900))
	cost.add_theme_color_override("font_color", AppTheme.PURPLE)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(cost)
	var note := Label.new()
	note.text = "Simulated purchase: nothing is charged."
	note.theme_type_variation = &"DimLabel"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)

	var buy := CandyButton.new(Icons.Kind.CHECK, "Buy", AppTheme.GREEN)
	buy.custom_minimum_size.y = 120
	buy.pressed.connect(_decide.bind(true))
	content.add_child(buy)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.theme_type_variation = &"GhostButton"
	cancel.pressed.connect(_decide.bind(false))
	UiFx.press_juice(cancel)
	content.add_child(cancel)
	closed.connect(_decide.bind(false))


func _decide(bought: bool) -> void:
	if _decided:
		return
	_decided = true
	decided.emit(bought)
	close()
