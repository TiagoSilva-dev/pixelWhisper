class_name SettingsModal
extends Modal
## Sound / Music / Haptics / Numbers / Grid / Language. Optional extra actions (e.g.
## "Restart picture") are injected by whoever opens it.

const LANGS := ["auto", "en", "pt"]


func _init() -> void:
	super()
	add_header("Settings")
	_toggle_row("Sound", &"sound_on")
	_toggle_row("Music", &"music_on")
	_toggle_row("Haptics", &"haptics_on")
	_toggle_row("Numbers", &"show_numbers")
	_toggle_row("Grid", &"show_grid")
	_toggle_row("Glass effects", &"glass_fx")
	_language_row()


func _toggle_row(label_text: String, setting: StringName) -> void:
	var row := HBoxContainer.new()
	content.add_child(row)
	var l := Label.new()
	l.text = label_text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var sw := ToggleSwitch.new(GameState.get(setting))
	sw.toggled.connect(func(on: bool) -> void: GameState.set_setting(setting, on))
	row.add_child(sw)


func _language_row() -> void:
	var row := HBoxContainer.new()
	content.add_child(row)
	var l := Label.new()
	l.text = "Language"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var b := Button.new()
	b.theme_type_variation = &"ChipButton"
	b.text = _lang_name(GameState.language)
	b.pressed.connect(func() -> void:
		var next: String = LANGS[(LANGS.find(GameState.language) + 1) % LANGS.size()]
		GameState.set_setting(&"language", next)
		b.text = _lang_name(next))
	UiFx.press_juice(b)
	row.add_child(b)


func _lang_name(code: String) -> String:
	match code:
		"en": return "English"
		"pt": return "Português"
		_: return "Automatic"


## Adds a full-width action button under the toggles. With `confirm`, the first tap only
## arms the button ("Tap again to confirm") so destructive actions can't happen by accident.
func add_action(text: String, callback: Callable, confirm: bool = false) -> void:
	var b := Button.new()
	b.theme_type_variation = &"GhostButton"
	b.text = text
	var armed := [false]
	b.pressed.connect(func() -> void:
		if confirm and not armed[0]:
			armed[0] = true
			b.text = "Tap again to confirm"
			b.add_theme_color_override("font_color", AppTheme.ACCENT)
			get_tree().create_timer(3.0).timeout.connect(func() -> void:
				if is_instance_valid(b):
					armed[0] = false
					b.text = text
					b.remove_theme_color_override("font_color"))
			return
		close()
		callback.call())
	UiFx.press_juice(b)
	content.add_child(b)
