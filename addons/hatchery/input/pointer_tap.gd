extends Node
## Turns a short press-and-release on open ground into one `tapped` signal,
## for mouse and touch alike. Only a press that began unhandled by the GUI
## (so not over a button or panel) and ended within `slop` pixels counts; a
## second finger, a drag or losing window focus cancels it. GUI controls keep
## Godot's touch-to-mouse emulation; emulated mouse events are ignored here.
##
##     var tap := PointerTap.new()
##     tap.available = func(at: Vector2) -> bool: return not hud_rect.has_point(at)
##     tap.tapped.connect(func(_screen, world): player.walk_to(world))
##     add_child(tap)

## `screen` is in viewport coordinates; `world` is the same point under the
## canvas transform as it was when the press began, so camera smoothing during
## the press cannot move the goal.
signal tapped(screen: Vector2, world: Vector2)
signal canceled

## A press that moves farther than this (pixels) is a drag, not a tap.
@export var slop: float = 24.0
## Optional Callable(at: Vector2) -> bool; false refuses a press or release there.
var available: Callable = Callable()

const MOUSE_POINTER: int = -1
const NO_POINTER: int = -2
var _touches: Dictionary = {}
var _pointer: int = NO_POINTER
var _pressed_at := Vector2.ZERO
var _world_at := Vector2.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_touches.clear()
		cancel()


func is_pressing() -> bool:
	return _pointer != NO_POINTER


func cancel() -> void:
	if _pointer != NO_POINTER:
		_pointer = NO_POINTER
		canceled.emit()


func _input(event: InputEvent) -> void:
	# Releases are watched before GUI dispatch, including over a menu or HUD.
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
			if _touches.size() > 1:
				cancel()
		else:
			_touches.erase(event.index)
			if event.canceled:
				cancel()
			elif _pointer == event.index:
				_finish(event.position)
	elif event is InputEventScreenDrag and event.index == _pointer:
		if event.position.distance_to(_pressed_at) > slop:
			cancel()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _pointer == MOUSE_POINTER:
			_finish(event.position)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and _pointer == MOUSE_POINTER:
		if event.position.distance_to(_pressed_at) > slop:
			cancel()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and _touches.size() == 1:
		_begin(event.index, event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_begin(MOUSE_POINTER, event.position)


func _begin(pointer: int, at: Vector2) -> void:
	if available.is_valid() and not available.call(at):
		return
	_pointer = pointer
	_pressed_at = at
	_world_at = get_viewport().get_canvas_transform().affine_inverse() * at


func _finish(at: Vector2) -> void:
	var ok: bool = at.distance_to(_pressed_at) <= slop and (not available.is_valid() or available.call(at))
	_pointer = NO_POINTER
	if ok:
		tapped.emit(at, _world_at)
	else:
		canceled.emit()
