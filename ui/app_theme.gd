class_name AppTheme
extends RefCounted
## Single source of truth for the look of the game: palette, fonts and the Theme resource.
## Built in code so the whole visual identity can be tuned in one file and diffed in git.
##
## Sizes are tuned for the 1080x1920 reference viewport (canvas_items stretch).

const BG_TOP := Color("1c1635")
const BG_BOTTOM := Color("0d0a17")
const SURFACE := Color("241d3d")
const SURFACE_HI := Color("322957")
const STROKE := Color("463a73")
const TEXT := Color("f5f0ff")
const TEXT_DIM := Color("aaa0cd")
const ACCENT := Color("ff7a90")
const ACCENT_DARK := Color("cf4b66")
const AMBER := Color("ffb36b")
const MINT := Color("5be3c1")
const SKY := Color("6bc4ff")
const SHADOW := Color(0, 0, 0, 0.42)

static var _fonts: Dictionary = {}
static var _theme: Theme


static func font(weight: int = 700) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Nunito.ttf")
	var ts := TextServerManager.get_primary_interface()
	if ts != null:
		var tag := ts.name_to_tag("wght")
		if tag != 0:
			fv.variation_opentype = {tag: weight}
	_fonts[weight] = fv
	return fv


static func box(color: Color, radius: int = 28, pad: Vector4 = Vector4(0, 0, 0, 0),
		border: int = 0, border_color: Color = Color.TRANSPARENT, shadow: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	if shadow > 0:
		sb.shadow_size = shadow
		sb.shadow_color = SHADOW
		sb.shadow_offset = Vector2(0, shadow * 0.35)
	sb.anti_aliasing = true
	return sb


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = font(700)
	t.default_font_size = 40

	# --- Labels ---------------------------------------------------------------
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", 40)
	_label_variation(t, "TitleLabel", 78, 900, TEXT)
	_label_variation(t, "HeadingLabel", 52, 800, TEXT)
	_label_variation(t, "BodyLabel", 40, 700, TEXT)
	_label_variation(t, "DimLabel", 34, 600, TEXT_DIM)
	_label_variation(t, "CaptionLabel", 28, 700, TEXT_DIM)

	# --- Buttons ----------------------------------------------------------------
	_button_style(t, "Button", SURFACE_HI, SURFACE_HI.lightened(0.08), SURFACE_HI.darkened(0.15), TEXT)
	t.set_font_size("font_size", "Button", 44)
	t.set_font("font", "Button", font(800))

	t.add_type("PrimaryButton")
	t.set_type_variation("PrimaryButton", "Button")
	_button_style(t, "PrimaryButton", ACCENT, ACCENT.lightened(0.07), ACCENT.darkened(0.1), Color.WHITE, 8, ACCENT_DARK)
	t.set_font_size("font_size", "PrimaryButton", 46)

	t.add_type("GhostButton")
	t.set_type_variation("GhostButton", "Button")
	_button_style(t, "GhostButton", Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.17), Color(1, 1, 1, 0.92), 0, Color.TRANSPARENT, true)

	t.add_type("ChipButton")
	t.set_type_variation("ChipButton", "Button")
	_button_style(t, "ChipButton", SURFACE_HI, SURFACE_HI.lightened(0.1), STROKE, TEXT_DIM, 0, Color.TRANSPARENT, false, Vector4(36, 16, 36, 16), 40)
	t.set_font_size("font_size", "ChipButton", 34)

	t.add_type("ChipActiveButton")
	t.set_type_variation("ChipActiveButton", "Button")
	_button_style(t, "ChipActiveButton", TEXT, TEXT, TEXT.darkened(0.1), BG_BOTTOM, 0, Color.TRANSPARENT, false, Vector4(36, 16, 36, 16), 40)
	t.set_font_size("font_size", "ChipActiveButton", 34)

	# --- Panels -----------------------------------------------------------------
	t.add_type("PalettePanel")
	t.set_type_variation("PalettePanel", "PanelContainer")
	var pp := box(SURFACE, 0, Vector4(0, 0, 0, 0), 0, Color.TRANSPARENT, 40)
	pp.corner_radius_top_left = 52
	pp.corner_radius_top_right = 52
	pp.shadow_offset = Vector2(0, -8)
	t.set_stylebox("panel", "PalettePanel", pp)

	# --- Progress bar -------------------------------------------------------------
	t.set_stylebox("background", "ProgressBar", box(Color(1, 1, 1, 0.1), 12))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 12))

	# --- Line edit ------------------------------------------------------------------
	var le := box(SURFACE_HI, 32, Vector4(36, 28, 36, 28), 3, STROKE)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", box(SURFACE_HI, 32, Vector4(36, 28, 36, 28), 3, ACCENT))
	t.set_stylebox("read_only", "LineEdit", le)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_DIM.darkened(0.25))
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.4))
	t.set_font_size("font_size", "LineEdit", 40)

	# Scrollbars are hidden everywhere (touch scrolling); keep them invisible if shown.
	for sb in ["VScrollBar", "HScrollBar"]:
		for part in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
			t.set_stylebox(part, sb, StyleBoxEmpty.new())
	return t


static func _label_variation(t: Theme, type_name: String, size: int, weight: int, color: Color) -> void:
	t.add_type(type_name)
	t.set_type_variation(type_name, "Label")
	t.set_font("font", type_name, font(weight))
	t.set_font_size("font_size", type_name, size)
	t.set_color("font_color", type_name, color)


static func _button_style(t: Theme, type_name: String, normal: Color, hover: Color, pressed: Color,
		font_color: Color, lip: int = 0, lip_color: Color = Color.TRANSPARENT,
		outline: bool = false, pad: Vector4 = Vector4(48, 26, 48, 26), radius: int = 36) -> void:
	var mk := func(c: Color) -> StyleBoxFlat:
		var sb := box(c, radius, pad)
		if lip > 0:
			# A darker "lip" under the button gives a tactile, pressable look.
			sb.border_width_bottom = lip
			sb.border_color = lip_color
			sb.content_margin_bottom = pad.w + 0.0
		if outline:
			sb.set_border_width_all(2)
			sb.border_color = Color(1, 1, 1, 0.28)
		return sb
	t.set_stylebox("normal", type_name, mk.call(normal))
	t.set_stylebox("hover", type_name, mk.call(hover))
	var pr: StyleBoxFlat = mk.call(pressed)
	if lip > 0:
		pr.border_width_bottom = 2
	t.set_stylebox("pressed", type_name, pr)
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	t.set_stylebox("disabled", type_name, mk.call(normal.darkened(0.35)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, type_name, font_color)
	t.set_color("font_disabled_color", type_name, font_color.darkened(0.5))
