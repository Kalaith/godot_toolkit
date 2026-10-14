extends RefCounted
## Screen shake as "trauma": hits add trauma (0..1), it drains over time, and
## the offset grows with trauma squared, so small knocks barely move the view
## while big ones jolt it. Purely presentation; a game's "screen shake" setting
## turns it off through `enabled` (or scales it through `strength`).
##
##     var shake := Shake.new()
##     shake.enabled = settings.values.screen_shake
##     shake.add(0.4)                      # on a heavy hit
##     # each frame:
##     arena.position = shake.step(delta)
##
## The wobble comes from the shake's own seeded rng, never the global one.

## Largest offset in pixels, at full trauma.
var strength: float = 14.0
## Largest tilt in radians at full trauma (0 for no rotation); read `angle`.
var max_angle: float = 0.0
## Trauma lost per second.
var decay: float = 1.8
## Wobbles per second.
var frequency: float = 26.0
var enabled: bool = true
var trauma: float = 0.0
## The offset and tilt from the last step.
var offset: Vector2 = Vector2.ZERO
var angle: float = 0.0
var rng := RandomNumberGenerator.new()
var _phase: float = 0.0
var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value


## Adds trauma (clamped to 1). Ignored while disabled.
func add(amount: float) -> void:
	if enabled and is_finite(amount) and amount > 0.0:
		trauma = minf(1.0, trauma + amount)


## Advances by `delta` seconds and returns the new offset.
func step(delta: float) -> Vector2:
	if not enabled or trauma <= 0.0:
		reset()
		return offset
	trauma = maxf(0.0, trauma - decay * delta)
	_phase += delta * frequency
	while _phase >= 1.0:
		_phase -= 1.0
		_from = _to
		_to = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
	# Ease between random targets so the wobble reads as a shake, not static.
	var wobble: Vector3 = _from.lerp(_to, smoothstep(0.0, 1.0, _phase))
	var power: float = trauma * trauma
	offset = Vector2(wobble.x, wobble.y) * strength * power
	angle = wobble.z * max_angle * power
	return offset


## Stops at once and centres the view.
func reset() -> void:
	trauma = 0.0
	offset = Vector2.ZERO
	angle = 0.0
	_from = Vector3.ZERO
	_to = Vector3.ZERO
	_phase = 0.0
