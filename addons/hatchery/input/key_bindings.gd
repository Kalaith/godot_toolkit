extends RefCounted
## Rebindable physical-keyboard slots (a primary and an alternate) for the
## actions a game lists; gamepad, mouse and touch events on those actions stay
## intact, and navigation keys stay reserved. Every listed action needs a
## default key in project.godot, or saved bindings can never validate.
##
##     var keys := KeyBindings.new({"move_left": "Move left", "jump": "Jump"})
##     keys.apply(keys.normalized(saved))
##
## A mapping is {action: [primary_code, alternate_code]}; 0 means unassigned
## (allowed only for the alternate). Errors are codes, so a game can word them
## from its own text catalog; `describe` gives plain English:
##   "bind_unknown", "bind_keep_primary", "bind_single_key",
##   "bind_key_taken|<key name>|<other action>"

const SLOTS: int = 2
const MAX_CODE: int = 0x1ffffff

## action -> player-facing label, in display order.
var actions: Dictionary
## Keys no action may take (navigation and modifiers).
var reserved: Array[int] = [KEY_ESCAPE, KEY_TAB, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
## When an action is newer than a saved mapping and its default key is taken,
## it gets the first free key from this list.
var spares: Array[int] = [KEY_U, KEY_O, KEY_Y, KEY_H, KEY_G, KEY_N, KEY_M, KEY_J, KEY_K, KEY_L]
## Saved mappings may omit actions added since they were written (they take
## their defaults). False demands every action.
var allow_missing: bool = true


func _init(action_labels: Dictionary) -> void:
	actions = action_labels


## The keys project.godot gives each action.
func defaults() -> Dictionary:
	var result: Dictionary = {}
	for action in actions:
		var codes: Array = []
		var setting: String = "input/" + action
		if ProjectSettings.has_setting(setting):
			for event in ProjectSettings.get_setting(setting).events:
				if event is InputEventKey and codes.size() < SLOTS:
					codes.append(int(event.physical_keycode))
		else:
			push_error("No input action in project.godot for " + action)
		while codes.size() < SLOTS:
			codes.append(0)
		result[action] = codes
	return result


func allowed(code: int) -> bool:
	if code <= 0 or code in reserved:
		return false
	return OS.find_keycode_from_string(OS.get_keycode_string(code)) == code


func valid(mapping: Variant) -> bool:
	if not mapping is Dictionary or mapping.size() > actions.size():
		return false
	if not allow_missing and mapping.size() != actions.size():
		return false
	for action in mapping:
		if not actions.has(action):
			return false
	var used: Array[int] = []
	for action in actions:
		if not mapping.has(action):
			continue
		var slots: Variant = mapping[action]
		if not slots is Array or slots.size() != SLOTS:
			return false
		for slot in range(SLOTS):
			var code: Variant = slots[slot]
			if not (code is int or code is float) or not is_finite(float(code)) or float(code) != floorf(float(code)):
				return false
			if code == 0 and slot > 0:
				continue
			if code > MAX_CODE or not allowed(int(code)) or used.has(int(code)):
				return false
			used.append(int(code))
	return true


## "" when `code` may go in `action`'s `slot`, else an error code.
func change_error(mapping: Dictionary, action: String, slot: int, code: int) -> String:
	if not actions.has(action) or slot < 0 or slot >= SLOTS:
		return "bind_unknown"
	if code == 0 and slot == 0:
		return "bind_keep_primary"
	if code != 0 and not allowed(code):
		return "bind_single_key"
	if code != 0:
		for other in actions:
			for other_slot in range(SLOTS):
				if other == action and other_slot == slot:
					continue
				if int(mapping[other][other_slot]) == code:
					return "bind_key_taken|%s|%s" % [key_name(code), other]
	return ""


## A validated mapping with integral codes (JSON numbers arrive as floats);
## actions missing from it take their default key, or a spare when the
## player already uses that key elsewhere.
func normalized(mapping: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var used: Array[int] = []
	for action in actions:
		if mapping.has(action):
			result[action] = [int(mapping[action][0]), int(mapping[action][1])]
			used.append_array(result[action])
	var fresh: Dictionary = defaults()
	for action in actions:
		if result.has(action):
			continue
		var code: int = int(fresh[action][0])
		for spare in [code] + spares:
			if not used.has(spare):
				code = spare
				break
		result[action] = [code, 0]
		used.append(code)
	return result


## Replaces each action's keyboard events with the mapping's keys.
func apply(mapping: Dictionary) -> void:
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		Input.action_release(action)
		var other_events: Array[InputEvent] = []
		for event in InputMap.action_get_events(action):
			if not event is InputEventKey:
				other_events.append(event)
		InputMap.action_erase_events(action)
		for code in mapping[action]:
			if int(code) != 0:
				var event := InputEventKey.new()
				event.physical_keycode = int(code)
				InputMap.action_add_event(action, event)
		for event in other_events:
			InputMap.action_add_event(action, event)


## Plain English for an error code from `change_error`.
func describe(error: String) -> String:
	var parts: PackedStringArray = error.split("|")
	match parts[0]:
		"":
			return ""
		"bind_keep_primary":
			return "Keep a primary key for every action."
		"bind_single_key":
			return "Choose a single key. Esc and Tab are reserved for navigation."
		"bind_key_taken":
			return "%s is already assigned to %s. Choose another key." % [parts[1], actions.get(parts[2], parts[2])]
	return "Unknown binding."


static func key_name(code: int) -> String:
	return OS.get_keycode_string(code) if code != 0 else "Unassigned"


## The first key bound to `action` now, for "Jump · Space" style hints.
static func hint(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return key_name(event.physical_keycode)
	return ""
