extends SceneTree
## Headless scenario runner, kept out of exported games. A game's
## tools/sim_checks.gd extends it and lists its modules:
##
##     extends "res://addons/hatchery/testing/check_runner.gd"
##     func modules() -> Array[String]:
##         return ["res://tools/checks/checks_data.gd", "res://tools/checks/checks_save.gd"]
##
## Run: godot --headless --path . --script res://tools/sim_checks.gd [-- --only=<text>] [--module=<text>] [--long]
##
## Every `check_*` method of every module returns "" on success or a failure
## message (Expect helps build those). Long scenarios (`long_check_*`) run
## only with --long. Prints PASS/FAIL per scenario and exits non-zero on any
## failure, or when nothing ran.
##
## Keep check methods untyped: a runtime error then returns null, which fails,
## where a typed `-> String` would silently return "" and pass.

var failures: int = 0
var count: int = 0


func _init() -> void:
	var only: String = ""
	var module_only: String = ""
	var long: bool = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
		elif argument.begins_with("--module="):
			module_only = argument.trim_prefix("--module=")
		elif argument == "--long":
			long = true
	var started: int = Time.get_ticks_msec()
	before_all()
	for path in modules():
		if not module_only.is_empty() and not path.contains(module_only):
			continue
		run_module(path, only, long)
	after_all()
	print("%d scenarios, %d failed, %.1fs" % [count, failures, (Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if failures > 0 or count == 0 else 0)


## The check modules to run, in order. Override in the game's runner.
func modules() -> Array[String]:
	return []


## Hooks for global setup (e.g. turning storage off) and reports.
func before_all() -> void:
	pass


func after_all() -> void:
	pass


func run_module(path: String, only: String = "", long: bool = false) -> void:
	var script: Variant = load(path)
	if not script is GDScript or not (script as GDScript).can_instantiate():
		record(path, "could not be loaded", 0.0)
		return
	var module: Object = script.new()
	for method in module.get_method_list():
		var name: String = method.name
		var runs: bool = name.begins_with("check_") or (long and name.begins_with("long_check_"))
		if not runs or (not only.is_empty() and not name.contains(only)):
			continue
		var begin: int = Time.get_ticks_msec()
		var result: Variant = module.call(name)
		record(name, result, (Time.get_ticks_msec() - begin) / 1000.0)
	if module is Node:
		module.free()


## Records one scenario: "" passes, anything else (null included) fails.
func record(name: String, result: Variant, seconds: float) -> void:
	count += 1
	if result is String and (result as String).is_empty():
		print("PASS  %s  (%.1fs)" % [name, seconds])
	else:
		failures += 1
		print("FAIL  %s  (%.1fs): %s" % [name, seconds, str(result)])
