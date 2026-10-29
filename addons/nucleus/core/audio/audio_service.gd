class_name NucleusAudioService
extends Node
## Application-wide facade for non-positional audio and bus preferences.

const LOG_CONTEXT: StringName = &"Audio"
const SILENCE_DB: float = -80.0

@onready var music: NucleusMusicService = %Music
@onready var _one_shots: NucleusAudioOneShotPool = %OneShotPool


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	if not ProjectSettings.get_setting("nucleus/integration/manage_project_preferences", false):
		return
	NucleusSettings.setting_changed.connect(_on_setting_changed)

	if NucleusSettings.is_initialized():
		_apply_all_settings()
	else:
		NucleusSettings.settings_loaded.connect(
			_apply_all_settings,
			CONNECT_ONE_SHOT,
		)


## Plays one non-positional sound effect.
func play_one_shot(
	stream: AudioStream,
	bus: StringName = NucleusAudioBuses.SFX,
	volume_linear: float = 1.0,
	pitch_scale: float = 1.0,
	from_position: float = 0.0,
	voice_priority: int = 0,
) -> AudioStreamPlayer:
	return _one_shots.play(
		stream,
		bus,
		volume_linear,
		pitch_scale,
		from_position,
		voice_priority,
	)


## Plays a reusable [NucleusAudioCue].
func play_cue(cue: NucleusAudioCue) -> AudioStreamPlayer:
	return _one_shots.play_cue(cue)


func stop_one_shots(bus: StringName = &"") -> void:
	if bus == &"":
		_one_shots.stop_all()
	else:
		_one_shots.stop_bus(bus)


## Sets one bus volume using a linear 0..1-style value.
func set_bus_volume_linear(
	bus: StringName,
	volume_linear: float,
) -> Error:
	var bus_index: int = AudioServer.get_bus_index(bus)

	if bus_index == -1:
		return ERR_DOES_NOT_EXIST

	var clamped_volume: float = maxf(0.0, volume_linear)
	var volume_db: float = (
		SILENCE_DB
		if is_zero_approx(clamped_volume)
		else linear_to_db(clamped_volume)
	)

	AudioServer.set_bus_volume_db(bus_index, volume_db)

	return OK


func get_bus_volume_linear(bus: StringName) -> float:
	var bus_index: int = AudioServer.get_bus_index(bus)

	if bus_index == -1:
		return 0.0

	return db_to_linear(AudioServer.get_bus_volume_db(bus_index))


func set_bus_muted(bus: StringName, muted: bool) -> Error:
	var bus_index: int = AudioServer.get_bus_index(bus)

	if bus_index == -1:
		return ERR_DOES_NOT_EXIST

	AudioServer.set_bus_mute(bus_index, muted)

	return OK


func is_bus_muted(bus: StringName) -> bool:
	var bus_index: int = AudioServer.get_bus_index(bus)

	if bus_index == -1:
		return false

	return AudioServer.is_bus_mute(bus_index)


func get_available_buses() -> Array[StringName]:
	var buses: Array[StringName] = []

	for bus_index: int in range(AudioServer.bus_count):
		buses.append(AudioServer.get_bus_name(bus_index))

	return buses


func _apply_all_settings() -> void:
	set_bus_muted(
		NucleusAudioBuses.MASTER,
		NucleusSettings.get_bool(NucleusSettingIds.AUDIO_MUTED),
	)

	set_bus_volume_linear(
		NucleusAudioBuses.MASTER,
		NucleusSettings.get_float(
			NucleusSettingIds.AUDIO_MASTER_VOLUME,
			0.9,
		),
	)
	set_bus_volume_linear(
		NucleusAudioBuses.MUSIC,
		NucleusSettings.get_float(
			NucleusSettingIds.AUDIO_MUSIC_VOLUME,
			0.8,
		),
	)

	var sfx_volume: float = NucleusSettings.get_float(
		NucleusSettingIds.AUDIO_SFX_VOLUME,
		0.9,
	)
	set_bus_volume_linear(NucleusAudioBuses.SFX, sfx_volume)
	set_bus_volume_linear(NucleusAudioBuses.ECHO_SFX, sfx_volume)

	set_bus_volume_linear(
		NucleusAudioBuses.VOICE,
		NucleusSettings.get_float(
			NucleusSettingIds.AUDIO_VOICE_VOLUME,
			0.8,
		),
	)
	set_bus_volume_linear(
		NucleusAudioBuses.UI,
		NucleusSettings.get_float(
			NucleusSettingIds.AUDIO_UI_VOLUME,
			0.9,
		),
	)
	set_bus_volume_linear(
		NucleusAudioBuses.AMBIENT,
		NucleusSettings.get_float(
			NucleusSettingIds.AUDIO_AMBIENT_VOLUME,
			0.9,
		),
	)


func _on_setting_changed(
	setting_id: StringName,
	value: Variant,
	_previous_value: Variant,
) -> void:
	match setting_id:
		NucleusSettingIds.AUDIO_MUTED:
			set_bus_muted(NucleusAudioBuses.MASTER, bool(value))

		NucleusSettingIds.AUDIO_MASTER_VOLUME:
			set_bus_volume_linear(
				NucleusAudioBuses.MASTER,
				float(value),
			)

		NucleusSettingIds.AUDIO_MUSIC_VOLUME:
			set_bus_volume_linear(
				NucleusAudioBuses.MUSIC,
				float(value),
			)

		NucleusSettingIds.AUDIO_SFX_VOLUME:
			set_bus_volume_linear(
				NucleusAudioBuses.SFX,
				float(value),
			)
			set_bus_volume_linear(
				NucleusAudioBuses.ECHO_SFX,
				float(value),
			)

		NucleusSettingIds.AUDIO_VOICE_VOLUME:
			set_bus_volume_linear(
				NucleusAudioBuses.VOICE,
				float(value),
			)

		NucleusSettingIds.AUDIO_UI_VOLUME:
			set_bus_volume_linear(
				NucleusAudioBuses.UI,
				float(value),
			)

		NucleusSettingIds.AUDIO_AMBIENT_VOLUME:
			set_bus_volume_linear(
				NucleusAudioBuses.AMBIENT,
				float(value),
			)
