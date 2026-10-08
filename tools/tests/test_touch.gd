extends SceneTree
## Synthetic multi-touch against the real game screen. Needs a window (not --headless):
##   godot --path . --rendering-driver opengl3 --resolution 540x960 --script res://tools/tests/test_touch.gd
##
##  1. single-finger drag paints a run of cells
##  2. quick tap paints one cell
##  3. two-finger pinch zooms, two-finger drag pans, and neither paints
##  4. a wrong-number tap emits wrong_tapped, and nothing gets painted

var main: Control
var cv
var game: Control
var k := Vector2.ONE   # canvas units -> window pixels


func touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos * k
	e.pressed = pressed
	Input.parse_input_event(e)


func drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos * k
	e.relative = rel * k
	Input.parse_input_event(e)


func frames(n: int = 2) -> void:
	for i in n:
		await process_frame


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func cell_pos(c: Vector2i) -> Vector2:
	return cv.global_position + cv._cell_center_local(c)


func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  "), name, "  ", detail)


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	_run()


func _run() -> void:
	await process_frame
	k = Vector2(root.size) / root.get_visible_rect().size
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await wait(1.0)
	main.open_level("fox")
	await wait(1.6)
	game = main.host.get_child(0)
	cv = game.canvas
	var lvl = cv.level

	# find a horizontal run of 8 cells of color 0 and select it
	var start := Vector2i(-1, -1)
	for y in lvl.height:
		for x in lvl.width - 8:
			var ok := true
			for i in 8:
				if lvl.cells[y * lvl.width + x + i] != 0:
					ok = false
					break
			if ok:
				start = Vector2i(x, y)
				break
		if start.x >= 0:
			break
	game._select(0, false)

	# 1) one-finger drag along the run
	var before: int = cv.painted_total
	var p0 := cell_pos(start)
	touch(0, p0, true)
	await wait(0.12)   # longer than TAP_ARM_MS so the stroke is armed
	for i in range(1, 9):
		var p := p0 + Vector2(i * cv.zoom, 0)
		drag(0, p, Vector2(cv.zoom, 0))
		await frames(1)
	touch(0, p0 + Vector2(8 * cv.zoom, 0), false)
	await frames()
	var painted: int = cv.painted_total - before
	check("1-finger drag paints the run (9 cells)", painted == 9, "painted=%d" % painted)

	# 2) quick tap on a single color-0 cell outside the run
	var tap_cell := Vector2i(-1, -1)
	for i in lvl.cell_count():
		if lvl.cells[i] == 0 and cv.painted[i] == 0:
			tap_cell = Vector2i(i % lvl.width, i / lvl.width)
			break
	before = cv.painted_total
	cv.focus_cell(tap_cell, 40.0, 0.0)
	await frames(3)
	var tp := cell_pos(tap_cell)
	touch(0, tp, true)
	await frames(1)
	touch(0, tp, false)
	await frames(2)
	check("quick tap paints exactly one cell", cv.painted_total - before == 1, "delta=%d" % (cv.painted_total - before))

	# 3) two-finger pinch: zoom out, no painting
	cv.fit_view(false)
	await frames(3)
	var z0: float = cv.zoom
	var centre: Vector2 = cv.global_position + cv.size * 0.5
	before = cv.painted_total
	var a := centre + Vector2(-60, 0)
	var b := centre + Vector2(60, 0)
	touch(0, a, true)
	touch(1, b, true)
	await frames(1)
	for i in 10:
		a += Vector2(-14, 0)
		b += Vector2(14, 0)
		drag(0, a, Vector2(-14, 0))
		drag(1, b, Vector2(14, 0))
		await frames(1)
	touch(0, a, false)
	touch(1, b, false)
	await frames(2)
	check("pinch-out zooms in", cv.zoom > z0 * 1.5, "zoom %.1f -> %.1f" % [z0, cv.zoom])
	check("pinch never paints", cv.painted_total == before, "delta=%d" % (cv.painted_total - before))

	# 3b) two-finger pan
	var off0: Vector2 = cv.view_offset
	a = centre + Vector2(-40, 0)
	b = centre + Vector2(40, 0)
	touch(0, a, true)
	touch(1, b, true)
	await frames(1)
	for i in 8:
		a += Vector2(0, 18)
		b += Vector2(0, 18)
		drag(0, a, Vector2(0, 18))
		drag(1, b, Vector2(0, 18))
		await frames(1)
	touch(0, a, false)
	touch(1, b, false)
	await frames(2)
	check("two-finger drag pans", cv.view_offset.distance_to(off0) > 40.0, "offset moved %.0f px" % cv.view_offset.distance_to(off0))

	# 3c) the finger that stays down after a pinch must not paint
	cv.fit_view(false)
	await frames(3)
	before = cv.painted_total
	a = centre + Vector2(-60, 0)
	b = centre + Vector2(60, 0)
	touch(0, a, true)
	touch(1, b, true)
	await frames(1)
	touch(1, b, false)          # lift one finger, keep the other moving over color-0 cells
	await frames(1)
	for i in 6:
		a += Vector2(10, 0)
		drag(0, a, Vector2(10, 0))
		await frames(1)
	touch(0, a, false)
	await frames(2)
	check("leftover finger after pinch does not paint", cv.painted_total == before, "delta=%d" % (cv.painted_total - before))

	# 4) wrong-number tap
	var wrong_cell := Vector2i(-1, -1)
	for i in lvl.cell_count():
		if lvl.cells[i] != 0 and cv.painted[i] == 0:
			wrong_cell = Vector2i(i % lvl.width, i / lvl.width)
			break
	cv.focus_cell(wrong_cell, 40.0, 0.0)
	await frames(3)
	var got: Array = [-1]
	cv.wrong_tapped.connect(func(idx): got[0] = idx)
	before = cv.painted_total
	var wp := cell_pos(wrong_cell)
	touch(0, wp, true)
	await wait(0.12)
	touch(0, wp, false)
	await frames(2)
	check("wrong-number tap reports the tapped number and paints nothing",
			got[0] == lvl.cells[wrong_cell.y * lvl.width + wrong_cell.x] and cv.painted_total == before,
			"reported=%d painted_delta=%d" % [got[0], cv.painted_total - before])

	# 5) a press on the floating wand button must not paint the cell underneath.
	#    No wands left, and the color of the cell under the button is selected: only a leak
	#    of the touch into the canvas could paint it.
	# Camera placed so the bottom-left of the image sits right under the wand button.
	cv.focus_cell(Vector2i(20, 30), 30.0, 0.0)  # mid-image: the wand button then covers real cells
	await frames(3)
	var wand = game.wand_button
	var wc: Vector2 = wand.global_position + wand.size * 0.5
	var under: Vector2i = cv._cell_at(wc - cv.global_position)
	var under_idx: int = lvl.cells[under.y * lvl.width + under.x]
	root.get_node("GameState").wands = 0
	game._select(under_idx, false)
	var cell_i: int = under.y * lvl.width + under.x
	var was_painted: int = cv.painted[cell_i]
	touch(0, wc, true)
	await wait(0.12)
	touch(0, wc, false)
	await frames(2)
	check("press on a floating button never paints under it",
			was_painted == 0 and cv.painted[cell_i] == 0,
			"cell %s color %d painted=%d (was %d)" % [under, under_idx, cv.painted[cell_i], was_painted])

	# 5b) control experiment: the same press on a plain canvas spot DOES paint
	var spot: Vector2 = cv.global_position + Vector2(cv.size.x * 0.5, 40.0)
	var spot_cell: Vector2i = cv._cell_at(spot - cv.global_position)
	var spot_i: int = spot_cell.y * lvl.width + spot_cell.x
	game._select(lvl.cells[spot_i], false)
	touch(0, spot, true)
	await wait(0.12)
	touch(0, spot, false)
	await frames(2)
	check("control: same press on free canvas paints", cv.painted[spot_i] == 1, "cell %s" % spot_cell)
	quit()
