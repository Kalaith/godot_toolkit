extends RefCounted
## Code-built UI from one Palette, so every screen of a game reads the same.
## Sizes are authored at the project's base resolution; the canvas_items
## stretch scales them.
##
##     static var ui := UiKit.new(MyPalette.new())
##     add_child(ui.label("Hello", 20))
##     column.add_child(ui.button("Start", _on_start, true))
const Palette = preload("res://addons/hatchery/ui/palette.gd")

var palette: Palette


func _init(colours: Palette = null) -> void:
	palette = colours if colours != null else Palette.new()


## A project-wide Theme for controls the kit does not build itself
## (TabContainer, OptionButton, tooltips, popups, progress bars).
func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = palette.body_size
	if palette.body_font != null:
		result.default_font = palette.body_font
	result.set_color("font_color", "Label", palette.text)
	for kind in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			result.set_stylebox(state, kind, button_box(state, false))
		result.set_color("font_color", kind, palette.text)
		result.set_color("font_hover_color", kind, Color.WHITE)
		result.set_color("font_pressed_color", kind, palette.accent)
		result.set_color("font_disabled_color", kind, Color(palette.muted, 0.6))
	result.set_stylebox("panel", "PanelContainer", panel_box())
	result.set_stylebox("panel", "PopupMenu", box(palette.panel, palette.line, palette.radius, 6))
	result.set_stylebox("hover", "PopupMenu", box(palette.panel_light, palette.panel_light, 4, 4))
	result.set_color("font_color", "PopupMenu", palette.text)
	result.set_color("font_hover_color", "PopupMenu", palette.accent)
	result.set_stylebox("panel", "TooltipPanel", box(palette.panel.darkened(0.4), palette.accent.darkened(0.4), palette.radius, 8))
	result.set_color("font_color", "TooltipLabel", palette.text)
	result.set_color("default_color", "RichTextLabel", palette.text)
	result.set_stylebox("background", "ProgressBar", box(palette.panel.darkened(0.4), palette.line, 4, 0))
	result.set_stylebox("fill", "ProgressBar", box(palette.accent.darkened(0.2), palette.accent.darkened(0.2), 4, 0))
	return result


func box(fill: Color, border: Color, corner: int, inner: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(corner)
	style.content_margin_left = inner
	style.content_margin_right = inner
	style.content_margin_top = inner * 0.6
	style.content_margin_bottom = inner * 0.6
	return style


func panel_box(alpha: float = 1.0, inner: int = -1) -> StyleBoxFlat:
	var opaque: bool = palette.high_contrast
	var style: StyleBoxFlat = box(Color(palette.panel, 1.0 if opaque else alpha), Color(palette.line, 1.0), palette.panel_radius, palette.margin if inner < 0 else inner)
	style.set_border_width_all(2 if opaque else 1)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style.shadow_size = 6
	style.shadow_offset = Vector2(2, 3)
	return style


func button_box(state: String, primary: bool) -> StyleBoxFlat:
	var fill: Color = palette.button_primary if primary else palette.button_fill
	match state:
		"hover":
			fill = fill.lightened(0.08)
		"pressed":
			fill = palette.button_pressed
		"disabled":
			fill = palette.button_disabled
	var border: Color = palette.accent if state in ["hover", "focus"] else Color(palette.line, 0.9)
	var style: StyleBoxFlat = box(fill, border, palette.radius, 14)
	style.set_border_width_all(2 if primary or state == "focus" else 1)
	return style


func label(value: String, size: int = -1, color: Variant = null) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", palette.body_size if size < 0 else size)
	node.add_theme_color_override("font_color", palette.text if color == null else color)
	node.add_theme_color_override("font_shadow_color", palette.shadow)
	node.add_theme_constant_override("shadow_offset_x", 1)
	node.add_theme_constant_override("shadow_offset_y", 1)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func heading(value: String, size: int = -1, color: Variant = null) -> Label:
	var node: Label = label(value, palette.heading_size if size < 0 else size, palette.accent if color == null else color)
	if palette.display_font != null:
		node.add_theme_font_override("font", palette.display_font)
	return node


## Numbers, counters and key names: the utility font, steady at small sizes.
func utility(value: String, size: int = -1, color: Variant = null) -> Label:
	var node: Label = label(value, size, color)
	if palette.utility_font != null:
		node.add_theme_font_override("font", palette.utility_font)
	return node


func wrapped(value: String, size: int = -1, color: Variant = null) -> Label:
	var node: Label = label(value, size, palette.muted if color == null else color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size.x = 40
	return node


## BBCode for a heading inside a RichTextLabel.
func rich_heading(value: String, size: int = -1, color: Variant = null) -> String:
	var tint: Color = palette.accent if color == null else color
	return "[font_size=%d][b][color=#%s]%s[/color][/b][/font_size]" % [palette.body_size + 6 if size < 0 else size, tint.to_html(false), value]


func button(value: String, callback: Callable = Callable(), primary: bool = false, size: int = -1) -> Button:
	var node := Button.new()
	node.text = value
	node.focus_mode = Control.FOCUS_ALL
	node.custom_minimum_size.y = palette.control_height
	node.add_theme_font_size_override("font_size", palette.body_size + 2 if size < 0 else size)
	node.add_theme_color_override("font_color", palette.text)
	node.add_theme_color_override("font_disabled_color", Color(palette.muted, 0.6))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		node.add_theme_stylebox_override(state, button_box(state, primary))
	if callback.is_valid():
		node.pressed.connect(callback)
	return node


func toggle(value: String, callback: Callable = Callable(), size: int = -1) -> CheckButton:
	var node := CheckButton.new()
	node.text = value
	node.focus_mode = Control.FOCUS_ALL
	node.custom_minimum_size.y = palette.control_height
	node.add_theme_font_size_override("font_size", palette.body_size + 1 if size < 0 else size)
	if callback.is_valid():
		node.toggled.connect(callback)
	return node


## A 0..100 slider; `callback` receives 0..1.
func slider(callback: Callable = Callable(), width: float = 200.0) -> HSlider:
	var node := HSlider.new()
	node.min_value = 0
	node.max_value = 100
	node.step = 1
	node.focus_mode = Control.FOCUS_ALL
	node.custom_minimum_size = Vector2(width, palette.control_height - 8)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if callback.is_valid():
		node.value_changed.connect(func(value: float) -> void: callback.call(value / 100.0))
	return node


func panel(alpha: float = 1.0, inner: int = -1) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", panel_box(alpha, inner))
	return node


func vbox(separation: int = 8) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


func hbox(separation: int = 8) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


func spacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func meter(value: float, maximum: float = 100.0, width: float = 160.0, color: Variant = null) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maximum
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, 14)
	bar.add_theme_stylebox_override("fill", box(palette.good if color == null else color, Color(0, 0, 0, 0), 4, 0))
	bar.add_theme_stylebox_override("background", box(Color(palette.background, 0.6), Color(0, 0, 0, 0), 4, 0))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


## A full-rect dimming layer for modal pages; it swallows clicks.
func shade(alpha: float = 0.72) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(palette.background, alpha)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return rect


## Fills `parent` with the background colour and a soft pool of light high in
## the middle, falling off to dark corners.
func backdrop(parent: Control, color: Variant = null) -> void:
	var base: Color = palette.background if color == null else color
	var rect := ColorRect.new()
	rect.color = base
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	var light := GradientTexture2D.new()
	light.fill = GradientTexture2D.FILL_RADIAL
	light.fill_from = Vector2(0.5, 0.3)
	light.fill_to = Vector2(1.15, 1.1)
	light.gradient = Gradient.new()
	light.gradient.set_color(0, base.lightened(0.07))
	light.gradient.set_color(1, base.darkened(0.45))
	var glow := TextureRect.new()
	glow.texture = light
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(glow)
