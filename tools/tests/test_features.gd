extends SceneTree
## Logic tests for the coin economy, the color symphony, the three power-ups, the time-lapse and
## the haptics. No window needed:
##   godot --headless --path . --script res://tools/tests/test_features.gd
## Every check prints PASS or FAIL (tools/run_tests.sh greps for FAIL).

var gs: Node
var fb: Node
var lib: Node


func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  "), name, "  ", detail)


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	_run()


func _run() -> void:
	await process_frame
	gs = root.get_node("GameState")
	fb = root.get_node("Feedback")
	lib = root.get_node("LevelLibrary")

	_test_economy()
	await _test_symphony()
	_test_recorder()
	await _test_canvas_power_ups()
	await _test_timelapse_playback()
	await _test_game_screen()
	quit()


# ---------------------------------------------------------------------------------
# coins
# ---------------------------------------------------------------------------------

func _test_economy() -> void:
	print("--- economy")
	check("starts with 250 coins", gs.coins == 250, "coins=%d" % gs.coins)
	check("spend 40 -> 210", gs.spend_coins(40) and gs.coins == 210)
	check("cannot overspend; wallet unchanged", not gs.spend_coins(1000) and gs.coins == 210)
	check("costs: wand 40 / bomb 25 / magnifier 15", gs.COST_WAND == 40 and gs.COST_BOMB == 25 and gs.COST_MAGNIFIER == 15)
	var before: int = gs.coins
	check("daily gift grants once", gs.claim_daily_gift() == gs.DAILY_GIFT and gs.coins == before + gs.DAILY_GIFT)
	check("daily gift cannot be claimed twice the same day", gs.claim_daily_gift() == 0 and gs.coins == before + gs.DAILY_GIFT)
	before = gs.coins
	check("first completion pays the reward", gs.mark_completed("econ_test") and gs.coins == before + gs.LEVEL_REWARD)
	before = gs.coins
	check("second completion pays nothing", not gs.mark_completed("econ_test") and gs.coins == before)
	gs.note_activity()
	check("painting today counts as a 1-day streak", gs.streak_days() == 1, "streak=%d" % gs.streak_days())
	gs.forget_level("econ_test")
	gs.coins = gs.STARTING_COINS


# ---------------------------------------------------------------------------------
# color symphony + pitch modulator
# ---------------------------------------------------------------------------------

func _test_symphony() -> void:
	print("--- symphony")
	var ratios: Array[float] = []
	for i in 10:
		ratios.append(fb.note_ratio(i))
	var ascending := true
	for i in range(1, 10):
		if ratios[i] <= ratios[i - 1]:
			ascending = false
	check("color 1 is the base note", is_equal_approx(ratios[0], 1.0))
	check("notes rise with the color number (10 distinct notes)", ascending)
	check("colors past the scale wrap around", is_equal_approx(fb.note_ratio(10), 1.0) and is_equal_approx(fb.note_ratio(13), ratios[3]))
	check("highest note x highest bend stays below pitch_scale 4", ratios[9] * fb.JITTER_MAX < 4.0, "%.2f" % (ratios[9] * fb.JITTER_MAX))
	check("pentatonic: color 1 and 2 are a whole tone apart", is_equal_approx(ratios[1], pow(2.0, 2.0 / 12.0)))

	await wait(0.1)
	var lo := 9.0
	var hi := 0.0
	var min_gap := 9.0
	var last_j := -1.0
	var out_of_range := 0
	var played := 0
	for n in 300:
		var color := n % 28
		if fb.pop(color):
			played += 1
			var j: float = fb._last_pitch / fb.note_ratio(color)
			lo = minf(lo, j)
			hi = maxf(hi, j)
			if j < 0.95 - 0.0001 or j > 1.15 + 0.0001:
				out_of_range += 1
			if last_j > 0.0:
				min_gap = minf(min_gap, absf(j - last_j))
			last_j = j
		await create_timer(0.03).timeout
	check("every pixel bends the note by 0.95..1.15", out_of_range == 0 and played > 200,
			"played=%d bend %.3f..%.3f" % [played, lo, hi])
	check("consecutive pixels never repeat the same bend", min_gap >= fb.MIN_JITTER_GAP - 0.0001, "min step %.3f" % min_gap)
	check("two instruments loaded (Kalimba + Marimba)", fb._pops.size() == 2)


# ---------------------------------------------------------------------------------
# time-lapse recorder
# ---------------------------------------------------------------------------------

func _test_recorder() -> void:
	print("--- recorder")
	var r := TimelapseRecorder.new()
	r.record(5, 1000)
	r.record(7, 1100)
	r.record(9, 101100)   # a 100 s pause in between
	check("events are stacked in paint order", r.cells == PackedInt32Array([5, 7, 9]))
	check("timestamps are active time (a long pause is squeezed to 3 s)", r.times == PackedInt32Array([0, 100, 3100]),
			str(r.times))

	var back := TimelapseRecorder.from_bytes(r.to_bytes())
	check("persistence round-trip keeps cells and times", back.cells == r.cells and back.times == r.times,
			"%s %s" % [back.cells, back.times])
	check("persisted size is 4 bytes per event", r.to_bytes().size() == 12)

	var painted := PackedByteArray()
	painted.resize(20)
	painted[5] = 1
	painted[9] = 1
	painted[11] = 1    # painted before history existed
	painted[7] = 0     # reset since: its event must go
	r.reconcile(painted)
	check("reconcile drops unpainted cells and prepends legacy ones", r.cells == PackedInt32Array([11, 5, 9]), str(r.cells))

	var tl := r.timeline(10.0, 3.0, 40.0)
	check("a short film is stretched to at least 3 s", is_equal_approx(tl[tl.size() - 1], 3.0), "%.2f" % tl[tl.size() - 1])

	var long := TimelapseRecorder.new()
	long.record(1, 0)
	for k in 200:
		long.record(2 + k, (k + 1) * 3000)   # 10 minutes of active time
	var tl2 := long.timeline(10.0, 3.0, 40.0)
	check("a long film is capped at 40 s (faster than 10x)", is_equal_approx(tl2[tl2.size() - 1], 40.0), "%.2f" % tl2[tl2.size() - 1])
	var mid := long.timeline(10.0, 3.0, 400.0)
	check("nominal rate is 10x real time", is_equal_approx(mid[mid.size() - 1], 600.0 / 10.0), "%.2f" % mid[mid.size() - 1])
	check("timeline is monotonic", _monotonic(tl2))


func _monotonic(a: PackedFloat32Array) -> bool:
	for i in range(1, a.size()):
		if a[i] < a[i - 1]:
			return false
	return true


# ---------------------------------------------------------------------------------
# wand / bomb / magnifier on the canvas
# ---------------------------------------------------------------------------------

func _make_canvas(level_id: String) -> Control:
	var cv: Control = load("res://game/canvas_view.gd").new()
	root.add_child(cv)
	cv.size = Vector2(1000, 1000)
	cv.set_level(lib.get_level(level_id), PackedByteArray())
	return cv


func _test_canvas_power_ups() -> void:
	print("--- power-ups on the canvas")
	var cv := _make_canvas("fox")
	await process_frame
	cv.fit_view(false)
	await process_frame
	var lvl = cv.level

	# --- wand, whole picture on screen: every cell of the selected color ---
	var c := 0
	cv.select_color(c)
	var expect: int = cv.remaining[c]
	var queued: int = cv.use_wand()
	check("wand (picture fits on screen) queues every cell of the color", queued == expect, "%d of %d" % [queued, expect])
	await wait(0.9)
	check("...and paints all of them", cv.remaining[c] == 0 and cv.pending_cells() == 0, "left=%d" % cv.remaining[c])
	check("the wand never touches other colors", cv.painted_total == expect, "painted_total=%d" % cv.painted_total)

	# --- wand while zoomed in: only what is on screen ---
	c = 1
	cv.select_color(c)
	cv.focus_cell(Vector2i(32, 32), 60.0, 0.0)
	await process_frame
	var tl: Vector2i = cv._cell_at(Vector2.ZERO)
	var br: Vector2i = cv._cell_at(cv.size)
	var visible_cells := 0
	for y in range(maxi(tl.y, 0), mini(br.y, lvl.height - 1) + 1):
		for x in range(maxi(tl.x, 0), mini(br.x, lvl.width - 1) + 1):
			if lvl.cells[y * lvl.width + x] == c and cv.painted[y * lvl.width + x] == 0:
				visible_cells += 1
	var all_left: int = cv.remaining[c]
	var q2: int = cv.use_wand()
	check("wand (zoomed in) queues only the visible cells of the color", q2 == visible_cells and q2 < all_left,
			"queued=%d visible=%d all=%d" % [q2, visible_cells, all_left])
	await wait(0.9)
	check("...the rest of the color stays unpainted", cv.remaining[c] == all_left - q2)

	# --- bomb: 5x5 square, every color ---
	cv.fit_view(false)
	await process_frame
	var centre := Vector2i(32, 40)
	var expect_bomb := 0
	var outside_before := 0
	for y in lvl.height:
		for x in lvl.width:
			var i: int = y * lvl.width + x
			if lvl.cells[i] == PixelLevel.EMPTY or cv.painted[i] != 0:
				continue
			if absi(x - centre.x) <= 2 and absi(y - centre.y) <= 2:
				expect_bomb += 1
	var total_before: int = cv.painted_total
	var colors_in_square := {}
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			colors_in_square[lvl.cells[(centre.y + dy) * lvl.width + centre.x + dx]] = true
	var painted_n: int = cv.apply_bomb(centre)
	await wait(0.6)
	check("bomb paints the whole 5x5 square", painted_n == expect_bomb and cv.painted_total == total_before + expect_bomb,
			"queued=%d expected=%d delta=%d" % [painted_n, expect_bomb, cv.painted_total - total_before])
	var square_ok := true
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var i: int = (centre.y + dy) * lvl.width + centre.x + dx
			if lvl.cells[i] != PixelLevel.EMPTY and cv.painted[i] == 0:
				square_ok = false
	check("every cell of the square is painted, whatever its color", square_ok, "%d colors in the square" % colors_in_square.size())
	var neighbour: int = (centre.y + 3) * lvl.width + centre.x
	check("cells just outside the square are untouched", cv.painted[neighbour] == 0 or lvl.cells[neighbour] == PixelLevel.EMPTY)
	check("bomb on a painted spot paints nothing", cv.apply_bomb(centre) == 0)
	var corner: int = cv.apply_bomb(Vector2i(0, 0))
	check("bomb in a corner is clipped to the picture (<= 9 cells)", corner <= 9, "queued=%d" % corner)
	await wait(0.5)

	# --- armed bomb: the next tap drops it, then it disarms ---
	var drops := []
	cv.bomb_dropped.connect(func(cell: Vector2i, n: int) -> void: drops.append([cell, n]))
	cv.armed_tool = &"bomb"
	var spot := Vector2i(10, 50)
	cv._begin_stroke(cv._cell_center_local(spot))
	await wait(0.5)
	check("armed bomb drops on the tapped cell and disarms", drops.size() == 1 and drops[0][0] == spot and cv.armed_tool == &"",
			str(drops))
	var painted_by_tap: int = cv.painted_total
	cv._begin_stroke(cv._cell_center_local(Vector2i(50, 10)))
	check("a normal tap afterwards paints as usual (no bomb)", drops.size() == 1)

	# --- magnifier ---
	cv.select_color(3)
	cv.fit_view(false)
	await process_frame
	var idx: int = cv.magnify()
	await wait(1.2)
	var target: Vector2i = cv._hint_cell
	var on_screen: Vector2 = cv._cell_center_local(target)
	check("magnifier returns the color of a missing cell", idx >= 0 and lvl.cells[target.y * lvl.width + target.x] == idx and cv.painted[target.y * lvl.width + target.x] == 0,
			"idx=%d cell=%s" % [idx, target])
	check("...prefers the selected color when it still has cells", idx == 3 or cv.remaining[3] == 0)
	check("...and zooms deep (>= 50 px per cell)", cv.zoom >= 50.0, "zoom=%.1f" % cv.zoom)
	check("...with that cell centred on screen", on_screen.distance_to(cv.size * 0.5) < 8.0, "off by %.1f px" % on_screen.distance_to(cv.size * 0.5))

	cv.queue_free()
	await process_frame


# ---------------------------------------------------------------------------------
# time-lapse playback
# ---------------------------------------------------------------------------------

func _test_timelapse_playback() -> void:
	print("--- time-lapse playback")
	var cv := _make_canvas("astronaut")
	await process_frame
	cv.fit_view(false)
	var lvl = cv.level
	# paint colors 0 and 1 in full, silently, with a little real time between strokes
	for c in 2:
		cv.select_color(c)
		for i in lvl.cell_count():
			if lvl.cells[i] == c:
				cv.paint_cell(i % lvl.width, i / lvl.width, true)
		await wait(0.05)
	var painted_snapshot: PackedByteArray = cv.painted.duplicate()
	var total: int = cv.painted_total
	var remaining_snapshot: PackedInt32Array = cv.remaining.duplicate()
	check("recorder saw every painted cell once", cv.recorder.size() == total, "%d events, %d cells" % [cv.recorder.size(), total])

	cv.play_timelapse()   # runs in the background; resolves when the film ends
	await wait(0.25)
	check("replay is running", cv.is_playing_timelapse())
	check("replay blocks painting", not cv.input_enabled)
	var flagged := _flagged(cv)
	check("the canvas was rewound to blank at the start", flagged < total, "%d of %d cells shown" % [flagged, total])
	await wait(1.8)
	var mid := _flagged(cv)
	check("cells reappear as the film plays", mid > flagged and mid < total, "%d -> %d of %d" % [flagged, mid, total])
	check("progress data is untouched while replaying", cv.painted == painted_snapshot and cv.remaining == remaining_snapshot and cv.painted_total == total)
	var finished := [false]
	cv.timelapse_finished.connect(func() -> void: finished[0] = true)
	var waited := 0.0
	while not finished[0] and waited < 8.0:
		await wait(0.1)
		waited += 0.1
	check("the film ends by itself (3 s minimum, nominal 10x)", finished[0] and not cv.is_playing_timelapse(), "after ~%.1fs" % waited)
	check("at the end every painted cell is shown again", _flagged(cv) == total, "%d of %d" % [_flagged(cv), total])
	check("painting is enabled again", cv.input_enabled)

	# a tap/back skips it
	cv.play_timelapse()
	await wait(0.3)
	cv.stop_timelapse()
	await process_frame
	check("stop_timelapse restores the picture at once", not cv.is_playing_timelapse() and _flagged(cv) == total and cv.input_enabled)
	cv.queue_free()
	await process_frame


## How many cells the state texture currently shows as painted.
func _flagged(cv: Control) -> int:
	var n := 0
	var img: Image = cv._state_img
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).g > 0.5:
				n += 1
	return n


# ---------------------------------------------------------------------------------
# the real game screen: prices, haptics, saving, confetti, win
# ---------------------------------------------------------------------------------

func _test_game_screen() -> void:
	print("--- game screen")
	gs.coins = 250
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await wait(0.8)
	main.open_level("moon_owl")
	await wait(1.4)
	var game: Control = main.host.get_child(0)
	var cv = game.canvas
	var lvl = cv.level
	var buzz: Array[int] = []
	fb.vibrated.connect(func(ms: int) -> void: buzz.append(ms))

	# --- haptics: 25 ms per painted cell, 100 ms when a color is finished ---
	var smallest := 0
	for c in lvl.palette.size():
		if lvl.counts[c] < lvl.counts[smallest]:
			smallest = c
	game._select(smallest, false)
	var cells: Array[int] = []
	for i in lvl.cell_count():
		if lvl.cells[i] == smallest:
			cells.append(i)
	await wait(0.1)
	cv.paint_cell(cells[0] % lvl.width, cells[0] / lvl.width)
	check("painting a cell vibrates for 25 ms", buzz.size() >= 1 and buzz[0] == 25, str(buzz))
	for k in range(1, cells.size()):
		cv.paint_cell(cells[k] % lvl.width, cells[k] / lvl.width, true)   # silent: no more haptics
	await wait(0.2)
	check("finishing a color vibrates for 100 ms", buzz.has(100), str(buzz))

	# --- prices ---
	game._select(0 if smallest != 0 else 1, false)
	var coins0: int = gs.coins
	var painted0: int = cv.painted_total
	game._on_wand()
	await wait(0.8)
	check("magic wand costs 40 coins and paints", gs.coins == coins0 - 40 and cv.painted_total > painted0,
			"coins %d -> %d, painted +%d" % [coins0, gs.coins, cv.painted_total - painted0])

	coins0 = gs.coins
	game._on_bomb()
	check("ink bomb arms without charging", cv.armed_tool == &"bomb" and gs.coins == coins0)
	check("the bomb slot shows it is armed", game.bomb_button.armed)
	var spot := Vector2i(32, 32)
	painted0 = cv.painted_total
	cv._begin_stroke(cv._cell_center_local(spot))
	await wait(0.6)
	check("dropping the bomb costs 25 coins", gs.coins == coins0 - 25 and cv.painted_total >= painted0, "coins %d -> %d" % [coins0, gs.coins])
	check("...and disarms it", cv.armed_tool == &"" and not game.bomb_button.armed)

	game._on_bomb()
	game._on_bomb()
	check("tapping the armed bomb again cancels it for free", cv.armed_tool == &"" and gs.coins == coins0 - 25)

	coins0 = gs.coins
	game._on_magnifier()
	await wait(1.1)
	check("magnifier costs 15 coins and zooms in", gs.coins == coins0 - 15 and cv.zoom > 40.0, "coins %d -> %d zoom %.0f" % [coins0, gs.coins, cv.zoom])

	# --- broke: nothing is charged, nothing happens ---
	gs.add_coins(10 - gs.coins)
	cv.fit_view(false)
	await wait(0.5)
	var painted1: int = cv.painted_total
	game._on_wand()
	game._on_bomb()
	game._on_magnifier()
	await wait(0.4)
	check("with 10 coins nothing is bought", gs.coins == 10 and cv.painted_total == painted1 and cv.armed_tool == &"" and cv.zoom < 40.0,
			"coins=%d armed=%s" % [gs.coins, cv.armed_tool])
	await wait(0.6)
	check("the coin pill follows the wallet", game.coins._label.text == "10", game.coins._label.text)

	# --- saving keeps the time-lapse ---
	game._save_progress()
	var saved: PackedByteArray = gs.get_timelapse("moon_owl")
	check("progress is saved together with the time-lapse history", saved.size() == cv.painted_total * 4,
			"%d bytes for %d painted cells" % [saved.size(), cv.painted_total])

	# --- time-lapse from the settings dialog (the dialog closing must not leave painting disabled) ---
	game._open_settings()
	await wait(0.4)
	game._play_timelapse(false)
	await wait(0.7)
	check("time-lapse from the settings dialog starts the film", cv.is_playing_timelapse())
	var spent := 0.0
	while cv.is_playing_timelapse() and spent < 12.0:
		await wait(0.2)
		spent += 0.2
	await wait(0.3)
	check("...and painting is enabled again afterwards", cv.input_enabled and not cv.is_playing_timelapse(), "input_enabled=%s" % cv.input_enabled)

	# --- finish the picture: confetti + win overlay + reward ---
	gs.add_coins(100 - gs.coins)
	for c in lvl.palette.size():
		cv.select_color(c)
		for i in lvl.cell_count():
			if lvl.cells[i] == c and cv.painted[i] == 0:
				cv.paint_cell(i % lvl.width, i / lvl.width, true)
	await wait(0.3)
	var firing := false
	for p in game.confetti._confetti:
		firing = firing or p.emitting
	check("100% fires the confetti particles (GPUParticles2D)", firing and game.confetti._confetti.size() == 3)
	await wait(3.2)
	check("the win overlay appears", _is_win_overlay(game._modal))
	check("first completion pays 60 coins", gs.coins == 160, "coins=%d" % gs.coins)
	check("the win overlay offers the time-lapse", _has_button(game._modal, "Time-lapse"))

	game._modal.timelapse_pressed.emit()
	await wait(0.8)
	check("time-lapse button starts the film", cv.is_playing_timelapse())
	var waited := 0.0
	while cv.is_playing_timelapse() and waited < 12.0:
		await wait(0.2)
		waited += 0.2
	await wait(1.0)
	check("after the film the win overlay comes back", is_instance_valid(game._modal) and _is_win_overlay(game._modal))

	main.queue_free()
	await process_frame


## (Not `is WinOverlay`: naming a class that reaches an autoload would break this script's compile.)
func _is_win_overlay(n: Object) -> bool:
	return is_instance_valid(n) and n.has_signal("timelapse_pressed")


func _has_button(node: Node, text: String) -> bool:
	if node is Button and (node as Button).text == text:
		return true
	for c in node.get_children():
		if _has_button(c, text):
			return true
	return false
