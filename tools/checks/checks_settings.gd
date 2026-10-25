extends RefCounted
## The engine-settings applier and the settings-page host.
const EngineSettings = preload("res://addons/hatchery/settings/engine_settings.gd")
const SettingsHost = preload("res://addons/hatchery/ui/settings_host.gd")
const SettingsPanel = preload("res://addons/hatchery/ui/settings_panel.gd")
const SettingsStore = preload("res://addons/hatchery/settings/settings_store.gd")
const Expect = preload("res://addons/hatchery/testing/expect.gd")


func check_engine_settings_reach_buses_and_report_sizes():
	var store := SettingsStore.new({"master": 0.5, "tone": 0.25, "muted": false, "fullscreen": false, "ui_scale": 0.5, "shake": true}, Expect.scratch_path("engine_settings.json"))
	var engine := EngineSettings.new(store, null, {"Master": "master", "ToolkitTone": "tone"})
	engine.scale_min = 0.75
	engine.scale_max = 1.25
	var seen: Array[String] = []
	engine.extra = func(key: String) -> void: seen.append(key)
	engine.apply_all()
	var tone: int = AudioServer.get_bus_index("ToolkitTone")
	var level: float = AudioServer.get_bus_volume_db(tone)
	store.values.muted = true
	engine.apply("muted")
	var master_muted: bool = AudioServer.is_bus_mute(0)
	store.values.muted = false
	engine.apply("muted")
	return Expect.all([
		Expect.truthy(tone > 0, "a listed bus the project lacks is created"),
		Expect.near(level, linear_to_db(0.25), 0.01, "a volume setting sets its bus"),
		Expect.truthy(master_muted and not AudioServer.is_bus_mute(0), "the muted setting silences Master and lifts"),
		Expect.equal(seen.size(), store.defaults.size() + 2, "every key reaches the game's own handler"),
		Expect.near(engine.ui_scale(), 1.0, 0.0001, "the middle of the range is the middle size"),
		Expect.equal(engine.slider_text("ui_scale", 1.0), "125%", "the size readout shows the scale"),
		Expect.equal(engine.slider_text("master", 0.5), "50%", "other readouts show a percentage"),
	])


func check_settings_host_opens_once_and_closes():
	var host := Control.new()
	var settings_host := SettingsHost.new(host)
	var store := SettingsStore.new({"master": 0.5}, Expect.scratch_path("settings_host.json"))
	var make := func() -> Control:
		var page := SettingsPanel.new()
		page.store = store
		page.close_button = Button.new()
		return page
	var first: Control = settings_host.open(make)
	var again: Control = settings_host.open(make)
	var children_open: int = host.get_child_count()
	var opened: bool = first != null
	var refused: bool = again == null
	first.close_requested.emit()
	var closed: bool = not settings_host.is_open()
	first.free()
	host.free()
	return Expect.all([
		Expect.truthy(opened, "the first open returns the page"),
		Expect.truthy(refused, "a second open is refused while one is showing"),
		Expect.equal(children_open, 1, "the page is added to the host"),
		Expect.truthy(closed, "the page's close request closes it"),
	])
