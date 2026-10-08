extends Control
## The hub: five pages (Home, Categories, Diary, Shop, Profile) and the fixed bottom bar that
## switches between them. Pages are built the first time they are shown and then kept, so the
## gallery keeps its scroll position while you peek at another tab.
##
## The hub is rebuilt every time you come back from a picture; `last_tab` and `last_category`
## remember where you were.

signal level_chosen(level_id: String)

static var last_tab: StringName = &"home"
static var last_category: StringName = Categories.ALL

@onready var page_host: Control = %PageHost
@onready var nav: BottomNav = %BottomNav

var _pages: Dictionary = {}     ## tab id -> Control
var _current: Control
var _modal: Modal


func _ready() -> void:
	nav.set_current(last_tab, false)
	nav.tab_selected.connect(_show_tab)
	_show_tab(last_tab, false)


func handle_back() -> bool:
	if is_instance_valid(_modal):
		_modal.close()
		return true
	if nav.current() != &"home":
		nav.set_current(&"home")
		_show_tab(&"home")
		return true
	return false  # let Main quit the app


# -- tabs ---------------------------------------------------------------------------------

func _show_tab(id: StringName, animate: bool = true) -> void:
	last_tab = id
	var page: Control = _pages.get(id)
	if page == null:
		page = _make_page(id)
		_pages[id] = page
		page_host.add_child(page)
	elif page.has_method("activate"):
		page.activate()
	if page == _current:
		return
	var old := _current
	_current = page
	if old != null:
		old.visible = false
	page.visible = true
	if animate:
		page.modulate.a = 0.0
		create_tween().tween_property(page, "modulate:a", 1.0, 0.22)
	else:
		page.modulate.a = 1.0


func _make_page(id: StringName) -> Control:
	match id:
		&"categories":
			var p := CategoriesPage.new()
			p.category_chosen.connect(_open_category)
			p.level_chosen.connect(_on_level_chosen)
			return p
		&"diary":
			var p := DiaryPage.new()
			p.level_chosen.connect(_on_level_chosen)
			return p
		&"shop":
			return ShopPage.new()
		&"profile":
			var p := ProfilePage.new()
			p.settings_requested.connect(_open_settings)
			return p
		_:
			var p := GalleryPage.new()
			p.category = last_category
			p.level_chosen.connect(_on_level_chosen)
			p.settings_requested.connect(_open_settings)
			p.shop_requested.connect(func() -> void:
				nav.set_current(&"shop")
				_show_tab(&"shop"))
			return p


func _open_category(id: StringName) -> void:
	last_category = id
	var gallery: GalleryPage = _pages.get(&"home")
	if gallery != null:
		gallery.select_category(id)
	nav.set_current(&"home")
	_show_tab(&"home")


func _on_level_chosen(level_id: String) -> void:
	var gallery: GalleryPage = _pages.get(&"home")
	if gallery != null:
		last_category = gallery.category
	if LevelLibrary.is_locked(level_id):
		_open_unlock(level_id)
		return
	level_chosen.emit(level_id)


## A Premium picture the player does not own: offer the video / the pack, and open the picture
## once either one works (after the dialog has faded out).
func _open_unlock(level_id: String) -> void:
	var level := LevelLibrary.get_level(level_id)
	if level == null:
		return
	var m := UnlockModal.new()
	_modal = m
	add_child(m)
	m.present(LevelLibrary.get_entry(level_id), level)
	m.unlocked.connect(func(id: String) -> void:
		await m.closed
		if is_inside_tree():
			level_chosen.emit(id))


func _open_settings() -> void:
	_modal = SettingsModal.new()
	add_child(_modal)
