#!/usr/bin/env python3
"""Downloads the game's icon set into assets/icons/ (run with `python3 -I tools/fetch_icons.py`).

Two third-party sets, both MIT-licensed (the notices are written to assets/icons/LICENSES.md):

  * Fluent Emoji "3D" (Microsoft)  -> assets/icons/color/*.png   256x256, illustrated icons
  * Phosphor Icons "bold"/"fill"   -> assets/icons/glyph/*.svg   white glyphs, tinted at draw time

Needs ImageMagick (`convert`). Each PNG is first centered on its visible box (the sets draw some
objects low in the square, e.g. the gem), so every icon fills the same optical area. The PNGs also
ship with black RGB under their transparent pixels, which turns into a dark halo as soon as they
are scaled down, so every transparent pixel is then given the color of its nearest visible
neighbour ("alpha bleeding"). Alpha itself is never touched by the bleeding.

Every file gets a `.import` of type "keep": Godot then exports it untouched and `ui/icons.gd` can
read the raw bytes at runtime and rasterize it at the exact on-screen size.

To use another icon: add a line to COLOR or GLYPHS, run this script, add the name to `Icons.Kind`
and to the tables in `ui/icons.gd`.
"""
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

FLUENT_COMMIT = "1ffb34c752ecf5d402f04cfb4b392c77f57c54bc"
PHOSPHOR_VERSION = "2.1.1"

FLUENT_URL = "https://raw.githubusercontent.com/microsoft/fluentui-emoji/%s/%s"
PHOSPHOR_URL = "https://cdn.jsdelivr.net/npm/@phosphor-icons/core@%s/assets/%s/%s.svg"

# local name -> path inside microsoft/fluentui-emoji
COLOR = {
	"star": "assets/Star/3D/star_3d.png",
	"paw": "assets/Paw prints/3D/paw_prints_3d.png",
	"brush": "assets/Paintbrush/3D/paintbrush_3d.png",
	"avatar": "assets/Girl/Default/3D/girl_3d_default.png",
	"diamond": "assets/Gem stone/3D/gem_stone_3d.png",
	"gear": "assets/Gear/3D/gear_3d.png",
	"coin": "assets/Coin/3D/coin_3d.png",
	"bulb": "assets/Light bulb/3D/light_bulb_3d.png",
	"wand": "assets/Magic wand/3D/magic_wand_3d.png",
	"bomb": "assets/Bomb/3D/bomb_3d.png",
	"magnifier": "assets/Magnifying glass tilted left/3D/magnifying_glass_tilted_left_3d.png",
	"home": "assets/House/3D/house_3d.png",
	"stack": "assets/Books/3D/books_3d.png",
	"calendar": "assets/Calendar/3D/calendar_3d.png",
	"shop": "assets/Shopping bags/3D/shopping_bags_3d.png",
	"user": "assets/Smiling face with smiling eyes/3D/smiling_face_with_smiling_eyes_3d.png",
	"gift": "assets/Wrapped gift/3D/wrapped_gift_3d.png",
	"flame": "assets/Fire/3D/fire_3d.png",
	"trophy": "assets/Trophy/3D/trophy_3d.png",
	"lock": "assets/Locked/3D/locked_3d.png",
	"clapper": "assets/Clapper board/3D/clapper_board_3d.png",
}

# local name -> (weight folder, file name) inside @phosphor-icons/core
GLYPHS = {
	"back": ("bold", "caret-left-bold"),
	"next": ("bold", "caret-right-bold"),
	"close": ("bold", "x-bold"),
	"plus": ("bold", "plus-bold"),
	"check": ("bold", "check-bold"),
	"play": ("fill", "play-fill"),
	"fit": ("bold", "corners-out-bold"),
	"save": ("bold", "download-simple-bold"),
	"replay": ("bold", "arrow-counter-clockwise-bold"),
}

ARTWORK_PX = 224   # longest side of the visible artwork inside the 256 px canvas
ROOT = Path(__file__).resolve().parent.parent / "assets" / "icons"
KEEP_IMPORT = '[remap]\n\nimporter="keep"\n'


def fetch(url: str) -> bytes:
	req = urllib.request.Request(url, headers={"User-Agent": "pixelwhisper-icon-fetch"})
	with urllib.request.urlopen(req, timeout=60) as resp:
		return resp.read()


def magick(args: list, data: bytes = b"") -> bytes:
	out = subprocess.run(["convert"] + args, input=data, capture_output=True, check=True)
	return out.stdout


def fit(png: bytes) -> bytes:
	"""Crops to the visible box and recenters it so its longest side is ARTWORK_PX."""
	box = magick(["png:-", "-alpha", "extract", "-threshold", "50%", "-format", "%@", "info:"], png).decode()
	return magick(["png:-", "-crop", box, "+repage", "-resize", "%dx%d" % (ARTWORK_PX, ARTWORK_PX),
			"-background", "none", "-gravity", "center", "-extent", "256x256", "PNG32:-"], png)


def bleed_alpha(png: bytes) -> bytes:
	w, h = (int(v) for v in magick(["png:-", "-format", "%w %h", "info:"], png).split())
	px = bytearray(magick(["png:-", "-depth", "8", "rgba:-"], png))
	assert len(px) == w * h * 4, "unexpected raw size"
	done = bytearray(w * h)
	queue = []
	for i in range(w * h):
		if px[i * 4 + 3] > 2:
			done[i] = 1
			queue.append(i)
	head = 0
	while head < len(queue):  # multi-source BFS: each hidden pixel copies its nearest visible one
		i = queue[head]
		head += 1
		x, y = i % w, i // w
		for j in (i - 1 if x else -1, i + 1 if x < w - 1 else -1, i - w if y else -1, i + w if y < h - 1 else -1):
			if j >= 0 and not done[j]:
				done[j] = 1
				px[j * 4:j * 4 + 3] = px[i * 4:i * 4 + 3]
				queue.append(j)
	return magick(["-size", "%dx%d" % (w, h), "-depth", "8", "rgba:-", "-strip", "PNG32:-"], bytes(px))


def write_keep(path: Path, data: bytes) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_bytes(data)
	Path(str(path) + ".import").write_text(KEEP_IMPORT)


def licenses() -> str:
	fluent = fetch(FLUENT_URL % (FLUENT_COMMIT, "LICENSE")).decode().strip()
	phosphor = fetch("https://cdn.jsdelivr.net/npm/@phosphor-icons/core@%s/LICENSE" % PHOSPHOR_VERSION).decode().strip()
	return (
		"# Icon licenses\n\n"
		"Both icon sets below are MIT-licensed. Regenerate the files with `python3 -I tools/fetch_icons.py`.\n\n"
		"## Fluent Emoji (3D) — `color/*.png`\n\n"
		"Source: https://github.com/microsoft/fluentui-emoji @ `%s`. Recentered on their visible box and "
		"alpha-bled (transparent pixels recolored) by the script; otherwise unmodified.\n\n```\n%s\n```\n\n"
		"## Phosphor Icons — `glyph/*.svg`\n\n"
		"Source: https://github.com/phosphor-icons/core (`@phosphor-icons/core@%s`). `currentColor` replaced "
		"by white so the game can tint them; otherwise unmodified.\n\n```\n%s\n```\n"
	) % (FLUENT_COMMIT, fluent, PHOSPHOR_VERSION, phosphor)


def main() -> int:
	for name, path in COLOR.items():
		url = FLUENT_URL % (FLUENT_COMMIT, urllib.parse.quote(path))
		write_keep(ROOT / "color" / (name + ".png"), bleed_alpha(fit(fetch(url))))
		print("color/%s.png" % name)
	for name, (weight, file) in GLYPHS.items():
		svg = fetch(PHOSPHOR_URL % (PHOSPHOR_VERSION, weight, file)).decode()
		assert "currentColor" in svg, name
		write_keep(ROOT / "glyph" / (name + ".svg"), svg.replace("currentColor", "#FFFFFF").encode())
		print("glyph/%s.svg" % name)
	(ROOT / "LICENSES.md").write_text(licenses())
	return 0


if __name__ == "__main__":
	sys.exit(main())
