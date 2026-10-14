extends RefCounted
## Reading and writing JSON without silent surprises. `read` returns null for a
## missing or unparsable file, so a caller can tell "absent" from "empty".
## JSON numbers arrive as floats; use DataRules.whole/integer_between before
## trusting one as an int.


## The parsed value of `path`, or null when the file is missing or not JSON.
static func read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return parse(FileAccess.get_file_as_string(path))


## The parsed value of `text`, or null when it is not JSON. Unlike
## JSON.parse_string this never logs a parse error to the console.
static func parse(text: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null


## `path` as a Dictionary, or {} with a message appended to `errors` when it
## is missing or not a JSON object. When `schema_version` is not -1 the
## object's `schema_version` must equal it.
static func read_object(path: String, errors: Array[String], schema_version: int = -1) -> Dictionary:
	var parsed: Variant = read(path)
	if not parsed is Dictionary:
		errors.append("Missing or not a JSON object: " + path)
		return {}
	if schema_version != -1:
		var found: Variant = parsed.get("schema_version")
		if not (found is int or found is float) or int(found) != schema_version:
			errors.append("%s: schema_version must be %d" % [path, schema_version])
			return {}
	return parsed


static func bytes(value: Variant, indent: String = "\t") -> PackedByteArray:
	return JSON.stringify(value, indent).to_utf8_buffer()


static func from_bytes(data: PackedByteArray) -> Variant:
	return parse(data.get_string_from_utf8())


## Every `*.json` file directly in `folder`, sorted by name so merges are stable.
static func files_in(folder: String) -> Array[String]:
	var result: Array[String] = []
	if not DirAccess.dir_exists_absolute(folder):
		return result
	var names: PackedStringArray = DirAccess.get_files_at(folder)
	names.sort()
	for name in names:
		if name.ends_with(".json"):
			result.append(folder.path_join(name))
	return result
