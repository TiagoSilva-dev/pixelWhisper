class_name RoundedTexture
extends TextureRect
## A TextureRect with antialiased rounded corners (see rounded_image.gdshader).
## Pixel art stays crisp: filtering is NEAREST and the stretch is a plain scale.

const SHADER := preload("res://shaders/rounded_image.gdshader")

@export var radius: float = 28.0:
	set(v):
		radius = v
		_sync()

var _mat: ShaderMaterial


func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	resized.connect(_sync)


func _ready() -> void:
	_sync()


func _sync() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("radius_px", radius)
	_mat.set_shader_parameter("rect_size", size)
