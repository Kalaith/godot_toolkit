extends RefCounted
## Keyboard and gamepad reach: every screen takes focus on its first control
## when it opens, and Back closes the topmost open overlay.


## The first visible control under `root` (depth first) that accepts focus.
static func first_focusable(root: Node) -> Control:
	for child in root.get_children():
		if child is Control and not (child as Control).visible:
			continue
		if child is Control and (child as Control).focus_mode == Control.FOCUS_ALL and not (child is BaseButton and (child as BaseButton).disabled):
			return child
		var found: Control = first_focusable(child)
		if found != null:
			return found
	return null


static func focus_first(root: Node) -> bool:
	if not is_instance_valid(root) or (root is CanvasItem and not (root as CanvasItem).is_visible_in_tree()):
		return false
	var target: Control = first_focusable(root)
	if target == null:
		return false
	target.grab_focus()
	return true


## Focuses `screen`'s first control whenever it becomes visible.
static func focus_on_show(screen: Control) -> void:
	screen.visibility_changed.connect(func() -> void:
		if screen.visible:
			var target: Control = first_focusable(screen)
			if target != null:
				target.grab_focus.call_deferred())


## The first visible screen of `overlays` (listed topmost first), or null.
static func topmost(overlays: Array) -> Control:
	for screen in overlays:
		if is_instance_valid(screen) and screen is Control and (screen as Control).is_visible_in_tree():
			return screen
	return null
