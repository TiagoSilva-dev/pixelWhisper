class_name AdProvider
extends RefCounted
## What the game needs from an ad SDK. `Ads` (autoload) talks only to this contract, so the
## game does not care which SDK sits behind it: `MockAdProvider` in the editor / Web / tests, and
## an AdMob wrapper on Android (see docs/MONETIZATION.md).
##
## This base class is also the "no ads at all" provider: nothing is ever ready, so the game
## simply skips every ad. Release builds on a phone use it until a real SDK is wired in.
##
## `show_*` are coroutines: callers `await` them. They must always come back, whatever happens
## (ad closed, failed to show, app backgrounded), or the game would hang on an ad.

signal availability_changed   ## an ad finished loading, or the one that was loaded got used up


## Connect to the SDK and start preloading. Called once by `Ads`.
func start() -> void:
	pass


func is_interstitial_ready() -> bool:
	return false


func is_rewarded_ready() -> bool:
	return false


## Shows a full-screen ad between two screens; returns when the player has closed it.
func show_interstitial() -> void:
	pass


## Shows an opt-in video; returns true only if the player earned the reward (watched it through).
func show_rewarded() -> bool:
	return false
