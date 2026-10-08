class_name TimelapseRecorder
extends RefCounted
## History of one picture's painting: a stack of (cell, timestamp) events, appended in the
## order the cells were painted. CanvasView.play_timelapse() replays it.
##
## Timestamps are milliseconds of *active* time since the first stroke: any pause longer than
## MAX_GAP_MS (the phone went to the drawer) is squeezed to MAX_GAP_MS when recorded, so a
## replay never sits idle. The history is persisted with the progress (see to_bytes()), which
## is what lets the replay start from the blank picture even after several sessions.

const MAX_GAP_MS := 3000
const LEGACY_STEP_MS := 8       ## spacing given to cells painted before history existed

var cells: PackedInt32Array = PackedInt32Array()   ## cell index of every event, in paint order
var times: PackedInt32Array = PackedInt32Array()   ## active ms since the first event

var _last_tick_ms: int = -1


func size() -> int:
	return cells.size()


func is_empty() -> bool:
	return cells.is_empty()


func duration_ms() -> int:
	return 0 if times.is_empty() else times[times.size() - 1]


func clear() -> void:
	cells.clear()
	times.clear()
	_last_tick_ms = -1


## Pushes one painted cell onto the stack, stamped with the current time.
func record(cell: int, now_ms: int = -1) -> void:
	if now_ms < 0:
		now_ms = Time.get_ticks_msec()
	var t := 0
	if not times.is_empty():
		var gap := mini(now_ms - _last_tick_ms, MAX_GAP_MS) if _last_tick_ms >= 0 else 0
		t = times[times.size() - 1] + maxi(gap, 0)
	_last_tick_ms = now_ms
	cells.append(cell)
	times.append(t)


## Makes the history agree with the picture that was just loaded: drops events for cells that are
## not painted (after a reset) and keeps only the first event of a cell; cells that are painted
## but have no event (saves from before this feature) become instant events at the very start.
func reconcile(painted: PackedByteArray) -> void:
	var seen := PackedByteArray()
	seen.resize(painted.size())
	var kept_cells := PackedInt32Array()
	var kept_times := PackedInt32Array()
	for i in cells.size():
		var c := cells[i]
		if c >= 0 and c < painted.size() and painted[c] != 0 and seen[c] == 0:
			seen[c] = 1
			kept_cells.append(c)
			kept_times.append(times[i])
	var legacy := PackedInt32Array()
	for c in painted.size():
		if painted[c] != 0 and seen[c] == 0:
			legacy.append(c)
	var shift := legacy.size() * LEGACY_STEP_MS
	cells = legacy.duplicate()
	times = PackedInt32Array()
	for k in legacy.size():
		times.append(k * LEGACY_STEP_MS)
	for i in kept_cells.size():
		cells.append(kept_cells[i])
		times.append(kept_times[i] + shift)
	_last_tick_ms = -1


## Seconds, from the start of the replay, at which each event must appear. The nominal rate is
## `speed` times real time; the whole replay is kept between `min_seconds` and `max_seconds`
## (a 40-minute session at 10x would be a four-minute film).
func timeline(speed: float = 10.0, min_seconds: float = 3.0, max_seconds: float = 40.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := cells.size()
	out.resize(n)
	if n == 0:
		return out
	var real_s := duration_ms() / 1000.0
	var total_s := clampf(real_s / maxf(speed, 0.01), min_seconds, max_seconds)
	for i in n:
		out[i] = total_s * (float(times[i]) / float(duration_ms()) if duration_ms() > 0 else float(i) / float(maxi(n - 1, 1)))
	return out


# -- persistence ---------------------------------------------------------------------------

## 4 bytes per event: uint16 cell, uint16 gap to the previous event in 10 ms units.
func to_bytes() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(cells.size() * 4)
	var prev := 0
	for i in cells.size():
		b.encode_u16(i * 4, clampi(cells[i], 0, 65535))
		b.encode_u16(i * 4 + 2, clampi(int(round((times[i] - prev) / 10.0)), 0, 65535))
		prev = times[i]
	return b


static func from_bytes(b: PackedByteArray) -> TimelapseRecorder:
	var r := TimelapseRecorder.new()
	var t := 0
	for i in b.size() / 4:
		r.cells.append(b.decode_u16(i * 4))
		t += b.decode_u16(i * 4 + 2) * 10
		r.times.append(t)
	return r
