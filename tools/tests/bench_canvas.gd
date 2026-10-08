extends SceneTree
## CPU-side cost of the hot paths (headless, no GPU involved):
##   godot --headless --path . --script res://tools/tests/bench_canvas.gd
## The GPU side is a single draw call regardless of what is printed here.


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	_run()


func _ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0


func _run() -> void:
	await process_frame
	var lib = root.get_node("LevelLibrary")
	var canvas_script: GDScript = load("res://game/canvas_view.gd")
	var cv: Control = canvas_script.new()
	cv.size = Vector2(1080, 1500)
	root.add_child(cv)
	await process_frame

	var t0 := Time.get_ticks_usec()
	var lvl = lib.get_level("sea_turtle")   # the most colorful bundled level (26 colors)
	print("build level (scan + quantize)  : %6.2f ms" % _ms(t0))

	t0 = Time.get_ticks_usec()
	cv.set_level(lvl, PackedByteArray())
	print("CanvasView.set_level           : %6.2f ms   (%d cells, %d colors)" % [_ms(t0), lvl.cell_count(), lvl.palette.size()])

	# Paint everything silently, color by color, like a worst-case swipe.
	t0 = Time.get_ticks_usec()
	var painted := 0
	for c in lvl.palette.size():
		cv.select_color(c)
		for i in lvl.cell_count():
			if lvl.cells[i] == c and cv.paint_cell(i % lvl.width, i / lvl.width, true):
				painted += 1
	var total := _ms(t0)
	print("paint_cell x%d (silent)      : %6.2f ms total = %.1f us/cell" % [painted, total, total * 1000.0 / painted])

	# _process with the maximum realistic number of cells mid pop-animation.
	cv.set_level(lvl, PackedByteArray())
	cv.select_color(0)
	var n := 0
	for i in lvl.cell_count():
		if lvl.cells[i] == 0 and n < 400:
			cv.paint_cell(i % lvl.width, i / lvl.width, true)
			n += 1
	t0 = Time.get_ticks_usec()
	var frames := 20
	for f in frames:
		cv._process(1.0 / 60.0)
	print("_process with %3d popping cells : %6.3f ms/frame  (budget at 60 fps: 16.7 ms)" % [n, _ms(t0) / frames])

	t0 = Time.get_ticks_usec()
	for f in 100:
		cv._apply_view()
	print("_apply_view (pan/zoom step)    : %6.3f ms" % (_ms(t0) / 100.0))

	t0 = Time.get_ticks_usec()
	cv.select_color(3)
	var found: bool = cv.request_hint()
	print("request_hint (full scan)       : %6.3f ms  (found=%s)" % [_ms(t0), found])

	var gs = root.get_node("GameState")
	var packed: PackedByteArray = cv.painted
	t0 = Time.get_ticks_usec()
	for f in 50:
		gs.store_progress("bench", packed, 100, 4096)
	print("GameState.store_progress       : %6.3f ms  (deflate + base64)" % (_ms(t0) / 50.0))
	gs.forget_level("bench")
	quit()
