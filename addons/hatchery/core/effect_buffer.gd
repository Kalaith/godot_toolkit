extends RefCounted
## A deferred effects buffer for simulations. Actors read the same snapshot of
## the world, push what they want to change here, and the driver applies the
## whole batch once per tick. Because the batch is applied in a canonical order
## (the pusher's `order`, then push order), the order actors were visited in
## cannot bias the result.
##
##     var effects := EffectBuffer.new()
##     for agent in agents:                      # read-only pass
##         effects.push(agent.id, {"kind": "eat", "who": agent.id})
##     effects.apply(func(effect: Dictionary) -> void: world.resolve(effect))
##
## Effects pushed while a batch is being applied wait for the next `apply`, so
## an effect never sees a half-applied tick.

var _queue: Array[Dictionary] = []
var _next: int = 0


## Queues `effect` for the next `apply`. `order` is a stable integer such as the
## actor's id; equal orders keep their push order.
func push(order: int, effect: Dictionary) -> void:
	_queue.append({"order": order, "seq": _next, "effect": effect})
	_next += 1


func size() -> int:
	return _queue.size()


func is_empty() -> bool:
	return _queue.is_empty()


## Applies every queued effect in canonical order through `handler(effect)` and
## empties the buffer. Returns how many were applied.
func apply(handler: Callable) -> int:
	var batch: Array[Dictionary] = _queue
	_queue = []
	batch.sort_custom(_before)
	for entry in batch:
		handler.call(entry.effect)
	return batch.size()


## Drops everything queued without applying it.
func clear() -> void:
	_queue = []


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a.order != b.order:
		return a.order < b.order
	return a.seq < b.seq
