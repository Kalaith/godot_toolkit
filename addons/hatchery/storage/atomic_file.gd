extends RefCounted
## The file-level steps every save in the toolkit is built from:
##
##   stage    write `<path>.tmp` and read it back byte for byte
##   rotate   move the current file aside (to `.bak`, `.corrupt`, ...)
##   promote  move `<path>.tmp` into place
##
## A failure at any step leaves the previous file (or its backup) on disk.
## Every function returns "" on success, else what went wrong in plain words.

const TMP: String = ".tmp"
const BAK: String = ".bak"
const CORRUPT: String = ".corrupt"
const PREVIOUS: String = ".previous"


static func stage(path: String, data: PackedByteArray) -> String:
	var temporary: String = path + TMP
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "Could not write %s (storage error %d)." % [path.get_file(), FileAccess.get_open_error()]
	file.store_buffer(data)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or FileAccess.get_file_as_bytes(temporary) != data:
		return "%s did not read back correctly after writing." % path.get_file()
	return ""


## Moves `path` to `path + suffix`, replacing an older file there. Nothing to
## move is not an error.
static func rotate(path: String, suffix: String = BAK) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var target: String = path + suffix
	if FileAccess.file_exists(target) and DirAccess.remove_absolute(target) != OK:
		return "Could not replace %s." % target.get_file()
	if DirAccess.rename_absolute(path, target) != OK:
		return "Could not move %s aside." % path.get_file()
	return ""


static func promote(path: String) -> String:
	if DirAccess.rename_absolute(path + TMP, path) != OK:
		# An interrupted swap must not leave the canonical name empty.
		if not FileAccess.file_exists(path) and FileAccess.file_exists(path + BAK):
			DirAccess.copy_absolute(path + BAK, path)
		return "Could not move %s into place." % path.get_file()
	return ""


## Stage, keep the old file as `.bak`, promote.
static func write(path: String, data: PackedByteArray) -> String:
	var error: String = stage(path, data)
	if error.is_empty():
		error = rotate(path, BAK)
	if error.is_empty():
		error = promote(path)
	return error


## Copies `path` to `path + suffix` unless that file already exists, so an
## earlier preserved copy is never overwritten. Returns false when nothing
## could be preserved.
static func preserve(path: String, suffix: String = CORRUPT) -> bool:
	if not FileAccess.file_exists(path):
		return true
	if FileAccess.file_exists(path + suffix):
		return false
	return DirAccess.copy_absolute(path, path + suffix) == OK


static func read_bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


## The bytes of `path`, or of its `.bak` when `accept` (Callable(bytes) -> bool)
## refuses the main file: {"bytes": PackedByteArray, "from_backup": bool}, or
## {} when neither is acceptable.
static func read_with_backup(path: String, accept: Callable) -> Dictionary:
	for candidate in [path, path + BAK]:
		var data: PackedByteArray = read_bytes(candidate)
		if not data.is_empty() and accept.call(data):
			return {"bytes": data, "from_backup": candidate != path}
	return {}


## Removes a file and every sidecar the toolkit writes beside it.
static func remove_all(path: String) -> void:
	for suffix in ["", TMP, BAK, CORRUPT, PREVIOUS]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
