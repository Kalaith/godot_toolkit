extends RefCounted
## Swaps whole screens (title, map, battle, results...) under one host and
## remembers where Back goes from each, so menus never wire their own back
## stacks. The previous screen is freed; screens are cheap to rebuild from
## game state.
##
##     var screens := ScreenSwitcher.new(self)
##     screens.show(map_screen, show_title)       # Back from the map -> title
##     func _unhandled_input(event): screens.handle_back(event)
const Focus = preload("res://addons/hatchery/ui/focus.gd")

var host: Node
var current: Node = null
var back_action: String = "ui_cancel"
## Gamepad B also goes back.
var pad_back: bool = true
## Focus the first button of each new screen, for keyboard and gamepad play.
var auto_focus: bool = true
var _back: Callable = Callable()


func _init(owner: Node) -> void:
	host = owner


## Replaces the current screen with `next`. `back` (optional) runs on Back.
func show(next: Node, back: Callable = Callable()) -> void:
	if is_instance_valid(current):
		current.queue_free()
	current = next
	_back = back
	host.add_child(next)
	if auto_focus and next is Control:
		Callable(Focus, "focus_first").call_deferred(next)


func can_go_back() -> bool:
	return _back.is_valid()


func go_back() -> bool:
	if not _back.is_valid():
		return false
	_back.call()
	return true


## Call from the host's _unhandled_input. Returns true when it went back.
func handle_back(event: InputEvent) -> bool:
	var pressed: bool = event.is_action_pressed(back_action) or \
		(pad_back and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	if not pressed or not _back.is_valid():
		return false
	host.get_viewport().set_input_as_handled()
	return go_back()
