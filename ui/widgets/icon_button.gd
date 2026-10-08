class_name IconButton
extends Control
## Raised glass button with a vector icon (no image assets: razor sharp at any DPI).
## The glass (bevel, rim light, shadow) is a shader on this control; the icon is painted by a
## child layer on top. Pressing squishes the button, darkens the glass and fires a soft tick.

signal pressed

enum Icon { BACK, HINT, WAND, FIT, SETTINGS, CLOSE, HOME, SAVE, NEXT, PLAY, PLUS, CHECK, SPARKLE, COIN }

const GOLD_LIGHT := Color("ffe08a")
const GOLD := Color("f4b73a")
const GOLD_DARK := Color("b9791a")
const SILVER_LIGHT := Color("f2f4ff")
const SILVER := Color("b9bfd8")
const SILVER_DARK := Color("6f7694")

@export var icon: Icon = Icon.BACK:
	set(v):
		icon = v
		_redraw_icon()
@export var tint: Color = Color(0.86, 0.82, 1.0, 1.0):   ## glass tint
	set(v):
		tint = v
		_refresh()
@export var icon_color: Color = AppTheme.TEXT:
	set(v):
		icon_color = v
		_redraw_icon()
@export var badge: String = "":
	set(v):
		badge = v
		_redraw_icon()
@export var dimmed: bool = false:
	set(v):
		dimmed = v
		modulate.a = 0.5 if v else 1.0
		_redraw_icon()
@export var radius_ratio: float = 0.30:   ## corner radius as a fraction of the button size (0.5 = circle)
	set(v):
		radius_ratio = v
		_refresh()

var _mat: ShaderMaterial
var _layer: _IconLayer
var _down: bool = false
var _tween: Tween


class _IconLayer extends Control:
	var btn: IconButton

	func _init(b: IconButton) -> void:
		btn = b
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		btn._paint_icon(self)


func _init(p_icon: Icon = Icon.BACK, size_px: float = 116.0) -> void:
	icon = p_icon
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_layer = _IconLayer.new(self)
	add_child(_layer)


func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(func() -> void:
		pivot_offset = size * 0.5
		_refresh())
	GameState.settings_changed.connect(_rebuild_material)
	_rebuild_material()


func _rebuild_material() -> void:
	_mat = Glass.make_material(false)
	material = _mat
	_refresh()


func _refresh() -> void:
	if _mat == null:
		return
	var s := minf(size.x, size.y)
	Glass.configure(_mat, size, Glass.Style.BUTTON, {"radius": s * radius_ratio, "tint": tint})
	_mat.set_shader_parameter("press", 1.0 if _down else 0.0)
	queue_redraw()


func _redraw_icon() -> void:
	if _layer:
		_layer.queue_redraw()


func _draw() -> void:
	if _mat != null:
		Glass.draw_quad(self, size, Glass.Style.BUTTON)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			Feedback.tick()
			_squish(0.9, 0.07)
			_refresh()
			accept_event()
		elif _down:
			_down = false
			_squish(1.0, 0.24, true)
			_refresh()
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
			accept_event()


func _squish(target: float, duration: float, bouncy: bool = false) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if bouncy:
		_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * target, duration)


## Attention bounce, e.g. when a counter changes.
func pop() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * 1.16, 0.1)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.26)


# -- icon painting -------------------------------------------------------------------------

func _paint_icon(ci: Control) -> void:
	var c := size * 0.5
	var u := minf(size.x, size.y) * 0.5 * 0.46
	_draw_icon(ci, c, u, icon_color)
	if badge != "":
		var br := minf(size.x, size.y) * 0.5 * 0.34
		var bc := Vector2(size.x - br * 0.9, br * 0.9)
		ci.draw_circle(bc, br + 3.0, Color(0.05, 0.03, 0.12, 0.9), true, -1.0, true)
		ci.draw_circle(bc, br, AppTheme.ACCENT, true, -1.0, true)
		ci.draw_arc(bc, br - 2.0, PI * 1.1, PI * 1.7, 12, Color(1, 1, 1, 0.45), 2.5, true)
		var f := AppTheme.font(900)
		var fs := int(br * 1.25)
		var tw := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		ci.draw_string(f, bc + Vector2(-tw.x * 0.5, f.get_ascent(fs) * 0.5 - 2.0), badge,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _polyline(ci: Control, pts: PackedVector2Array, w: float, col: Color) -> void:
	ci.draw_polyline(pts, col, w, true)
	for p in pts:  # round caps and joints
		ci.draw_circle(p, w * 0.5, col, true, -1.0, true)


func _star(ci: Control, center: Vector2, radius: float, col: Color) -> void:
	var k := 0.26
	var pts := PackedVector2Array([
		center + Vector2(0, -1) * radius, center + Vector2(k, -k) * radius,
		center + Vector2(1, 0) * radius, center + Vector2(k, k) * radius,
		center + Vector2(0, 1) * radius, center + Vector2(-k, k) * radius,
		center + Vector2(-1, 0) * radius, center + Vector2(-k, -k) * radius])
	ci.draw_colored_polygon(pts, col)


## Soft drop shadow under an icon so it sits on the glass instead of printing on it.
func _drop(ci: Control, c: Vector2, u: float) -> Vector2:
	return c + Vector2(0, u * 0.07)


func _draw_icon(ci: Control, c: Vector2, u: float, col: Color) -> void:
	var w := maxf(3.0, u * 0.24)
	var shade := Color(0, 0, 0, 0.28)
	match icon:
		Icon.BACK:
			_polyline(ci, PackedVector2Array([_drop(ci, c, u) + Vector2(0.35, -1.0) * u, _drop(ci, c, u) + Vector2(-0.45, 0) * u, _drop(ci, c, u) + Vector2(0.35, 1.0) * u]), w, shade)
			_polyline(ci, PackedVector2Array([c + Vector2(0.35, -1.0) * u, c + Vector2(-0.45, 0) * u, c + Vector2(0.35, 1.0) * u]), w, col)
		Icon.NEXT:
			_polyline(ci, PackedVector2Array([c + Vector2(-0.35, -1.0) * u, c + Vector2(0.45, 0) * u, c + Vector2(-0.35, 1.0) * u]), w, col)
		Icon.CLOSE:
			_polyline(ci, PackedVector2Array([c + Vector2(-0.8, -0.8) * u, c + Vector2(0.8, 0.8) * u]), w, col)
			_polyline(ci, PackedVector2Array([c + Vector2(0.8, -0.8) * u, c + Vector2(-0.8, 0.8) * u]), w, col)
		Icon.PLUS:
			_polyline(ci, PackedVector2Array([c + Vector2(-0.9, 0) * u, c + Vector2(0.9, 0) * u]), w, col)
			_polyline(ci, PackedVector2Array([c + Vector2(0, -0.9) * u, c + Vector2(0, 0.9) * u]), w, col)
		Icon.CHECK:
			_polyline(ci, PackedVector2Array([c + Vector2(-0.9, 0.05) * u, c + Vector2(-0.3, 0.7) * u, c + Vector2(0.95, -0.7) * u]), w * 1.1, col)
		Icon.PLAY:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.5, -0.9) * u, c + Vector2(0.95, 0) * u, c + Vector2(-0.5, 0.9) * u]), col)
		Icon.FIT:
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					_polyline(ci, PackedVector2Array([
						c + Vector2(sx * 1.0, sy * 0.4) * u, c + Vector2(sx * 1.0, sy * 1.0) * u,
						c + Vector2(sx * 0.4, sy * 1.0) * u]), w, col)
		Icon.HINT:
			# glowing bulb in gold
			var bc := c + Vector2(0, -0.26) * u
			ci.draw_circle(bc, 1.25 * u, Color(GOLD.r, GOLD.g, GOLD.b, 0.16), true, -1.0, true)
			ci.draw_circle(bc + Vector2(0, 0.05) * u, 0.8 * u, GOLD_DARK, true, -1.0, true)
			ci.draw_circle(bc, 0.8 * u, GOLD, true, -1.0, true)
			ci.draw_circle(bc + Vector2(-0.12, -0.14) * u, 0.55 * u, GOLD_LIGHT, true, -1.0, true)
			ci.draw_rect(Rect2(c + Vector2(-0.4, 0.4) * u, Vector2(0.8, 0.28) * u), SILVER)
			ci.draw_rect(Rect2(c + Vector2(-0.3, 0.74) * u, Vector2(0.6, 0.2) * u), SILVER_DARK)
			ci.draw_arc(bc + Vector2(-0.05, -0.1) * u, 0.42 * u, PI * 1.05, PI * 1.62, 12, Color(1, 1, 1, 0.8), w * 0.55, true)
		Icon.WAND, Icon.SPARKLE:
			_star(ci, c + Vector2(-0.1, 0.12) * u + Vector2(0, 0.06) * u, 0.95 * u, GOLD_DARK)
			_star(ci, c + Vector2(-0.1, 0.12) * u, 0.95 * u, GOLD_LIGHT if icon == Icon.WAND else col)
			_star(ci, c + Vector2(0.72, -0.72) * u, 0.4 * u, col if icon == Icon.SPARKLE else GOLD_LIGHT)
			_star(ci, c + Vector2(0.78, 0.62) * u, 0.28 * u, col if icon == Icon.SPARKLE else GOLD_LIGHT)
		Icon.COIN:
			# glossy gold coin with an embossed star
			ci.draw_circle(c + Vector2(0, 0.1) * u, 1.12 * u, Color(0, 0, 0, 0.3), true, -1.0, true)
			ci.draw_circle(c, 1.12 * u, GOLD_DARK, true, -1.0, true)
			ci.draw_circle(c + Vector2(0, -0.04) * u, 1.02 * u, GOLD, true, -1.0, true)
			ci.draw_circle(c + Vector2(-0.06, -0.12) * u, 0.78 * u, GOLD_LIGHT, true, -1.0, true)
			ci.draw_arc(c, 0.86 * u, 0.0, TAU, 40, Color(GOLD_DARK.r, GOLD_DARK.g, GOLD_DARK.b, 0.55), 2.5, true)
			_star(ci, c + Vector2(0, 0.04) * u, 0.5 * u, GOLD_DARK)
			ci.draw_arc(c, 1.0 * u, PI * 1.05, PI * 1.55, 14, Color(1, 1, 1, 0.9), w * 0.45, true)
		Icon.SETTINGS:
			# brushed-silver gear
			var tooth := 0.42 * u
			for layer in 2:
				var off := Vector2(0, 0.08 * u) if layer == 0 else Vector2.ZERO
				var body := SILVER_DARK if layer == 0 else SILVER
				for k in 8:
					var d := Vector2.from_angle(k * TAU / 8.0)
					ci.draw_line(c + off + d * 0.7 * u, c + off + d * 1.1 * u, body, tooth, true)
				ci.draw_circle(c + off, 0.78 * u, body, true, -1.0, true)
			ci.draw_circle(c + Vector2(-0.05, -0.06) * u, 0.62 * u, SILVER_LIGHT, true, -1.0, true)
			ci.draw_circle(c, 0.3 * u, Color(0.18, 0.15, 0.3, 0.85), true, -1.0, true)
			ci.draw_arc(c, 0.3 * u, PI * 1.1, PI * 1.9, 10, Color(1, 1, 1, 0.35), 2.0, true)
		Icon.HOME:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-1.05, -0.05) * u, c + Vector2(0, -1.0) * u, c + Vector2(1.05, -0.05) * u]), col)
			ci.draw_rect(Rect2(c + Vector2(-0.72, -0.05) * u, Vector2(1.44, 0.98) * u), col)
			ci.draw_rect(Rect2(c + Vector2(-0.2, 0.35) * u, Vector2(0.4, 0.58) * u), Color(0.2, 0.16, 0.35, 0.9))
		Icon.SAVE:
			_polyline(ci, PackedVector2Array([c + Vector2(0, -1.0) * u, c + Vector2(0, 0.38) * u]), w, col)
			_polyline(ci, PackedVector2Array([c + Vector2(-0.6, -0.2) * u, c + Vector2(0, 0.45) * u, c + Vector2(0.6, -0.2) * u]), w, col)
			_polyline(ci, PackedVector2Array([c + Vector2(-0.95, 0.4) * u, c + Vector2(-0.95, 0.98) * u, c + Vector2(0.95, 0.98) * u, c + Vector2(0.95, 0.4) * u]), w, col)
