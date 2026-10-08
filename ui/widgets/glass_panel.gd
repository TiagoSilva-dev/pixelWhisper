class_name GlassPanel
extends PanelContainer
## A container whose background is frosted glass. Its children lay out like in any
## PanelContainer; content padding comes from `padding` (the stylebox is empty).

@export var style: Glass.Style = Glass.Style.PANEL:
	set(v):
		style = v
		_refresh()
@export var blur: bool = false:          ## real backdrop blur (needs a BackBufferCopy before it)
	set(v):
		blur = v
		_rebuild_material()
@export var padding: Vector4 = Vector4(32, 24, 32, 24):   ## left, top, right, bottom
	set(v):
		padding = v
		_apply_padding()

var overrides: Dictionary = {}
var _mat: ShaderMaterial
var _sheen_tween: Tween


func _init(p_style: Glass.Style = Glass.Style.PANEL, p_blur: bool = false) -> void:
	style = p_style
	blur = p_blur
	mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_padding()


func _ready() -> void:
	_rebuild_material()
	resized.connect(_refresh)
	GameState.settings_changed.connect(_rebuild_material)


func _apply_padding() -> void:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = padding.x
	sb.content_margin_top = padding.y
	sb.content_margin_right = padding.z
	sb.content_margin_bottom = padding.w
	add_theme_stylebox_override("panel", sb)


func _rebuild_material() -> void:
	_mat = Glass.make_material(blur)
	material = _mat
	_refresh()


func _refresh() -> void:
	if _mat != null:
		Glass.configure(_mat, size, style, overrides)
	queue_redraw()


func _draw() -> void:
	if _mat != null:
		Glass.draw_quad(self, size, style)


## Re-applies `overrides` after you changed them.
func restyle() -> void:
	_refresh()


## One light sweep across the glass (entry / press flourish).
func play_sheen(duration: float = 0.9) -> void:
	if _mat == null:
		return
	if _sheen_tween:
		_sheen_tween.kill()
	_sheen_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sheen_tween.tween_method(func(v: float) -> void: _mat.set_shader_parameter("sheen", v), 0.0, 1.0, duration)
	_sheen_tween.tween_callback(func() -> void: _mat.set_shader_parameter("sheen", -1.0))


func set_glow(amount: float) -> void:
	if _mat:
		_mat.set_shader_parameter("glow", amount)


func set_press(amount: float) -> void:
	if _mat:
		_mat.set_shader_parameter("press", amount)
