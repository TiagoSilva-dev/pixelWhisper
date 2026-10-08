extends SceneTree
## Statistical check of the ASMR note: bend range, repetition, voices, throttling.
## (The color -> note mapping and the per-pixel bend per color are covered in test_features.gd.)
##   godot --headless --path . --script res://tools/tests/test_audio.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var fb = root.get_node("Feedback")
	print("streams: instruments=%d pool=%d music=%s" % [fb._pops.size(), fb._pool.size(), fb._music != null])

	var pitches: Array[float] = []
	var played := 0
	var skipped := 0
	for i in 400:
		if fb.pop():
			played += 1
			pitches.append(fb._last_pitch)
		else:
			skipped += 1
		await create_timer(0.03).timeout   # ~33 pops/second, like a fast drag

	var mn := 9.0
	var mx := 0.0
	var min_gap := 9.0
	var sum := 0.0
	for i in pitches.size():
		mn = minf(mn, pitches[i])
		mx = maxf(mx, pitches[i])
		sum += pitches[i]
		if i > 0:
			min_gap = minf(min_gap, absf(pitches[i] - pitches[i - 1]))
	print("played=%d skipped=%d" % [played, skipped])
	print("pitch range: %.3f .. %.3f (mean %.3f)   smallest step between consecutive pops: %.3f" % [mn, mx, sum / pitches.size(), min_gap])
	# color 0 is the base note (ratio 1.0), so the pitch IS the random bend: 0.95 .. 1.15
	print("PASS in range" if mn >= 0.95 - 0.0001 and mx <= 1.15 + 0.0001 else "FAIL out of range")
	print("PASS no near-repeats" if min_gap >= 0.03 - 0.0001 else "FAIL near-repeat (%.3f)" % min_gap)

	# throttle: 50 calls in the same frame must not machine-gun
	await create_timer(0.1).timeout
	var burst := 0
	for i in 50:
		if fb.pop():
			burst += 1
	print("PASS throttle" if burst == 1 else "FAIL throttle: %d pops in one frame" % burst)

	# players keep independent pitches (each voice owns its player)
	await create_timer(0.1).timeout
	var distinct := {}
	for i in 6:
		fb.pop()
		await create_timer(0.03).timeout
	for p in fb._pool:
		if p.playing:
			distinct[snappedf(p.pitch_scale, 0.001)] = true
	print("concurrent voices with distinct pitches: ", distinct.size())

	# settings respected
	var gs = root.get_node("GameState")
	gs.sound_on = false
	await create_timer(0.1).timeout
	print("PASS muted when sound off" if not fb.pop() else "FAIL pop played with sound off")
	gs.sound_on = true
	quit()
