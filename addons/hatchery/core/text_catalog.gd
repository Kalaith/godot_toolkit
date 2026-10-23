extends RefCounted
## Player-facing text from JSON catalogs. Each file holds
## `{"schema_version": 1, "labels": {"key": "Text with {placeholders}"}}`;
## files split by responsibility share one key namespace, and a key defined in
## two files is reported by `problems()`. Another language overlays
## `<locale_root>/<code>/*.json` with the same shape, replacing only keys the
## base catalogs define, so a stray key cannot add text the game never asks for.
##
##     static var text := TextCatalog.new(["res://data/text.json", "res://data/text_ui.json"])
##     text.label("settings_title")
##     text.format("greeting", {"name": who})
const JsonIO = preload("res://addons/hatchery/core/json_io.gd")

const _ACCENTS: Dictionary = {"a": "á", "e": "é", "i": "ï", "o": "ö", "u": "ü", "A": "Å", "E": "É", "O": "Ø"}

var files: Array[String] = []
var locale_root: String = "res://data/locale"
var locale: String = "en"
## The pseudo-language for layout testing: accented, a third longer and
## bracketed, so text that bypasses the catalog stands out.
var pseudo: bool = false
var _labels: Dictionary = {}
var _owner: Dictionary = {}
var _problems: Array[String] = []


func _init(paths: Array[String] = []) -> void:
	files = paths


func labels() -> Dictionary:
	if _labels.is_empty():
		_load()
	return _labels


func has(key: String) -> bool:
	return labels().has(key)


## The text for `key`. An unknown key is an error (reported, and returned as
## the key itself so the gap is visible on screen).
func label(key: String) -> String:
	var all: Dictionary = labels()
	if not all.has(key):
		push_error("Text has no label " + key)
		return key
	return pseudo_of(str(all[key])) if pseudo else str(all[key])


func format(key: String, args: Dictionary) -> String:
	return fill(label(key), args)


func set_locale(code: String) -> void:
	locale = code
	reload()


func reload() -> void:
	_labels.clear()
	_owner.clear()
	_problems.clear()


## Missing or malformed files and keys defined twice.
func problems() -> Array[String]:
	labels()
	return _problems.duplicate()


## Every key `required` lists that the catalogs lack.
func missing(required: Array) -> Array[String]:
	var result: Array[String] = []
	for key in required:
		if not labels().has(str(key)):
			result.append(str(key))
	return result


func _load() -> void:
	for path in files:
		var parsed: Variant = JsonIO.read(path)
		if not parsed is Dictionary or not parsed.get("labels") is Dictionary:
			_problems.append("Text catalog is missing or has no labels object: " + path)
			continue
		for key in parsed.labels:
			if _owner.has(key):
				_problems.append("Label %s is defined in both %s and %s" % [key, _owner[key], path])
				continue
			if not parsed.labels[key] is String:
				_problems.append("Label %s in %s is not a string" % [key, path])
				continue
			_owner[key] = path
			_labels[key] = parsed.labels[key]
	if locale != "en":
		var overlay: Dictionary = {}
		for path in JsonIO.files_in(locale_root.path_join(locale)):
			var parsed: Variant = JsonIO.read(path)
			if parsed is Dictionary and parsed.get("labels") is Dictionary:
				overlay.merge(parsed.labels, true)
		for key in overlay:
			if _labels.has(key) and overlay[key] is String:
				_labels[key] = overlay[key]


## `{name}` placeholders replaced from `args`; unknown placeholders stay.
static func fill(template: String, args: Dictionary) -> String:
	var result: String = template
	for key in args:
		result = result.replace("{" + str(key) + "}", shown(args[key]))
	return result


## `value` as text for a player. JSON numbers arrive as floats, and Godot 4.4+
## writes a whole float as "40.0" where it used to write "40".
static func shown(value: Variant) -> String:
	if value is float and is_finite(value) and value == floorf(value) and absf(value) < 1.0e15:
		return str(int(value))
	return str(value)


## A label in the pseudo-language; `{placeholders}` are kept as they are.
static func pseudo_of(text: String) -> String:
	var out: String = ""
	var inside: bool = false
	for ch in text:
		if ch == "{":
			inside = true
		elif ch == "}":
			inside = false
		out += ch if inside or not _ACCENTS.has(ch) else str(_ACCENTS[ch])
	var pad: int = maxi(text.length() / 3, 1)
	return "[" + out + " " + "~".repeat(pad) + "]"
