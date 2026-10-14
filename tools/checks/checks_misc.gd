extends RefCounted
## Audio synthesis and levels, shapes, the UI kit and the settings panel
## (built headless, not looked at: verify visuals in a consuming game).
const Synth = preload("res://addons/hatchery/audio/synth.gd")
const Levels = preload("res://addons/hatchery/audio/levels.gd")
const Shapes = preload("res://addons/hatchery/draw/shapes.gd")
const UiKit = preload("res://addons/hatchery/ui/ui_kit.gd")
const Palette = preload("res://addons/hatchery/ui/palette.gd")
const SettingsPanel = preload("res://addons/hatchery/ui/settings_panel.gd")
const SettingsStore = preload("res://addons/hatchery/settings/settings_store.gd")
const KeyBindings = preload("res://addons/hatchery/input/key_bindings.gd")
const Focus = preload("res://addons/hatchery/ui/focus.gd")
const Expect = preload("res://addons/hatchery/testing/expect.gd")


func check_synth_is_seeded_and_loops():
	var make := func(seed_value: int) -> PackedByteArray:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		return Synth.tone(rng, [[440.0, 1.0]], 0.2, 0.3, 4.0).data
	var rng := RandomNumberGenerator.new()
	var wind: AudioStreamWAV = Synth.wind_loop(rng, 1.0)
	var drone: AudioStreamWAV = Synth.drone_loop(110.0, [1.0, 1.5], 1.0)
	return Expect.all([
		Expect.truthy(make.call(3) == make.call(3) and make.call(3) != make.call(4), "the same seed gives the same sound"),
		Expect.equal(make.call(3).size(), int(0.2 * Synth.RATE) * 2, "16-bit mono length"),
		Expect.truthy(wind.loop_mode == AudioStreamWAV.LOOP_FORWARD and wind.loop_end == Synth.RATE, "loops cover the whole buffer"),
		Expect.equal(drone.data.size(), Synth.RATE * 2, "drone length"),
		Expect.near(Synth.pitch(220.0, 12.0), 440.0, 0.001, "an octave doubles"),
	])


func check_levels():
	return Expect.all([
		Expect.equal(Levels.db(-10.0, 0.0), Levels.SILENT_DB, "zero gain is silent"),
		Expect.equal(Levels.db(-10.0, 1.0), -10.0, "unity gain keeps the mix level"),
		Expect.near(Levels.gain([0.5, 0.5, 2.0]), 0.25, 0.0001, "gains multiply and clamp"),
		Expect.truthy(Levels.ensure_bus("Effects") == AudioServer.get_bus_index("Effects"), "a missing bus is created"),
	])


func check_shapes():
	var star: PackedVector2Array = Shapes.polygon_points(Vector2.ZERO, 10.0, 5, 0.5)
	var rounded: PackedVector2Array = Shapes.rounded_rect_points(Rect2(0, 0, 40, 20), 6.0, 4)
	return Expect.all([
		Expect.equal(star.size(), 10, "a five-point star has ten points"),
		Expect.truthy(star[0].distance_to(Vector2(0, -10)) < 0.001, "it starts straight up"),
		Expect.equal(rounded.size(), 20, "four corners of five points"),
	])


func check_ui_kit_and_settings_panel_build():
	var palette := Palette.new()
	var ui := UiKit.new(palette)
	var good_before: Color = palette.good
	palette.set_accessibility(true, true)
	var swapped: bool = palette.good != good_before and palette.high_contrast
	palette.set_accessibility(false, false)
	var store := SettingsStore.new({"master": 0.5, "muted": true, "size": 0.5})
	store.save_enabled = false
	store.keys = KeyBindings.new({"jump": "Jump"})
	store.load_settings()
	var page := SettingsPanel.new()
	page.store = store
	page.ui = ui
	page.sections = [{"title": "Sound", "sliders": ["master", "size"], "toggles": ["muted"]}]
	page.commit_on_release = ["size"]
	page.slider_text = func(key: String, value: float) -> String: return "x%.1f" % (value * 2.0) if key == "size" else "%d%%" % roundi(value * 100.0)
	page.text = func(key: String, english: String) -> String: return english.to_upper() if key == "settings_back" else english
	var host := Control.new()
	host.size = Vector2(1280, 720)
	host.add_child(page)
	page._ready()
	page.refresh()
	# Range only emits value_changed inside the tree; emit as a drag would.
	page.sliders.master.value_changed.emit(80.0)
	var master_readout: String = page.readouts.master.text
	page.sliders.size.drag_started.emit()
	page.sliders.size.value = 90.0
	page.sliders.size.value_changed.emit(90.0)
	var size_mid_drag: float = store.values.size
	var size_readout: String = page.readouts.size.text
	page.sliders.size.drag_ended.emit(true)
	var result: String = Expect.all([
		Expect.truthy(swapped, "accessibility swaps the palette"),
		Expect.equal(palette.good, good_before, "and swaps back"),
		Expect.truthy(ui.theme() is Theme and ui.button("x").custom_minimum_size.y >= 48, "touch-sized buttons"),
		Expect.equal(page.close_button.text, "BACK", "words go through the text callable"),
		Expect.truthy(page.toggles.muted.button_pressed, "toggles show stored values"),
		Expect.equal(store.values.master, 0.8, "a slider edits the store"),
		Expect.equal(master_readout, "80%", "a slider reads out its value"),
		Expect.truthy(size_mid_drag == 0.5 and size_readout == "x1.8", "a release-committed slider only reads out while dragged"),
		Expect.equal(store.values.size, 0.9, "and commits when the drag ends"),
		Expect.equal(page.key_buttons.jump[0].text, "Space", "key buttons name their keys"),
		Expect.truthy(Focus.first_focusable(page) != null, "the page has something to focus"),
	])
	host.free()
	return result
