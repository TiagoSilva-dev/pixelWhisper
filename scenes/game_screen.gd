extends Control
## The painting screen: top bar, canvas, floating tools and the palette bar.
## Owns the game flow (color selection, auto-advance, hints, wand, save, win).

signal home_requested
signal level_requested(level_id: String)

const SAVE_INTERVAL_SEC := 0.6

@onready var canvas: CanvasView = %Canvas
@onready var title_label: Label = %TitleLabel
@onready var progress_bar: GlassProgress = %Progress
@onready var percent_label: Label = %Percent
@onready var palette_row: HBoxContainer = %PaletteRow
@onready var palette_scroll: ScrollContainer = %PaletteScroll
@onready var back_button: IconButton = %BackButton
@onready var hint_button: IconButton = %HintButton
@onready var menu_button: IconButton = %MenuButton
@onready var wand_button: IconButton = %WandButton
@onready var fit_button: IconButton = %FitButton

var level: PixelLevel
var _swatches: Array[PaletteSwatch] = []
var _modal: Modal
var _save_timer: Timer
var _completed: bool = false
var _discard_progress: bool = false
var _scroll_tween: Tween


func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_INTERVAL_SEC
	_save_timer.timeout.connect(_save_progress)
	add_child(_save_timer)

	back_button.pressed.connect(_go_home)
	hint_button.pressed.connect(_on_hint)
	menu_button.pressed.connect(_open_settings)
	wand_button.pressed.connect(_on_wand)
	fit_button.pressed.connect(func() -> void: canvas.fit_view())
	wand_button.tint = Color(1.0, 0.86, 0.55)    # warm glass for the "magic" tools
	hint_button.tint = Color(1.0, 0.9, 0.62)

	canvas.input_blockers = [wand_button, fit_button]
	canvas.cell_painted.connect(_on_cell_painted)
	canvas.color_completed.connect(_on_color_completed)
	canvas.progress_changed.connect(_on_progress)
	canvas.level_completed.connect(_on_level_completed)
	canvas.wrong_tapped.connect(_on_wrong_tapped)
	canvas.fit_state_changed.connect(_on_fit_state_changed)
	GameState.wallet_changed.connect(_refresh_wand)
	_refresh_wand()
	fit_button.modulate.a = 0.0
	fit_button.visible = false


## Called by Main right after the scene enters the tree.
func start(level_id: String) -> void:
	level = LevelLibrary.get_level(level_id)
	if level == null:
		push_error("GameScreen: unknown level %s" % level_id)
		home_requested.emit()
		return
	GameState.last_level_id = level_id
	title_label.text = level.title
	canvas.set_level(level, GameState.get_painted(level_id, level.cell_count()))
	_completed = canvas.is_complete()
	_build_palette()
	var first := canvas.next_unfinished_color(-1)
	if first >= 0:
		_select(first, false)
	_on_progress(canvas.painted_total, level.total_paintable)
	# The canvas gets its real size one frame later (container layout).
	await get_tree().process_frame
	canvas.fit_view(false)


func handle_back() -> bool:
	if is_instance_valid(_modal):
		if _modal is WinOverlay:
			return true  # the win screen has explicit buttons
		_modal.close()
		return true
	_go_home()
	return true


# ---------------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------------

func _build_palette() -> void:
	for c in palette_row.get_children():
		c.queue_free()
	_swatches.clear()
	for i in level.palette.size():
		var sw := PaletteSwatch.new()
		sw.setup(i, level.palette[i], level.counts[i], canvas.remaining[i])
		sw.chosen.connect(_on_swatch_chosen)
		palette_row.add_child(sw)
		_swatches.append(sw)
		UiFx.pop_in(sw, i * 0.018, 0.3)


func _on_swatch_chosen(index: int) -> void:
	if canvas.remaining[index] <= 0:
		UiFx.toast(self, tr("Everything of this color is painted"), 1.6)
		Feedback.wrong()
		return
	_select(index)


func _select(index: int, scroll_to: bool = true) -> void:
	canvas.select_color(index)
	for i in _swatches.size():
		_swatches[i].set_selected(i == index)
	if scroll_to and index >= 0 and index < _swatches.size():
		_scroll_swatch_into_view(_swatches[index])


func _scroll_swatch_into_view(sw: Control) -> void:
	if _scroll_tween:
		_scroll_tween.kill()
	var target := sw.position.x + sw.size.x * 0.5 - palette_scroll.size.x * 0.5
	target = clampf(target, 0.0, maxf(0.0, palette_row.size.x - palette_scroll.size.x))
	_scroll_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_scroll_tween.tween_property(palette_scroll, "scroll_horizontal", int(target), 0.35)


# ---------------------------------------------------------------------------------
# Canvas events
# ---------------------------------------------------------------------------------

func _on_cell_painted(_cell: int, color_index: int) -> void:
	_swatches[color_index].set_remaining(canvas.remaining[color_index])
	_save_timer.start()


func _on_color_completed(color_index: int) -> void:
	if canvas.is_complete():
		return  # the win sequence takes over
	Feedback.color_done()
	var next := canvas.next_unfinished_color(color_index)
	await get_tree().create_timer(0.5).timeout
	if next >= 0 and canvas.selected == color_index and is_inside_tree():
		_select(next)


func _on_progress(painted: int, total: int) -> void:
	var ratio := float(painted) / float(maxi(total, 1))
	progress_bar.animate_to(ratio, 0.22)
	percent_label.text = "%d%%" % int(floor(ratio * 100.0))


func _on_wrong_tapped(color_index: int) -> void:
	if color_index < _swatches.size():
		_swatches[color_index].wiggle()
	Feedback.wrong()


func _on_fit_state_changed(is_fit: bool) -> void:
	if is_fit and fit_button.visible:
		var t := create_tween()
		t.tween_property(fit_button, "modulate:a", 0.0, 0.2)
		t.tween_callback(func() -> void: fit_button.visible = false)
	elif not is_fit and not fit_button.visible:
		fit_button.visible = true
		create_tween().tween_property(fit_button, "modulate:a", 1.0, 0.2)


func _on_level_completed() -> void:
	if _completed:
		return
	_completed = true
	_save_progress()
	var first_time := GameState.mark_completed(level.id)
	Feedback.win()
	await canvas.play_completion()
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return
	var win := WinOverlay.new()
	_open_modal(win)
	var has_next := LevelLibrary.next_unfinished(level.id) != ""
	win.present(level, first_time, has_next)
	win.next_pressed.connect(func() -> void:
		level_requested.emit(LevelLibrary.next_unfinished(level.id)))
	win.home_pressed.connect(_go_home)
	win.save_pressed.connect(_on_save_image)


# ---------------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------------

func _on_hint() -> void:
	if canvas.selected < 0:
		UiFx.toast(self, tr("Pick a color first"), 1.6)
		return
	if canvas.request_hint():
		Feedback.hint()
	else:
		UiFx.toast(self, tr("Everything of this color is painted"), 1.6)


func _on_wand() -> void:
	if canvas.selected < 0:
		UiFx.toast(self, tr("Pick a color first"), 1.6)
		return
	if GameState.wands <= 0:
		UiFx.toast(self, tr("No wands left. Finish a picture to earn one!"), 2.4)
		Feedback.wrong()
		return
	if canvas.use_wand(40) > 0:
		GameState.spend_wand()
		Feedback.wand()
	else:
		UiFx.toast(self, tr("Everything of this color is painted"), 1.6)


func _refresh_wand() -> void:
	wand_button.badge = str(GameState.wands) if GameState.wands > 0 else ""
	wand_button.dimmed = GameState.wands <= 0
	wand_button.pop()


func _on_save_image() -> void:
	var where := ImageExport.save(level)
	if where == "":
		UiFx.toast(self, tr("Could not save the image"))
	else:
		UiFx.toast(self, "%s\n%s" % [tr("Image saved"), where.get_file() if OS.has_feature("web") else where], 3.4)


# ---------------------------------------------------------------------------------
# Navigation / modals
# ---------------------------------------------------------------------------------

func _open_settings() -> void:
	var m := SettingsModal.new()
	m.add_action("Restart picture", _restart_level, true)
	_open_modal(m)


func _open_modal(m: Modal) -> void:
	_modal = m
	canvas.input_enabled = false
	add_child(m)
	m.closed.connect(func() -> void:
		# Re-enable painting unless the picture is already finished.
		if not _completed:
			canvas.input_enabled = true)


func _restart_level() -> void:
	_discard_progress = true  # otherwise _exit_tree would write the old state over the reset
	_save_timer.stop()
	GameState.reset_level(level.id)
	level_requested.emit(level.id)


func _save_progress() -> void:
	if level == null or _discard_progress:
		return
	GameState.store_progress(level.id, canvas.painted, canvas.painted_total, level.total_paintable)
	GameState.flush()


func _go_home() -> void:
	_save_progress()
	home_requested.emit()


func _exit_tree() -> void:
	if level != null and canvas != null:
		_save_progress()
