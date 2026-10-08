class_name Modal
extends Control
## Base for dialogs: the scene behind blurs and dims, and a frosted-glass card floats in.
## Subclasses fill `content` (a VBoxContainer inside the card) and may set
## `dismiss_on_outside_tap`. With "Glass effects" off the backdrop is a plain dim.

const BACKDROP_SHADER := preload("res://shaders/backdrop_blur.gdshader")

signal closed

var dismiss_on_outside_tap: bool = true
var card: GlassPanel
var content: VBoxContainer

var _backdrop: ColorRect
var _backdrop_mat: ShaderMaterial
var _closing: bool = false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	if Glass.effects_on():
		var copy := BackBufferCopy.new()
		copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		add_child(copy)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Glass.effects_on():
		_backdrop_mat = ShaderMaterial.new()
		_backdrop_mat.shader = BACKDROP_SHADER
		_backdrop_mat.set_shader_parameter("amount", 0.0)
		_backdrop.material = _backdrop_mat
	else:
		_backdrop.color = Color(0.03, 0.02, 0.09, 0.0)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	card = GlassPanel.new(Glass.Style.MODAL, true)
	card.padding = Vector4(44, 40, 44, 44)
	card.custom_minimum_size.x = 900.0
	center.add_child(card)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 28)
	card.add_child(content)


func _ready() -> void:
	_set_backdrop(0.0)
	create_tween().tween_method(_set_backdrop, 0.0, 1.0, 0.32).set_trans(Tween.TRANS_SINE)
	await get_tree().process_frame
	if is_instance_valid(card):
		UiFx.pop_in(card, 0.0, 0.42)
		card.play_sheen(1.1)


func _set_backdrop(v: float) -> void:
	if _backdrop_mat:
		_backdrop_mat.set_shader_parameter("amount", v)
	else:
		_backdrop.color.a = 0.74 * v


func close() -> void:
	if _closing:
		return
	_closing = true
	var t := create_tween().set_parallel(true)
	t.tween_method(_set_backdrop, 1.0, 0.0, 0.2)
	t.tween_property(card, "modulate:a", 0.0, 0.16)
	t.tween_property(card, "scale", Vector2.ONE * 0.93, 0.18).set_trans(Tween.TRANS_CUBIC)
	await t.finished
	closed.emit()
	queue_free()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if dismiss_on_outside_tap and not card.get_global_rect().has_point(event.global_position):
			close()
		accept_event()


## Side length for a square picture inside a dialog: as large as `max_side`, but never
## taller than ~36% of the screen so the buttons below stay on screen on short devices.
func art_side(max_side: float) -> float:
	return minf(max_side, get_viewport_rect().size.y * 0.36)


## Title row with a close button on the right.
func add_header(title_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	content.add_child(row)
	var title := Label.new()
	title.text = title_text
	title.theme_type_variation = &"HeadingLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var x := IconButton.new(IconButton.Icon.CLOSE, 96.0)
	x.pressed.connect(close)
	row.add_child(x)
