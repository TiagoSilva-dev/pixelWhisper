extends Node
## Video ads: an interstitial when a picture is finished, and the opt-in rewarded video that opens
## a Premium picture. Premium players never see an interstitial.
##
## The game talks only to this node; the SDK lives behind an `AdProvider` (see _make_provider and
## docs/MONETIZATION.md). An ad that is not ready (offline, no fill, no SDK) is skipped, never
## waited for: the player is never held up by an ad.

signal presenting_changed(on: bool)    ## an ad is on screen (or has just closed)
signal availability_changed            ## a rewarded or interstitial ad became ready / was used up

var provider: AdProvider
var presenting: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	provider = _make_provider()
	provider.availability_changed.connect(availability_changed.emit)
	provider.start()


## Which SDK to use (see Monetization.mocks_allowed). The real one plugs in here, before the mock
## fallback, once the plugin is installed (docs/MONETIZATION.md).
func _make_provider() -> AdProvider:
	if Monetization.mocks_allowed():
		return MockAdProvider.new(self)
	return AdProvider.new()   # release build on a phone, no SDK yet: no ads at all


func is_rewarded_ready() -> bool:
	return provider.is_rewarded_ready()


## Plays an interstitial and returns true if one was shown. Returns false at once (and the caller
## just carries on) for Premium players, while another ad is on screen, or if none is ready.
func show_interstitial() -> bool:
	if GameState.premium or presenting or not provider.is_interstitial_ready():
		return false
	_set_presenting(true)
	await provider.show_interstitial()
	_set_presenting(false)
	return true


## Plays a rewarded video; true only if the player watched it to the end and earned the reward.
func show_rewarded() -> bool:
	if presenting or not provider.is_rewarded_ready():
		return false
	_set_presenting(true)
	var earned: bool = await provider.show_rewarded()
	_set_presenting(false)
	return earned


func _set_presenting(on: bool) -> void:
	presenting = on
	Feedback.pause_music(on)   # an ad brings its own sound
	presenting_changed.emit(on)
