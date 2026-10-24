extends RefCounted
## A registry of a game's hand-edited JSON catalogs: each file read once,
## cached, checked for its `schema_version`, and indexed by id for lookups.
## Problems are collected, never defaulted away, so a game can show them at
## startup and refuse to run on broken data.
##
##     static var data := DataFiles.new({
##         "zones": "res://data/zones.json",
##         "traits": "res://data/traits.json",
##     }, 1)
##     if not data.load_all(): show(data.errors)
##     var zone: Dictionary = data.find("zones", "zones", "home_clearing")
##
## Catalog shape (the fields of each entry) is the game's own business: write
## it with DataRules. This only guarantees the file is an object of the
## expected schema and that ids can be looked up.

const JsonIO = preload("res://addons/hatchery/core/json_io.gd")

## name -> res:// path.
var files: Dictionary
var schema_version: int
## Every problem found while reading, each once.
var errors: Array[String] = []
var _cache: Dictionary = {}
var _index: Dictionary = {}


func _init(paths: Dictionary, expected_schema: int = 1) -> void:
	files = paths
	schema_version = expected_schema


## Reads every registered file. True when all of them are usable.
func load_all() -> bool:
	for name in files:
		file(name)
	return errors.is_empty()


## The parsed object of the named file; {} (and an error) when it is not
## registered, missing, not an object, or of another schema_version.
func file(name: String) -> Dictionary:
	if not _cache.has(name):
		if not files.has(name):
			errors.append("Data file is not registered: " + name)
			_cache[name] = {}
		else:
			_cache[name] = JsonIO.read_object(String(files[name]), errors, schema_version)
	return _cache[name]


## The list under `list_key` in the named file, or [] when it is not a list.
func entries(name: String, list_key: String) -> Array:
	var list: Variant = file(name).get(list_key)
	return list if list is Array else []


## The entry of `list_key` whose "id" is `id`, or {}. The first one wins when
## ids repeat (validation reports repeats).
func find(name: String, list_key: String, id: Variant) -> Dictionary:
	return _ids(name, list_key).get(id, {})


func has_id(name: String, list_key: String, id: Variant) -> bool:
	return _ids(name, list_key).has(id)


## Ids in file order.
func ids(name: String, list_key: String) -> Array:
	return _ids(name, list_key).keys()


## Forgets everything read, so the next lookup reads the files again.
func reload() -> void:
	_cache.clear()
	_index.clear()
	errors.clear()


func _ids(name: String, list_key: String) -> Dictionary:
	var key: String = name + "/" + list_key
	if not _index.has(key):
		var table: Dictionary = {}
		for entry in entries(name, list_key):
			if entry is Dictionary and entry.has("id") and not table.has(entry.id):
				table[entry.id] = entry
		_index[key] = table
	return _index[key]
