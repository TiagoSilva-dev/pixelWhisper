extends Node
## Catalogue of playable pictures: the bundled pack in res://assets/levels/ (listed, in display
## order, by manifest.json). Adding a picture = drop a 64x64 PNG there and add one manifest line.
##
## Levels are built lazily and cached. Building one is a ~3 ms pixel scan, so there is
## no need to pre-bake anything at export time.

signal library_changed

const BUNDLED_DIR := "res://assets/levels/"

## [{id, title, path, category, popular, premium}] in display order. `title` is an English
## translation key; `category` is one of Categories (animals / drawings / anime).
var entries: Array[Dictionary] = []
var _cache: Dictionary = {}  # id -> PixelLevel


func _ready() -> void:
	rescan()


func rescan() -> void:
	entries.clear()
	_cache.clear()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUNDLED_DIR + "manifest.json"))
	if typeof(manifest) == TYPE_DICTIONARY:
		for item in manifest.get("levels", []):
			entries.append({
				"id": str(item.id),
				"title": str(item.title),
				"path": BUNDLED_DIR + str(item.file),
				"category": str(item.get("category", "drawings")),
				"popular": bool(item.get("popular", false)),
				"premium": bool(item.get("premium", false)),
			})
	else:
		push_error("LevelLibrary: cannot read %smanifest.json" % BUNDLED_DIR)
	library_changed.emit()


func get_entry(level_id: String) -> Dictionary:
	for e in entries:
		if e.id == level_id:
			return e
	return {}


## Entries of a category (see Categories), in display order. `Categories.ALL` returns everything.
func entries_in(category: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries:
		if Categories.matches(e, category):
			out.append(e)
	return out


func index_of(level_id: String) -> int:
	for i in entries.size():
		if entries[i].id == level_id:
			return i
	return -1


## Is this a Premium picture the player has not opened yet (no Premium pack, no rewarded video)?
func is_locked(level_id: String) -> bool:
	var e := get_entry(level_id)
	return e.get("premium", false) and not GameState.premium and not GameState.has_unlocked(level_id)


## The entry after `level_id` that the player has not finished and can play, wrapping around.
## Locked Premium pictures are skipped: "Next picture" must never land on a paywall.
func next_unfinished(level_id: String) -> String:
	var start := index_of(level_id)
	for step in range(1, entries.size() + 1):
		var e := entries[(start + step) % entries.size()]
		if not GameState.is_completed(e.id) and not is_locked(e.id):
			return e.id
	return ""


func get_level(level_id: String) -> PixelLevel:
	if _cache.has(level_id):
		return _cache[level_id]
	var e := get_entry(level_id)
	if e.is_empty():
		return null
	# Imported textures: works in the editor *and* in exported builds.
	var tex := load(e.path) as Texture2D
	if tex == null:
		push_error("LevelLibrary: cannot load image %s" % e.path)
		return null
	var level := LevelGenerator.generate(tex.get_image(), {"id": e.id, "title": e.title})
	_cache[level_id] = level
	return level
