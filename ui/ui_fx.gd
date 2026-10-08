class_name UiFx
extends RefCounted
## Small animation / feedback helpers shared by every screen.

static var _toast_layer: CanvasLayer


## Gives a Button the same squish-on-press feel as IconButton, plus a soft tick.
static func press_juice(b: BaseButton) -> void:
	var sync_pivot := func() -> void: b.pivot_offset = b.size * 0.5
	b.resized.connect(sync_pivot)
	sync_pivot.call()
	b.button_down.connect(func() -> void:
		Feedback.tick()
		b.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) \
			.tween_property(b, "scale", Vector2.ONE * 0.95, 0.06))
	b.button_up.connect(func() -> void:
		b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
			.tween_property(b, "scale", Vector2.ONE, 0.22))


## Fade + scale in from slightly smaller, with optional stagger delay.
static func pop_in(c: Control, delay: float = 0.0, duration: float = 0.38) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * 0.86
	c.modulate.a = 0.0
	var t := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE, duration).set_delay(delay)
	t.tween_property(c, "modulate:a", 1.0, duration * 0.6).set_delay(delay).set_trans(Tween.TRANS_LINEAR)


## Slides a rounded message up from the bottom of the screen and fades it out.
static func toast(from: Node, text: String, seconds: float = 2.2) -> void:
	var tree := from.get_tree()
	if _toast_layer == null or not is_instance_valid(_toast_layer):
		_toast_layer = CanvasLayer.new()
		_toast_layer.layer = 100
		tree.root.add_child(_toast_layer)

	var panel := GlassPanel.new(Glass.Style.PILL, false)
	panel.padding = Vector4(44, 24, 44, 24)
	panel.overrides = {"radius": 44.0}
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 560
	panel.add_child(label)
	_toast_layer.add_child(panel)

	var vp := tree.root.get_visible_rect().size
	panel.reset_size()
	panel.position = Vector2((vp.x - panel.size.x) * 0.5, vp.y - panel.size.y - 300.0)
	panel.modulate.a = 0.0
	var y := panel.position.y
	panel.position.y = y + 40.0
	var t := panel.create_tween()
	t.set_parallel(true)
	t.tween_property(panel, "position:y", y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "modulate:a", 1.0, 0.2)
	t.chain().tween_interval(seconds)
	t.chain().tween_property(panel, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(panel.queue_free)
