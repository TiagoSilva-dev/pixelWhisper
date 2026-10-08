class_name PixelLevel
extends RefCounted
## Immutable description of one color-by-number puzzle.
##
## The picture is stored as one palette index per cell (PackedByteArray) instead of
## one node per cell, so a 64x64 level costs ~4 KB and is trivial to save/restore.

const EMPTY := 255  ## Palette index of transparent cells (not paintable).

var id: String = ""
var title: String = ""
var width: int = 0
var height: int = 0
var palette: PackedColorArray = PackedColorArray()
var cells: PackedByteArray = PackedByteArray()
var counts: PackedInt32Array = PackedInt32Array()  ## Paintable cells per palette index.
var total_paintable: int = 0


func cell_count() -> int:
	return width * height


func index_of(x: int, y: int) -> int:
	return y * width + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func color_at(x: int, y: int) -> Color:
	var idx := cells[index_of(x, y)]
	return Color(0, 0, 0, 0) if idx == EMPTY else palette[idx]


func recount() -> void:
	counts = PackedInt32Array()
	counts.resize(palette.size())
	total_paintable = 0
	for i in cells.size():
		var idx := cells[i]
		if idx != EMPTY:
			counts[idx] += 1
			total_paintable += 1


## Full-color picture; transparent cells keep alpha 0. Used as the shader's "answer key".
func build_target_image() -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			img.set_pixel(x, y, color_at(x, y))
	return img


## Thumbnail: painted cells in color, the rest as a soft grayscale preview.
func build_progress_image(painted: PackedByteArray, grayscale_mix: float = 0.5) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var i := index_of(x, y)
			var c := color_at(x, y)
			if c.a == 0.0:
				img.set_pixel(x, y, c)
			elif i < painted.size() and painted[i] != 0:
				img.set_pixel(x, y, c)
			else:
				var lum := c.get_luminance()
				var g := lerpf(lum, 0.86, grayscale_mix)
				img.set_pixel(x, y, Color(g, g, g, 1.0))
	return img
