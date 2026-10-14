extends RefCounted
## Player preferences in user://settings.json: simple values plus optional key
## and gamepad bindings. Preferences never share a file or schema with earned
## progression.
##
##     var settings := SettingsStore.new({"master": 1.0, "muted": false, "fullscreen": false})
##     settings.keys = KeyBindings.new(MY_KEY_ACTIONS)
##     settings.pad = PadBindings.new(MY_PAD_ACTIONS)
##     settings.load_settings()
##     settings.apply_bindings()
##
## Values are booleans, numbers (0..1 unless `ranges` says otherwise) or
## strings from `choices`. A saved file missing a newer key takes its default,
## so adding a setting never invalidates existing preferences. An unreadable
## file with no good backup turns saving off for the session rather than
## replacing it (see JsonSave.block_on_damage).
const JsonSave = preload("res://addons/hatchery/storage/json_save.gd")
const DataRules = preload("res://addons/hatchery/core/data_rules.gd")

var defaults: Dictionary
## key -> Vector2(minimum, maximum) for numeric settings outside 0..1.
var ranges: Dictionary = {}
## key -> Array of allowed strings for string settings.
var choices: Dictionary = {}
## Optional KeyBindings and PadBindings; null leaves that section out.
var keys: RefCounted = null
var pad: RefCounted = null
var values: Dictionary
var key_bindings: Dictionary = {}
var pad_bindings: Dictionary = {}
var file: JsonSave

var last_error: String:
	get:
		return file.last_error
var writes_blocked: bool:
	get:
		return file.writes_blocked
var save_enabled: bool:
	get:
		return file.enabled
	set(value):
		file.enabled = value


func _init(default_values: Dictionary, path: String = "user://settings.json", schema: int = 1) -> void:
	defaults = default_values
	values = defaults.duplicate(true)
	file = JsonSave.new(path, schema, _valid)
	file.noun = "settings"
	file.block_on_damage = true
	file.indent = ""
	# Older schemas differ only in keys, which load already tolerates.
	file.migrate = func(data: Dictionary) -> Dictionary:
		data[file.schema_key] = file.version
		return data


func load_settings() -> void:
	_reset_bindings()
	var data: Dictionary = file.load_data()
	if data.is_empty():
		return
	values = defaults.duplicate(true)
	for key in data["values"]:
		if defaults.has(key):
			values[key] = data["values"][key]
	if keys != null and data.has("key_bindings"):
		key_bindings = keys.normalized(data.key_bindings)
	if pad != null and data.has("pad_bindings"):
		pad_bindings = pad.normalized(data.pad_bindings)


func save_settings() -> bool:
	var snapshot: Dictionary = {file.schema_key: file.version, "values": values}
	if keys != null:
		snapshot["key_bindings"] = key_bindings
	if pad != null:
		snapshot["pad_bindings"] = pad_bindings
	return file.save_data(snapshot)


## Sets one value when it is the right type and in range. Does not save.
func set_value(key: String, value: Variant) -> bool:
	if not accepts_value(key, value):
		return false
	values[key] = float(value) if defaults[key] is float else value
	return true


func accepts_value(key: String, value: Variant) -> bool:
	if not defaults.has(key):
		return false
	var standard: Variant = defaults[key]
	if standard is bool:
		return value is bool
	if standard is String:
		return value is String and (not choices.has(key) or choices[key].has(value))
	if not DataRules.finite(value):
		return false
	var span: Vector2 = ranges.get(key, Vector2(0.0, 1.0))
	return float(value) >= span.x and float(value) <= span.y


func apply_bindings() -> void:
	if keys != null:
		keys.apply(key_bindings)
	if pad != null:
		pad.apply(pad_bindings)


## "" or an error code from KeyBindings.change_error.
func rebind(action: String, slot: int, code: int) -> String:
	var error: String = keys.change_error(key_bindings, action, slot, code)
	if error.is_empty():
		key_bindings[action][slot] = code
		keys.apply(key_bindings)
	return error


func reset_keys() -> void:
	key_bindings = keys.defaults()
	keys.apply(key_bindings)


func rebind_pad(action: String, button: int) -> String:
	var error: String = pad.change_error(pad_bindings, action, button)
	if error.is_empty():
		pad_bindings[action] = button
		pad.apply(pad_bindings)
	return error


func reset_pad() -> void:
	pad_bindings = pad.defaults()
	pad.apply(pad_bindings)


func _reset_bindings() -> void:
	values = defaults.duplicate(true)
	key_bindings = keys.defaults() if keys != null else {}
	pad_bindings = pad.defaults() if pad != null else {}


## Validates only the keys present: a missing key is a migration (defaulted on
## load), not damage. Unknown keys are ignored.
func _valid(data: Dictionary) -> bool:
	if not data.get("values") is Dictionary:
		return false
	for key in data["values"]:
		if defaults.has(key) and not accepts_value(key, data["values"][key]):
			return false
	if data.has("key_bindings") and (keys == null or not keys.valid(data.key_bindings)):
		return false
	if data.has("pad_bindings") and (pad == null or not pad.valid(data.pad_bindings)):
		return false
	return true
