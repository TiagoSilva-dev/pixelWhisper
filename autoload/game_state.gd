extends Node
## Persistent player state: settings, wallet and per-level progress.
##
## Painted cells are stored as one byte per cell, deflate-compressed + base64'd, so a
## full 64x64 level is ~100-300 bytes on disk. Saves are debounced (painting fires
## dozens of changes per second) and also flushed when the app is backgrounded, which
## is the only reliable "quit" signal on mobile.

signal settings_changed
signal wallet_changed
signal progress_changed(level_id: String)

const SAVE_PATH := "user://save.json"
const SAVE_TMP_PATH := "user://save.json.tmp"
const SAVE_VERSION := 1
const SAVE_DEBOUNCE_SEC := 1.5
const STARTING_WANDS := 3

var sound_on: bool = true
var music_on: bool = true
var haptics_on: bool = true
var show_numbers: bool = true
var show_grid: bool = true
var glass_fx: bool = true       ## backdrop-blur glass; off = cheaper translucent glass
var hint_seen: bool = false     ## the "tap to start coloring" pill has been dismissed once
var language: String = "auto"  ## "auto" | "en" | "pt"
var wands: int = STARTING_WANDS
var last_level_id: String = ""

## level_id -> {"p": base64(deflate(painted)), "sz": raw byte count, "n": painted, "t": total, "done": bool}
var _progress: Dictionary = {}
var _dirty: bool = false
var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE_SEC
	_save_timer.timeout.connect(flush)
	add_child(_save_timer)
	_load()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			flush()


# -- settings ---------------------------------------------------------------

func set_setting(key: StringName, value: Variant) -> void:
	if get(key) == value:
		return
	set(key, value)
	settings_changed.emit()
	_request_save()


# -- wallet -----------------------------------------------------------------

func add_wands(n: int) -> void:
	wands = maxi(0, wands + n)
	wallet_changed.emit()
	_request_save()


func spend_wand() -> bool:
	if wands <= 0:
		return false
	add_wands(-1)
	return true


# -- progress ---------------------------------------------------------------

func get_painted(level_id: String, cell_count: int) -> PackedByteArray:
	var painted := PackedByteArray()
	painted.resize(cell_count)
	var rec: Dictionary = _progress.get(level_id, {})
	if rec.is_empty():
		return painted
	var packed := Marshalls.base64_to_raw(rec.get("p", ""))
	var raw := packed.decompress(int(rec.get("sz", 0)), FileAccess.COMPRESSION_DEFLATE)
	if raw.size() == cell_count:
		return raw
	return painted  # Level changed shape since the save; start clean rather than corrupt.


func store_progress(level_id: String, painted: PackedByteArray, painted_count: int, total: int) -> void:
	var packed := painted.compress(FileAccess.COMPRESSION_DEFLATE)
	var rec: Dictionary = _progress.get(level_id, {})
	rec["p"] = Marshalls.raw_to_base64(packed)
	rec["sz"] = painted.size()
	rec["n"] = painted_count
	rec["t"] = total
	rec["done"] = rec.get("done", false) or (total > 0 and painted_count >= total)
	_progress[level_id] = rec
	last_level_id = level_id
	progress_changed.emit(level_id)
	_request_save()


func mark_completed(level_id: String) -> bool:
	## Returns true only the first time, so rewards are granted once.
	var rec: Dictionary = _progress.get(level_id, {})
	var first_time: bool = not rec.get("done", false)
	rec["done"] = true
	_progress[level_id] = rec
	if first_time:
		add_wands(1)
	progress_changed.emit(level_id)
	_request_save()
	return first_time


func reset_level(level_id: String) -> void:
	var rec: Dictionary = _progress.get(level_id, {})
	var was_done: bool = rec.get("done", false)
	_progress.erase(level_id)
	if was_done:
		# Keep the "completed once" badge; replaying shouldn't re-grant rewards.
		_progress[level_id] = {"done": true, "n": 0, "t": rec.get("t", 0), "sz": 0, "p": ""}
	progress_changed.emit(level_id)
	_request_save()


func is_completed(level_id: String) -> bool:
	return _progress.get(level_id, {}).get("done", false)


func painted_count(level_id: String) -> int:
	return _progress.get(level_id, {}).get("n", 0)


func ratio(level_id: String) -> float:
	var rec: Dictionary = _progress.get(level_id, {})
	var t: int = rec.get("t", 0)
	if t <= 0:
		return 0.0
	return clampf(float(rec.get("n", 0)) / float(t), 0.0, 1.0)


func has_started(level_id: String) -> bool:
	return painted_count(level_id) > 0


func forget_level(level_id: String) -> void:
	_progress.erase(level_id)
	_request_save()


# -- persistence ------------------------------------------------------------

func _request_save() -> void:
	_dirty = true
	if _save_timer and is_inside_tree():
		_save_timer.start()


func flush() -> void:
	if not _dirty:
		return
	_dirty = false
	var data := {
		"version": SAVE_VERSION,
		"settings": {
			"sound_on": sound_on, "music_on": music_on, "haptics_on": haptics_on,
			"show_numbers": show_numbers, "show_grid": show_grid, "language": language,
			"glass_fx": glass_fx, "hint_seen": hint_seen,
		},
		"wands": wands,
		"last_level_id": last_level_id,
		"progress": _progress,
	}
	# Write to a temp file and rename, so a crash mid-write can't destroy the save.
	var f := FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("GameState: cannot write save (%s)" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(SAVE_TMP_PATH, SAVE_PATH)


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: save file unreadable, starting fresh")
		return
	var s: Dictionary = parsed.get("settings", {})
	sound_on = s.get("sound_on", sound_on)
	music_on = s.get("music_on", music_on)
	haptics_on = s.get("haptics_on", haptics_on)
	show_numbers = s.get("show_numbers", show_numbers)
	show_grid = s.get("show_grid", show_grid)
	glass_fx = s.get("glass_fx", glass_fx)
	hint_seen = s.get("hint_seen", hint_seen)
	language = s.get("language", language)
	wands = int(parsed.get("wands", wands))
	last_level_id = parsed.get("last_level_id", "")
	var prog: Variant = parsed.get("progress", {})
	if typeof(prog) == TYPE_DICTIONARY:
		_progress = prog
