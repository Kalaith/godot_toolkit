extends SceneTree
## Shared capture driver for any Godot 4 project. It loads the configured main
## scene, applies optional InputMap actions, and writes viewport frames per shot.

const DEFAULT_FPS: int = 30

var _plan_path: String = ""
var _output_dir: String = ""
var _failures: int = 0


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected user arguments: <plan.json> <capture-output-dir>")
		quit(2)
		return
	_plan_path = args[0]
	_output_dir = args[1]
	_run.call_deferred()


func _run() -> void:
	var plan_file := FileAccess.open(_plan_path, FileAccess.READ)
	if plan_file == null:
		push_error("Could not read the promo plan: %s" % _plan_path)
		quit(2)
		return
	var plan_value: Variant = JSON.parse_string(plan_file.get_as_text())
	if typeof(plan_value) != TYPE_DICTIONARY:
		push_error("Promo plan must contain a JSON object.")
		quit(2)
		return
	var plan: Dictionary = plan_value
	var fps: int = int(plan.get("fps", DEFAULT_FPS))
	var settle_frames: int = int(plan.get("settleFrames", fps * 3))
	var shots: Array = plan.get("shots", [])
	if fps < 1 or fps > 60 or shots.is_empty():
		push_error("Promo plan needs at least one shot and an fps value from 1 to 60.")
		quit(2)
		return
	var total_seconds: float = 0.0
	for shot_value in shots:
		if typeof(shot_value) == TYPE_DICTIONARY:
			total_seconds += float(shot_value.get("seconds", 0.0))
	if total_seconds < 15.0 or total_seconds > 30.0:
		push_error("Promo plans must total between 15 and 30 seconds.")
		quit(2)
		return

	var main_scene_path: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene_path.is_empty():
		push_error("This Godot project has no application/run/main_scene configured.")
		quit(2)
		return
	var main_scene_resource: Resource = load(main_scene_path)
	if not main_scene_resource is PackedScene:
		push_error("The configured main scene could not be loaded: %s" % main_scene_path)
		quit(2)
		return

	var main_scene: Node = (main_scene_resource as PackedScene).instantiate()
	root.add_child(main_scene)
	await _frames(settle_frames)

	for shot_value in shots:
		if typeof(shot_value) != TYPE_DICTIONARY:
			_failures += 1
			push_error("Every shot must be a JSON object.")
			continue
		var shot: Dictionary = shot_value
		var shot_name: String = str(shot.get("name", "")).strip_edges()
		var seconds: float = float(shot.get("seconds", 0.0))
		if shot_name.is_empty() or not shot_name.is_valid_filename() or seconds <= 0.0:
			_failures += 1
			push_error("Every shot needs a safe filename and a positive duration.")
			continue
		var frame_count: int = roundi(seconds * fps)
		if frame_count < 1 or frame_count > fps * 30:
			_failures += 1
			push_error("Shot %s must be no longer than 30 seconds." % shot_name)
			continue
		var shot_dir: String = _output_dir.path_join(shot_name)
		DirAccess.make_dir_recursive_absolute(shot_dir)
		var actions_by_frame: Dictionary = {}
		var actions: Array = shot.get("actions", [])
		for action_value in actions:
			if typeof(action_value) != TYPE_DICTIONARY:
				_failures += 1
				push_error("Actions in %s must be JSON objects." % shot_name)
				continue
			var action: Dictionary = action_value
			var frame: int = int(action.get("frame", 0))
			if frame < 0 or frame >= frame_count:
				_failures += 1
				push_error("Action frame is outside shot %s." % shot_name)
				continue
			if not actions_by_frame.has(frame):
				actions_by_frame[frame] = []
			actions_by_frame[frame].append(action)

		var auto_release_actions: Array[String] = []
		for frame in range(frame_count):
			for action_name in auto_release_actions:
				Input.action_release(action_name)
			auto_release_actions.clear()
			if actions_by_frame.has(frame):
				for action in actions_by_frame[frame]:
					_apply_action(action, auto_release_actions)
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			if image.save_png(shot_dir.path_join("%05d.png" % frame)) != OK:
				_failures += 1
				push_error("Could not save frame %d for shot %s." % [frame, shot_name])
		for action_name in auto_release_actions:
			Input.action_release(action_name)
		print("GODOT PROMO SHOT %s: %d frames" % [shot_name, frame_count])

	print("GODOT PROMO CAPTURE COMPLETE: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _apply_action(action: Dictionary, auto_release_actions: Array[String]) -> void:
	var kind: String = str(action.get("type", ""))
	var action_name: String = str(action.get("action", ""))
	if kind == "press" or kind == "tap":
		if not InputMap.has_action(action_name):
			_failures += 1
			push_error("Unknown InputMap action: %s" % action_name)
			return
		Input.action_press(action_name)
		if kind == "tap":
			auto_release_actions.append(action_name)
	elif kind == "release":
		if not InputMap.has_action(action_name):
			_failures += 1
			push_error("Unknown InputMap action: %s" % action_name)
			return
		Input.action_release(action_name)
	elif kind == "click":
		var position := Vector2(float(action.get("x", 0.0)), float(action.get("y", 0.0)))
		var button := int(action.get("button", MOUSE_BUTTON_LEFT))
		var press_event := InputEventMouseButton.new()
		press_event.button_index = button
		press_event.position = position
		press_event.pressed = true
		Input.parse_input_event(press_event)
		var release_event := InputEventMouseButton.new()
		release_event.button_index = button
		release_event.position = position
		release_event.pressed = false
		Input.parse_input_event(release_event)
	else:
		_failures += 1
		push_error("Unsupported promo action type: %s" % kind)


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame
