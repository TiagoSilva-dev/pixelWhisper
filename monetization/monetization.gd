class_name Monetization
extends RefCounted
## The one rule that decides whether ads and purchases are simulated.


## May the fake ad / fake purchase providers be used? Yes in the editor, in debug builds and on
## desktop / Web (so the whole flow can be tried anywhere). NEVER in a release build on a phone:
## the fake store would hand out Premium for free and the fake ads would ship to players. Such a
## build uses the base providers (no ads, nothing for sale) until a real SDK is wired in.
static func mocks_allowed(debug: bool = OS.is_debug_build(), mobile: bool = OS.has_feature("mobile")) -> bool:
	return debug or not mobile
