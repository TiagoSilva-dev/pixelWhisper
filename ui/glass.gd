class_name Glass
extends RefCounted
## Factory + presets for the frosted-glass look (see shaders/glass_common.gdshaderinc).
##
## Two shader variants share one set of uniforms:
##   * faux  - translucent fill + rim light + shadow. No framebuffer copy.
##   * blur  - the same, plus a real blur of whatever is behind (needs a BackBufferCopy
##             earlier in the tree). Only used when Settings -> "Glass effects" is on.

const SHADER_FAUX := preload("res://shaders/glass.gdshader")
const SHADER_BLUR := preload("res://shaders/glass_blur.gdshader")

enum Style { PANEL, CARD, BUTTON, PILL, MODAL }

const PRESETS := {
	Style.PANEL: {"radius": 44.0, "fill_top": 0.20, "fill_bottom": 0.09, "rim": 0.66, "bevel": 0.0, "shadow_alpha": 0.42, "shadow_size": 30.0, "margin": 52.0},
	Style.CARD: {"radius": 38.0, "fill_top": 0.16, "fill_bottom": 0.06, "rim": 0.52, "bevel": 0.0, "shadow_alpha": 0.34, "shadow_size": 24.0, "margin": 44.0},
	Style.BUTTON: {"radius": 30.0, "fill_top": 0.27, "fill_bottom": 0.12, "rim": 0.78, "bevel": 1.0, "shadow_alpha": 0.40, "shadow_size": 16.0, "margin": 30.0},
	Style.PILL: {"radius": 999.0, "fill_top": 0.19, "fill_bottom": 0.08, "rim": 0.6, "bevel": 0.0, "shadow_alpha": 0.36, "shadow_size": 22.0, "margin": 40.0},
	Style.MODAL: {"radius": 54.0, "fill_top": 0.66, "fill_bottom": 0.56, "rim": 0.74, "bevel": 0.0, "shadow_alpha": 0.55, "shadow_size": 46.0, "margin": 72.0, "tint": Color(0.13, 0.09, 0.30)},
}

static var _white: ImageTexture


static func effects_on() -> bool:
	return GameState.glass_fx


## A 4x4 white texture: drawing it gives the shader well-defined UVs (0..1) on any rect.
static func white() -> ImageTexture:
	if _white == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white


static func margin_of(style: Style) -> float:
	return PRESETS[style].margin


## `want_blur` is honoured only when glass effects are enabled in Settings.
static func make_material(want_blur: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_BLUR if (want_blur and effects_on()) else SHADER_FAUX
	# A panel that asked for the blurred backdrop but cannot have it needs more body,
	# otherwise the content scrolling under it fights with its text.
	m.set_meta(&"degraded", want_blur and not effects_on())
	return m


## Pushes a preset (plus optional overrides) and the current size into a glass material.
static func configure(m: ShaderMaterial, rect_size: Vector2, style: Style, overrides: Dictionary = {}) -> void:
	var p: Dictionary = PRESETS[style].duplicate()
	p.merge(overrides, true)
	var blur_variant := m.shader == SHADER_BLUR
	if not blur_variant and m.get_meta(&"degraded", false) and style != Style.MODAL:
		p.fill_top = 0.82
		p.fill_bottom = 0.74
		if not overrides.has("tint"):
			p.tint = Color(0.15, 0.11, 0.33)
	var radius: float = minf(float(p.radius), minf(rect_size.x, rect_size.y) * 0.5)
	m.set_shader_parameter("rect_size", rect_size)
	m.set_shader_parameter("radius", radius)
	for k in ["fill_top", "fill_bottom", "rim", "bevel", "shadow_alpha", "shadow_size", "margin"]:
		m.set_shader_parameter(k, float(p[k]))
	if p.has("tint"):
		m.set_shader_parameter("tint", p.tint)
	if p.has("glow_color"):
		m.set_shader_parameter("glow_color", p.glow_color)


## Draws the glass quad (panel rect grown by the preset margin) onto `ci`, which must
## have a glass material assigned.
static func draw_quad(ci: CanvasItem, size: Vector2, style: Style) -> void:
	var m := margin_of(style)
	ci.draw_texture_rect(white(), Rect2(Vector2(-m, -m), size + Vector2(m, m) * 2.0), false)
