extends RefCounted
## Linear 0..1 volume settings turned into decibels, for buses or for single
## players. Silence is -80 dB (or a muted bus), never -inf.

const SILENT_DB: float = -80.0


## `base_db` (the mix level a sound was authored at) adjusted by a linear gain.
static func db(base_db: float, gain: float, silent: bool = false) -> float:
	if silent or not is_finite(gain) or gain <= 0.0:
		return SILENT_DB
	return maxf(SILENT_DB, base_db + linear_to_db(gain))


## The product of every gain in `chain`, e.g. [master, music].
static func gain(chain: Array) -> float:
	var result: float = 1.0
	for value in chain:
		result *= clampf(float(value), 0.0, 1.0)
	return result


## Creates `bus_name` routed to Master when the project's bus layout lacks it.
static func ensure_bus(bus_name: String) -> int:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")
	return index


static func set_bus(bus_name: String, level: float, muted: bool = false) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))
	AudioServer.set_bus_mute(index, muted or level <= 0.001)


## Applies settings to buses: `bus_keys` maps bus name -> settings key, e.g.
## {"Master": "master", "Music": "music", "Effects": "effects"}. `muted_key`
## names a boolean that silences Master.
static func apply_buses(values: Dictionary, bus_keys: Dictionary, muted_key: String = "muted") -> void:
	var muted: bool = bool(values.get(muted_key, false))
	for bus_name in bus_keys:
		var key: String = bus_keys[bus_name]
		if values.has(key):
			set_bus(bus_name, float(values[key]), muted and bus_name == "Master")
