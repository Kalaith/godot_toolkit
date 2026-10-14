extends Control
## A complete settings page over the game: sliders and toggles in sections,
## key and gamepad rebinding with capture, resets, and Back / Title / Exit.
## It edits a SettingsStore directly and saves on every change; it never
## pauses the game behind it.
##
##     var page := SettingsPanel.new()
##     page.store = settings
##     page.ui = ui_kit
##     page.sections = [
##         {"title": "settings_sound", "sliders": ["master", "music"], "toggles": ["muted"]},
##         {"title": "settings_display", "toggles": ["fullscreen", "reduce_motion"]},
##     ]
##     page.applied.connect(func(_key): push_settings_to_engine())
##     add_child(page)
##
## Every word goes through `text` (Callable(key, english) -> String) so a game
## can serve it from its catalog; without one the English fallback shows.
## Keys used: the section titles, "setting_<key>", "action_<action>", and the
## "settings_*" keys in ENGLISH.
signal close_requested
signal title_requested
signal exit_requested
## A value changed, was applied to the store and saved (or failed to save).
signal applied(key: String)

const UiKit = preload("res://addons/hatchery/ui/ui_kit.gd")
const KeyBindings = preload("res://addons/hatchery/input/key_bindings.gd")
const PadBindings = preload("res://addons/hatchery/input/pad_bindings.gd")
const TextCatalog = preload("res://addons/hatchery/core/text_catalog.gd")
const Display = preload("res://addons/hatchery/settings/display.gd")

const ENGLISH: Dictionary = {
	"settings_title": "Settings", "settings_tab_general": "General", "settings_tab_keys": "Controls",
	"settings_back": "Back", "settings_to_title": "Title screen", "settings_exit": "Exit game",
	"settings_keys_help": "Choose a binding, then press a key. Keys use physical keyboard positions.",
	"settings_pad": "Gamepad buttons", "settings_reset_keys": "Restore default keys",
	"settings_reset_pad": "Restore default buttons", "settings_press_key": "Press a key...",
	"settings_press_button": "Press a button...", "settings_clear": "Clear",
	"settings_capture_key": "Press a new key for {action}. Esc cancels.",
	"settings_capture_pad": "Press a gamepad button for {action}. Esc cancels.",
	"settings_single_key": "Choose a single key without Shift, Ctrl, Alt or Meta.",
	"settings_web_exit": "Close the browser tab to exit.",
}

var store: RefCounted
var ui: UiKit
## [{"title": key, "sliders": [setting keys], "toggles": [setting keys]}, ...]
var sections: Array = []
## Callable(key: String, english: String) -> String.
var text: Callable = Callable()
## Callable(key: String, value: float) -> String for the readout beside each
## slider (value is the stored 0..1); defaults to a percentage.
var slider_text: Callable = Callable()
## Slider keys whose change is committed only when a drag ends (keyboard and
## gamepad steps still commit at once), e.g. a UI scale that would otherwise
## resize the page under the pointer mid-drag.
var commit_on_release: Array = []
## Callable(error_code: String) -> String for binding errors; defaults to the
## bindings' own English.
var describe_error: Callable = Callable()
var show_title_button: bool = false
var show_exit_button: bool = false
## The action that closes the page (when not choosing a key).
var close_action: String = "ui_cancel"
var panel_size := Vector2(820, 860)

var tabs: TabContainer
var notice: Label
var close_button: Button
var sliders: Dictionary = {}
var readouts: Dictionary = {}
var toggles: Dictionary = {}
var key_buttons: Dictionary = {}
var pad_buttons: Dictionary = {}
var capture_action: String = ""
var capture_slot: int = 0
var capture_pad: bool = false
var _panel: PanelContainer
var _dragging: String = ""


func _ready() -> void:
	if ui == null:
		ui = UiKit.new()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ui.shade())
	_panel = ui.panel(0.97, 24)
	add_child(_panel)
	var body: VBoxContainer = ui.vbox(12)
	_panel.add_child(body)
	body.add_child(ui.heading(_t("settings_title")))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tab_changed.connect(func(_index: int) -> void: cancel_capture())
	body.add_child(tabs)
	_build_general()
	if store.keys != null or store.pad != null:
		_build_controls()
	# A page with no Controls tab needs no tab bar.
	tabs.tabs_visible = tabs.get_tab_count() > 1
	notice = ui.wrapped("", -1, ui.palette.accent)
	notice.custom_minimum_size.y = 28
	body.add_child(notice)
	var actions: HBoxContainer = ui.hbox(12)
	body.add_child(actions)
	close_button = ui.button(_t("settings_back"), func() -> void:
		cancel_capture()
		close_requested.emit(), true)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(close_button)
	if show_title_button:
		actions.add_child(ui.button(_t("settings_to_title"), func() -> void: title_requested.emit()))
	if show_exit_button:
		var exit: Button = ui.button(_t("settings_exit"), func() -> void: exit_requested.emit())
		exit.disabled = not Display.can_quit()
		exit.tooltip_text = _t("settings_web_exit") if exit.disabled else ""
		actions.add_child(exit)
	resized.connect(_layout)
	_panel.minimum_size_changed.connect(_layout, CONNECT_DEFERRED)
	visibility_changed.connect(func() -> void:
		if visible:
			close_button.grab_focus.call_deferred())
	_layout()
	refresh()


func _build_general() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = _t("settings_tab_general")
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var rows: VBoxContainer = ui.vbox(8)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for section in sections:
		rows.add_child(ui.heading(_t(str(section.get("title", ""))), ui.palette.body_size + 4))
		for key in section.get("sliders", []):
			var row: HBoxContainer = ui.hbox(14)
			var name_label: Label = ui.label(_t("setting_" + key, str(key).capitalize()))
			name_label.custom_minimum_size.x = 220
			row.add_child(name_label)
			var slider: HSlider = ui.slider(func(value: float) -> void: _slide(str(key), value))
			slider.drag_started.connect(func() -> void: _dragging = str(key))
			slider.drag_ended.connect(func(_changed: bool) -> void: _release(str(key)))
			row.add_child(slider)
			sliders[key] = slider
			var readout: Label = ui.utility("", -1, ui.palette.muted)
			readout.custom_minimum_size.x = 64
			readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(readout)
			readouts[key] = readout
			rows.add_child(row)
		for key in section.get("toggles", []):
			var toggle: CheckButton = ui.toggle(_t("setting_" + key, str(key).capitalize()), func(on: bool) -> void: _set_value(str(key), on))
			rows.add_child(toggle)
			toggles[key] = toggle


func _build_controls() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = _t("settings_tab_keys")
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var holder: VBoxContainer = ui.vbox(8)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	var resets: HBoxContainer = ui.hbox(10)
	if store.keys != null:
		holder.add_child(ui.wrapped(_t("settings_keys_help")))
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 10)
		holder.add_child(grid)
		for action in store.keys.actions:
			var name_label: Label = ui.label(_action(action))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(name_label)
			var pair: Array[Button] = []
			for slot in range(KeyBindings.SLOTS):
				var button: Button = ui.button("", _begin_capture.bind(action, slot, false), false, ui.palette.body_size)
				button.custom_minimum_size.x = 150
				button.clip_text = true
				grid.add_child(button)
				pair.append(button)
			key_buttons[action] = pair
			grid.add_child(ui.button(_t("settings_clear"), func() -> void:
				cancel_capture()
				_report(store.rebind(action, 1, 0)), false, ui.palette.body_size - 2))
		resets.add_child(ui.button(_t("settings_reset_keys"), func() -> void:
			store.reset_keys()
			_save("")))
	if store.pad != null:
		holder.add_child(ui.heading(_t("settings_pad"), ui.palette.body_size + 4))
		var pad_grid := GridContainer.new()
		pad_grid.columns = 2
		pad_grid.add_theme_constant_override("h_separation", 10)
		holder.add_child(pad_grid)
		for action in store.pad.actions:
			var name_label: Label = ui.label(_action(action))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pad_grid.add_child(name_label)
			var button: Button = ui.button("", _begin_capture.bind(action, 0, true), false, ui.palette.body_size)
			button.custom_minimum_size.x = 220
			pad_grid.add_child(button)
			pad_buttons[action] = button
		resets.add_child(ui.button(_t("settings_reset_pad"), func() -> void:
			store.reset_pad()
			_save("")))
	holder.add_child(resets)


func refresh() -> void:
	if store == null or tabs == null:
		return
	for key in sliders:
		sliders[key].set_value_no_signal(float(store.values[key]) * 100.0)
		readouts[key].text = _slider_text(str(key), float(store.values[key]))
	for key in toggles:
		toggles[key].set_pressed_no_signal(bool(store.values[key]))
	for action in key_buttons:
		for slot in range(KeyBindings.SLOTS):
			var waiting: bool = capture_action == action and capture_slot == slot and not capture_pad
			key_buttons[action][slot].text = _t("settings_press_key") if waiting else KeyBindings.key_name(int(store.key_bindings[action][slot]))
	for action in pad_buttons:
		var waiting: bool = capture_action == action and capture_pad
		pad_buttons[action].text = _t("settings_press_button") if waiting else PadBindings.button_name(int(store.pad_bindings[action]))


func cancel_capture() -> void:
	capture_action = ""
	if notice != null:
		notice.text = ""
	refresh()


## Sliders on `commit_on_release` only show the value while dragged.
func _slide(key: String, value: float) -> void:
	if _dragging == key and commit_on_release.has(key):
		readouts[key].text = _slider_text(key, value)
	else:
		_set_value(key, value)


func _release(key: String) -> void:
	_dragging = ""
	if commit_on_release.has(key):
		_set_value(key, sliders[key].value / 100.0)


func _slider_text(key: String, value: float) -> String:
	if slider_text.is_valid():
		return str(slider_text.call(key, value))
	return "%d%%" % roundi(value * 100.0)


func _set_value(key: String, value: Variant) -> void:
	if store.set_value(key, value):
		_save(key)


func _save(key: String) -> void:
	if not store.save_settings():
		notice.text = store.last_error
	refresh()
	applied.emit(key)


func _report(error: String) -> void:
	_save("")
	if not error.is_empty():
		notice.text = describe_error.call(error) if describe_error.is_valid() else _english_error(error)


func _english_error(error: String) -> String:
	var bindings: RefCounted = store.pad if error.begins_with("bind_button") else store.keys
	return bindings.describe(error) if bindings != null else error


func _begin_capture(action: String, slot: int, pad: bool) -> void:
	capture_action = action
	capture_slot = slot
	capture_pad = pad
	notice.text = TextCatalog.fill(_t("settings_capture_pad" if pad else "settings_capture_key"), {"action": _action(action)})
	refresh()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or capture_action.is_empty():
		return
	if capture_pad and event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled()
		var action: String = capture_action
		capture_action = ""
		_report(store.rebind_pad(action, event.button_index))
	elif event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE:
			cancel_capture()
		elif capture_pad:
			return
		elif event.alt_pressed or event.ctrl_pressed or event.meta_pressed or (event.shift_pressed and event.physical_keycode != KEY_SHIFT):
			notice.text = _t("settings_single_key")
		else:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			var action: String = capture_action
			capture_action = ""
			_report(store.rebind(action, capture_slot, code))


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not capture_action.is_empty() or event.is_echo():
		return
	var step: int = 0
	if event.is_action_pressed(close_action) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		close_requested.emit()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		step = -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1
	elif event is InputEventKey and event.pressed and event.physical_keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		step = -1 if event.physical_keycode == KEY_PAGEUP else 1
	else:
		return
	if step != 0:
		tabs.current_tab = posmod(tabs.current_tab + step, tabs.get_tab_count())
	get_viewport().set_input_as_handled()


func _layout() -> void:
	if _panel == null:
		return
	_panel.size = Vector2(minf(panel_size.x, size.x - 32), minf(panel_size.y, size.y - 32))
	_panel.position = (size - _panel.size) * 0.5


func _action(action: String) -> String:
	var english: String = action.capitalize()
	if store.keys != null and store.keys.actions.has(action):
		english = store.keys.actions[action]
	elif store.pad != null and store.pad.actions.has(action):
		english = store.pad.actions[action]
	return _t("action_" + action, english)


func _t(key: String, english: String = "") -> String:
	var fallback: String = ENGLISH.get(key, english if not english.is_empty() else key)
	return str(text.call(key, fallback)) if text.is_valid() else fallback
