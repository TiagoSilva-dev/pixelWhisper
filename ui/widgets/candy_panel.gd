class_name CandyPanel
extends PanelContainer
## A rounded white card with a cream border and a soft warm shadow. Its children lay out like
## in any PanelContainer; the inner margin comes from `padding`.

@export var fill: Color = AppTheme.SURFACE:
	set(v):
		fill = v
		_apply()
@export var border_color: Color = AppTheme.STROKE:
	set(v):
		border_color = v
		_apply()
@export var border_width: int = 4:
	set(v):
		border_width = v
		_apply()
@export var radius: int = 40:
	set(v):
		radius = v
		_apply()
@export var shadow: int = 16:
	set(v):
		shadow = v
		_apply()
@export var padding: Vector4 = Vector4(28, 24, 28, 24):   ## left, top, right, bottom
	set(v):
		padding = v
		_apply()
@export var flat_bottom: bool = false:                     ## square bottom corners (docked panels)
	set(v):
		flat_bottom = v
		_apply()


func _init(p_fill: Color = AppTheme.SURFACE, p_radius: int = 40) -> void:
	fill = p_fill
	radius = p_radius
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	_apply()


func _apply() -> void:
	var sb := AppTheme.box(fill, radius, padding, border_width, border_color, shadow)
	if flat_bottom:
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_bottom_right = 0
		sb.shadow_offset = Vector2(0, -shadow * 0.4)
	add_theme_stylebox_override("panel", sb)
