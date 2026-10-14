extends RefCounted
## Small builders for check results: each returns "" when the expectation
## holds, else a readable failure. Chain several with `all`, which reports the
## first failure:
##
##     func check_new_game_is_valid():
##         var game := Progression.new()
##         return Expect.all([
##             Expect.truthy(game.valid(game.to_dict()), "a new game saves as valid"),
##             Expect.equal(game.coins, 0, "a new game has no coins"),
##         ])


static func all(results: Array) -> String:
	for result in results:
		if not result is String:
			return "a check returned %s instead of a message" % str(result)
		if not (result as String).is_empty():
			return result
	return ""


static func truthy(condition: bool, what: String) -> String:
	return "" if condition else "expected: " + what


static func falsy(condition: bool, what: String) -> String:
	return "" if not condition else "expected not: " + what


static func equal(actual: Variant, expected: Variant, what: String) -> String:
	if typeof(actual) == typeof(expected) and actual == expected:
		return ""
	if (actual is int or actual is float) and (expected is int or expected is float) and float(actual) == float(expected):
		return ""
	return "%s: expected %s, got %s" % [what, str(expected), str(actual)]


static func near(actual: float, expected: float, tolerance: float, what: String) -> String:
	return "" if absf(actual - expected) <= tolerance else "%s: expected %s +/- %s, got %s" % [what, expected, tolerance, actual]


static func between(actual: float, minimum: float, maximum: float, what: String) -> String:
	return "" if actual >= minimum and actual <= maximum else "%s: expected %s..%s, got %s" % [what, minimum, maximum, actual]


static func contains(collection: Variant, item: Variant, what: String) -> String:
	if (collection is Array or collection is Dictionary or collection is String) and collection.has(item):
		return ""
	return "%s: %s does not contain %s" % [what, str(collection), str(item)]


static func empty(collection: Variant, what: String) -> String:
	if (collection is Array or collection is Dictionary or collection is String) and collection.is_empty():
		return ""
	return "%s: expected nothing, got %s" % [what, str(collection)]


## Same seed, same result: `run` (Callable(seed) -> Variant) is called twice
## and the results compared as JSON.
static func deterministic(run: Callable, seed_value: int, what: String) -> String:
	var first: String = JSON.stringify(run.call(seed_value))
	var second: String = JSON.stringify(run.call(seed_value))
	return "" if first == second else what + ": the same seed gave different results"


## A throwaway user:// path for one check, cleared of earlier runs' files.
static func scratch_path(name: String) -> String:
	var path: String = "user://checks/" + name.validate_filename()
	DirAccess.make_dir_recursive_absolute("user://checks")
	for suffix in ["", ".tmp", ".bak", ".corrupt", ".previous"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	return path
