extends RefCounted
## The colours, fonts and sizes one game's UI is drawn with. UiKit builds
## every widget from a palette, so a game restyles by changing values here,
## never by editing builders. Accessibility swaps (colour-safe good/bad news,
## high-contrast panels) change the palette in place; rebuild or refresh
## screens after calling `set_accessibility`.
##
##     var palette := Palette.new()
##     palette.accent = Color("e2bf7c")
##     palette.display_font = preload("res://assets/fonts/Title.ttf")

var background := Color("12111a")
var panel := Color("1d1b28")
var panel_light := Color("2a2738")
var line := Color("3b3750")
var text := Color("ece6f5")
var muted := Color("a49cb8")
var accent := Color("e8c170")
var good := Color("7fd38b")
var warn := Color("eda57c")
var bad := Color("ef6f6c")
var shadow := Color(0.0, 0.0, 0.0, 0.45)
var button_fill := Color("2a2738")
var button_primary := Color("443e58")
var button_pressed := Color("514869")
var button_disabled := Color("1f1d29")
## Optional fonts; null uses the theme default.
var body_font: Font = null
var display_font: Font = null
var utility_font: Font = null
var body_size: int = 16
var heading_size: int = 28
var radius: int = 6
var panel_radius: int = 10
var margin: int = 12
## Touch-friendly minimum height for buttons and toggles.
var control_height: int = 48
var high_contrast: bool = false
var _standard: Dictionary = {}


## Colour-safe moves good and bad news from green and red to blue and orange;
## high contrast makes panels opaque with a bright border.
func set_accessibility(colour_safe: bool, contrast: bool) -> void:
	if _standard.is_empty():
		_standard = {"good": good, "bad": bad, "warn": warn, "panel": panel, "line": line}
	good = Color("7fb6ff") if colour_safe else _standard.good
	bad = Color("ff8c1a") if colour_safe else _standard.bad
	warn = Color("f0b35a") if colour_safe else _standard.warn
	high_contrast = contrast
	panel = Color(_standard.panel.darkened(0.4), 1.0) if contrast else _standard.panel
	line = Color("f2e2b0") if contrast else _standard.line


## Red when low, warn in the middle, accent, then good when high (0..1).
func level_color(fraction: float) -> Color:
	if fraction < 0.25:
		return bad
	if fraction < 0.5:
		return warn
	if fraction < 0.7:
		return accent
	return good
