extends SceneTree
## Visual smoke test: drives the real Main scene (home -> game -> real mouse drag -> settings ->
## completion -> home -> settings over home) and saves a PNG of each state.
##   godot --path . --rendering-driver opengl3 --resolution 540x960 --script res://tools/tests/screenshot_tour.gd
## Output: user://shots/ (the path is printed).

const OUT := "user://shots/"
var main: Control


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func shot(name: String, settle: float = 0.25) -> void:
	await wait(settle)
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("saved ", ProjectSettings.globalize_path(OUT + name + ".png"))


func mouse(pos: Vector2, pressed: bool, rel := Vector2.ZERO, motion := false) -> void:
	# `pos` is in canvas (1080-wide) coordinates; the window is smaller, so scale it.
	var k := Vector2(root.size) / root.get_visible_rect().size  # canvas units -> window pixels
	pos *= k
	rel *= k
	var ev: InputEvent
	if motion:
		var m := InputEventMouseMotion.new()
		m.position = pos
		m.global_position = pos
		m.relative = rel
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		ev = m
	else:
		var b := InputEventMouseButton.new()
		b.position = pos
		b.global_position = pos
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		ev = b
	Input.parse_input_event(ev)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# Autoload _ready() runs AFTER this, so wipe the save before GameState loads it.
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	_run()


func _run() -> void:
	# fresh save so the run is reproducible
	await process_frame
	var gs = root.get_node("GameState")

	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await wait(1.2)
	await shot("10_home_fresh")

	main.open_level("fox")
	await wait(1.6)
	var game: Control = main.host.get_child(0)
	await shot("11_game_fit")

	# ---- real input: drag across cells with the mouse -----------------------
	var cv = game.canvas
	cv.select_color(0)
	game._select(0, false)
	var lvl = cv.level
	# find a horizontal run of cells of color 0, then drag along it
	var start := Vector2i(-1, -1)
	for y in lvl.height:
		for x in lvl.width - 8:
			var ok := true
			for k in 8:
				if lvl.cells[y * lvl.width + x + k] != 0:
					ok = false
					break
			if ok:
				start = Vector2i(x, y)
				break
		if start.x >= 0:
			break
	print("drag run starts at ", start, " color0 cells=", lvl.counts[0])
	var before: int = cv.painted_total
	var p0: Vector2 = cv.global_position + cv._cell_center_local(start)
	mouse(p0, true)
	for k in range(1, 9):
		var p := p0 + Vector2(k * cv.zoom, 0)
		mouse(p, false, Vector2(cv.zoom, 0), true)
		await process_frame
	mouse(p0 + Vector2(8 * cv.zoom, 0), false)
	await process_frame
	print("painted by drag: ", cv.painted_total - before, " (expected 9)")

	# paint a lot more through the API so the picture looks in-progress
	for c in lvl.palette.size():
		if c % 2 == 0 and c < 12:
			cv.select_color(c)
			for i in lvl.cell_count():
				if lvl.cells[i] == c and (i % 5) != 0:
					cv.paint_cell(i % lvl.width, i / lvl.width, true)
	game._select(1, true)
	await shot("12_game_progress", 0.8)

	cv.focus_cell(Vector2i(32, 28), 34.0, 0.0)
	await shot("13_game_zoomed")

	game._open_settings()
	await shot("14_settings", 0.6)
	game._modal.close()
	await wait(0.5)

	# ---- finish the level to see the win flow --------------------------------
	cv.fit_view(false)
	for c in lvl.palette.size():
		cv.select_color(c)
		for i in lvl.cell_count():
			if lvl.cells[i] == c and cv.painted[i] == 0:
				cv.paint_cell(i % lvl.width, i / lvl.width, true)
	await wait(0.9)
	await shot("15_completion_reveal", 0.1)
	await wait(2.6)
	await shot("16_win_overlay", 0.5)

	game._modal.home_pressed.emit()
	await wait(1.4)
	await shot("17_home_with_progress", 0.4)

	# ---- settings dialog over the gallery (backdrop blur) -------------------------
	var home: Control = main.host.get_child(0)
	home.settings_button.pressed.emit()
	await shot("18_settings_over_home", 0.8)
	print("DONE")
	quit()
