class_name LevelGenerator
extends RefCounted
## Turns any Image (bundled PNG or a PixelLab download) into a PixelLevel.
##
## 1. Scan every pixel with get_pixel(x, y) and build a histogram of unique colors.
## 2. If there are more than `max_colors`, quantize (see PaletteQuantizer).
## 3. Build the color -> numeric ID dictionary (the UI palette). IDs are assigned by
##    frequency, so "1" is the most common color and big areas get painted first.
## 4. Store one palette index per cell. No per-cell nodes are ever created.

const DEFAULT_MAX_COLORS := 28
const DEFAULT_MIN_CELLS := 6
const ALPHA_CUTOFF := 0.5

## opts: max_colors:int, min_cells:int, grid:int (resample to grid x grid), id:String,
##       title:String
static func generate(image: Image, opts: Dictionary = {}) -> PixelLevel:
	var img: Image = image.duplicate()
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var grid: int = opts.get("grid", 0)
	if grid > 0 and (img.get_width() != grid or img.get_height() != grid):
		img.resize(grid, grid, Image.INTERPOLATE_NEAREST)

	var w := img.get_width()
	var h := img.get_height()
	var max_colors: int = clampi(opts.get("max_colors", DEFAULT_MAX_COLORS), 2, 64)
	var min_cells: int = opts.get("min_cells", DEFAULT_MIN_CELLS)

	# 1) Scan.
	var raw_keys := PackedInt64Array()
	raw_keys.resize(w * h)
	var histogram := {}
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < ALPHA_CUTOFF:
				raw_keys[y * w + x] = -1
				continue
			c.a = 1.0
			var key := c.to_rgba32()
			raw_keys[y * w + x] = key
			histogram[key] = histogram.get(key, 0) + 1

	# 2) Reduce to a playable palette. Runs even when the color count is already low:
	#    generators leave stray 1-2 cell shades that nobody wants to hunt down.
	#    Pictures that are already clean come back unchanged.
	var mapping := PaletteQuantizer.reduce(histogram, max_colors, min_cells)

	# 3) Unique color -> numeric ID, most frequent first.
	var freq := {}
	for i in raw_keys.size():
		if raw_keys[i] != -1:
			var m: int = mapping[raw_keys[i]]
			freq[m] = freq.get(m, 0) + 1
	var ordered: Array = freq.keys()
	ordered.sort_custom(func(a, b): return freq[a] > freq[b] or (freq[a] == freq[b] and a < b))

	var color_to_id := {}
	var level := PixelLevel.new()
	for key in ordered:
		color_to_id[key] = level.palette.size()
		level.palette.append(Color.hex(key))

	# 4) Cells.
	level.width = w
	level.height = h
	level.cells.resize(w * h)
	for i in raw_keys.size():
		if raw_keys[i] == -1:
			level.cells[i] = PixelLevel.EMPTY
		else:
			level.cells[i] = color_to_id[mapping[raw_keys[i]]]
	level.recount()

	level.id = opts.get("id", "")
	level.title = opts.get("title", "")
	return level
