extends RefCounted
## One JSON document under user:// with a schema version, validation, staged
## writes, a backup and recovery: the progression and preferences files every
## game keeps.
##
##     var store := JsonSave.new("user://progression.json", 3, _valid)
##     store.migrate = _migrate          # optional: older schema -> current
##     var data: Dictionary = store.load_data()   # {} means start fresh
##     if not store.save_data(snapshot): show(store.last_error)
##
## Guarantees:
## - Nothing is written unless `validate` accepts it, before and after writing.
## - The previous good file is kept as `.bak`; a damaged file falls back to it.
## - A damaged file is preserved as `.corrupt`, never silently overwritten,
##   and an existing `.corrupt` is never replaced (saving stops instead).
## - A file from a newer version blocks writes for the session.
const JsonIO = preload("res://addons/hatchery/core/json_io.gd")
const AtomicFile = preload("res://addons/hatchery/storage/atomic_file.gd")
const DataRules = preload("res://addons/hatchery/core/data_rules.gd")

var path: String
var version: int
var schema_key: String = "schema"
## Callable(data: Dictionary) -> bool, for data already at `version`.
var validate: Callable
## Optional Callable(data: Dictionary) -> Dictionary, given data whose schema
## is older than `version`; it returns the data brought up to date.
var migrate: Callable = Callable()
## Used in messages: "Could not save <noun>."
var noun: String = "the save"
## Settings-style policy: a damaged file with no good backup blocks writes for
## the session instead of starting fresh and preserving it on the next save.
var block_on_damage: bool = false
## Checks and captures turn storage off; loads return {} and saves succeed.
var enabled: bool = true
var indent: String = "\t"
var last_error: String = ""
var recovered: bool = false
var writes_blocked: bool = false
var _archive_corrupt: bool = false


func _init(save_path: String, schema_version: int, validator: Callable) -> void:
	path = save_path
	version = schema_version
	validate = validator


func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + AtomicFile.BAK)


## The stored data brought up to date, or {} when there is nothing usable (a
## first run, or damage with no good backup; `last_error` says which).
func load_data() -> Dictionary:
	last_error = ""
	recovered = false
	writes_blocked = false
	_archive_corrupt = false
	if not enabled:
		return {}
	if not path.begins_with("user://"):
		writes_blocked = true
		last_error = "The save path must be under user://."
		return {}
	if not FileAccess.file_exists(path):
		if not FileAccess.file_exists(path + AtomicFile.BAK):
			return {}
		# A missing file beside a backup is an interrupted replacement.
		var backup: Variant = upgraded(JsonIO.read(path + AtomicFile.BAK))
		if accepts(backup):
			recovered = true
			last_error = "Recovered %s from its backup after an interrupted save." % noun
			return backup
		writes_blocked = true
		last_error = "The backup of %s is damaged; it is preserved and saving is off." % noun
		return {}
	var raw: Variant = JsonIO.read(path)
	if raw is Dictionary and DataRules.whole(raw.get(schema_key)) and int(raw[schema_key]) > version:
		writes_blocked = true
		last_error = "%s comes from a newer version; it is preserved and saving is off." % noun.capitalize()
		return {}
	var current: Variant = upgraded(raw)
	if accepts(current):
		return current
	var backup: Variant = upgraded(JsonIO.read(path + AtomicFile.BAK))
	if accepts(backup):
		_archive_corrupt = true
		recovered = true
		last_error = "%s was damaged. Recovered its backup; the damaged file will be kept as .corrupt." % noun.capitalize()
		return backup
	if block_on_damage:
		writes_blocked = true
		last_error = "%s could not be read. Changes last this session." % noun.capitalize()
		return {}
	_archive_corrupt = true
	last_error = "%s was damaged. Starting fresh; the damaged file will be kept as .corrupt." % noun.capitalize()
	return {}


func save_data(data: Dictionary) -> bool:
	last_error = ""
	if not accepts(data):
		return _fail("Refused to save invalid data to %s." % noun)
	if not enabled:
		return true
	if writes_blocked:
		return _fail("Saving %s is off to protect an incompatible or damaged file." % noun)
	if not path.begins_with("user://"):
		return _fail("The save path must be under user://.")
	var folder: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder) and DirAccess.make_dir_recursive_absolute(folder) != OK:
		return _fail("Could not create the folder for %s." % noun)
	var staged: String = AtomicFile.stage(path, JsonIO.bytes(data, indent))
	if not staged.is_empty():
		return _fail(staged)
	if not accepts(JsonIO.read(path + AtomicFile.TMP)):
		return _fail("%s did not read back after writing; the previous file is kept." % noun.capitalize())
	if FileAccess.file_exists(path):
		if _archive_corrupt or not accepts(upgraded(JsonIO.read(path))):
			# A damaged or foreign file goes to .corrupt, never over the backup.
			if FileAccess.file_exists(path + AtomicFile.CORRUPT):
				return _fail("A .corrupt copy already exists, so the damaged %s was kept. Move it aside before saving again." % noun)
			var moved: String = AtomicFile.rotate(path, AtomicFile.CORRUPT)
			if not moved.is_empty():
				return _fail(moved)
		else:
			var rotated: String = AtomicFile.rotate(path, AtomicFile.BAK)
			if not rotated.is_empty():
				return _fail(rotated)
	_archive_corrupt = false
	var promoted: String = AtomicFile.promote(path)
	return _fail(promoted) if not promoted.is_empty() else true


## Copies the current file to `.previous`, which ordinary saves never rotate,
## before a deliberate reset ("new game"). False when the copy failed.
func keep_previous() -> bool:
	if not enabled or not FileAccess.file_exists(path):
		return true
	if DirAccess.copy_absolute(path, path + AtomicFile.PREVIOUS) != OK:
		return _fail("Could not keep a copy of %s, so it was not replaced." % noun)
	return true


## Whether `data` is a Dictionary at the current schema that `validate` accepts.
func accepts(data: Variant) -> bool:
	if not data is Dictionary or not DataRules.whole(data.get(schema_key)):
		return false
	return int(data[schema_key]) == version and bool(validate.call(data))


## `data` passed through `migrate` when its schema is older; otherwise as is.
func upgraded(data: Variant) -> Variant:
	if not data is Dictionary or not migrate.is_valid() or not DataRules.whole(data.get(schema_key)):
		return data
	if int(data[schema_key]) >= version or int(data[schema_key]) < 1:
		return data
	var result: Variant = migrate.call((data as Dictionary).duplicate(true))
	return result


func _fail(message: String) -> bool:
	last_error = message
	return false
