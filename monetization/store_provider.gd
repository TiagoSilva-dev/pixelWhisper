class_name StoreProvider
extends RefCounted
## What the game needs from the app store's billing. `Store` (autoload) talks only to this
## contract: `MockStoreProvider` in the editor / Web / tests, and a Google Play Billing wrapper
## on Android (see docs/MONETIZATION.md).
##
## This base class is also the "store unavailable" provider: nothing can be bought. Release
## builds on a phone use it until real billing is wired in, so they can never hand out Premium.
##
## `buy_premium` and `restore` are coroutines: callers `await` them, and they must always come
## back (bought, canceled, failed, app backgrounded).

enum Result { OK, CANCELED, FAILED }

## The price became known, or the store gave a definite answer about what the player owns (it
## connected, a purchase went through elsewhere, a refund). Emit it ONLY after a real answer: never
## while still connecting and never when offline, because an authoritative provider's answer can
## revoke Premium, and a paying player must not lose it just because the phone has no signal.
signal changed

## True when the store, not the save file, is the source of truth for what the player owns:
## `Store` then overwrites the saved Premium flag with `owns_premium()` whenever `changed` fires.
## Real billing is authoritative; the mock is not (it has no account behind it).
var authoritative: bool = false


## Connect to the store and query what the player already owns. Called once by `Store`.
func start() -> void:
	pass


func is_available() -> bool:
	return false


## Localized price from the store ("R$ 19,90"); empty while unknown.
func price_text() -> String:
	return ""


## What the store says the player owns (only meaningful when `authoritative`).
func owns_premium() -> bool:
	return false


func buy_premium() -> Result:
	return Result.FAILED


## Asks the store again what the player owns ("Restore purchases"); true if Premium is owned. If
## the store cannot be reached, answer with the last known state (GameState.premium), never false.
func restore() -> bool:
	return false
