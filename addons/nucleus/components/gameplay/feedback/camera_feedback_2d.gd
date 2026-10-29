class_name NucleusCameraFeedback2D
extends Node
## Additive camera/game-feel mixer for a dedicated Node2D feedback pivot.
##
## The target should not also be animated by another transform-owning system.

signal impulse_started(profile: NucleusCameraImpulseProfile2D)
signal impulse_finished(profile: NucleusCameraImpulseProfile2D)

@export var target: Node2D
@export var enabled: bool = true
@export var use_camera_offset: bool = true
@export var apply_rotation: bool = false

var _base_position: Vector2
var _base_rotation: float

var _impulses: Array[Dictionary] = []
var _offset_sources: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	if target == null:
		target = get_parent() as Node2D

	if target == null:
		NucleusLog.error(
			"%s requires a dedicated Node2D target." % get_path(),
			&"CameraFeedback2D",
		)
		set_process(false)
		return

	recapture_baseline()


func _exit_tree() -> void:
	_restore_baseline()


func _process(delta: float) -> void:
	if target == null:
		return

	if not enabled:
		_restore_baseline()
		return

	_update_impulses(delta)

	var position_offset := Vector2.ZERO
	var rotation_offset: float = 0.0

	for source: Dictionary in _offset_sources.values():
		var scale: float = NucleusMotionPolicy.get_motion_scale(
			bool(source["respect_reduced_motion"]),
			float(source["reduced_motion_scale"]),
		)
		position_offset += source["position"] * scale
		rotation_offset += float(source["rotation"]) * scale

	for impulse: Dictionary in _impulses:
		var sample: Dictionary = _sample_impulse(impulse)
		position_offset += sample["position"]
		rotation_offset += float(sample["rotation"])

	if use_camera_offset and target is Camera2D:
		(target as Camera2D).offset = (
			_base_position + position_offset
		)
	else:
		target.position = _base_position + position_offset

	if apply_rotation:
		target.rotation = _base_rotation + rotation_offset


func play_impulse(
	profile: NucleusCameraImpulseProfile2D,
	strength: float = 1.0,
) -> Error:
	if profile == null:
		return ERR_INVALID_PARAMETER

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.NoiseType.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	noise.seed = (
		profile.seed
		if profile.seed != 0
		else int(Time.get_ticks_usec() % 2147483647)
	)

	_impulses.append(
		{
			"profile": profile,
			"elapsed": 0.0,
			"strength": maxf(0.0, strength),
			"noise": noise,
		}
	)
	impulse_started.emit(profile)

	return OK


func set_offset_source(
	source_id: StringName,
	position: Vector2,
	rotation_radians: float = 0.0,
	respect_reduced_motion: bool = true,
	reduced_motion_scale: float = 0.20,
) -> Error:
	if source_id == &"":
		return ERR_INVALID_PARAMETER

	_offset_sources[source_id] = {
		"position": position,
		"rotation": rotation_radians,
		"respect_reduced_motion": respect_reduced_motion,
		"reduced_motion_scale": clampf(
			reduced_motion_scale,
			0.0,
			1.0,
		),
	}

	return OK


func remove_offset_source(source_id: StringName) -> bool:
	return _offset_sources.erase(source_id)


func clear_feedback() -> void:
	_impulses.clear()
	_offset_sources.clear()
	_restore_baseline()


func recapture_baseline() -> void:
	if target == null:
		return

	_base_position = (
		(target as Camera2D).offset
		if use_camera_offset and target is Camera2D
		else target.position
	)
	_base_rotation = target.rotation


func _update_impulses(delta: float) -> void:
	for index: int in range(
		_impulses.size() - 1,
		-1,
		-1,
	):
		var impulse: Dictionary = _impulses[index]
		impulse["elapsed"] = float(impulse["elapsed"]) + delta
		var profile := impulse["profile"] as NucleusCameraImpulseProfile2D

		if float(impulse["elapsed"]) < profile.duration:
			_impulses[index] = impulse
			continue

		_impulses.remove_at(index)
		impulse_finished.emit(profile)


func _sample_impulse(impulse: Dictionary) -> Dictionary:
	var profile := impulse["profile"] as NucleusCameraImpulseProfile2D
	var elapsed: float = float(impulse["elapsed"])
	var progress: float = clampf(
		elapsed / maxf(profile.duration, 0.001),
		0.0,
		1.0,
	)
	var decay: float = pow(
		1.0 - progress,
		profile.decay_power,
	)
	var scale: float = (
		float(impulse["strength"])
		* decay
		* NucleusMotionPolicy.get_motion_scale(
			profile.respect_reduced_motion,
			profile.reduced_motion_scale,
		)
	)
	var noise := impulse["noise"] as FastNoiseLite
	var time: float = elapsed * profile.frequency

	return {
		"position": (
			profile.position_kick
			+ Vector2(
				noise.get_noise_1d(time),
				noise.get_noise_1d(time + 31.7),
			) * profile.position_amplitude
		) * scale,
		"rotation": (
			deg_to_rad(profile.rotation_kick_degrees)
			+ (
				deg_to_rad(profile.rotation_degrees)
				* noise.get_noise_1d(time + 67.1)
			)
		) * scale,
	}


func _restore_baseline() -> void:
	if target == null:
		return

	if use_camera_offset and target is Camera2D:
		(target as Camera2D).offset = _base_position
	else:
		target.position = _base_position

	if apply_rotation:
		target.rotation = _base_rotation
