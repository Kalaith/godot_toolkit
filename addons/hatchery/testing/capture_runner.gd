extends SceneTree
## Drives the real game and saves screenshots, for checking visuals by looking
## at them. Needs a rendering window (not --headless). A game's
## tools/capture.gd extends it and scripts the tour:
##
##     extends "res://addons/hatchery/testing/capture_runner.gd"
##     func tour() -> void:
##         var main: Node = await open_scene("res://scenes/main.tscn")
##         await shot("01_title")
##         main.start_game()
##         await seconds(1.5)
##         await shot("02_map")
##
## Run: godot --path . --script res://tools/capture.gd -- [output dir] [--size=1280x720]

var out_dir: String = "user://captures"
var shots: Array[String] = []


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--size="):
			var parts: PackedStringArray = argument.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				root.size = Vector2i(int(parts[0]), int(parts[1]))
		elif not argument.begins_with("--"):
			out_dir = argument
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


## The scripted tour. Override in the game's capture script.
func tour() -> void:
	pass


func _run() -> void:
	await tour()
	print("Saved %d capture(s) to %s" % [shots.size(), ProjectSettings.globalize_path(out_dir)])
	quit(0)


## Instantiates `path` under the root and waits for it to settle.
func open_scene(path: String, settle_frames: int = 10) -> Node:
	var node: Node = load(path).instantiate()
	root.add_child(node)
	await frames(settle_frames)
	return node


func frames(count: int) -> void:
	for i in range(count):
		await process_frame


func seconds(duration: float) -> void:
	await create_timer(duration).timeout


## Saves the current frame as `<out_dir>/<name>.png`.
func shot(name: String) -> String:
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join(name + ".png")
	var error: Error = root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save capture " + path)
		return ""
	shots.append(path)
	return path
