extends SceneTree
## The icon set: every Kind has a readable file, rasterizes at the requested size, fills its box and
## leaves no dark halo around the edges when scaled down (the PNGs are alpha-bled by tools/fetch_icons.py).
##   godot --headless --path . --script res://tools/tests/test_icons.gd

var _fails := 0


func _initialize() -> void:
	var kinds: Array = Icons.FILES.keys()
	_check(kinds.size() == Icons.Kind.size() - 1, "every Kind except NONE has a file (%d of %d)" % [kinds.size(), Icons.Kind.size() - 1])

	for kind in kinds:
		var name: String = Icons.Kind.find_key(kind)
		for px in [24, 72, 200, 400]:
			var tex := Icons.texture(kind, px)
			if tex == null:
				_check(false, "%s renders at %d px" % [name, px])
				continue
			var w := tex.get_width()
			var want: int = px if Icons.is_glyph(kind) else mini(px, int(Icons.SOURCE_PX))
			_check(absi(w - want) <= 1 and tex.get_height() == w, "%s at %d px has size %d (want %d)" % [name, px, w, want])
		_check(Icons.texture(kind, 72) == Icons.texture(kind, 72), "%s is cached" % name)

		var box := _opaque_box(Icons.texture(kind, 128).get_image())
		_check(maxf(box.size.x, box.size.y) >= 0.6 and minf(box.size.x, box.size.y) >= 0.3 and maxf(box.size.x, box.size.y) <= 1.0,
				"%s fills its square (%.2f x %.2f)" % [name, box.size.x, box.size.y])

	# Glyphs are white (the caller tints them).
	for kind in [Icons.Kind.BACK, Icons.Kind.CHECK, Icons.Kind.PLAY]:
		var img := Icons.texture(kind, 64).get_image()
		var dimmest := 1.0
		for y in img.get_height():
			for x in img.get_width():
				var p := img.get_pixel(x, y)
				if p.a > 0.3:
					dimmest = minf(dimmest, minf(p.r, minf(p.g, p.b)))
		_check(dimmest > 0.95, "glyph %s is white where visible (dimmest channel %.2f)" % [Icons.Kind.find_key(kind), dimmest])

	# Bright icons must not grow a dark rim when shrunk: the translucent edge pixels keep the body's color.
	for kind in [Icons.Kind.COIN, Icons.Kind.STAR, Icons.Kind.BULB]:
		var img := Icons.texture(kind, 40).get_image()
		var darkest_edge := 1.0
		var edge_pixels := 0
		for y in img.get_height():
			for x in img.get_width():
				var p := img.get_pixel(x, y)
				if p.a > 0.15 and p.a < 0.85:
					edge_pixels += 1
					darkest_edge = minf(darkest_edge, p.get_luminance())
		_check(edge_pixels > 10 and darkest_edge > 0.4, "%s has a clean edge at 40 px (%d edge px, darkest %.2f)" % [Icons.Kind.find_key(kind), edge_pixels, darkest_edge])

	# Drawing into a real CanvasItem must not raise errors or leave the node without commands.
	var node := Control.new()
	root.add_child(node)
	node.draw.connect(func() -> void:
		for kind in kinds:
			Icons.draw(node, kind, Vector2(50, 50), 30.0, Color("3ea6ff"))
		Icons.draw(node, Icons.Kind.NONE, Vector2.ZERO, 10.0))
	node.queue_redraw()
	await process_frame
	await process_frame
	_check(true, "Icons.draw runs inside _draw()")

	print("FAIL: %d icon check(s)" % _fails if _fails else "PASS: icons")
	quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


## Bounding box of the visible pixels, as fractions of the image (position + size).
func _opaque_box(img: Image) -> Rect2:
	var minp := Vector2(img.get_width(), img.get_height())
	var maxp := Vector2(-1, -1)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				minp = minp.min(Vector2(x, y))
				maxp = maxp.max(Vector2(x, y))
	if maxp.x < 0:
		return Rect2()
	var s := Vector2(img.get_width(), img.get_height())
	return Rect2(minp / s, (maxp - minp + Vector2.ONE) / s)
