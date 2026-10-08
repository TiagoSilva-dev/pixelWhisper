class_name MockAdProvider
extends AdProvider
## Stand-in for the ad SDK in the editor, the Web build and the tests: it plays a fake ad (see
## MockAdScreen) so the whole flow can be seen and tried without any account or device.
##
## The public vars are the knobs the tests turn.

var seconds: float = 3.0              ## how long the fake ad runs; 0 = no screen, done at once
var auto_close: bool = false          ## close by itself when the countdown ends (otherwise the player taps X)
var interstitial_ready: bool = true
var rewarded_ready: bool = true
var player_closes_early: bool = false ## with `seconds` = 0: a rewarded video ends without paying
var shown_interstitial: int = 0
var shown_rewarded: int = 0

var _host: Node


func _init(host: Node) -> void:
	_host = host


func is_interstitial_ready() -> bool:
	return interstitial_ready


func is_rewarded_ready() -> bool:
	return rewarded_ready


func show_interstitial() -> void:
	shown_interstitial += 1
	await _play(false)


func show_rewarded() -> bool:
	shown_rewarded += 1
	return await _play(true)


func _play(rewarded: bool) -> bool:
	if seconds <= 0.0:
		await _host.get_tree().process_frame   # still asynchronous, like a real SDK
		return not (rewarded and player_closes_early)
	return await MockAdScreen.play(_host, rewarded, seconds, auto_close)
