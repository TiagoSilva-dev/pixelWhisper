class_name GlyphAtlas
extends RefCounted
## Builds the digit font used by canvas_grid.gdshader.
##
## 5x7 pixel digits, 6 px per glyph cell (5 + 1 blank column) and 1 blank row above and
## below, so the atlas is 60 x 9. The blank padding is what lets the shader bilinear-filter
## the bitmap for smooth edges without bleeding into a neighbouring glyph.

const GLYPHS: Array[String] = [
	"01110" + "10001" + "10011" + "10101" + "11001" + "10001" + "01110",  # 0
	"00100" + "01100" + "00100" + "00100" + "00100" + "00100" + "01110",  # 1
	"01110" + "10001" + "00001" + "00010" + "00100" + "01000" + "11111",  # 2
	"11110" + "00001" + "00001" + "01110" + "00001" + "00001" + "11110",  # 3
	"00010" + "00110" + "01010" + "10010" + "11111" + "00010" + "00010",  # 4
	"11111" + "10000" + "11110" + "00001" + "00001" + "10001" + "01110",  # 5
	"00110" + "01000" + "10000" + "11110" + "10001" + "10001" + "01110",  # 6
	"11111" + "00001" + "00010" + "00100" + "01000" + "01000" + "01000",  # 7
	"01110" + "10001" + "10001" + "01110" + "10001" + "10001" + "01110",  # 8
	"01110" + "10001" + "10001" + "01111" + "00001" + "00010" + "01100",  # 9
]

static var _cached: ImageTexture


static func get_texture() -> ImageTexture:
	if _cached == null:
		_cached = ImageTexture.create_from_image(_build_image())
	return _cached


static func _build_image() -> Image:
	var img := Image.create(60, 9, false, Image.FORMAT_R8)
	for d in GLYPHS.size():
		var bits := GLYPHS[d]
		for row in 7:
			for col in 5:
				if bits[row * 5 + col] == "1":
					img.set_pixel(d * 6 + col, row + 1, Color(1, 1, 1, 1))
	return img
