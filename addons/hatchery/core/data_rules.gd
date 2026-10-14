extends RefCounted
## Shape checks for hand-edited data and saves. The static predicates answer
## one question each; an instance collects readable errors with a context
## prefix, so a catalog validator reads as a list of rules:
##
##     var check := DataRules.new(errors, "blocks[stone]")
##     check.integer_between(entry, "id", 0, 255)
##     check.boolean(entry, "solid")
##     check.one_of(entry, "shape", shapes)
##
## Every field method returns whether the field passed, so a caller can skip
## checks that depend on it.

var errors: Array[String]
var context: String


func _init(into: Array[String], where: String = "") -> void:
	errors = into
	context = where


## The same error list under another context, e.g. one entry of a list.
func at(where: String) -> RefCounted:
	return get_script().new(errors, where)


func fail(message: String) -> bool:
	errors.append(context + ": " + message if not context.is_empty() else message)
	return false


func schema_version(data: Dictionary, expected: int, key: String = "schema_version") -> bool:
	if not whole(data.get(key)) or int(data[key]) != expected:
		return fail("%s must be %d" % [key, expected])
	return true


func number(data: Dictionary, key: String) -> bool:
	return true if finite(data.get(key)) else fail(key + " must be a number")


func number_between(data: Dictionary, key: String, minimum: float, maximum: float) -> bool:
	if not finite(data.get(key)) or float(data[key]) < minimum or float(data[key]) > maximum:
		return fail("%s must be a number from %s to %s" % [key, minimum, maximum])
	return true


func integer(data: Dictionary, key: String) -> bool:
	return true if whole(data.get(key)) else fail(key + " must be a whole number")


func integer_between(data: Dictionary, key: String, minimum: int, maximum: int) -> bool:
	if not integer_in(data.get(key), minimum, maximum):
		return fail("%s must be a whole number from %d to %d" % [key, minimum, maximum])
	return true


func boolean(data: Dictionary, key: String) -> bool:
	return true if data.get(key) is bool else fail(key + " must be true or false")


func text(data: Dictionary, key: String) -> bool:
	return true if nonempty(data.get(key)) else fail(key + " must be a nonempty string")


func one_of(data: Dictionary, key: String, allowed: Array) -> bool:
	return true if allowed.has(data.get(key)) else fail("unknown %s %s" % [key, str(data.get(key))])


func list(data: Dictionary, key: String, allow_empty: bool = true) -> bool:
	var value: Variant = data.get(key)
	if not value is Array or (not allow_empty and value.is_empty()):
		return fail(key + (" must be a list" if allow_empty else " must be a nonempty list"))
	return true


func object(data: Dictionary, key: String) -> bool:
	return true if data.get(key) is Dictionary else fail(key + " must be an object")


func vec2(data: Dictionary, key: String) -> bool:
	return true if is_vec2(data.get(key)) else fail(key + " must be [x, y]")


## Optional fields: checked with `rule` (a field method name) only when present.
func optional(data: Dictionary, key: String, rule: String, args: Array = []) -> bool:
	if not data.has(key):
		return true
	return callv(rule, [data, key] + args)


## Every entry of `entries` (an Array of Dictionaries) has a unique, nonempty
## `key`. Returns the ids seen, in order.
func unique_ids(entries: Variant, key: String = "id") -> Array:
	var seen: Array = []
	if not entries is Array:
		fail("expected a list of entries")
		return seen
	for entry in entries:
		if not entry is Dictionary:
			fail("an entry is not an object")
			continue
		var id: Variant = entry.get(key)
		if not nonempty(id) and not whole(id):
			fail("an entry has no " + key)
		elif seen.has(id):
			fail("duplicate %s %s" % [key, str(id)])
		else:
			seen.append(id)
	return seen


static func finite(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


## A finite number with no fractional part (JSON delivers ints as floats).
static func whole(value: Variant) -> bool:
	return finite(value) and float(value) == floorf(float(value))


static func integer_in(value: Variant, minimum: int, maximum: int) -> bool:
	return whole(value) and float(value) >= minimum and float(value) <= maximum


static func fraction(value: Variant) -> bool:
	return finite(value) and float(value) >= 0.0 and float(value) <= 1.0


static func nonempty(value: Variant) -> bool:
	return value is String and not (value as String).strip_edges().is_empty()


static func is_vec2(value: Variant) -> bool:
	return value is Array and value.size() == 2 and finite(value[0]) and finite(value[1])


## JSON stores positions as [x, y].
static func to_vec2(raw: Variant) -> Vector2:
	return Vector2(float(raw[0]), float(raw[1]))
