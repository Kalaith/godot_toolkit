extends RefCounted
## Pushes a SettingsStore's values into the engine: volumes onto audio buses,
## full screen, and the interface size. A game builds one, lists its buses, and
## calls `apply` when the settings page reports a change.
##
##     var engine := EngineSettings.new(store, get_tree(), {"Master": "master", "Music": "music"})
##     engine.scale_min = 0.75
##     engine.apply_all()
##     page.applied.connect(engine.apply)
##     page.slider_text = engine.slider_text
##
## Settings the game handles itself (colour-safe palettes, screen shake) go in
## `extra`, called with every key. Keep the engine out of the store's own
## fields: the two would hold each other alive.
const Display = preload("res://addons/hatchery/settings/display.gd")
const Levels = preload("res://addons/hatchery/audio/levels.gd")

var store: RefCounted
var tree: SceneTree
## Bus name -> settings key (0..1 volume), e.g. {"Master": "master"}.
var buses: Dictionary = {}
## A boolean setting that silences Master.
var muted_key: String = "muted"
var fullscreen_key: String = "fullscreen"
## The 0..1 setting that sets the interface size, mapped onto the range below.
var scale_key: String = "ui_scale"
var scale_min: float = 0.85
var scale_max: float = 1.5
## Optional Callable(key: String) for the game's own settings.
var extra: Callable = Callable()


func _init(settings_store: RefCounted, scene_tree: SceneTree, bus_keys: Dictionary = {}) -> void:
	store = settings_store
	tree = scene_tree
	buses = bus_keys
	ensure_buses()


## Creates every listed bus the project's layout lacks.
func ensure_buses() -> void:
	for bus_name in buses:
		if bus_name != "Master":
			Levels.ensure_bus(bus_name)


func apply_all() -> void:
	for key in store.defaults:
		apply(key)


## Pushes one changed value to the engine ("" applies everything).
func apply(key: String) -> void:
	if key.is_empty():
		apply_all()
		return
	var values: Dictionary = store.values
	if key == muted_key or buses.values().has(key):
		Levels.apply_buses(values, buses, muted_key)
	elif key == fullscreen_key:
		Display.set_fullscreen(bool(values.get(fullscreen_key, false)))
	elif key == scale_key:
		Display.set_ui_scale(tree, ui_scale())
	if extra.is_valid():
		extra.call(key)


func ui_scale() -> float:
	return Display.scale_from_fraction(float(store.values.get(scale_key, 0.0)), scale_min, scale_max)


## The readout beside a settings slider: the interface size as the scale it
## sets, anything else as a percentage.
func slider_text(key: String, value: float) -> String:
	if key == scale_key:
		return "%d%%" % roundi(Display.scale_from_fraction(value, scale_min, scale_max) * 100.0)
	return "%d%%" % roundi(value * 100.0)
