extends RefCounted
## Placeholder sound synthesised at start, so a prototype can ship with no
## audio files: tones with partials and noise, plucked strings, and seamless
## noise loops (wind, rain, drones). Every random sample comes from the rng
## passed in, so the same seed always gives the same sounds.
##
##     var rng := RandomNumberGenerator.new()
##     rng.seed = 7
##     var chime: AudioStreamWAV = Synth.tone(rng, [[880.0, 0.5], [1320.0, 0.3]], 1.4, 0.0, 2.5)

const RATE: int = 22050


## Partials [[frequency_hz, weight], ...] mixed with a share of white `noise`
## (0..1), with an exponential `decay` (per second) and a click-free attack.
static func tone(rng: RandomNumberGenerator, partials: Array, seconds: float, noise: float, decay: float, peak: float = 0.8) -> AudioStreamWAV:
	var count: int = int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / RATE
		var value: float = 0.0
		for partial in partials:
			value += sin(TAU * float(partial[0]) * t) * float(partial[1])
		value = value * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise
		value *= exp(-t * decay) * minf(t * 400.0, 1.0)
		data.encode_s16(i * 2, _sample(value, peak))
	return stream(data)


## A plucked string (a guqin- or harp-like voice): fundamental plus decaying
## second and third harmonics, a sharp attack and a long tail.
static func pluck(hz: float, seconds: float = 2.4, decay: float = 1.6, peak: float = 0.6) -> AudioStreamWAV:
	var count: int = int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / RATE
		var value: float = sin(TAU * hz * t) * 0.6 + sin(TAU * hz * 2.0 * t) * 0.25 * exp(-t * 3.0) \
			+ sin(TAU * hz * 3.0 * t) * 0.12 * exp(-t * 6.0)
		value *= exp(-t * decay) * minf(t * 900.0, 1.0)
		data.encode_s16(i * 2, _sample(value, peak))
	return stream(data)


## Low-passed noise that swells and falls once per loop: wind. `smooth`
## (0..1) is how heavily the noise is filtered; smaller is softer.
static func wind_loop(rng: RandomNumberGenerator, seconds: float = 4.0, smooth: float = 0.02, peak: float = 0.37) -> AudioStreamWAV:
	var count: int = int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var low: float = 0.0
	for i in range(count):
		low = lerpf(low, rng.randf_range(-1.0, 1.0), smooth)
		var swell: float = 0.55 + 0.45 * sin(TAU * float(i) / count)
		data.encode_s16(i * 2, _sample(low * swell * 3.0, peak))
	return stream(data, true)


## High-passed noise: rain, surf, static.
static func hiss_loop(rng: RandomNumberGenerator, seconds: float = 4.0, peak: float = 0.27) -> AudioStreamWAV:
	var count: int = int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var high: float = 0.0
	for i in range(count):
		high = rng.randf_range(-1.0, 1.0) - high * 0.4
		data.encode_s16(i * 2, _sample(high * 0.5, peak))
	return stream(data, true)


## A sustained chord of `ratios` over `root_hz`, with a slow tremolo; loops
## seamlessly because each partial completes whole cycles.
static func drone_loop(root_hz: float, ratios: Array, seconds: float = 4.0, peak: float = 0.3) -> AudioStreamWAV:
	var count: int = int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var partials: Array[float] = []
	for ratio in ratios:
		# Round each frequency to whole cycles per loop so the seam is silent.
		partials.append(roundf(root_hz * float(ratio) * seconds) / seconds)
	for i in range(count):
		var t: float = float(i) / RATE
		var value: float = 0.0
		for hz in partials:
			value += sin(TAU * hz * t)
		value *= (0.8 + 0.2 * sin(TAU * t / seconds)) / maxf(partials.size(), 1)
		data.encode_s16(i * 2, _sample(value, peak))
	return stream(data, true)


## `semitones` above `root_hz`.
static func pitch(root_hz: float, semitones: float) -> float:
	return root_hz * pow(2.0, semitones / 12.0)


## 16-bit mono PCM at RATE, optionally looping over its whole length.
static func stream(data: PackedByteArray, loop: bool = false) -> AudioStreamWAV:
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = RATE
	result.data = data
	if loop:
		result.loop_mode = AudioStreamWAV.LOOP_FORWARD
		result.loop_end = data.size() / 2
	return result


static func _sample(value: float, peak: float) -> int:
	return int(clampf(value, -1.0, 1.0) * clampf(peak, 0.0, 1.0) * 32767.0)
