extends SceneTree
## Loads every script, scene and shader in the project and reports the ones that fail.
##   godot --headless --path . --script res://tools/tests/check_project.gd
## Exit code = number of failures, so it can gate CI.

const EXTENSIONS := [".gd", ".tscn", ".gdshader"]
const SKIP_DIRS := [".godot", ".git", "addons", "tools", "build"]


func _initialize() -> void:
	var paths: Array[String] = []
	_collect("res://", paths)
	paths.sort()
	var failed := 0
	for p in paths:
		var res := ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE)
		var ok := res != null
		if res is GDScript:
			ok = (res as GDScript).can_instantiate() or (res as GDScript).is_abstract()
		if not ok:
			failed += 1
			print("FAIL  ", p)
	print("checked %d files, %d failure(s)" % [paths.size(), failed])
	quit(failed)


func _collect(dir: String, out: Array[String]) -> void:
	for d in DirAccess.get_directories_at(dir):
		if d in SKIP_DIRS:
			continue
		_collect(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		for ext in EXTENSIONS:
			if f.ends_with(ext):
				out.append(dir.path_join(f))
