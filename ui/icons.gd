class_name Icons
extends RefCounted
## Every icon of the game, from two free icon sets (see assets/icons/LICENSES.md and
## tools/fetch_icons.py):
##
##   * "color" icons: Fluent Emoji 3D, 256x256 PNGs that keep their own colors;
##   * "glyph" icons: Phosphor SVGs (back, close, check...), white, tinted with `color`.
##
## `Icons.draw(canvas_item, kind, center, u, color)` paints into the `_draw()` of any CanvasItem;
## the artwork stays inside [-u, u] around `center`. Each icon is rasterized once per on-screen
## size (SVGs straight from the vectors, PNGs with a Lanczos downscale), so it stays sharp at any
## DPI and window scale. `color` only affects glyphs (its alpha also fades color icons).

enum Kind {
	NONE, BACK, CLOSE, CHECK, PLAY, NEXT, PLUS, FIT, SAVE, REPLAY,
	STAR, PAW, BRUSH, AVATAR, DIAMOND, GEAR, COIN, BULB, WAND, BOMB, MAGNIFIER,
	HOME, STACK, CALENDAR, SHOP, USER, GIFT, FLAME, TROPHY, LOCK, CLAPPER,
}

const DIR := "res://assets/icons/"
const FILES := {
	Kind.BACK: "glyph/back.svg",
	Kind.CLOSE: "glyph/close.svg",
	Kind.CHECK: "glyph/check.svg",
	Kind.PLAY: "glyph/play.svg",
	Kind.NEXT: "glyph/next.svg",
	Kind.PLUS: "glyph/plus.svg",
	Kind.FIT: "glyph/fit.svg",
	Kind.SAVE: "glyph/save.svg",
	Kind.REPLAY: "glyph/replay.svg",
	Kind.STAR: "color/star.png",
	Kind.PAW: "color/paw.png",
	Kind.BRUSH: "color/brush.png",
	Kind.AVATAR: "color/avatar.png",
	Kind.DIAMOND: "color/diamond.png",
	Kind.GEAR: "color/gear.png",
	Kind.COIN: "color/coin.png",
	Kind.BULB: "color/bulb.png",
	Kind.WAND: "color/wand.png",
	Kind.BOMB: "color/bomb.png",
	Kind.MAGNIFIER: "color/magnifier.png",
	Kind.HOME: "color/home.png",
	Kind.STACK: "color/stack.png",
	Kind.CALENDAR: "color/calendar.png",
	Kind.SHOP: "color/shop.png",
	Kind.USER: "color/user.png",
	Kind.GIFT: "color/gift.png",
	Kind.FLAME: "color/flame.png",
	Kind.TROPHY: "color/trophy.png",
	Kind.LOCK: "color/lock.png",
	Kind.CLAPPER: "color/clapper.png",
}

const SOURCE_PX := 256.0       # the PNGs' size and the SVGs' viewBox
const GLYPH_SPAN := 1.12       # artwork half-extent per unit of `u` (Phosphor leaves ~6% padding)
const COLOR_SPAN := 1.1
const SNAP_PX := 4             # on-screen sizes are rounded to this, so tweens don't mint textures

static var _sources: Dictionary = {}    # Kind -> Image (PNG) | String (SVG)
static var _textures: Dictionary = {}   # kind * 4096 + pixels -> ImageTexture


static func draw(ci: CanvasItem, kind: Kind, c: Vector2, u: float, col: Color = Color.WHITE) -> void:
	if not FILES.has(kind):
		return
	var glyph := is_glyph(kind)
	var half := u * (GLYPH_SPAN if glyph else COLOR_SPAN)
	var tex := texture(kind, _screen_pixels(ci, half * 2.0))
	if tex:
		ci.draw_texture_rect(tex, Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0), false,
				col if glyph else Color(1, 1, 1, col.a))


static func is_glyph(kind: Kind) -> bool:
	return FILES.get(kind, "").ends_with(".svg")


## The icon rasterized to `px` x `px` (cached). Null if its file can't be read.
static func texture(kind: Kind, px: int) -> Texture2D:
	var key: int = kind * 4096 + px
	if not _textures.has(key):
		_textures[key] = _rasterize(kind, px)
	return _textures[key]


## A plain five-point star for decoration that is not an icon (the paper background).
static func star(ci: CanvasItem, center: Vector2, radius: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		pts.append(center + Vector2.from_angle(a) * radius * (1.0 if i % 2 == 0 else 0.45))
	ci.draw_colored_polygon(pts, col)


# -- internals ----------------------------------------------------------------------------

## On-screen size in physical pixels: `extent` is in canvas units, the window may stretch them.
## The node's own `scale` is ignored on purpose (press/pop tweens animate it).
static func _screen_pixels(ci: CanvasItem, extent: float) -> int:
	var stretch := 1.0
	if ci.is_inside_tree():
		stretch = ci.get_viewport().get_final_transform().get_scale().x
	return maxi(SNAP_PX * 2, roundi(extent * stretch / SNAP_PX) * SNAP_PX)


static func _rasterize(kind: Kind, px: int) -> Texture2D:
	var src: Variant = _source(kind)
	var img: Image
	if src is String:
		img = Image.new()
		if img.load_svg_from_string(src, px / SOURCE_PX) != OK:
			return null
	elif src is Image:
		img = src
		if px < img.get_width():
			img = img.duplicate()
			img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	else:
		return null
	return ImageTexture.create_from_image(img)


static func _source(kind: Kind) -> Variant:
	if not _sources.has(kind):
		var path: String = DIR + FILES[kind]
		var bytes := FileAccess.get_file_as_bytes(path)
		var src: Variant = null
		if bytes.is_empty():
			push_error("Icons: cannot read %s" % path)
		elif path.ends_with(".svg"):
			src = bytes.get_string_from_utf8()
		else:
			var img := Image.new()
			if img.load_png_from_buffer(bytes) == OK:
				src = img
		_sources[kind] = src
	return _sources[kind]
