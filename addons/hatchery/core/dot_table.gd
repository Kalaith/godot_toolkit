extends RefCounted
## A JSON object read by dot-separated paths ("agents.sight_radius").
## A missing path is a data error: it is reported and fails fast in debug
## builds, never silently defaulted. Resolved paths are cached, so per-frame
## reads do not split strings again.
const JsonIO = preload("res://addons/hatchery/core/json_io.gd")

var source: String = ""
var data: Dictionary = {}
var _cache: Dictionary = {}


static func from_file(path: String) -> RefCounted:
	var table: RefCounted = load("res://addons/hatchery/core/dot_table.gd").new()
	table.source = path
	var parsed: Variant = JsonIO.read(path)
	if not parsed is Dictionary:
		push_error("Data is missing or invalid: " + path)
		assert(false, "Data is missing or invalid: " + path)
	else:
		table.data = parsed
	return table


static func from_dictionary(values: Dictionary, label: String = "<memory>") -> RefCounted:
	var table: RefCounted = load("res://addons/hatchery/core/dot_table.gd").new()
	table.source = label
	table.data = values
	return table


func has(path: String) -> bool:
	return _resolve(path, false) != null or _cache.has(path)


func value(path: String) -> Variant:
	if _cache.has(path):
		return _cache[path]
	var found: Variant = _resolve(path, true)
	if found != null:
		_cache[path] = found
	return found


func number(path: String) -> float:
	return float(value(path))


func integer(path: String) -> int:
	return int(value(path))


func flag(path: String) -> bool:
	return bool(value(path))


func text(path: String) -> String:
	return str(value(path))


func dict(path: String) -> Dictionary:
	var result: Variant = value(path)
	return result if result is Dictionary else {}


func list(path: String) -> Array:
	var result: Variant = value(path)
	return result if result is Array else []


func vec2(path: String) -> Vector2:
	var raw: Variant = value(path)
	return Vector2(float(raw[0]), float(raw[1])) if raw is Array and raw.size() == 2 else Vector2.ZERO


func _resolve(path: String, report: bool) -> Variant:
	var node: Variant = data
	for key in path.split("."):
		if not node is Dictionary or not (node as Dictionary).has(key):
			if report:
				push_error("%s has no value at %s" % [source, path])
				assert(false, "%s has no value at %s" % [source, path])
			return null
		node = node[key]
	return node
