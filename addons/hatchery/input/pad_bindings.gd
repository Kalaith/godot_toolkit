extends RefCounted
## One rebindable gamepad button per listed action; sticks, triggers and every
## keyboard event stay intact. Every listed action needs a default button in
## project.godot.
##
## A mapping is {action: button_index}. Errors are codes, worded by the game or
## by `describe`: "bind_unknown", "bind_button_fixed",
## "bind_button_taken|<button name>|<other action>"

const NAMES: Array[String] = [
	"A / Cross", "B / Circle", "X / Square", "Y / Triangle", "Back / Select", "Guide",
	"Start", "Left stick press", "Right stick press", "Left bumper", "Right bumper",
	"D-pad up", "D-pad down", "D-pad left", "D-pad right", "Misc button",
	"Paddle 1", "Paddle 2", "Paddle 3", "Paddle 4", "Touchpad",
]

## action -> player-facing label, in display order.
var actions: Dictionary
## Buttons the game keeps for itself (e.g. Start for settings, B for back).
var reserved: Array[int] = []


func _init(action_labels: Dictionary, fixed_buttons: Array[int] = []) -> void:
	actions = action_labels
	reserved = fixed_buttons


func defaults() -> Dictionary:
	var result: Dictionary = {}
	for action in actions:
		var setting: String = "input/" + action
		if not ProjectSettings.has_setting(setting):
			push_error("No input action in project.godot for " + action)
			continue
		for event in ProjectSettings.get_setting(setting).events:
			if event is InputEventJoypadButton:
				result[action] = int(event.button_index)
				break
		if not result.has(action):
			push_error("No default gamepad button in project.godot for " + action)
	return result


func allowed(button: int) -> bool:
	return button >= 0 and button < NAMES.size() and not button in reserved


func valid(mapping: Variant) -> bool:
	if not mapping is Dictionary or mapping.size() != actions.size():
		return false
	var used: Array[int] = []
	for action in actions:
		var button: Variant = mapping.get(action)
		if not (button is int or button is float) or not is_finite(float(button)) or float(button) != floorf(float(button)):
			return false
		if not allowed(int(button)) or used.has(int(button)):
			return false
		used.append(int(button))
	return true


func change_error(mapping: Dictionary, action: String, button: int) -> String:
	if not actions.has(action):
		return "bind_unknown"
	if not allowed(button):
		return "bind_button_fixed"
	for other in actions:
		if other != action and int(mapping[other]) == button:
			return "bind_button_taken|%s|%s" % [button_name(button), other]
	return ""


func normalized(mapping: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for action in actions:
		result[action] = int(mapping[action])
	return result


func apply(mapping: Dictionary) -> void:
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		Input.action_release(action)
		var other_events: Array[InputEvent] = []
		for event in InputMap.action_get_events(action):
			if not event is InputEventJoypadButton:
				other_events.append(event)
		InputMap.action_erase_events(action)
		for event in other_events:
			InputMap.action_add_event(action, event)
		if mapping.has(action):
			var pad := InputEventJoypadButton.new()
			pad.button_index = int(mapping[action])
			InputMap.action_add_event(action, pad)


func describe(error: String) -> String:
	var parts: PackedStringArray = error.split("|")
	match parts[0]:
		"":
			return ""
		"bind_button_fixed":
			return "That button cannot be assigned."
		"bind_button_taken":
			return "%s is already assigned to %s. Choose another button." % [parts[1], actions.get(parts[2], parts[2])]
	return "Unknown binding."


static func button_name(button: int) -> String:
	return NAMES[button] if button >= 0 and button < NAMES.size() else "Button %d" % button
