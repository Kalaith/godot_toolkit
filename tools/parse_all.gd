extends SceneTree
## Loads every script under addons/ so a parse error anywhere fails, even in
## modules no check uses. Run: godot --headless --path . --script res://tools/parse_all.gd


func _init() -> void:
	var failed: int = 0
	var paths: Array[String] = []
	_collect("res://addons/hatchery", paths)
	for path in paths:
		var script: Variant = load(path)
		if not script is GDScript or not (script as GDScript).can_instantiate():
			failed += 1
			print("FAIL  ", path)
	print("%d scripts, %d failed to load" % [paths.size(), failed])
	quit(1 if failed > 0 else 0)


func _collect(folder: String, into: Array[String]) -> void:
	for name in DirAccess.get_files_at(folder):
		if name.ends_with(".gd"):
			into.append(folder.path_join(name))
	for name in DirAccess.get_directories_at(folder):
		_collect(folder.path_join(name), into)
