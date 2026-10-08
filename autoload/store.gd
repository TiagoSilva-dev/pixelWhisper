extends Node
## The Premium pack, bought once: every picture unlocked, the power-ups free and no interstitials.
## Whether the player owns it lives in `GameState.premium` (saved).
##
## The app store sits behind a `StoreProvider` (see _make_provider and docs/MONETIZATION.md). When
## that provider is authoritative (real billing) the saved flag is re-checked against the store
## every time it reports, so editing the save file does not unlock Premium and a refund revokes it.

signal state_changed   ## the price became known, or ownership was re-checked

const Result := StoreProvider.Result

var provider: StoreProvider


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	provider = _make_provider()
	provider.changed.connect(_sync)
	provider.start()


## Which billing to use (see Monetization.mocks_allowed). The real one plugs in here, before the
## mock fallback, once the plugin is installed (docs/MONETIZATION.md).
func _make_provider() -> StoreProvider:
	if Monetization.mocks_allowed():
		return MockStoreProvider.new(self)
	return StoreProvider.new()   # release build on a phone, no billing yet: nothing for sale


func is_available() -> bool:
	return provider.is_available()


## The store's own formatted price ("R$ 19,90"); empty while unknown.
func price_text() -> String:
	return provider.price_text()


## Starts the purchase and returns how it went. Already owning Premium counts as OK.
func buy_premium() -> Result:
	if GameState.premium:
		return Result.OK
	var result: Result = await provider.buy_premium()
	if result == Result.OK:
		GameState.set_premium(true)
	state_changed.emit()
	return result


## "Restore purchases": asks the store again; true if the player owns Premium afterwards.
func restore() -> bool:
	var owned: bool = await provider.restore()
	if provider.authoritative or owned:   # a store with no account behind it can only grant, never revoke
		GameState.set_premium(owned)
	state_changed.emit()
	return GameState.premium


## The store answered (see StoreProvider.changed): trust it over the save file if it is authoritative.
func _sync() -> void:
	if provider.authoritative:
		GameState.set_premium(provider.owns_premium())
	state_changed.emit()
