class_name AppTheme
extends RefCounted
## Single source of truth for the look of the game: palette, fonts and the Theme resource.
## Built in code so the whole visual identity can be tuned in one file and diffed in git.
##
## The look is light and playful ("candy"): cream paper, white cards with a soft warm shadow,
## saturated flat colors with a darker "lip" under every pressable thing.
##
## Sizes are tuned for the 1080x1920 reference viewport (canvas_items stretch).

# --- paper & ink --------------------------------------------------------------------------
const BG_TOP := Color("fffdf0")
const BG_BOTTOM := Color("f8f6ef")
const SURFACE := Color("ffffff")
const SURFACE_DIM := Color("f4efdd")
const STROKE := Color("eadfc2")
const INK := Color("2b2350")
const INK_DIM := Color("7d7699")
const SHADOW := Color(0.36, 0.27, 0.08, 0.17)

# --- candy colors (categories, buttons, cards) --------------------------------------------
const PURPLE := Color("8b5cf0")
const GREEN := Color("3dc15f")
const ORANGE := Color("ff9a1f")
const BLUE := Color("3ea6ff")
const CYAN := Color("17cfe3")
const PINK := Color("f0288f")
const RED := Color("f2494b")
const YELLOW := Color("ffc928")
const MINT := Color("3fd6a6")
const SKY_SOFT := Color("dcecff")

## Vivid backgrounds the gallery cards cycle through (behind the pixel art).
const CARD_BACKS: Array[Color] = [
	Color("45c96a"), Color("74c6f5"), Color("2fd9e6"), Color("ffa133"),
	Color("ff6fae"), Color("a98bff"), Color("ffd23f"), Color("5fd8b0"),
]
## Info-strip colors under the thumbnail (pink first, as in the reference).
const CARD_STRIPS: Array[Color] = [
	Color("e91e8c"), Color("e8384f"), Color("8e44e0"), Color("f26b1d"), Color("1fa7c9"),
]

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


static func lip(c: Color) -> Color:
	return c.darkened(0.24)


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
		sb.shadow_offset = Vector2(0, shadow * 0.4)
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
	t.set_color("font_color", "Label", INK)
	t.set_font_size("font_size", "Label", 40)
	_label_variation(t, "TitleLabel", 78, 900, INK)
	_label_variation(t, "HeadingLabel", 52, 900, INK)
	_label_variation(t, "BodyLabel", 40, 700, INK)
	_label_variation(t, "DimLabel", 34, 700, INK_DIM)
	_label_variation(t, "CaptionLabel", 28, 800, INK_DIM)

	# --- Buttons (dialogs) --------------------------------------------------------
	_button_style(t, "Button", SURFACE_DIM, SURFACE_DIM.lightened(0.4), SURFACE_DIM.darkened(0.06), INK, 6, STROKE)
	t.set_font_size("font_size", "Button", 44)
	t.set_font("font", "Button", font(800))

	t.add_type("PrimaryButton")
	t.set_type_variation("PrimaryButton", "Button")
	_button_style(t, "PrimaryButton", PINK, PINK.lightened(0.07), PINK.darkened(0.08), Color.WHITE, 8, lip(PINK))
	t.set_font_size("font_size", "PrimaryButton", 46)

	t.add_type("GhostButton")
	t.set_type_variation("GhostButton", "Button")
	_button_style(t, "GhostButton", SURFACE, Color("fffaf0"), SURFACE_DIM, INK, 6, STROKE)

	t.add_type("ChipButton")
	t.set_type_variation("ChipButton", "Button")
	_button_style(t, "ChipButton", SKY_SOFT, SKY_SOFT.lightened(0.3), SKY_SOFT.darkened(0.08), Color("1d5fa8"), 5,
			SKY_SOFT.darkened(0.2), Vector4(36, 14, 36, 14), 40)
	t.set_font_size("font_size", "ChipButton", 34)

	# --- Line edit (search box) -------------------------------------------------------
	var le := box(SURFACE, 44, Vector4(40, 22, 40, 22), 4, STROKE)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", box(SURFACE, 44, Vector4(40, 22, 40, 22), 4, PURPLE))
	t.set_stylebox("read_only", "LineEdit", le)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK_DIM.lightened(0.2))
	t.set_color("caret_color", "LineEdit", PURPLE)
	t.set_color("selection_color", "LineEdit", Color(PURPLE, 0.3))
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
		font_color: Color, lip_px: int = 0, lip_color: Color = Color.TRANSPARENT,
		pad: Vector4 = Vector4(48, 24, 48, 24), radius: int = 40) -> void:
	var mk := func(c: Color) -> StyleBoxFlat:
		var sb := box(c, radius, pad)
		if lip_px > 0:
			# A darker "lip" under the button gives a tactile, pressable look.
			sb.border_width_bottom = lip_px
			sb.border_color = lip_color
			sb.content_margin_bottom = pad.w
		return sb
	t.set_stylebox("normal", type_name, mk.call(normal))
	t.set_stylebox("hover", type_name, mk.call(hover))
	var pr: StyleBoxFlat = mk.call(pressed)
	if lip_px > 0:
		pr.border_width_bottom = 2
		pr.content_margin_top = pad.y + (lip_px - 2)
	t.set_stylebox("pressed", type_name, pr)
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	t.set_stylebox("disabled", type_name, mk.call(normal.darkened(0.15)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, type_name, font_color)
	t.set_color("font_disabled_color", type_name, font_color.darkened(0.3))
