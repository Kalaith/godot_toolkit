extends RefCounted
## Ambience beds and screen shake (headless: nothing is heard or seen here).
const Ambience = preload("res://addons/hatchery/audio/ambience.gd")
const Shake = preload("res://addons/hatchery/fx/shake.gd")
const Synth = preload("res://addons/hatchery/audio/synth.gd")
const Expect = preload("res://addons/hatchery/testing/expect.gd")


func check_ambience_switches_beds_once():
	var rng := RandomNumberGenerator.new()
	var wind: AudioStreamWAV = Synth.wind_loop(rng, 0.5)
	var hum: AudioStreamWAV = Synth.drone_loop(80.0, [1.0, 1.5], 0.5)
	var ambience := Ambience.new()
	ambience.fade_seconds = 0.0
	var first: bool = ambience.play_bed("ruins", [{"stream": wind, "db": -12.0}, {"stream": hum, "db": -20.0}])
	var again: bool = ambience.play_bed("ruins", [{"stream": wind, "db": -12.0}])
	var ruins_layers: int = ambience.players().size()
	var ruins_db: float = ambience.players()[0].volume_db
	ambience.play_bed("fen", [{"stream": hum, "db": -9.0}, {}])
	var fen_layers: int = ambience.players().size()
	ambience.stop()
	var result: String = Expect.all([
		Expect.truthy(first and not again, "the bed already on is not restarted"),
		Expect.equal(ruins_layers, 2, "every layer gets a player"),
		Expect.equal(ruins_db, -12.0, "layers settle at their level"),
		Expect.equal(fen_layers, 1, "a layer without a stream is skipped"),
		Expect.truthy(ambience.current == "" and ambience.players().is_empty(), "stop leaves silence"),
	])
	ambience.free()
	return result


func check_shake_grows_drains_and_turns_off():
	var trace := func(seed_value: int) -> Array:
		var shake := Shake.new(seed_value)
		shake.add(0.8)
		var offsets: Array = []
		for i in range(10):
			offsets.append(shake.step(1.0 / 60.0))
		return offsets
	var shake := Shake.new()
	shake.add(0.3)
	shake.add(0.9)
	var capped: float = shake.trauma
	var moved: bool = false
	for i in range(6):
		moved = moved or shake.step(1.0 / 60.0).length() > 0.0
	for i in range(120):
		shake.step(1.0 / 60.0)
	var settled: Vector2 = shake.offset
	var off := Shake.new()
	off.enabled = false
	off.add(1.0)
	return Expect.all([
		Expect.equal(capped, 1.0, "trauma caps at one"),
		Expect.truthy(moved, "trauma moves the view"),
		Expect.truthy(shake.trauma == 0.0 and settled == Vector2.ZERO, "it drains back to centre"),
		Expect.truthy(off.trauma == 0.0 and off.step(0.1) == Vector2.ZERO, "disabled shake never moves"),
		Expect.truthy(trace.call(5) == trace.call(5), "the same seed shakes the same way"),
	])
