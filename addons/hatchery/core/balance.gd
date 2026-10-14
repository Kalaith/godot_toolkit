extends RefCounted
## Gameplay balance read once from data/balance.json, through static calls so
## scripts and headless checks read the same numbers and a retune changes one
## file and no check literals:
##
##     const Balance = preload("res://addons/hatchery/core/balance.gd")
##     var speed: float = Balance.number("helper.walk_speed")
##
## A game with its balance elsewhere sets `Balance.path` before the first read.
## A missing path is a data error (see dot_table.gd).
const DotTable = preload("res://addons/hatchery/core/dot_table.gd")

static var path: String = "res://data/balance.json"
static var _table: RefCounted = null


static func table() -> RefCounted:
	if _table == null:
		_table = DotTable.from_file(path)
	return _table


## Drops the cached file, e.g. after a check edits it or `path` changes.
static func reload() -> void:
	_table = null


static func data() -> Dictionary:
	return table().data


static func has(key_path: String) -> bool:
	return table().has(key_path)


static func value(key_path: String) -> Variant:
	return table().value(key_path)


static func number(key_path: String) -> float:
	return table().number(key_path)


static func integer(key_path: String) -> int:
	return table().integer(key_path)


static func flag(key_path: String) -> bool:
	return table().flag(key_path)


static func dict(key_path: String) -> Dictionary:
	return table().dict(key_path)


static func list(key_path: String) -> Array:
	return table().list(key_path)


## JSON stores positions as [x, y].
static func vec(raw: Variant) -> Vector2:
	return Vector2(float(raw[0]), float(raw[1]))
