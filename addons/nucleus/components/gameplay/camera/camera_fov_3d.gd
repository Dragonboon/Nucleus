class_name NucleusCameraFov3D
extends Node
## Smooth target-FOV controller for a Camera3D.
##
## Primary systems drive target_fov. Additive temporary systems use source-owned
## offsets so sprint/aim/game-feel requests cannot overwrite one another.

signal target_fov_changed(fov: float)
signal effective_fov_changed(fov: float)
signal fov_settled(fov: float)

@export var camera: Camera3D
@export_range(1.0, 179.0, 0.1)
var base_fov: float = 75.0
@export_range(0.0, 1000.0, 0.01, "or_greater")
var response: float = 8.0
@export var apply_base_fov_on_ready: bool = true

var target_fov: float = 75.0

var _offset_sources: Dictionary[StringName, float] = {}
var _last_effective_fov: float = -1.0


func _ready() -> void:
	if camera == null:
		camera = get_parent() as Camera3D

	if camera == null:
		NucleusLog.error(
			"%s requires a Camera3D." % get_path(),
			&"CameraFov3D",
		)
		set_process(false)
		return

	target_fov = clampf(
		base_fov,
		1.0,
		179.0,
	)
	_last_effective_fov = get_effective_target_fov()

	if apply_base_fov_on_ready:
		camera.fov = _last_effective_fov


func _process(delta: float) -> void:
	if camera == null:
		return

	var effective: float = get_effective_target_fov()

	if not is_equal_approx(effective, _last_effective_fov):
		_last_effective_fov = effective
		effective_fov_changed.emit(effective)

	if is_equal_approx(camera.fov, effective):
		return

	var weight: float = NucleusMotionMath.exponential_weight(
		response,
		delta,
	)
	camera.fov = lerpf(
		camera.fov,
		effective,
		weight,
	)

	if absf(camera.fov - effective) <= 0.01:
		camera.fov = effective
		fov_settled.emit(camera.fov)


func set_target_fov(
	fov: float,
	instant: bool = false,
) -> void:
	target_fov = clampf(
		fov,
		1.0,
		179.0,
	)

	if instant and camera:
		camera.fov = get_effective_target_fov()
		fov_settled.emit(camera.fov)

	target_fov_changed.emit(target_fov)


func reset_fov(instant: bool = false) -> void:
	set_target_fov(
		base_fov,
		instant,
	)


func set_fov_offset(
	source_id: StringName,
	offset_degrees: float,
) -> Error:
	if source_id == &"":
		return ERR_INVALID_PARAMETER

	_offset_sources[source_id] = offset_degrees
	return OK


func remove_fov_offset(source_id: StringName) -> bool:
	return _offset_sources.erase(source_id)


func clear_fov_offsets() -> void:
	_offset_sources.clear()


func get_effective_target_fov() -> float:
	var offset: float = 0.0

	for value: float in _offset_sources.values():
		offset += value

	return clampf(
		target_fov + offset,
		1.0,
		179.0,
	)
