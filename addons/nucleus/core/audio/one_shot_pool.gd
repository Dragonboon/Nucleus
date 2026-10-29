class_name NucleusAudioOneShotPool
extends Node
## Dynamic pool for arbitrary non-positional one-shot sounds.
##
## The pool grows on demand up to [member max_players]. At capacity, a new voice
## may replace the oldest voice among the lowest active priority. Lower-priority
## requests are rejected instead of interrupting more important playback.

signal voice_rejected(priority: int)
signal voice_stolen(previous_priority: int, new_priority: int)

const LOG_CONTEXT: StringName = &"Audio"

@export_range(1, 128, 1, "or_greater")
var initial_players: int = 8
@export_range(1, 256, 1, "or_greater")
var max_players: int = 32

var _players: Array[AudioStreamPlayer] = []
var _started_at_usec: Dictionary[AudioStreamPlayer, int] = {}
var _priorities: Dictionary[AudioStreamPlayer, int] = {}


func _ready() -> void:
	max_players = maxi(max_players, initial_players)

	for _index: int in range(initial_players):
		_create_player()


## Plays an arbitrary AudioStream through one pooled player.
func play(
	stream: AudioStream,
	bus: StringName = NucleusAudioBuses.SFX,
	volume_linear: float = 1.0,
	pitch_scale: float = 1.0,
	from_position: float = 0.0,
	voice_priority: int = 0,
) -> AudioStreamPlayer:
	if stream == null:
		return null

	var player: AudioStreamPlayer = _acquire_player(voice_priority)

	if player == null:
		return null

	_reset_player(player)

	player.stream = stream
	player.bus = _validated_bus(bus)
	player.volume_linear = maxf(0.0, volume_linear)
	player.pitch_scale = clampf(pitch_scale, 0.01, 4.0)

	_started_at_usec[player] = Time.get_ticks_usec()
	_priorities[player] = voice_priority
	player.play(maxf(0.0, from_position))

	return player


## Plays a reusable cue Resource.
func play_cue(cue: NucleusAudioCue) -> AudioStreamPlayer:
	if cue == null:
		return null

	return play(
		cue.stream,
		cue.bus,
		cue.volume_linear,
		cue.pitch_scale,
		cue.from_position,
		cue.voice_priority,
	)


## Stops every currently active pooled sound.
func stop_all() -> void:
	for player: AudioStreamPlayer in _players:
		player.stop()
		_reset_player(player)


## Stops pooled sounds routed to one bus.
func stop_bus(bus: StringName) -> void:
	for player: AudioStreamPlayer in _players:
		if player.playing and player.bus == bus:
			player.stop()
			_reset_player(player)


func get_active_voice_count() -> int:
	var count: int = 0

	for player: AudioStreamPlayer in _players:
		if player.playing:
			count += 1

	return count


func _create_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "OneShot%d" % _players.size()
	player.bus = NucleusAudioBuses.SFX
	player.finished.connect(_on_player_finished.bind(player))

	add_child(player)
	_players.append(player)
	_started_at_usec[player] = 0
	_priorities[player] = 0

	return player


func _acquire_player(priority: int) -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			return player

	if _players.size() < max_players:
		return _create_player()

	var victim: AudioStreamPlayer
	var victim_priority: int = 2147483647
	var victim_started_at: int = 9223372036854775807

	for player: AudioStreamPlayer in _players:
		var player_priority: int = int(_priorities.get(player, 0))
		var started_at: int = int(_started_at_usec.get(player, 0))

		if (
			player_priority < victim_priority
			or (
				player_priority == victim_priority
				and started_at < victim_started_at
			)
		):
			victim = player
			victim_priority = player_priority
			victim_started_at = started_at

	if victim == null or priority < victim_priority:
		voice_rejected.emit(priority)
		return null

	victim.stop()
	voice_stolen.emit(victim_priority, priority)
	return victim


func _reset_player(player: AudioStreamPlayer) -> void:
	player.stream = null
	player.bus = NucleusAudioBuses.SFX
	player.volume_linear = 1.0
	player.pitch_scale = 1.0
	player.stream_paused = false
	_started_at_usec[player] = 0
	_priorities[player] = 0


func _validated_bus(bus: StringName) -> StringName:
	if AudioServer.get_bus_index(bus) != -1:
		return bus

	NucleusLog.warning(
		"Unknown audio bus '%s'; falling back to SFX." % bus,
		LOG_CONTEXT,
	)

	return NucleusAudioBuses.SFX


func _on_player_finished(player: AudioStreamPlayer) -> void:
	_reset_player(player)
