extends Node
## Persistent player state: settings, coins and per-level progress (plus each picture's
## time-lapse history, and the days the player painted on).
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

const STARTING_COINS := 250
const LEVEL_REWARD := 60        ## coins for finishing a picture for the first time
const DAILY_GIFT := 50          ## coins from the shop's free daily gift
const COST_WAND := 40
const COST_BOMB := 25
const COST_MAGNIFIER := 15
const MAX_ACTIVITY_DAYS := 400

var sound_on: bool = true
var music_on: bool = true
var haptics_on: bool = true
var show_numbers: bool = true
var show_grid: bool = true
var language: String = "auto"  ## "auto" | "en" | "pt"
var coins: int = STARTING_COINS
var last_level_id: String = ""
var last_gift_day: String = ""        ## "YYYY-MM-DD" of the last claimed daily gift
var activity_days: Array[String] = [] ## days (ascending, "YYYY-MM-DD") with at least one painted cell

## level_id -> {"p": base64(deflate(painted)), "sz": raw byte count, "n": painted, "t": total, "done": bool,
##              "tl": base64(deflate(time-lapse bytes)), "tlsz": raw byte count}
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

func add_coins(n: int) -> void:
	coins = maxi(0, coins + n)
	wallet_changed.emit()
	_request_save()


func can_afford(price: int) -> bool:
	return coins >= price


## Takes `price` coins; returns false (and changes nothing) if the wallet can't pay.
func spend_coins(price: int) -> bool:
	if price < 0 or coins < price:
		return false
	add_coins(-price)
	return true


# -- days played / daily gift ---------------------------------------------------

func today() -> String:
	return Time.get_date_string_from_system()


## Called whenever a cell gets painted; remembers that the player painted today.
func note_activity() -> void:
	var d := today()
	if not activity_days.is_empty() and activity_days[activity_days.size() - 1] == d:
		return
	activity_days.append(d)
	while activity_days.size() > MAX_ACTIVITY_DAYS:
		activity_days.pop_front()
	_request_save()


func has_activity_on(day: String) -> bool:
	return activity_days.has(day)


## Consecutive days painted, counting back from today (or from yesterday, if today is still empty).
func streak_days() -> int:
	var day_s := 86400
	# Local wall-clock time read as if it were UTC: stepping whole days from it keeps local dates.
	var t := int(Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system(false)))
	var cursor := t if has_activity_on(Time.get_date_string_from_unix_time(t)) else t - day_s
	var n := 0
	while has_activity_on(Time.get_date_string_from_unix_time(cursor)):
		n += 1
		cursor -= day_s
	return n


func can_claim_daily_gift() -> bool:
	return last_gift_day != today()


## Returns the coins granted (0 if today's gift was already taken).
func claim_daily_gift() -> int:
	if not can_claim_daily_gift():
		return 0
	last_gift_day = today()
	add_coins(DAILY_GIFT)
	return DAILY_GIFT


## Pictures finished at least once.
func completed_count() -> int:
	var n := 0
	for id in _progress:
		if _progress[id].get("done", false):
			n += 1
	return n


## Cells painted over every picture still in progress or finished.
func total_painted() -> int:
	var n := 0
	for id in _progress:
		n += int(_progress[id].get("n", 0))
	return n


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
	## Returns true only the first time, so the coin reward is granted once.
	var rec: Dictionary = _progress.get(level_id, {})
	var first_time: bool = not rec.get("done", false)
	rec["done"] = true
	_progress[level_id] = rec
	if first_time:
		add_coins(LEVEL_REWARD)
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


## The raw time-lapse history of a picture (see TimelapseRecorder.to_bytes()); empty if none.
func get_timelapse(level_id: String) -> PackedByteArray:
	var rec: Dictionary = _progress.get(level_id, {})
	var packed := Marshalls.base64_to_raw(rec.get("tl", ""))
	if packed.is_empty():
		return PackedByteArray()
	return packed.decompress(int(rec.get("tlsz", 0)), FileAccess.COMPRESSION_DEFLATE)


func store_timelapse(level_id: String, raw: PackedByteArray) -> void:
	var rec: Dictionary = _progress.get(level_id, {})
	if raw.is_empty():     # nothing painted yet (e.g. a picture opened and left at once)
		rec.erase("tl")
		rec.erase("tlsz")
	else:
		rec["tl"] = Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE))
		rec["tlsz"] = raw.size()
	_progress[level_id] = rec
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
		},
		"coins": coins,
		"last_gift_day": last_gift_day,
		"activity_days": activity_days,
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
	language = s.get("language", language)
	coins = int(parsed.get("coins", coins))
	last_gift_day = str(parsed.get("last_gift_day", ""))
	activity_days.clear()
	for d in parsed.get("activity_days", []):
		activity_days.append(str(d))
	last_level_id = parsed.get("last_level_id", "")
	var prog: Variant = parsed.get("progress", {})
	if typeof(prog) == TYPE_DICTIONARY:
		_progress = prog
