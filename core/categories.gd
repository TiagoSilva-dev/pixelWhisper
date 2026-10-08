class_name Categories
extends RefCounted
## The gallery's categories. A picture belongs to exactly one `category` (animals / drawings /
## anime, set in assets/levels/manifest.json) and can additionally carry the `popular` and
## `premium` tags. "Popular" and "Premium" therefore behave as categories in the UI too.

const ALL := &"all"


## [{id, title (English translation key), color, icon}] in display order.
static func list() -> Array[Dictionary]:
	return [
		{"id": &"popular", "title": "Popular", "color": AppTheme.PURPLE, "icon": Icons.Kind.STAR},
		{"id": &"animals", "title": "Animals", "color": AppTheme.GREEN, "icon": Icons.Kind.PAW},
		{"id": &"drawings", "title": "Drawings", "color": AppTheme.ORANGE, "icon": Icons.Kind.BRUSH},
		{"id": &"anime", "title": "Anime", "color": AppTheme.BLUE, "icon": Icons.Kind.AVATAR},
		{"id": &"premium", "title": "Premium", "color": AppTheme.CYAN, "icon": Icons.Kind.DIAMOND},
	]


static func info(id: StringName) -> Dictionary:
	for c in list():
		if c.id == id:
			return c
	return {}


## Does a LevelLibrary entry belong to category `id`? `ALL` (or an empty id) matches everything.
static func matches(entry: Dictionary, id: StringName) -> bool:
	match id:
		&"", ALL:
			return true
		&"popular":
			return entry.get("popular", false)
		&"premium":
			return entry.get("premium", false)
		_:
			return entry.get("category", "") == String(id)
