extends SceneTree
## Premium, ads and the store (the mock providers stand in for the SDKs): saved state, which pictures
## are locked, interstitial and rewarded rules, the purchase outcomes, and the real UI flows
## (locked picture -> dialog -> video / purchase -> picture opens, ad before the win screen).
## No window needed:
##   godot --headless --path . --script res://tools/tests/test_monetization.gd
## Every check prints PASS or FAIL (tools/run_tests.sh greps for FAIL).

var gs: Node
var ads: Node
var store: Node
var lib: Node


## An authoritative store whose answer the test controls (what real billing will be).
class FakeBilling extends StoreProvider:
	var owned: bool = false

	func _init() -> void:
		authoritative = true

	func owns_premium() -> bool:
		return owned


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
	ads = root.get_node("Ads")
	store = root.get_node("Store")
	lib = root.get_node("LevelLibrary")
	gs.set_setting(&"language", "en")    # the checks compare English texts, whatever the machine's locale is
	ads.provider.seconds = 0.0          # no fake ad screen unless a test asks for it
	store.provider.instant = true

	_test_state()
	_test_library()
	await _test_ads()
	await _test_store()
	await _test_shop_page()
	await _test_flows()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	quit()


func _reset() -> void:
	gs.premium = false
	gs._unlocked.clear()
	gs.coins = gs.STARTING_COINS
	ads.provider.interstitial_ready = true
	ads.provider.rewarded_ready = true
	ads.provider.player_closes_early = false
	store.provider.next_result = StoreProvider.Result.OK
	store.provider.available = true


# ---------------------------------------------------------------------------------
# saved state and prices
# ---------------------------------------------------------------------------------

func _test_state() -> void:
	print("--- state")
	_reset()
	check("starts without Premium and with nothing unlocked", not gs.premium and not gs.has_unlocked("x"))
	check("power-ups cost their list price", gs.price_of(gs.COST_WAND) == 40)

	var events := [0, 0]    # entitlements_changed, wallet_changed
	gs.entitlements_changed.connect(func() -> void: events[0] += 1)
	gs.wallet_changed.connect(func() -> void: events[1] += 1)
	gs.set_premium(true)
	gs.set_premium(true)
	check("Premium is announced once", events[0] == 1, str(events))
	check("Premium makes every power-up free", gs.price_of(gs.COST_WAND) == 0 and gs.price_of(gs.COST_BOMB) == 0 and gs.price_of(gs.COST_MAGNIFIER) == 0)
	check("a free power-up can be 'bought' with an empty wallet and touches nothing",
			gs.spend_coins(0) and gs.coins == gs.STARTING_COINS and events[1] == 0, "wallet events=%d" % events[1])

	gs.unlock_level("lvl_x")
	gs.unlock_level("lvl_x")
	check("unlocking a picture is announced once and remembered", events[0] == 2 and gs.has_unlocked("lvl_x"), str(events))

	var on_disk: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://save.json"))
	check("Premium and unlocks are written at once (not after the save delay)",
			typeof(on_disk) == TYPE_DICTIONARY and on_disk.get("premium", false) == true and on_disk.get("unlocked", []).has("lvl_x"), str(on_disk))
	gs.premium = false
	gs._unlocked.clear()
	gs._load()
	check("...and survive a reload", gs.premium and gs.has_unlocked("lvl_x"))
	gs.set_premium(false)
	check("Premium can be revoked", not gs.premium and gs.price_of(40) == 40)
	_reset()


# ---------------------------------------------------------------------------------
# which pictures are locked
# ---------------------------------------------------------------------------------

func _test_library() -> void:
	print("--- library")
	_reset()
	var premium_ids: Array[String] = []
	var free_ids: Array[String] = []
	for e in lib.entries:
		if e.premium:
			premium_ids.append(e.id)
		else:
			free_ids.append(e.id)
	check("the catalogue has both Premium and free pictures", premium_ids.size() >= 2 and free_ids.size() >= 2,
			"%d premium, %d free" % [premium_ids.size(), free_ids.size()])

	var all_locked := true
	for id in premium_ids:
		all_locked = all_locked and lib.is_locked(id)
	var none_free_locked := true
	for id in free_ids:
		none_free_locked = none_free_locked and not lib.is_locked(id)
	check("every Premium picture starts locked", all_locked)
	check("free pictures are never locked", none_free_locked)
	check("an unknown id is not 'locked'", not lib.is_locked("no_such_picture"))

	gs.unlock_level(premium_ids[0])
	check("a rewarded video opens that one picture only", not lib.is_locked(premium_ids[0]) and lib.is_locked(premium_ids[1]))
	gs.set_premium(true)
	var any_locked := false
	for id in premium_ids:
		any_locked = any_locked or lib.is_locked(id)
	check("the Premium pack opens every picture", not any_locked)
	_reset()

	var skips_locked := true
	for e in lib.entries:
		var nxt: String = lib.next_unfinished(e.id)
		skips_locked = skips_locked and (nxt == "" or not lib.is_locked(nxt))
	check("'Next picture' never lands on a locked picture", skips_locked)

	for id in free_ids:
		gs.mark_completed(id)
	check("with every free picture done and the rest locked, there is no next picture", lib.next_unfinished(free_ids[0]) == "")
	gs.set_premium(true)
	check("...until Premium opens the others", premium_ids.has(lib.next_unfinished(free_ids[0])))
	for id in free_ids:
		gs.forget_level(id)
	_reset()


# ---------------------------------------------------------------------------------
# ads
# ---------------------------------------------------------------------------------

func _test_ads() -> void:
	print("--- ads")
	_reset()
	var p = ads.provider
	var edges: Array[bool] = []
	ads.presenting_changed.connect(func(on: bool) -> void: edges.append(on))

	var shown: bool = await ads.show_interstitial()
	check("an interstitial is shown to a free player", shown and p.shown_interstitial == 1)
	check("...announced as started then finished", edges == [true, false], str(edges))
	check("...and nothing is left 'presenting'", not ads.presenting)

	gs.set_premium(true)
	shown = await ads.show_interstitial()
	check("Premium players never see an interstitial", not shown and p.shown_interstitial == 1)
	gs.set_premium(false)

	p.interstitial_ready = false
	shown = await ads.show_interstitial()
	check("an interstitial that is not ready is skipped, not waited for", not shown and p.shown_interstitial == 1)
	p.interstitial_ready = true

	ads.show_interstitial()          # left running on purpose: the next call must not stack on top of it
	check("while an ad is on screen, 'presenting' is true", ads.presenting)
	shown = await ads.show_interstitial()
	check("a second ad is never stacked on a running one", not shown and p.shown_interstitial == 2)
	await process_frame
	await process_frame
	check("...and the first one still finishes cleanly", not ads.presenting)

	var earned: bool = await ads.show_rewarded()
	check("a rewarded video that is watched pays", earned and p.shown_rewarded == 1)
	p.player_closes_early = true
	earned = await ads.show_rewarded()
	check("a rewarded video closed early does not pay", not earned and p.shown_rewarded == 2)
	p.player_closes_early = false
	p.rewarded_ready = false
	earned = await ads.show_rewarded()
	check("with no video loaded nothing is shown and nothing is paid", not earned and p.shown_rewarded == 2 and not ads.is_rewarded_ready())
	p.rewarded_ready = true
	gs.set_premium(true)
	earned = await ads.show_rewarded()
	check("opt-in videos stay available to Premium players", earned and p.shown_rewarded == 3)
	_reset()

	# the fake ad screen itself: it appears, counts down, closes by itself, and is gone afterwards
	p.seconds = 0.3
	p.auto_close = true
	var result := [false, false]    # finished, reward
	var run := func() -> void:
		result[1] = await ads.show_rewarded()
		result[0] = true
	run.call()
	await process_frame
	await process_frame
	check("the fake ad screen is on top while it plays", _find_script_node("mock_ad_screen.gd") != null and ads.presenting)
	await wait(0.7)
	check("it closes by itself when the countdown ends, and the reward is paid", result[0] and result[1] and not ads.presenting)
	check("...removing its screen", _find_script_node("mock_ad_screen.gd") == null)
	p.seconds = 0.0
	p.auto_close = false


## First node under the root whose script file is `file` (used to find the fake ad screen).
func _find_script_node(file: String) -> Node:
	for n in root.get_children():
		var s: Script = n.get_script()
		if s != null and s.resource_path.ends_with(file):
			return n
	return null


# ---------------------------------------------------------------------------------
# the store
# ---------------------------------------------------------------------------------

func _test_store() -> void:
	print("--- store")
	_reset()
	var rule = load("res://monetization/monetization.gd")
	check("fake ads/purchases are allowed in the editor, in debug builds and on desktop/Web",
			rule.mocks_allowed(true, true) and rule.mocks_allowed(true, false) and rule.mocks_allowed(false, false))
	check("...but never in a release build on a phone (it would give Premium away)", not rule.mocks_allowed(false, true))
	var base := StoreProvider.new()
	check("the fallback store has nothing for sale and nothing owned",
			not base.is_available() and base.price_text() == "" and not base.owns_premium() and await base.buy_premium() == StoreProvider.Result.FAILED)
	var no_ads := AdProvider.new()
	check("the fallback ad provider never has an ad ready", not no_ads.is_interstitial_ready() and not no_ads.is_rewarded_ready() and not await no_ads.show_rewarded())
	var p = store.provider
	var R := StoreProvider.Result
	check("the mock store is available and quotes a price", store.is_available() and store.price_text() != "", store.price_text())
	p.available = false
	check("an unavailable store quotes no price", not store.is_available() and store.price_text() == "")
	p.available = true

	p.next_result = R.CANCELED
	var r: int = await store.buy_premium()
	check("a canceled purchase gives nothing", r == R.CANCELED and not gs.premium)
	p.next_result = R.FAILED
	r = await store.buy_premium()
	check("a failed purchase gives nothing", r == R.FAILED and not gs.premium)
	p.next_result = R.OK
	r = await store.buy_premium()
	check("a successful purchase turns Premium on", r == R.OK and gs.premium)
	var started: int = p.purchases_started
	r = await store.buy_premium()
	check("buying again does not open a second purchase", r == R.OK and p.purchases_started == started)

	gs.set_premium(false)
	check("restoring with nothing owned changes nothing", not await store.restore() and not gs.premium)
	gs.set_premium(true)
	check("restoring when owned keeps Premium", await store.restore() and gs.premium)

	# real billing: the store is the truth, and its answer can both grant and revoke
	var mock = store.provider
	var fake := FakeBilling.new()
	store.provider = fake
	fake.changed.connect(store._sync)
	gs.set_premium(true)
	fake.owned = false
	fake.changed.emit()
	check("an authoritative store revokes Premium that it does not know (refund, edited save)", not gs.premium)
	fake.owned = true
	fake.changed.emit()
	check("...and grants it when it does", gs.premium)
	store.provider = mock
	_reset()


# ---------------------------------------------------------------------------------
# the shop page
# ---------------------------------------------------------------------------------

func _test_shop_page() -> void:
	print("--- shop page")
	_reset()
	var page: Control = load("res://scenes/pages/shop_page.gd").new()
	root.add_child(page)
	await process_frame
	await process_frame
	var labels: Array[String] = []
	for r in page._price_rows:
		labels.append(r.label.text)
	check("power-ups show their coin price", labels == ["40", "25", "15"], str(labels))
	check("'Restore purchases' is offered", page._restore_button.visible)
	gs.set_premium(true)
	await process_frame
	labels.clear()
	for r in page._price_rows:
		labels.append(r.label.text)
	check("Premium turns every price into 'Free'", labels == ["Free", "Free", "Free"], str(labels))
	check("...and hides 'Restore purchases'", not page._restore_button.visible)
	var btn = load("res://ui/widgets/power_up_button.gd").new()
	root.add_child(btn)
	btn.cost = 40
	gs.add_coins(-gs.coins)
	check("a power-up slot counts as affordable with an empty wallet", btn.affordable())
	btn.queue_free()
	page.queue_free()
	_reset()


# ---------------------------------------------------------------------------------
# the real UI
# ---------------------------------------------------------------------------------

func _premium_ids() -> Array[String]:
	var out: Array[String] = []
	for e in lib.entries_in(&"premium"):
		out.append(e.id)
	return out


## The screen Main is showing.
func _screen(main: Control) -> Control:
	return main.host.get_child(0)


func _test_flows() -> void:
	print("--- flows")
	_reset()
	var ids := _premium_ids()
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await wait(0.8)
	var home := _screen(main)

	# --- a locked picture asks first ---
	home._on_level_chosen(ids[0])
	await wait(0.5)
	var modal = home._modal
	check("tapping a locked picture opens the unlock dialog instead of the picture",
			is_instance_valid(modal) and modal.has_signal("unlocked") and _screen(main) == home)
	check("the dialog offers the video while one is ready", modal._watch.text == "Watch a video" and not modal._watch.dimmed)
	check("...and the pack with its price", modal._buy.text.contains(store.price_text()), modal._buy.text)

	# --- no video loaded: nothing happens ---
	ads.provider.rewarded_ready = false
	modal._refresh()
	check("with no video loaded the button says so", modal._watch.text == "Video unavailable" and modal._watch.dimmed)
	modal._on_watch()
	await wait(0.3)
	check("...and pressing it unlocks nothing", not gs.has_unlocked(ids[0]) and is_instance_valid(modal))
	ads.provider.rewarded_ready = true
	modal._refresh()

	# --- watching the video opens that picture ---
	ads.provider.player_closes_early = true
	modal._on_watch()
	await wait(0.4)
	check("closing the video early unlocks nothing", not gs.has_unlocked(ids[0]) and is_instance_valid(modal) and not modal._busy)
	ads.provider.player_closes_early = false
	modal._on_watch()
	await wait(2.4)
	check("watching the video unlocks the picture for good", gs.has_unlocked(ids[0]) and not lib.is_locked(ids[0]))
	var game := _screen(main)
	check("...and the picture opens", game != home and game.level != null and game.level.id == ids[0])
	check("...without giving the other Premium pictures away", lib.is_locked(ids[1]))

	# --- the pack: free power-ups with an empty wallet ---
	game._go_home()
	await wait(1.4)
	home = _screen(main)
	home._on_level_chosen(ids[1])
	await wait(0.5)
	modal = home._modal
	store.provider.next_result = StoreProvider.Result.CANCELED
	modal._on_buy()
	await wait(0.4)
	check("canceling the purchase leaves the dialog open and nothing unlocked", is_instance_valid(modal) and not gs.premium and lib.is_locked(ids[1]))
	store.provider.next_result = StoreProvider.Result.OK
	modal._on_buy()
	await wait(2.4)
	check("buying Premium opens the picture", gs.premium and _screen(main).level != null and _screen(main).level.id == ids[1])

	game = _screen(main)
	gs.add_coins(-gs.coins)
	game._select(0, false)
	var painted0: int = game.canvas.painted_total
	game._on_wand()
	await wait(0.8)
	check("with Premium the magic wand works with 0 coins and charges nothing",
			game.canvas.painted_total > painted0 and gs.coins == 0, "painted +%d, coins=%d" % [game.canvas.painted_total - painted0, gs.coins])

	# --- finishing a picture: the ad comes after the celebration, before the win screen ---
	_reset()
	ads.provider.shown_interstitial = 0
	var at_ad := [-1]       # -1 = no ad yet, 0 = win screen not open when the ad started, 1 = it was
	ads.presenting_changed.connect(func(on: bool) -> void:
		if on and at_ad[0] == -1:
			at_ad[0] = 1 if _is_win_overlay(_screen(main)._modal) else 0)
	game._go_home()
	await wait(1.4)
	main.open_level("moon_owl")
	await wait(1.4)
	game = _screen(main)
	_paint_everything(game)
	await wait(3.6)
	check("finishing a picture plays one interstitial", ads.provider.shown_interstitial == 1, "shown=%d" % ads.provider.shown_interstitial)
	check("...before the win screen, not on top of it", at_ad[0] == 0, str(at_ad))
	check("...and the win screen follows", _is_win_overlay(game._modal) and not ads.presenting)

	# --- Premium players go straight to the win screen ---
	game._go_home()
	await wait(1.4)
	gs.set_premium(true)
	main.open_level("parrot")
	await wait(1.4)
	game = _screen(main)
	at_ad[0] = -1
	_paint_everything(game)
	await wait(3.6)
	check("a Premium player gets no interstitial", ads.provider.shown_interstitial == 1)
	check("...and sees the win screen", _is_win_overlay(game._modal))

	# --- an ad that is not ready never holds the win screen back ---
	game._go_home()
	await wait(1.4)
	_reset()
	ads.provider.interstitial_ready = false
	main.open_level("fox")
	await wait(1.4)
	game = _screen(main)
	_paint_everything(game)
	await wait(3.6)
	check("with no ad ready the win screen still appears", ads.provider.shown_interstitial == 1 and _is_win_overlay(game._modal))

	main.queue_free()
	await process_frame


func _paint_everything(game: Control) -> void:
	var cv = game.canvas
	var lvl = cv.level
	for c in lvl.palette.size():
		cv.select_color(c)
		for i in lvl.cell_count():
			if lvl.cells[i] == c and cv.painted[i] == 0:
				cv.paint_cell(i % lvl.width, i / lvl.width, true)


## (Not `is WinOverlay`: naming a class that reaches an autoload would break this script's compile.)
func _is_win_overlay(n: Object) -> bool:
	return is_instance_valid(n) and n.has_signal("timelapse_pressed")
