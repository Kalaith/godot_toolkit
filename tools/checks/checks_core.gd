extends RefCounted
## Data rules, dot tables, text catalogs and deterministic helpers.
const DataRules = preload("res://addons/hatchery/core/data_rules.gd")
const DotTable = preload("res://addons/hatchery/core/dot_table.gd")
const JsonIO = preload("res://addons/hatchery/core/json_io.gd")
const TextCatalog = preload("res://addons/hatchery/core/text_catalog.gd")
const Det = preload("res://addons/hatchery/core/det.gd")
const Expect = preload("res://addons/hatchery/testing/expect.gd")


func check_data_rules_collect_contextual_errors():
	var errors: Array[String] = []
	var rules := DataRules.new(errors, "blocks")
	var entry: Dictionary = {"id": 3.0, "solid": "yes", "shape": "cube", "speed": 2.5}
	rules.integer_between(entry, "id", 0, 255)
	rules.boolean(entry, "solid")
	rules.one_of(entry, "shape", ["cube", "slab"])
	rules.optional(entry, "speed", "number_between", [0.0, 1.0])
	rules.optional(entry, "absent", "text")
	rules.at("blocks[2]").unique_ids([{"id": "a"}, {"id": "a"}, {"name": "x"}])
	return Expect.all([
		Expect.equal(errors.size(), 4, "error count " + str(errors)),
		Expect.truthy(errors[0] == "blocks: solid must be true or false", "first error is the boolean"),
		Expect.truthy(errors[2].begins_with("blocks[2]: duplicate id"), "nested context prefixes errors"),
		Expect.truthy(DataRules.whole(4.0) and not DataRules.whole(4.5) and not DataRules.whole(INF), "whole numbers"),
		Expect.truthy(DataRules.is_vec2([1, 2.5]) and not DataRules.is_vec2([1]), "vec2 shape"),
	])


func check_dot_table_reads_paths():
	var table: RefCounted = DotTable.from_dictionary({"agents": {"sight": 12, "speeds": [1, 2]}, "pos": [3, 4]})
	return Expect.all([
		Expect.equal(table.number("agents.sight"), 12.0, "number"),
		Expect.equal(table.integer("agents.sight"), 12, "integer"),
		Expect.equal(table.list("agents.speeds").size(), 2, "list"),
		Expect.equal(table.vec2("pos"), Vector2(3, 4), "vec2"),
		Expect.truthy(table.has("agents.sight") and not table.has("agents.missing"), "has"),
	])


func check_json_io_tells_absent_from_broken():
	var path: String = Expect.scratch_path("json_io.json")
	var absent: Variant = JsonIO.read(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	var broken: Variant = JsonIO.read(path)
	var errors: Array[String] = []
	JsonIO.read_object(path, errors)
	return Expect.all([
		Expect.truthy(absent == null and broken == null, "missing and broken files read as null"),
		Expect.equal(errors.size(), 1, "read_object reports the broken file"),
		Expect.equal(JsonIO.from_bytes(JsonIO.bytes({"a": 1})), {"a": 1.0}, "bytes round trip"),
	])


func check_text_catalog_fills_overlays_and_reports():
	var base: String = Expect.scratch_path("text_base.json")
	var extra: String = Expect.scratch_path("text_extra.json")
	_write(base, {"schema_version": 1, "labels": {"hello": "Hello {name}", "bye": "Bye"}})
	_write(extra, {"schema_version": 1, "labels": {"bye": "Farewell", "ok": "OK"}})
	DirAccess.make_dir_recursive_absolute("user://checks/locale/fr")
	_write("user://checks/locale/fr/ui.json", {"labels": {"hello": "Bonjour {name}", "stray": "x"}})
	var text := TextCatalog.new([base, extra])
	text.locale_root = "user://checks/locale"
	var english: String = text.format("hello", {"name": "Ana"})
	var problems: Array[String] = text.problems()
	text.set_locale("fr")
	var french: String = text.format("hello", {"name": "Ana"})
	text.pseudo = true
	var pseudo: String = text.label("bye")
	return Expect.all([
		Expect.equal(english, "Hello Ana", "placeholders fill"),
		Expect.equal(problems.size(), 1, "a key defined twice is reported"),
		Expect.equal(french, "Bonjour Ana", "a locale overlays known keys"),
		Expect.falsy(text.has("stray"), "a locale cannot add keys"),
		Expect.truthy(pseudo.begins_with("[By") and pseudo.ends_with("~]"), "pseudo-language brackets text: " + pseudo),
		Expect.equal(TextCatalog.pseudo_of("{n} a"), "[{n} á ~]", "pseudo keeps placeholders"),
		Expect.equal(text.missing(["ok", "nope"]), ["nope"], "missing keys"),
	])


func check_det_is_seeded_and_stable():
	var draw := func(seed_value: int) -> Array:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var items: Array = range(10)
		Det.shuffle(rng, items)
		return [items, Det.pick(rng, items), Det.weighted_key(rng, {"b": 1.0, "a": 3.0}), Det.weighted_index(rng, [0, 0])]
	var people: Array = [{"id": "c", "score": 1}, {"id": "a", "score": 2}, {"id": "b", "score": 1}]
	Det.sort_by(people, func(p): return p.score, func(p): return p.id, true)
	var first: RandomNumberGenerator = Det.fork(5, "weather")
	var second: RandomNumberGenerator = Det.fork(5, "weather")
	var other: RandomNumberGenerator = Det.fork(5, "raids")
	return Expect.all([
		Expect.deterministic(draw, 42, "seeded draws"),
		Expect.equal(draw.call(42)[3], -1, "all-zero weights choose nothing"),
		Expect.equal(people.map(func(p): return p.id), ["a", "b", "c"], "ties break on id"),
		Expect.truthy(first.randi() == second.randi() and Det.fork(5, "weather").randi() != other.randi(), "forked streams"),
	])


func _write(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()
