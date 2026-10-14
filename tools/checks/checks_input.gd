extends RefCounted
## Key and pad bindings and the settings store that saves them.
const KeyBindings = preload("res://addons/hatchery/input/key_bindings.gd")
const PadBindings = preload("res://addons/hatchery/input/pad_bindings.gd")
const SettingsStore = preload("res://addons/hatchery/settings/settings_store.gd")
const Expect = preload("res://addons/hatchery/testing/expect.gd")

const KEY_ACTIONS: Dictionary = {"jump": "Jump", "interact": "Use"}
const PAD_ACTIONS: Dictionary = {"jump": "Jump", "interact": "Use"}


func check_key_defaults_come_from_project():
	var keys := KeyBindings.new(KEY_ACTIONS)
	var defaults: Dictionary = keys.defaults()
	return Expect.all([
		Expect.equal(defaults.jump, [KEY_SPACE, 0], "one default key leaves the alternate empty"),
		Expect.equal(defaults.interact, [KEY_E, KEY_F], "two default keys"),
		Expect.truthy(keys.valid(defaults), "defaults are valid"),
	])


func check_key_rebinding_rules():
	var keys := KeyBindings.new(KEY_ACTIONS)
	var mapping: Dictionary = keys.defaults()
	return Expect.all([
		Expect.equal(keys.change_error(mapping, "jump", 0, 0), "bind_keep_primary", "primary cannot be cleared"),
		Expect.equal(keys.change_error(mapping, "jump", 1, KEY_ESCAPE), "bind_single_key", "Esc is reserved"),
		Expect.equal(keys.change_error(mapping, "jump", 1, KEY_E), "bind_key_taken|E|interact", "duplicates are refused"),
		Expect.equal(keys.describe("bind_key_taken|E|interact"), "E is already assigned to Use. Choose another key.", "English wording"),
		Expect.equal(keys.change_error(mapping, "jump", 1, KEY_J), "", "a free key is accepted"),
		Expect.falsy(keys.valid({"jump": [KEY_E, 0], "interact": [KEY_E, 0]}), "a saved duplicate is invalid"),
		Expect.falsy(keys.valid({"jump": [32.5, 0]}), "fractional codes are invalid"),
	])


func check_newer_action_takes_a_free_key():
	var keys := KeyBindings.new(KEY_ACTIONS)
	# Saved before "interact" existed, with its default key E taken by jump.
	var saved: Dictionary = {"jump": [float(KEY_E), 0.0]}
	var strict := KeyBindings.new(KEY_ACTIONS)
	strict.allow_missing = false
	var normalized: Dictionary = keys.normalized(saved)
	return Expect.all([
		Expect.truthy(keys.valid(saved), "a mapping missing a newer action is valid"),
		Expect.falsy(strict.valid(saved), "unless every action is demanded"),
		Expect.equal(normalized.jump, [KEY_E, 0], "codes become ints"),
		Expect.equal(normalized.interact, [KEY_U, 0], "the newer action takes the first spare"),
	])


func check_apply_keeps_pad_events():
	var keys := KeyBindings.new(KEY_ACTIONS)
	var mapping: Dictionary = keys.defaults()
	mapping.jump = [KEY_K, 0]
	keys.apply(mapping)
	var kinds: Array = InputMap.action_get_events("jump").map(func(e: InputEvent) -> String: return e.get_class())
	var hint: String = KeyBindings.hint("jump")
	keys.apply(keys.defaults())
	return Expect.all([
		Expect.equal(hint, "K", "the new key is live"),
		Expect.contains(kinds, "InputEventJoypadButton", "the pad button survives"),
	])


func check_pad_bindings():
	var pad := PadBindings.new(PAD_ACTIONS, [JOY_BUTTON_START] as Array[int])
	var mapping: Dictionary = pad.defaults()
	return Expect.all([
		Expect.equal(mapping, {"jump": 0, "interact": 2}, "defaults from project"),
		Expect.equal(pad.change_error(mapping, "jump", JOY_BUTTON_START), "bind_button_fixed", "reserved buttons"),
		Expect.equal(pad.change_error(mapping, "jump", 2), "bind_button_taken|X / Square|interact", "duplicates"),
		Expect.truthy(pad.valid({"jump": 1.0, "interact": 3.0}), "JSON floats are valid"),
	])


func check_settings_store_round_trip_and_tolerance():
	var path: String = Expect.scratch_path("settings.json")
	var settings := SettingsStore.new({"master": 1.0, "muted": false, "quality": "high", "fov": 70.0}, path)
	settings.choices = {"quality": ["low", "high"]}
	settings.ranges = {"fov": Vector2(50, 110)}
	settings.keys = KeyBindings.new(KEY_ACTIONS)
	settings.pad = PadBindings.new(PAD_ACTIONS)
	settings.load_settings()
	var refused: bool = not settings.set_value("master", 1.5) and not settings.set_value("quality", "ultra") and not settings.set_value("muted", 1)
	settings.set_value("master", 0.25)
	settings.set_value("fov", 90)
	var rebind: String = settings.rebind("jump", 1, KEY_J)
	var saved: bool = settings.save_settings()
	# A newer build adds a setting; the old file still loads.
	var newer := SettingsStore.new({"master": 1.0, "muted": false, "quality": "high", "fov": 70.0, "captions": true}, path)
	newer.ranges = settings.ranges
	newer.keys = KeyBindings.new(KEY_ACTIONS)
	newer.pad = PadBindings.new(PAD_ACTIONS)
	newer.load_settings()
	settings.keys.apply(settings.keys.defaults())
	return Expect.all([
		Expect.truthy(refused, "out-of-range and mistyped values are refused"),
		Expect.truthy(rebind.is_empty() and saved, "rebind and save: " + rebind + settings.last_error),
		Expect.equal(newer.values.master, 0.25, "saved values load"),
		Expect.equal(newer.values.fov, 90.0, "custom ranges load"),
		Expect.equal(newer.values.captions, true, "a new setting takes its default"),
		Expect.equal(newer.key_bindings.jump, [KEY_SPACE, KEY_J], "bindings load"),
		Expect.truthy(newer.last_error.is_empty(), "no error: " + newer.last_error),
	])
