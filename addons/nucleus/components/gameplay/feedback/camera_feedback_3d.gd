class_name NucleusCameraFeedback3D
extends Node
## Additive transform/FOV mixer for a dedicated Node3D feedback pivot.
##
## Transform ownership remains local to the pivot. FOV is delegated to the
## existing NucleusCameraFov3D through one source-owned additive offset.

signal impulse_started(profile: NucleusCameraImpulseProfile3D)
signal impulse_finished(profile: NucleusCameraImpulseProfile3D)

@export var target: Node3D
@export var fov_controller: NucleusCameraFov3D
@export var enabled: bool = true

var _base_position: Vector3
var _base_rotation: Vector3

var _impulses: Array[Dictionary] = []
var _offset_sources: Dictionary[StringName, Dictionary] = {}
var _fov_source_id: StringName


func _ready() -> void:
	if target == null:
		target = get_parent() as Node3D

	if target == null:
		NucleusLog.error(
			"%s requires a dedicated Node3D target." % get_path(),
			&"CameraFeedback3D",
		)
		set_process(false)
		return

	_fov_source_id = StringName(
		"camera_feedback:%s" % get_instance_id()
	)
	recapture_baseline()


func _exit_tree() -> void:
	_restore_baseline()

	if fov_controller:
		fov_controller.remove_fov_offset(
			_fov_source_id
		)


func _process(delta: float) -> void:
	if target == null:
		return

	if not enabled:
		_restore_baseline()
		_apply_fov(0.0)
		return

	_update_impulses(delta)

	var position_offset := Vector3.ZERO
	var rotation_offset := Vector3.ZERO
	var fov_offset: float = 0.0

	for source: Dictionary in _offset_sources.values():
		var scale: float = NucleusMotionPolicy.get_motion_scale(
			bool(source["respect_reduced_motion"]),
			float(source["reduced_motion_scale"]),
		)
		position_offset += source["position"] * scale
		rotation_offset += source["rotation"] * scale
		fov_offset += float(source["fov"]) * scale

	for impulse: Dictionary in _impulses:
		var sample: Dictionary = _sample_impulse(impulse)
		position_offset += sample["position"]
		rotation_offset += sample["rotation"]
		fov_offset += float(sample["fov"])

	target.position = _base_position + position_offset
	target.rotation = _base_rotation + rotation_offset
	_apply_fov(fov_offset)


func play_impulse(
	profile: NucleusCameraImpulseProfile3D,
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
	position: Vector3,
	rotation_radians: Vector3 = Vector3.ZERO,
	fov_degrees: float = 0.0,
	respect_reduced_motion: bool = true,
	reduced_motion_scale: float = 0.20,
) -> Error:
	if source_id == &"":
		return ERR_INVALID_PARAMETER

	_offset_sources[source_id] = {
		"position": position,
		"rotation": rotation_radians,
		"fov": fov_degrees,
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
	_apply_fov(0.0)


func recapture_baseline() -> void:
	if target == null:
		return

	_base_position = target.position
	_base_rotation = target.rotation


func _update_impulses(delta: float) -> void:
	for index: int in range(
		_impulses.size() - 1,
		-1,
		-1,
	):
		var impulse: Dictionary = _impulses[index]
		impulse["elapsed"] = float(impulse["elapsed"]) + delta
		var profile := impulse["profile"] as NucleusCameraImpulseProfile3D

		if float(impulse["elapsed"]) < profile.duration:
			_impulses[index] = impulse
			continue

		_impulses.remove_at(index)
		impulse_finished.emit(profile)


func _sample_impulse(impulse: Dictionary) -> Dictionary:
	var profile := impulse["profile"] as NucleusCameraImpulseProfile3D
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
			+ Vector3(
				noise.get_noise_1d(time),
				noise.get_noise_1d(time + 31.7),
				noise.get_noise_1d(time + 67.1),
			) * profile.position_amplitude
		) * scale,
		"rotation": (
			Vector3(
				deg_to_rad(profile.rotation_kick_degrees.x),
				deg_to_rad(profile.rotation_kick_degrees.y),
				deg_to_rad(profile.rotation_kick_degrees.z),
			)
			+ Vector3(
				noise.get_noise_1d(time + 97.3),
				noise.get_noise_1d(time + 131.9),
				noise.get_noise_1d(time + 173.3),
			) * Vector3(
				deg_to_rad(profile.rotation_degrees.x),
				deg_to_rad(profile.rotation_degrees.y),
				deg_to_rad(profile.rotation_degrees.z),
			)
		) * scale,
		"fov": (
			profile.fov_kick_degrees
			+ (
				profile.fov_noise_degrees
				* noise.get_noise_1d(time + 211.1)
			)
		) * scale,
	}


func _apply_fov(offset: float) -> void:
	if fov_controller:
		fov_controller.set_fov_offset(
			_fov_source_id,
			offset,
		)


func _restore_baseline() -> void:
	if target:
		target.position = _base_position
		target.rotation = _base_rotation
