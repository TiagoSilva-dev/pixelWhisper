extends SceneTree
## Visual smoke test: drives the real Main scene through every tab of the hub, a game with real
## mouse input, the three power-ups, the time-lapse, the win flow and the dialogs, saving a PNG
## of each state.
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
	await process_frame
	var gs = root.get_node("GameState")
	var ads = root.get_node("Ads")
	ads.provider.seconds = 2.0        # the fake ads close by themselves, so the tour never waits for a tap
	ads.provider.auto_close = true

	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await wait(1.4)
	await shot("10_home_fresh")

	var home: Control = main.host.get_child(0)
	home.nav._on_tapped(&"categories")
	await shot("11_tab_categories", 0.6)
	home.nav._on_tapped(&"diary")
	await shot("12_tab_diary", 0.6)
	home.nav._on_tapped(&"shop")
	await shot("13_tab_shop", 0.6)
	home.nav._on_tapped(&"profile")
	await shot("14_tab_profile", 0.6)
	home.nav._on_tapped(&"home")
	await wait(0.3)
	home._pages[&"home"]._bar._on_pill(&"animals")
	await shot("15_home_animals", 0.9)
	home._pages[&"home"]._bar._on_pill(&"anime")
	await shot("16_home_anime", 0.5)
	home._pages[&"home"]._bar._on_pill(&"anime")   # clear the filter again

	# ---- Premium: locked pictures, the dialog, the (fake) rewarded video ------------------------
	home._pages[&"home"]._bar._on_pill(&"premium")
	await shot("17_home_premium", 0.9)
	home._pages[&"home"]._bar._on_pill(&"premium")
	home._on_level_chosen("baby_unicorn")
	await shot("18_unlock_dialog", 0.7)
	home._modal._on_watch()
	await shot("19_fake_rewarded_ad", 0.8)
	await wait(2.6)                   # the video ends by itself and the picture opens
	main.host.get_child(0)._go_home()
	await wait(1.6)
	home = main.host.get_child(0)

	main.open_level("fox")
	await wait(1.6)
	var game: Control = main.host.get_child(0)
	await shot("20_game_fit")

	# ---- real input: drag across cells with the mouse -----------------------
	var cv = game.canvas
	cv.select_color(0)
	game._select(0, false)
	var lvl = cv.level
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
	await shot("21_game_progress", 0.8)

	# ---- power-ups ----------------------------------------------------------------------
	var coins_before: int = gs.coins
	game._on_wand()
	await wait(0.2)
	await shot("22_wand_cascade", 0.05)
	await wait(0.9)
	print("wand: coins %d -> %d" % [coins_before, gs.coins])
	game._on_bomb()
	await shot("23_bomb_armed", 0.3)
	var target := Vector2i(30, 30)
	cv._begin_stroke(cv._cell_center_local(target))
	await wait(0.15)
	await shot("24_bomb_blast", 0.05)
	await wait(0.6)
	game._on_magnifier()
	await shot("25_magnifier_zoom", 1.1)

	cv.fit_view(false)
	await wait(0.3)
	game._open_settings()
	await shot("26_settings", 0.6)
	game._modal.close()
	await wait(0.5)

	# ---- finish the level to see the win flow --------------------------------
	cv.fit_view(false)
	for c in lvl.palette.size():
		cv.select_color(c)
		for i in lvl.cell_count():
			if lvl.cells[i] == c and cv.painted[i] == 0:
				cv.paint_cell(i % lvl.width, i / lvl.width, true)
	await wait(0.6)
	await shot("30_completion_confetti", 0.1)
	await wait(2.4)
	await shot("30b_fake_interstitial", 0.4)   # the ad between the celebration and the win screen
	await wait(2.4)
	await shot("31_win_overlay", 0.5)

	# ---- time-lapse -------------------------------------------------------------------------
	game._modal.timelapse_pressed.emit()
	await wait(2.0)
	await shot("32_timelapse_midway", 0.1)
	await wait(6.0)
	await shot("33_after_timelapse", 0.8)

	if is_instance_valid(game._modal):
		game._modal.home_pressed.emit()
	await wait(1.4)
	await shot("40_home_with_progress", 0.4)

	home = main.host.get_child(0)
	home.nav._on_tapped(&"diary")
	await shot("42_diary_with_progress", 0.8)
	home.nav._on_tapped(&"profile")
	await shot("43_profile_with_progress", 0.6)
	home.nav._on_tapped(&"home")
	await wait(0.3)
	home._open_settings()
	await shot("44_settings_over_home", 0.8)
	home._modal.close()
	await wait(0.5)

	# ---- a picture left half-way shows up as "Continue" ---------------------------------------
	main.open_level("parrot")
	await wait(1.6)
	game = main.host.get_child(0)
	cv = game.canvas
	lvl = cv.level
	for c in 4:
		cv.select_color(c)
		for i in lvl.cell_count():
			if lvl.cells[i] == c and (i % 3) != 0:
				cv.paint_cell(i % lvl.width, i / lvl.width, true)
	await wait(0.3)
	game._go_home()
	await wait(1.5)
	await shot("45_home_continue_card", 0.5)
	home = main.host.get_child(0)

	# ---- the same screens in Portuguese ---------------------------------------------------
	gs.set_setting(&"language", "pt")
	await wait(0.4)
	await shot("50_pt_home", 0.5)
	home.nav._on_tapped(&"shop")
	await shot("51_pt_shop", 0.6)
	home.nav._on_tapped(&"categories")
	await shot("52_pt_categories", 0.6)
	main.open_level("moon_owl")
	await wait(1.6)
	await shot("53_pt_game", 0.4)

	# ---- Premium owned: free power-ups, the active card, the member badge --------------------------
	gs.set_setting(&"language", "en")
	gs.set_premium(true)
	await shot("54_game_premium_free", 0.6)
	game = main.host.get_child(0)
	game._go_home()
	await wait(1.5)
	home = main.host.get_child(0)
	home.nav._on_tapped(&"shop")
	await shot("55_shop_premium_active", 0.6)
	home.nav._on_tapped(&"profile")
	await shot("56_profile_premium", 0.6)
	print("DONE")
	quit()
