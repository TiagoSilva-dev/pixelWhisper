extends Node
## Audio + haptics. Everything the player can feel or hear goes through here, so the
## "ASMR" tuning lives in one place and respects the Sound / Haptics settings.
##
## The color symphony: every paint plays a soft Kalimba or Marimba note. The note comes from the
## color's palette index (a pentatonic scale over two octaves, so any two colors sound good
## together) and each pixel then gets its own small random bend, `pitch_scale` x 0.95..1.15.
##
## Why a pool: when one AudioStreamPlayer changes pitch_scale, every voice it is still
## playing changes too. Dragging a finger across the canvas fires a note every ~30 ms,
## so each note gets its own player (round-robin) and keeps its own pitch.

signal vibrated(ms: int)   ## every time a vibration is requested (the tests listen to this)

const JITTER_MIN := 0.95
const JITTER_MAX := 1.15
const MIN_JITTER_GAP := 0.03      ## Re-roll if the bend is too close to the previous pixel's.
const POP_MIN_INTERVAL_MS := 26   ## Dense drags can paint many cells per frame; don't machine-gun.
const HAPTIC_MIN_INTERVAL_MS := 35
const PAINT_HAPTIC_MS := 25
const COLOR_DONE_HAPTIC_MS := 100
const POP_VOLUME_DB := -7.0
## Semitones above the C4 the samples are recorded at: major pentatonic, two octaves
## (highest note A5 x 1.15 stays under pitch_scale 4).
const NOTES: Array[int] = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]
const POOL_SIZE := 10

const SFX_BUS := &"SFX"
const MUSIC_BUS := &"Music"

var _pops: Array[AudioStream] = []   ## the instruments (Kalimba, Marimba)
var _pool: Array[AudioStreamPlayer] = []
var _next_player := 0
var _last_pitch := 1.0
var _last_jitter := 1.0
var _last_pop_ms := 0
var _last_haptic_ms := 0
var _streams: Dictionary = {}  # name -> AudioStream
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)

	for n in ["kalimba", "marimba"]:
		var s := _load_stream(n)
		if s:
			_pops.append(s)
	for n in ["tick", "wrong", "hint", "wand", "color_done", "win"]:
		_streams[n] = _load_stream(n)

	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_pool.append(p)

	var amb := _load_stream("ambient")
	if amb is AudioStreamWAV:
		var loop: AudioStreamWAV = amb.duplicate()
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = loop.data.size() / 2  # 16-bit mono -> frames
		_music = AudioStreamPlayer.new()
		_music.stream = loop
		_music.bus = MUSIC_BUS
		_music.volume_db = -17.0
		add_child(_music)

	GameState.settings_changed.connect(_apply_settings)
	_apply_settings()


func _load_stream(stream_name: String) -> AudioStream:
	var path := "res://assets/audio/%s.wav" % stream_name
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	push_warning("Feedback: missing %s (run tools/gen_audio.py and re-import)" % path)
	return null


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, &"Master")


func _apply_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not GameState.sound_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), not GameState.music_on)
	if _music:
		if GameState.music_on and not _music.playing:
			_music.play()
		elif not GameState.music_on and _music.playing:
			_music.stop()


# -- the color symphony ----------------------------------------------------------

## Pitch ratio of the note that belongs to palette index `color_index` (0-based).
static func note_ratio(color_index: int) -> float:
	var semis: int = NOTES[posmod(color_index, NOTES.size())]
	return pow(2.0, semis / 12.0)


## Called once per correctly painted cell. Returns true if a sound actually played.
func pop(color_index: int = 0) -> bool:
	if not GameState.sound_on or _pops.is_empty():
		return false
	var now := Time.get_ticks_msec()
	if now - _last_pop_ms < POP_MIN_INTERVAL_MS:
		return false
	_last_pop_ms = now

	var jitter := randf_range(JITTER_MIN, JITTER_MAX)
	if absf(jitter - _last_jitter) < MIN_JITTER_GAP:
		# Nudge away from the previous bend (staying inside the range) so a drag
		# never plays the same tone twice in a row.
		jitter = JITTER_MIN + fposmod(jitter - JITTER_MIN + (JITTER_MAX - JITTER_MIN) * 0.5, JITTER_MAX - JITTER_MIN)
	_last_jitter = jitter
	_last_pitch = note_ratio(color_index) * jitter

	var p := _acquire()
	p.stream = _pops[randi() % _pops.size()]
	p.pitch_scale = _last_pitch
	p.volume_db = POP_VOLUME_DB + randf_range(-2.5, 1.0)
	p.play()
	return true


# -- one-shots --------------------------------------------------------------------

func play(sound: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not GameState.sound_on:
		return
	var s: AudioStream = _streams.get(sound)
	if s == null:
		return
	var p := _acquire()
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func tick() -> void:
	play(&"tick", -9.0, randf_range(0.97, 1.05))


func wrong() -> void:
	play(&"wrong", -10.0)
	haptic(18)


func color_done() -> void:
	play(&"color_done", -5.0)
	vibrate(COLOR_DONE_HAPTIC_MS)


func hint() -> void:
	play(&"hint", -6.0)
	haptic(20)


func wand() -> void:
	play(&"wand", -5.0)
	haptic_pattern([25, 20, 25, 20, 40])


func win() -> void:
	play(&"win", -2.0)
	haptic_pattern([60, 60, 60, 60, 120])


# -- haptics ----------------------------------------------------------------------

## Single short tick. Throttled: vibration motors can't keep up with a pop every 30 ms
## and queueing pulses makes the phone buzz long after the finger stops.
func haptic(ms: int = PAINT_HAPTIC_MS) -> void:
	if not GameState.haptics_on:
		return
	var now := Time.get_ticks_msec()
	if now - _last_haptic_ms < HAPTIC_MIN_INTERVAL_MS:
		return
	vibrate(ms)


## The one place that talks to the vibration motor. Not throttled: used for the longer
## "color finished" pulse, which lands right after a paint tick and must not be swallowed.
func vibrate(ms: int) -> void:
	if not GameState.haptics_on:
		return
	_last_haptic_ms = Time.get_ticks_msec()
	Input.vibrate_handheld(ms)
	vibrated.emit(ms)


## Alternating [on, off, on, ...] durations in ms.
func haptic_pattern(pattern: Array) -> void:
	if not GameState.haptics_on:
		return
	var t := 0
	for i in pattern.size():
		if i % 2 == 0:
			get_tree().create_timer(t / 1000.0).timeout.connect(vibrate.bind(int(pattern[i])))
		t += int(pattern[i])


func _acquire() -> AudioStreamPlayer:
	# Prefer an idle player; otherwise steal the oldest one.
	for i in _pool.size():
		var p := _pool[(_next_player + i) % _pool.size()]
		if not p.playing:
			_next_player = (_next_player + i + 1) % _pool.size()
			return p
	var stolen := _pool[_next_player]
	_next_player = (_next_player + 1) % _pool.size()
	return stolen
