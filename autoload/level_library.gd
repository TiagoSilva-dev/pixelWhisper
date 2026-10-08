extends Node
## Catalogue of playable pictures: the bundled pack in res://assets/levels/ (listed, in display
## order, by manifest.json). Adding a picture = drop a 64x64 PNG there and add one manifest line.
##
## Levels are built lazily and cached. Building one is a ~3 ms pixel scan, so there is
## no need to pre-bake anything at export time.

signal library_changed

const BUNDLED_DIR := "res://assets/levels/"

## [{id, title, path}] in display order. `title` is an English translation key.
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
			})
	else:
		push_error("LevelLibrary: cannot read %smanifest.json" % BUNDLED_DIR)
	library_changed.emit()


func get_entry(level_id: String) -> Dictionary:
	for e in entries:
		if e.id == level_id:
			return e
	return {}


func index_of(level_id: String) -> int:
	for i in entries.size():
		if entries[i].id == level_id:
			return i
	return -1


## The entry after `level_id` that the player has not finished, wrapping around.
func next_unfinished(level_id: String) -> String:
	var start := index_of(level_id)
	for step in range(1, entries.size() + 1):
		var e := entries[(start + step) % entries.size()]
		if not GameState.is_completed(e.id):
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
