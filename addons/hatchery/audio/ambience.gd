extends Node
## Background ambience: one "bed" of looping layers at a time (wind over a
## drone, rain over a hum), crossfaded when the bed changes. Asking for the bed
## already playing does nothing, so screens can request theirs on every show.
##
##     var ambience := Ambience.new()
##     ambience.bus = &"Ambience"
##     add_child(ambience)
##     ambience.play_bed("fen", [{"stream": rain, "db": -14.0}, {"stream": hum, "db": -20.0}])
##     ambience.stop()
##
## Layers should be looping streams (Synth's *_loop helpers loop). Each layer
## starts at its own offset into its loop, so layers of different lengths
## drift against each other instead of repeating together.

const SILENT_DB: float = -80.0

@export var bus: StringName = &"Master"
## Seconds to fade a bed in and the previous one out.
@export var fade_seconds: float = 1.5
## Godot 4.2's headless dummy driver keeps unconsumed playback instances, so
## headless runs track beds without playing them.
var output_enabled: bool = DisplayServer.get_name() != "headless"
## The bed on now ("" when silent).
var current: String = ""
var _players: Array[AudioStreamPlayer] = []


## Crossfades to `bed_id` built from `layers`: [{"stream": AudioStream,
## "db": float, "offset": 0..1 (optional, where in the loop to start)}, ...].
## Returns false when that bed was already playing.
func play_bed(bed_id: String, layers: Array) -> bool:
	if bed_id == current:
		return false
	_fade_out_current()
	current = bed_id
	for layer in layers:
		var stream: AudioStream = layer.get("stream")
		if stream == null:
			continue
		var player := AudioStreamPlayer.new()
		player.name = "Bed_%s_%d" % [bed_id.validate_node_name(), _players.size()]
		player.bus = bus
		player.stream = stream
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
		if output_enabled:
			player.play(clampf(float(layer.get("offset", 0.0)), 0.0, 1.0) * stream.get_length())
		_fade(player, float(layer.get("db", 0.0)), false)
	return true


## Fades the current bed out; `seconds` < 0 uses fade_seconds.
func stop(seconds: float = -1.0) -> void:
	_fade_out_current(seconds)
	current = ""


## The players of the bed on now (for checks and captions).
func players() -> Array[AudioStreamPlayer]:
	return _players.duplicate()


func _fade_out_current(seconds: float = -1.0) -> void:
	for player in _players:
		_fade(player, SILENT_DB, true, seconds)
	_players.clear()


func _fade(player: AudioStreamPlayer, to_db: float, then_free: bool, seconds: float = -1.0) -> void:
	var length: float = fade_seconds if seconds < 0.0 else seconds
	if length <= 0.0 or not is_inside_tree():
		player.volume_db = to_db
		if then_free:
			player.queue_free()
		return
	var tween: Tween = player.create_tween()
	# Fade in decibels from near silence would rush the start; fade linear gain.
	var from: float = db_to_linear(player.volume_db)
	tween.tween_method(func(gain: float) -> void: player.volume_db = linear_to_db(maxf(gain, 0.0001)),
		from, db_to_linear(to_db), length)
	if then_free:
		tween.tween_callback(player.queue_free)


func _exit_tree() -> void:
	for player in get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
