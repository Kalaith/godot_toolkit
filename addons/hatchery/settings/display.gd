extends RefCounted
## Window and platform questions every game asks, answered safely under
## --headless and in the browser.


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


static func is_web() -> bool:
	return OS.has_feature("web")


## A browser owns its tab's lifetime; SceneTree.quit cannot close it, so an
## "Exit" button should be disabled there.
static func can_quit() -> bool:
	return not is_web()


static func is_fullscreen() -> bool:
	if is_headless():
		return false
	var mode: int = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## Switches only when the mode actually changes, and leaves a maximized window
## alone when asked for windowed.
static func set_fullscreen(on: bool) -> void:
	if is_headless() or on == is_fullscreen():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


## Returns the new state.
static func toggle_fullscreen() -> bool:
	set_fullscreen(not is_fullscreen())
	return is_fullscreen()


## Scales every canvas item (UI) by `factor`, e.g. an accessibility UI size.
static func set_ui_scale(tree: SceneTree, factor: float) -> void:
	if tree != null and tree.root != null and is_finite(factor) and factor > 0.0:
		tree.root.content_scale_factor = factor


## Maps a 0..1 setting onto [minimum, maximum], e.g. 85 % .. 150 % UI size.
static func scale_from_fraction(fraction: float, minimum: float = 0.85, maximum: float = 1.5) -> float:
	return lerpf(minimum, maximum, clampf(fraction, 0.0, 1.0))
