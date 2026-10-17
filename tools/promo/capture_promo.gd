extends SceneTree
## Shared capture driver for any Godot 4 project. It loads the configured main
## scene off-screen and samples real-time gameplay with bounded background encoding.

const DEFAULT_FPS: int = 30

var _plan_path: String = ""
var _output_dir: String = ""
var _failures: int = 0
var _jobs: Array[Dictionary] = []


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3 or args[2] != "--promo-background":
		push_error("Launch with Promoter record_game.py: <plan.json> <capture-output-dir> --promo-background")
		quit(2)
		return
	if not bool(ProjectSettings.get_setting("promotion/background_capture_safe", false)):
		push_error("This game has not declared background-safe pointer handling. Capture refused.")
		quit(2)
		return
	_plan_path = args[0]
	_output_dir = args[1]
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-10000, -10000))
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
	current_scene = main_scene
	await process_frame
	await process_frame
	var setup_releases: Array[String] = []
	for action in plan.get("setupActions", []):
		_apply_action(action, setup_releases)
	await process_frame
	for action_name in setup_releases:
		Input.action_release(action_name)
	await create_timer(maxf(float(settle_frames) / fps, 0.001)).timeout

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
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

		await _record_shot(shot_dir, seconds, fps, actions_by_frame)


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


## Disable VSync only in this isolated run: waiting for presentation during GPU
## readback was stalling the game. Encoding/disk writes use at most two workers;
## if overloaded, skip a capture slot instead of blocking or growing a queue.
func _record_shot(directory: String, seconds: float, fps: int, actions: Dictionary) -> void:
	var releases: Array[String] = []
	var frame_count: int = roundi(seconds * fps)
	var previous_slot: int = -1
	var samples: Array[int] = []
	var readback_usec: int = 0
	var start_frames: int = Engine.get_process_frames()
	var start: int = Time.get_ticks_usec()
	var last_frame: int = start
	var longest_frame: int = 0
	while true:
		await process_frame
		var now: int = Time.get_ticks_usec()
		longest_frame = maxi(longest_frame, now - last_frame)
		last_frame = now
		for action_name in releases:
			Input.action_release(action_name)
		releases.clear()
		var elapsed: float = (Time.get_ticks_usec() - start) / 1000000.0
		if elapsed >= seconds:
			break
		var slot: int = mini(int(elapsed * fps), frame_count - 1)
		if slot <= previous_slot:
			continue
		for due in range(previous_slot + 1, slot + 1):
			for action in actions.get(due, []):
				_apply_action(action, releases)
		previous_slot = slot
		await RenderingServer.frame_post_draw
		_collect_jobs(false)
		if _jobs.size() >= 2:
			continue
		var before: int = Time.get_ticks_usec()
		var image: Image = root.get_texture().get_image()
		readback_usec += Time.get_ticks_usec() - before
		var result: Dictionary = {"error": OK}
		var task: int = WorkerThreadPool.add_task(_save_frame.bind(image, directory.path_join("%05d.jpg" % slot), result))
		_jobs.append({"task": task, "result": result})
		samples.append(slot)
	var elapsed_seconds: float = (Time.get_ticks_usec() - start) / 1000000.0
	var game_fps: float = (Engine.get_process_frames() - start_frames) / elapsed_seconds
	_collect_jobs(true)
	if samples.is_empty():
		_failures += 1
		push_error("No frames captured for %s" % directory)
	_write_report(directory.path_join("capture.json"), {
		"schemaVersion": 1, "samples": samples,
		"readbackMeanMs": readback_usec / 1000.0 / maxi(samples.size(), 1), "seconds": seconds,
		"elapsedSeconds": elapsed_seconds, "fps": fps, "frameCount": frame_count,
		"gameFps": game_fps, "maxFrameMs": longest_frame / 1000.0,
	})
	print("GODOT PROMO SHOT %s: %.3fs, %.1f game fps" % [directory.get_file(), elapsed_seconds, game_fps])


func _write_report(path: String, report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures += 1
		push_error("Cannot write capture report: %s" % path)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")


func _save_frame(image: Image, path: String, result: Dictionary) -> void:
	result.error = image.save_jpg(path, 0.95)


func _collect_jobs(wait_all: bool) -> void:
	for index in range(_jobs.size() - 1, -1, -1):
		var job: Dictionary = _jobs[index]
		if not wait_all and not WorkerThreadPool.is_task_completed(job.task):
			continue
		WorkerThreadPool.wait_for_task_completion(job.task)
		if int(job.result.error) != OK:
			_failures += 1
			push_error("Could not write a promo frame (error %s)." % job.result.error)
		_jobs.remove_at(index)
