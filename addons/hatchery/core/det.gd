extends RefCounted
## Deterministic helpers for simulations that must replay identically from a
## seed. They never touch the global randi()/randf() or Array.shuffle(), which
## draw from the engine's shared generator; every draw comes from the
## RandomNumberGenerator the caller owns.
##
## `sort_custom` is not stable, so comparators must tie-break on a stable id;
## `sort_by` does that for you.


## A uniformly chosen element, or `fallback` when `items` is empty.
static func pick(rng: RandomNumberGenerator, items: Array, fallback: Variant = null) -> Variant:
	if items.is_empty():
		return fallback
	return items[rng.randi_range(0, items.size() - 1)]


## An index into `weights` (non-negative numbers) chosen in proportion to its
## weight, or -1 when every weight is zero.
static func weighted_index(rng: RandomNumberGenerator, weights: Array) -> int:
	var total: float = 0.0
	for weight in weights:
		total += maxf(float(weight), 0.0)
	if total <= 0.0:
		return -1
	var roll: float = rng.randf() * total
	for i in range(weights.size()):
		roll -= maxf(float(weights[i]), 0.0)
		if roll < 0.0:
			return i
	return weights.size() - 1


## A key of `table` ({key: weight}) chosen in proportion to its weight. Keys
## are visited in sorted order, so insertion order cannot change the result.
static func weighted_key(rng: RandomNumberGenerator, table: Dictionary, fallback: Variant = null) -> Variant:
	var keys: Array = table.keys()
	keys.sort()
	var weights: Array = keys.map(func(key: Variant) -> float: return float(table[key]))
	var index: int = weighted_index(rng, weights)
	return keys[index] if index >= 0 else fallback


## Fisher-Yates shuffle in place, from the caller's generator.
static func shuffle(rng: RandomNumberGenerator, items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var held: Variant = items[i]
		items[i] = items[j]
		items[j] = held


static func chance(rng: RandomNumberGenerator, probability: float) -> bool:
	return probability > 0.0 and rng.randf() < probability


## Sorts `items` in place by `score` (Callable(item) -> comparable), ties
## broken by `id` (Callable(item) -> comparable), so equal scores always land
## in the same order. `descending` puts the highest score first.
static func sort_by(items: Array, score: Callable, id: Callable, descending: bool = false) -> void:
	items.sort_custom(func(a: Variant, b: Variant) -> bool:
		var sa: Variant = score.call(a)
		var sb: Variant = score.call(b)
		if sa != sb:
			return sa > sb if descending else sa < sb
		return id.call(a) < id.call(b))


## A child generator for a named stream, so adding draws to one system does
## not shift every other system's sequence.
static func fork(seed_value: int, stream: String) -> RandomNumberGenerator:
	var child := RandomNumberGenerator.new()
	child.seed = hash([seed_value, stream])
	return child
