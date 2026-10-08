class_name AuroraBackground
extends Control
## Animated aurora + bokeh behind the whole game.
## Rendered into a tiny SubViewport (1/4 resolution) and stretched: the image is blurry by
## design, and this keeps the per-frame GPU cost negligible on old phones.

const SHADER := preload("res://shaders/aurora.gdshader")
const DOWNSCALE := 4.0

var _sub: SubViewport
var _rect: ColorRect
var _view: TextureRect
var _mat: ShaderMaterial


func _ready() -> void:
	add_to_group(&"aurora")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # NOT set_anchors_preset: that keeps the old (0) size

	_sub = SubViewport.new()
	_sub.disable_3d = true
	_sub.transparent_bg = false
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)

	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = ColorRect.new()
	_rect.material = _mat
	_sub.add_child(_rect)

	_view = TextureRect.new()
	_view.texture = _sub.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view)

	resized.connect(_sync)
	_sync()


## 0 at rest; the gallery feeds its scroll position (in screens) so the light pools drift.
func set_parallax(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("parallax", v)


func _sync() -> void:
	if _sub == null or size.x < 2.0 or size.y < 2.0:
		return
	var s := Vector2i(maxi(64, int(size.x / DOWNSCALE)), maxi(64, int(size.y / DOWNSCALE)))
	_sub.size = s
	_rect.size = Vector2(s)
	_mat.set_shader_parameter("aspect", size.x / size.y)
