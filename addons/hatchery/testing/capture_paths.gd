extends RefCounted
## The single home for verification screenshots: docs/verification/, flat, with
## stable `<label>.png` names. Re-capturing a screen overwrites its file, so there
## are no timestamps, run suffixes, subfolders or duplicates.

const DIRECTORY: String = "res://docs/verification"
## Exported builds cannot write to res://, so their captures stay in user data.
const PACKAGED_DIRECTORY: String = "user://verification"


## Absolute folder captures belong in (not created).
static func folder() -> String:
	return ProjectSettings.globalize_path(DIRECTORY if OS.has_feature("editor") else PACKAGED_DIRECTORY)


## The same folder, created when needed.
static func directory() -> String:
	var path: String = folder()
	DirAccess.make_dir_recursive_absolute(path)
	return path


## Absolute path for `<label>.png`.
static func file(label: String) -> String:
	assert(not label.contains("/") and not label.contains("\\"), "Capture labels are flat names, not paths.")
	return folder().path_join(label + ".png")
