extends "res://addons/hatchery/testing/check_runner.gd"
## The toolkit's own checks, run through its own runner:
##   godot --headless --path . --script res://tools/self_checks.gd [-- --only=<text>]


func modules() -> Array[String]:
	return [
		"res://tools/checks/checks_core.gd",
		"res://tools/checks/checks_storage.gd",
		"res://tools/checks/checks_input.gd",
		"res://tools/checks/checks_misc.gd",
	]
