class_name NucleusMusicService
extends Node
## Persistent music playback with interruptible crossfades.
##
## Any AudioStream can be played, including AudioStreamPlaylist,
## AudioStreamRandomizer, and AudioStreamInteractive.

signal stream_changed(previous_stream: AudioStream, stream: AudioStream)
signal stream_started(stream: AudioStream)
signal stream_finished(stream: AudioStream)

const SILENCE_DB: float = -80.0

@onready var _player_a: AudioStreamPlayer = %PlayerA
@onready var _player_b: AudioStreamPlayer = %PlayerB

var _active_player: AudioStreamPlayer
var _fade_tween: Tween


func _ready() -> void:
	_active_player = _player_a

	_player_a.finished.connect(_on_player_finished.bind(_player_a))
	_player_b.finished.connect(_on_player_finished.bind(_player_b))


## Starts a stream, optionally crossfading from the current one.
func play(
	stream: AudioStream,
	fade_seconds: float = 0.5,
	from_position: float = 0.0,
	bus: StringName = NucleusAudioBuses.MUSIC,
) -> Error:
	if stream == null:
		return ERR_INVALID_PARAMETER

	var previous_stream: AudioStream = get_current_stream()

	if previous_stream == stream and _active_player:
		if _active_player.stream_paused:
			_active_player.stream_paused = false
			return OK

		if _active_player.playing:
			return OK

		_active_player.play(maxf(0.0, from_position))
		stream_started.emit(stream)
		return OK

	_stop_fade()

	if (
		_active_player == null
		or not _active_player.playing
		or fade_seconds <= 0.0
	):
		_stop_players()

		_active_player = _player_a
		_prepare_player(
			_active_player,
			stream,
			bus,
			0.0,
		)
		_active_player.play(maxf(0.0, from_position))
	else:
		var previous_player: AudioStreamPlayer = _active_player
		var next_player: AudioStreamPlayer = _other_player(previous_player)

		next_player.stop()
		_prepare_player(
			next_player,
			stream,
			bus,
			SILENCE_DB,
		)
		next_player.play(maxf(0.0, from_position))

		_active_player = next_player
		_fade_tween = create_tween().set_parallel(true)
		_fade_tween.tween_property(
			previous_player,
			"volume_db",
			SILENCE_DB,
			fade_seconds,
		)
		_fade_tween.tween_property(
			next_player,
			"volume_db",
			0.0,
			fade_seconds,
		)
		_fade_tween.chain().tween_callback(
			_complete_crossfade.bind(previous_player, next_player)
		)

	if previous_stream != stream:
		stream_changed.emit(previous_stream, stream)

	stream_started.emit(stream)

	return OK


## Stops music immediately or with a fade.
func stop(fade_seconds: float = 0.0) -> void:
	_stop_fade()

	if fade_seconds <= 0.0:
		_stop_players()
		return

	_fade_tween = create_tween().set_parallel(true)

	for player: AudioStreamPlayer in [_player_a, _player_b]:
		if player.playing:
			_fade_tween.tween_property(
				player,
				"volume_db",
				SILENCE_DB,
				fade_seconds,
			)

	_fade_tween.chain().tween_callback(_stop_players)


func pause() -> void:
	for player: AudioStreamPlayer in [_player_a, _player_b]:
		if player.has_stream_playback():
			player.stream_paused = true


func resume() -> void:
	for player: AudioStreamPlayer in [_player_a, _player_b]:
		if player.has_stream_playback():
			player.stream_paused = false


func is_playing() -> bool:
	return _active_player != null and _active_player.playing


func get_current_stream() -> AudioStream:
	return _active_player.stream if _active_player else null


func get_playback_position() -> float:
	if _active_player == null:
		return 0.0

	return _active_player.get_playback_position()


func _prepare_player(
	player: AudioStreamPlayer,
	stream: AudioStream,
	bus: StringName,
	volume_db: float,
) -> void:
	player.stream = stream
	player.bus = (
		bus
		if AudioServer.get_bus_index(bus) != -1
		else NucleusAudioBuses.MUSIC
	)
	player.pitch_scale = 1.0
	player.volume_db = volume_db
	player.stream_paused = false


func _other_player(player: AudioStreamPlayer) -> AudioStreamPlayer:
	return _player_b if player == _player_a else _player_a


func _complete_crossfade(
	previous_player: AudioStreamPlayer,
	next_player: AudioStreamPlayer,
) -> void:
	previous_player.stop()
	previous_player.stream = null
	previous_player.volume_db = 0.0
	next_player.volume_db = 0.0
	_fade_tween = null


func _stop_players() -> void:
	for player: AudioStreamPlayer in [_player_a, _player_b]:
		player.stop()
		player.stream = null
		player.volume_db = 0.0
		player.pitch_scale = 1.0
		player.stream_paused = false

	_fade_tween = null


func _stop_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = null


func _on_player_finished(player: AudioStreamPlayer) -> void:
	var finished_stream: AudioStream = player.stream

	if player == _active_player and finished_stream:
		stream_finished.emit(finished_stream)

	player.stream = null
	player.volume_db = 0.0
