extends "res://addons/hatchery/testing/parse_runner.gd"
## Loads every script under addons/ so a parse error anywhere fails, even in
## modules no check uses. Run: godot --headless --path . --script res://tools/parse_all.gd


func folders() -> Array[String]:
	return ["res://addons/hatchery"]
