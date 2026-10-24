extends RefCounted
## A whole-number tick clock for simulations: days, an hour clock and named
## periods of the day ("morning", "night") derived from it. Integer ticks only,
## so the same run gives the same clock; real time and rendering stay outside.
##
##     var clock := SimClock.new(720, SimClock.tick_at(720, 1, 7.0))
##     clock.set_periods([{"id": "morning", "from": 5.0}, {"id": "night", "from": 21.0}])
##     if clock.advance() > 0: daily_tick()
##     label.text = "Day %d  %s  (%s)" % [clock.day(), clock.text(), clock.period()]
##
## Days count from 1. Hours are 0..24 on a 24-hour face whatever the length of
## a day in ticks.

const HOURS_PER_DAY: float = 24.0

var ticks_per_day: int
var tick: int = 0
## Ascending by "from" (hour, 0..24). The period before the first "from" is
## the last entry, so a "night" starting at 21 also covers 02:00.
var periods: Array = []


func _init(per_day: int = 720, start_tick: int = 0) -> void:
	ticks_per_day = maxi(per_day, 1)
	tick = maxi(start_tick, 0)


## Tick of `hour` (0..24) on `day` (1 or more) for a day of `per_day` ticks.
static func tick_at(per_day: int, day_number: int, hour_of_day: float = 0.0) -> int:
	return (maxi(day_number, 1) - 1) * per_day + int(round(clampf(hour_of_day, 0.0, HOURS_PER_DAY) / HOURS_PER_DAY * per_day))


## Installs `list` ([{"id": String, "from": hour}]). Returns false and keeps the
## old periods when it is empty, unnamed, out of range or not ascending.
func set_periods(list: Array) -> bool:
	var last: float = -1.0
	for entry in list:
		if not entry is Dictionary or not entry.get("id") is String or String(entry.id).is_empty():
			return false
		var from: Variant = entry.get("from")
		if not (from is float or from is int) or not is_finite(float(from)):
			return false
		if float(from) < 0.0 or float(from) >= HOURS_PER_DAY or float(from) <= last:
			return false
		last = float(from)
	if list.is_empty():
		return false
	periods = list.duplicate(true)
	return true


## Moves time on by `count` ticks. Returns how many day boundaries were crossed.
func advance(count: int = 1) -> int:
	if count <= 0:
		return 0
	var before: int = day()
	tick += count
	return day() - before


func day() -> int:
	return tick / ticks_per_day + 1


func tick_of_day() -> int:
	return tick % ticks_per_day


## 0.0 up to (not including) 24.0.
func hour_fraction() -> float:
	return float(tick_of_day()) * HOURS_PER_DAY / float(ticks_per_day)


func hour() -> int:
	return int(hour_fraction())


func minute() -> int:
	return int((hour_fraction() - float(hour())) * 60.0)


## The id of the period now, or "" when no periods are set.
func period() -> String:
	if periods.is_empty():
		return ""
	var now: float = hour_fraction()
	var current: String = String(periods[periods.size() - 1].id)
	for entry in periods:
		if float(entry.from) > now:
			break
		current = String(entry.id)
	return current


## "07:30".
func text() -> String:
	return "%02d:%02d" % [hour(), minute()]


## Ticks from now until the clock next reads `hour_of_day` (a full day if it
## reads that now).
func ticks_until(hour_of_day: float) -> int:
	var target: int = int(round(clampf(hour_of_day, 0.0, HOURS_PER_DAY) / HOURS_PER_DAY * ticks_per_day)) % ticks_per_day
	var wait: int = target - tick_of_day()
	return wait if wait > 0 else wait + ticks_per_day


func snapshot() -> Dictionary:
	return {"tick": tick, "ticks_per_day": ticks_per_day}


## Restores a snapshot of the same day length. Returns false (and changes
## nothing) for a snapshot that is malformed or from another day length.
func restore(data: Dictionary) -> bool:
	var saved_tick: Variant = data.get("tick")
	var saved_day: Variant = data.get("ticks_per_day")
	if not (saved_tick is int or saved_tick is float) or not (saved_day is int or saved_day is float):
		return false
	if float(saved_tick) < 0.0 or float(saved_tick) != floorf(float(saved_tick)) or int(saved_day) != ticks_per_day:
		return false
	tick = int(saved_tick)
	return true
