extends SceneTree
## Loads every GDScript under the folders a game lists, so a parse error fails
## even in a script nothing else loads yet. Kept out of exported games. A game's
## tools/parse_all.gd extends it:
##
##     extends "res://addons/hatchery/testing/parse_runner.gd"
##     func folders() -> Array[String]:
##         return ["res://scripts", "res://tools"]
##
## Run: godot --headless --path . --script res://tools/parse_all.gd
## Exits non-zero when any script fails to load, or when none was found.


func _init() -> void:
	var failed: int = 0
	var paths: Array[String] = []
	for folder in folders():
		_collect(folder, paths)
	for path in paths:
		var script: Variant = load(path)
		if not script is GDScript or not (script as GDScript).can_instantiate():
			failed += 1
			print("FAIL  ", path)
	print("%d scripts, %d failed to load" % [paths.size(), failed])
	quit(1 if failed > 0 or paths.is_empty() else 0)


## The folders to scan, each searched recursively. Override in the game's script.
func folders() -> Array[String]:
	return []


func _collect(folder: String, into: Array[String]) -> void:
	for name in DirAccess.get_files_at(folder):
		if name.ends_with(".gd"):
			into.append(folder.path_join(name))
	for name in DirAccess.get_directories_at(folder):
		_collect(folder.path_join(name), into)
