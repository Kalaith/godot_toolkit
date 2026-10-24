extends RefCounted
## The simulation helpers: the tick clock, the effects buffer, the data-file
## registry and saving a generator's position.
const SimClock = preload("res://addons/hatchery/core/sim_clock.gd")
const EffectBuffer = preload("res://addons/hatchery/core/effect_buffer.gd")
const DataFiles = preload("res://addons/hatchery/core/data_files.gd")
const Det = preload("res://addons/hatchery/core/det.gd")
const JsonIO = preload("res://addons/hatchery/core/json_io.gd")
const Expect = preload("res://addons/hatchery/testing/expect.gd")

const PERIODS: Array = [
	{"id": "morning", "from": 5.0}, {"id": "day", "from": 11.0},
	{"id": "evening", "from": 17.0}, {"id": "night", "from": 21.0},
]


func check_clock_reads_hours_and_days():
	var clock := SimClock.new(720, SimClock.tick_at(720, 1, 7.5))
	var start: String = clock.text()
	var crossed: int = clock.advance(720)
	return Expect.all([
		Expect.equal(start, "07:30", "start of day one"),
		Expect.equal(clock.day(), 2, "a whole day later"),
		Expect.equal(crossed, 1, "one boundary crossed"),
		Expect.equal(clock.text(), "07:30", "the hour repeats"),
		Expect.equal(clock.advance(0) + clock.advance(-5), 0, "no negative time"),
		Expect.equal(SimClock.new(720, SimClock.tick_at(720, 3, 0.0)).day(), 3, "tick_at counts from day 1"),
	])


func check_clock_periods_wrap_past_midnight():
	var clock := SimClock.new(240)
	var installed: bool = clock.set_periods(PERIODS)
	var seen: Dictionary = {}
	for hour in [2.0, 5.0, 10.9, 11.0, 18.0, 21.0, 23.5]:
		clock.tick = SimClock.tick_at(240, 1, hour)
		seen[hour] = clock.period()
	var kept: int = clock.periods.size()
	var unordered: bool = clock.set_periods([{"id": "a", "from": 9.0}, {"id": "b", "from": 3.0}])
	var unnamed: bool = clock.set_periods([{"from": 3.0}])
	return Expect.all([
		Expect.truthy(installed, "ascending periods install"),
		Expect.equal(seen[2.0], "night", "before the first period is the last one"),
		Expect.equal(seen[5.0], "morning", "a period starts on its hour"),
		Expect.equal(seen[10.9], "morning", "and lasts until the next"),
		Expect.equal(seen[11.0], "day", "next period"),
		Expect.equal(seen[18.0], "evening", "evening"),
		Expect.equal(seen[21.0], "night", "night starts"),
		Expect.equal(seen[23.5], "night", "night holds to midnight"),
		Expect.falsy(unordered or unnamed, "unordered or unnamed periods are refused"),
		Expect.equal(clock.periods.size(), kept, "a refused list changes nothing"),
		Expect.equal(SimClock.new().period(), "", "no periods, no period"),
	])


func check_clock_waits_for_an_hour_and_restores():
	var clock := SimClock.new(240, SimClock.tick_at(240, 1, 20.0))
	var wait: int = clock.ticks_until(21.0)
	var next_day: int = clock.ticks_until(20.0)
	var other := SimClock.new(240)
	var restored: bool = other.restore(clock.snapshot())
	var wrong_length: bool = SimClock.new(480).restore(clock.snapshot())
	var negative: bool = other.restore({"tick": -1, "ticks_per_day": 240})
	return Expect.all([
		Expect.equal(wait, 10, "one hour is ten ticks of a 240-tick day"),
		Expect.equal(next_day, 240, "the same hour is a full day away"),
		Expect.truthy(restored and other.tick == clock.tick, "a snapshot restores"),
		Expect.falsy(wrong_length, "another day length is refused"),
		Expect.falsy(negative, "a negative tick is refused"),
	])


func check_effects_apply_in_canonical_order():
	var run := func(visit: Array) -> Array:
		var buffer := EffectBuffer.new()
		for who in visit:
			buffer.push(who, {"who": who, "step": 1})
			buffer.push(who, {"who": who, "step": 2})
		var applied: Array = []
		buffer.apply(func(effect: Dictionary) -> void: applied.append("%d.%d" % [effect.who, effect.step]))
		return applied
	var forward: Array = run.call([1, 2, 3])
	var backward: Array = run.call([3, 2, 1])
	return Expect.all([
		Expect.equal(forward, ["1.1", "1.2", "2.1", "2.2", "3.1", "3.2"], "by actor, then push order"),
		Expect.equal(backward, forward, "visiting order does not change the result"),
	])


func check_effects_pushed_while_applying_wait_a_tick():
	var buffer := EffectBuffer.new()
	var log: Array = []
	buffer.push(1, {"n": 1})
	var applied: int = buffer.apply(func(effect: Dictionary) -> void:
		log.append(effect.n)
		if effect.n == 1:
			buffer.push(0, {"n": 2}))
	var queued_after: int = buffer.size()
	buffer.apply(func(effect: Dictionary) -> void: log.append(effect.n))
	buffer.push(5, {"n": 9})
	buffer.clear()
	return Expect.all([
		Expect.equal(applied, 1, "only the first batch"),
		Expect.equal(queued_after, 1, "the new effect waits"),
		Expect.equal(log, [1, 2], "and runs next tick"),
		Expect.truthy(buffer.is_empty(), "clear drops the rest"),
	])


func check_data_files_index_and_report_problems():
	var path: String = Expect.scratch_path("data_files_zones.json")
	var old: String = Expect.scratch_path("data_files_old.json")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify({
		"schema_version": 2, "zones": [{"id": "a", "name": "A"}, {"id": "b"}, {"id": "a", "name": "again"}, 7]}))
	FileAccess.open(old, FileAccess.WRITE).store_string(JSON.stringify({"schema_version": 1}))
	var data := DataFiles.new({"zones": path, "old": old, "absent": "user://checks/not_there.json"}, 2)
	var ok: bool = data.load_all()
	var problems: int = data.errors.size()
	data.file("nowhere")
	return Expect.all([
		Expect.falsy(ok, "bad files fail load_all"),
		Expect.equal(problems, 2, "old schema and missing file reported once each: " + str(data.errors)),
		Expect.equal(data.find("zones", "zones", "a").get("name"), "A", "first entry with an id wins"),
		Expect.truthy(data.has_id("zones", "zones", "b") and not data.has_id("zones", "zones", "c"), "has_id"),
		Expect.equal(data.ids("zones", "zones"), ["a", "b"], "ids in file order, non-objects skipped"),
		Expect.equal(data.find("zones", "zones", "zz"), {}, "unknown id is empty"),
		Expect.equal(data.entries("old", "zones"), [], "an unusable file has no entries"),
		Expect.equal(data.errors.size(), 3, "an unregistered name is an error"),
	])


func check_generator_position_survives_json():
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654321987
	for i in 7:
		rng.randi()
	var saved: Variant = JsonIO.parse(JSON.stringify(Det.save_state(rng)))
	var expected: Array = [rng.randi(), rng.randf(), rng.randi_range(0, 1000)]
	var again := RandomNumberGenerator.new()
	var loaded: bool = Det.load_state(again, saved)
	var replay: Array = [again.randi(), again.randf(), again.randi_range(0, 1000)]
	return Expect.all([
		Expect.truthy(loaded, "a saved state loads"),
		Expect.equal(replay, expected, "the sequence carries on from the same place"),
		Expect.falsy(Det.load_state(again, {"seed": "x", "state": "1"}), "text that is not a number is refused"),
		Expect.falsy(Det.load_state(again, 5), "so is a non-object"),
	])
