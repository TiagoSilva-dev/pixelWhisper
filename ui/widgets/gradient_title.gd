class_name GradientTitle
extends Control
## The "PixelWhisper" logo: rounded heavy font, every letter in its own candy color with a white
## sticker outline and a soft drop shadow. Single line, drawn in one pass.

const LETTER_COLORS: Array[Color] = [
	Color("8b5cf0"), Color("a24be0"), Color("d63fb5"), Color("f0288f"), Color("ff5a5f"), Color("ff8a1f"),
	Color("f2b705"), Color("3dc15f"), Color("19b6d2"), Color("3ea6ff"), Color("5b7bff"), Color("8b5cf0"),
]

@export var text: String = "PixelWhisper":
	set(v):
		text = v
		update_minimum_size()
		queue_redraw()
@export var font_size: int = 84:
	set(v):
		font_size = v
		update_minimum_size()
		queue_redraw()

const OUTLINE := 14


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	var f := AppTheme.font(900)
	var s := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return Vector2(ceilf(s.x) + OUTLINE, ceilf(f.get_height(font_size)) + OUTLINE)


func _draw() -> void:
	var f := AppTheme.font(900)
	var y := OUTLINE * 0.5 + f.get_ascent(font_size)
	var x0 := OUTLINE * 0.5
	# pass 1: outline + shadow under everything, pass 2: the colored letters
	for i in text.length():
		var ch := text[i]
		var x := x0 + f.get_string_size(text.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string_outline(f, Vector2(x, y + 5), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, OUTLINE, Color(0.35, 0.2, 0.5, 0.28))
	for i in text.length():
		var ch := text[i]
		var x := x0 + f.get_string_size(text.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string_outline(f, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, OUTLINE, Color.WHITE)
	for i in text.length():
		var ch := text[i]
		var x := x0 + f.get_string_size(text.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(f, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, LETTER_COLORS[i % LETTER_COLORS.size()])
