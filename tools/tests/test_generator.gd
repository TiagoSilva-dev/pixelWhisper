extends SceneTree
## Headless check of LevelGenerator + PaletteQuantizer against the bundled PNGs.
##   godot --headless --path . --script res://tools/tests/test_generator.gd

const DIR := "res://assets/levels/"


func _init() -> void:
	var failures := 0
	var dir := DirAccess.open(DIR)
	var files: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".png"):
			files.append(f)
	files.sort()

	for f in files:
		var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + f))
		var t0 := Time.get_ticks_usec()
		var lvl := LevelGenerator.generate(img, {"id": f})
		var ms := (Time.get_ticks_usec() - t0) / 1000.0

		var unique := {}
		for y in img.get_height():
			for x in img.get_width():
				unique[img.get_pixel(x, y).to_rgba32()] = true

		# Mean OKLab error between source and quantized picture.
		var err := 0.0
		for y in lvl.height:
			for x in lvl.width:
				err += PaletteQuantizer.to_oklab(img.get_pixel(x, y)).distance_to(
						PaletteQuantizer.to_oklab(lvl.color_at(x, y)))
		err /= float(lvl.cell_count())

		var sum := 0
		for n in lvl.counts:
			sum += n
		var ok := sum == lvl.cell_count() and lvl.total_paintable == lvl.cell_count() \
				and lvl.palette.size() <= LevelGenerator.DEFAULT_MAX_COLORS \
				and lvl.counts[lvl.counts.size() - 1] >= LevelGenerator.DEFAULT_MIN_CELLS  # sorted by frequency
		if not ok:
			failures += 1
		print("%-20s %s  src=%2d -> palette=%2d  smallest=%3d cells  err=%.4f  %.1f ms" % [
				f, "OK  " if ok else "FAIL", unique.size(), lvl.palette.size(),
				lvl.counts[lvl.counts.size() - 1], err, ms])

	print("\n%d level(s), %d failure(s)" % [files.size(), failures])
	quit(1 if failures > 0 else 0)
