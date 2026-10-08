class_name PaletteQuantizer
extends RefCounted
## Reduces a color histogram to a small, playable palette.
##
## AI generators return anti-aliased art with dozens of near-identical shades;
## a color-by-number puzzle needs a handful of clearly distinct colors. We run a
## weighted median-cut in OKLab (so "distance" matches what the eye sees) and then
## fold tiny clusters into their nearest neighbour so nobody has to paint 3 stray cells.

## histogram: {rgba32:int -> count:int}
## Returns {rgba32:int -> rgba32:int} mapping every source color to its palette color.
static func reduce(histogram: Dictionary, max_colors: int, min_cells: int) -> Dictionary:
	var entries: Array[Dictionary] = []
	for key in histogram:
		var c := Color.hex(key)
		entries.append({"key": key, "n": histogram[key], "lab": to_oklab(c)})

	# --- weighted median cut -------------------------------------------------
	var boxes: Array = [entries]
	while boxes.size() < max_colors:
		var best := -1
		var best_score := 0.0
		var best_axis := 0
		for i in boxes.size():
			var box: Array = boxes[i]
			if box.size() < 2:
				continue
			var info := _box_extent(box)
			if info.score > best_score:
				best_score = info.score
				best = i
				best_axis = info.axis
		if best == -1:
			break
		var halves := _split(boxes[best], best_axis)
		boxes[best] = halves[0]
		boxes.append(halves[1])

	# --- palette = weighted OKLab centroid of each box -----------------------
	var pal_keys: Array[int] = []
	var pal_lab: Array[Vector3] = []
	for box in boxes:
		if box.size() == 1:
			# A lone shade stays bit-exact (no OKLab round-trip drift).
			pal_keys.append(box[0].key)
			pal_lab.append(box[0].lab)
			continue
		var sum := Vector3.ZERO
		var total := 0
		for e in box:
			sum += (e.lab as Vector3) * float(e.n)
			total += e.n
		var c := from_oklab(sum / maxf(float(total), 1.0))
		pal_keys.append(c.to_rgba32())
		pal_lab.append(to_oklab(c))

	var assign := _assign_nearest(entries, pal_lab)  # entry idx -> palette idx

	# --- fold tiny clusters into their nearest neighbour ---------------------
	var alive: Array[bool] = []
	alive.resize(pal_keys.size())
	alive.fill(true)
	while true:
		var counts := _cluster_counts(entries, assign, pal_keys.size())
		var victim := -1
		var victim_n := min_cells
		for p in pal_keys.size():
			if alive[p] and counts[p] < victim_n:
				victim = p
				victim_n = counts[p]
		if victim == -1 or _alive_count(alive) <= 2:
			break
		alive[victim] = false
		for e_idx in entries.size():
			if assign[e_idx] == victim:
				assign[e_idx] = _nearest_alive(entries[e_idx].lab, pal_lab, alive)

	var mapping := {}
	for e_idx in entries.size():
		mapping[entries[e_idx].key] = pal_keys[assign[e_idx]]
	return mapping


# -- helpers --------------------------------------------------------------

static func _box_extent(box: Array) -> Dictionary:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var pop := 0
	for e in box:
		var v: Vector3 = e.lab
		lo = Vector3(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z))
		hi = Vector3(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z))
		pop += e.n
	var span := hi - lo
	# Lightness differences are the most visible to a painter; weight them up.
	var weighted := Vector3(span.x * 1.6, span.y, span.z)
	var axis := 0
	if weighted.y > weighted[axis]:
		axis = 1
	if weighted.z > weighted[axis]:
		axis = 2
	return {"axis": axis, "score": weighted[axis] * sqrt(float(pop))}


static func _split(box: Array, axis: int) -> Array:
	var sorted := box.duplicate()
	sorted.sort_custom(func(a, b): return a.lab[axis] < b.lab[axis])
	var total := 0
	for e in sorted:
		total += e.n
	var run := 0
	var cut := 1
	for i in sorted.size() - 1:
		run += sorted[i].n
		cut = i + 1
		if run * 2 >= total:
			break
	return [sorted.slice(0, cut), sorted.slice(cut)]


static func _assign_nearest(entries: Array[Dictionary], pal_lab: Array[Vector3]) -> Array[int]:
	var out: Array[int] = []
	for e in entries:
		var best := 0
		var best_d := INF
		for p in pal_lab.size():
			var d := (e.lab as Vector3).distance_squared_to(pal_lab[p])
			if d < best_d:
				best_d = d
				best = p
		out.append(best)
	return out


static func _cluster_counts(entries: Array[Dictionary], assign: Array[int], n: int) -> Array[int]:
	var counts: Array[int] = []
	counts.resize(n)
	counts.fill(0)
	for i in entries.size():
		counts[assign[i]] += entries[i].n
	return counts


static func _alive_count(alive: Array[bool]) -> int:
	var n := 0
	for a in alive:
		if a:
			n += 1
	return n


static func _nearest_alive(lab: Vector3, pal_lab: Array[Vector3], alive: Array[bool]) -> int:
	var best := -1
	var best_d := INF
	for p in pal_lab.size():
		if not alive[p]:
			continue
		var d := lab.distance_squared_to(pal_lab[p])
		if d < best_d:
			best_d = d
			best = p
	return best


# -- OKLab ------------------------------------------------------------------

static func _srgb_to_linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _linear_to_srgb(v: float) -> float:
	v = clampf(v, 0.0, 1.0)
	return v * 12.92 if v <= 0.0031308 else 1.055 * pow(v, 1.0 / 2.4) - 0.055


static func to_oklab(c: Color) -> Vector3:
	var r := _srgb_to_linear(c.r)
	var g := _srgb_to_linear(c.g)
	var b := _srgb_to_linear(c.b)
	var l := pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m := pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s := pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	return Vector3(
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


static func from_oklab(v: Vector3) -> Color:
	var l_ := v.x + 0.3963377774 * v.y + 0.2158037573 * v.z
	var m_ := v.x - 0.1055613458 * v.y - 0.0638541728 * v.z
	var s_ := v.x - 0.0894841775 * v.y - 1.2914855480 * v.z
	var l := l_ * l_ * l_
	var m := m_ * m_ * m_
	var s := s_ * s_ * s_
	return Color(
		_linear_to_srgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
		_linear_to_srgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
		_linear_to_srgb(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
		1.0)
