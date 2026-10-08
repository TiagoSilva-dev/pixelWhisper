class_name ImageExport
extends RefCounted
## Renders a finished picture as a shareable PNG (nearest-neighbour upscale + frame)
## and saves it where the platform allows.

## Returns the finished artwork, `scale` times larger, on a dark rounded-looking frame.
static func render(level: PixelLevel, scale: int = 16, frame: int = 48) -> Image:
	var art := level.build_target_image()
	art.resize(level.width * scale, level.height * scale, Image.INTERPOLATE_NEAREST)
	var out := Image.create(art.get_width() + frame * 2, art.get_height() + frame * 2, false, Image.FORMAT_RGBA8)
	out.fill(AppTheme.BG_BOTTOM)
	out.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i(frame, frame))
	return out


## Saves the picture. Returns a human-readable location ("" on failure).
## Web: triggers a browser download. Desktop/mobile: Pictures/PixelWhisper, falling back
## to the app's private user:// folder when the OS refuses (e.g. Android without storage access).
static func save(level: PixelLevel) -> String:
	var img := render(level)
	var file_name := "pixelwhisper_%s_%d.png" % [level.id, Time.get_unix_time_from_system()]

	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), file_name, "image/png")
		return file_name

	var dirs: Array[String] = []
	var pictures := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pictures != "":
		dirs.append(pictures.path_join("PixelWhisper"))
	dirs.append("user://exports")
	for dir in dirs:
		if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
			continue
		var path: String = dir.path_join(file_name)
		if img.save_png(path) == OK:
			return ProjectSettings.globalize_path(path) if path.begins_with("user://") else path
	return ""
