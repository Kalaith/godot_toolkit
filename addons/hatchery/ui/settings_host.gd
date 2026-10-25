extends RefCounted
## Opens a settings page over a host node and, on close, returns focus to
## whatever had it, so keyboard and gamepad players keep their place.
##
##     var settings_host := SettingsHost.new(self)
##     func open_settings(): settings_host.open(settings.make_page)
##     func close_settings(): settings_host.close()
##
## The page is a SettingsPanel (or anything with `close_requested` and a
## `close_button`); it is freed on close.

var host: Node
var page: Control = null
var _focus_before: Control = null


func _init(owner: Node) -> void:
	host = owner


func is_open() -> bool:
	return is_instance_valid(page)


## Builds the page with `make_page` (Callable() -> Control) and adds it to the
## host. Returns the page, or null when one is already open.
func open(make_page: Callable) -> Control:
	if is_open():
		return null
	_focus_before = host.get_viewport().gui_get_focus_owner() if host.is_inside_tree() else null
	page = make_page.call()
	page.close_requested.connect(close)
	host.add_child(page)
	if host.is_inside_tree():
		page.close_button.grab_focus.call_deferred()
	return page


func close() -> void:
	if not is_open():
		return
	page.queue_free()
	page = null
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus.call_deferred()
