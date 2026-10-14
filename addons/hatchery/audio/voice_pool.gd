extends Node
## A fixed set of AudioStreamPlayers used round-robin for one-shot sounds, so
## overlapping effects never allocate players during play and a burst steals
## the oldest voice instead of piling up. Per-cue cooldowns drop cues that
## arrive too fast rather than queueing a backlog.
##
##     var sfx := VoicePool.new()
##     sfx.bus = &"Effects"
##     add_child(sfx)
##     sfx.play(thud, -6.0, randf_range(0.9, 1.1))
##     sfx.play_limited("step", step_sound, 0.14, -9.0)

@export var voices: int = 6
@export var bus: StringName = &"Master"
## Godot 4.2's headless dummy driver keeps unconsumed playback instances, so
## headless runs schedule cues (counted in `played`) without playing them.
var output_enabled: bool = DisplayServer.get_name() != "headless"
## Cues started, per cue name given to play_limited (for checks and captions).
var played: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cooldowns: Dictionary = {}


func _ready() -> void:
	for i in range(maxi(voices, 1)):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.bus = bus
		add_child(player)
		_players.append(player)


func _process(delta: float) -> void:
	for cue in _cooldowns.keys():
		_cooldowns[cue] = float(_cooldowns[cue]) - delta
		if _cooldowns[cue] <= 0.0:
			_cooldowns.erase(cue)


## Plays `sound` on the next voice. Returns the player used.
func play(sound: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = sound
	player.volume_db = volume_db
	player.pitch_scale = pitch
	if output_enabled:
		player.play()
	return player


## Plays `sound` unless the same `cue` played less than `cooldown` seconds ago.
func play_limited(cue: String, sound: AudioStream, cooldown: float, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	if _cooldowns.has(cue):
		return false
	_cooldowns[cue] = cooldown
	played[cue] = int(played.get(cue, 0)) + 1
	play(sound, volume_db, pitch)
	return true


func stop_all() -> void:
	for player in _players:
		player.stop()


func _exit_tree() -> void:
	for player in _players:
		player.stop()
		player.stream = null
