extends RefCounted
## Saves made of several files in one folder per slot, e.g.
## user://worlds/<slot>/{meta.json, sim.bin, chunks.bin}. Every file is staged
## and verified before any replaces its predecessor, so a failure leaves the
## previous save whole; each previous file is kept as `.bak`, a file that cannot
## be read falls back to its backup, and an unreadable file with no good
## backup is preserved as `.corrupt`.
##
##     var worlds := SlotStore.new("user://worlds/", ["meta.json", "sim.bin"])
##     worlds.write("valley", {"meta.json": JsonIO.bytes(meta), "sim.bin": var_to_bytes(state)})
##     var files: Dictionary = worlds.read("valley", func(name, bytes): return bytes.size() > 0)
const AtomicFile = preload("res://addons/hatchery/storage/atomic_file.gd")

var root: String
## Every file a complete save holds; the first is the slot's marker.
var files: Array[String]
## Files a save may lack (added after older saves were written): `read` skips
## one with no file and no backup, but a damaged one still fails the read.
var optional: Array[String] = []
var last_error: String = ""


func _init(root_folder: String, file_names: Array[String]) -> void:
	root = root_folder if root_folder.ends_with("/") else root_folder + "/"
	files = file_names


func folder(slot: String) -> String:
	return root + slot.validate_filename() + "/"


func exists(slot: String) -> bool:
	var marker: String = folder(slot) + files[0]
	return FileAccess.file_exists(marker) or FileAccess.file_exists(marker + AtomicFile.BAK)


## Slot names with a save, sorted.
func slots() -> Array[String]:
	var result: Array[String] = []
	if not DirAccess.dir_exists_absolute(root):
		return result
	var names: PackedStringArray = DirAccess.get_directories_at(root)
	names.sort()
	for name in names:
		if exists(name):
			result.append(name)
	return result


## `payload` maps file name -> PackedByteArray. False (with `last_error`) when
## any file could not be written and verified.
func write(slot: String, payload: Dictionary) -> bool:
	last_error = ""
	var base: String = folder(slot)
	if DirAccess.make_dir_recursive_absolute(base) != OK and not DirAccess.dir_exists_absolute(base):
		last_error = "Could not create the save folder."
		return false
	for name in payload:
		var staged: String = AtomicFile.stage(base + name, payload[name])
		if not staged.is_empty():
			last_error = staged
			return false
	for name in payload:
		var error: String = AtomicFile.rotate(base + name, AtomicFile.BAK)
		if error.is_empty():
			error = AtomicFile.promote(base + name)
		if not error.is_empty():
			last_error = error
			return false
	return true


## File name -> PackedByteArray for every file in `files` (and each present
## `optional` file), each accepted by `valid` (Callable(name: String,
## bytes: PackedByteArray) -> bool) from the file or its backup. {} when any
## file is unusable.
func read(slot: String, valid: Callable) -> Dictionary:
	last_error = ""
	var base: String = folder(slot)
	var result: Dictionary = {}
	for name in files + optional:
		var path: String = base + name
		if name in optional and not FileAccess.file_exists(path) and not FileAccess.file_exists(path + AtomicFile.BAK):
			continue
		var found: Dictionary = AtomicFile.read_with_backup(path, func(bytes: PackedByteArray) -> bool: return valid.call(name, bytes))
		if found.is_empty():
			AtomicFile.preserve(path, AtomicFile.CORRUPT)
			last_error = "The save is damaged: %s could not be read." % name
			return {}
		if found.from_backup:
			last_error = "Recovered %s from its backup." % name
			AtomicFile.preserve(path, AtomicFile.CORRUPT)
		result[name] = found.bytes
	return result


func delete(slot: String) -> void:
	var base: String = folder(slot)
	for name in files + optional:
		AtomicFile.remove_all(base + name)
	DirAccess.remove_absolute(base)
