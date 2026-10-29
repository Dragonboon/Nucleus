@tool
class_name NucleusGpuParticlesFxBinding3D
extends Node
## Adapter from NucleusLocalFxVolume3D to one native GPUParticles3D.
##
## The binding owns amount, amount_ratio, and emitting on the assigned particle
## system. Emission shape, shader/material content, lifetime, and bounds stay native.

@export var volume: NucleusLocalFxVolume3D
@export var particles: GPUParticles3D

@export_group("Capacity")
@export var apply_quality_capacity: bool = true
@export_range(0, 1000000, 1, "or_greater")
var base_amount_override: int = 0

@export_group("Emission")
@export_range(0.0, 1.0, 0.001)
var emission_threshold: float = 0.005

var _base_amount: int = 1
var _base_amount_captured: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_resolve_dependencies()
	_connect_volume()

	var error := apply_now()

	if error != OK:
		NucleusLog.error(
			"%s could not bind localized FX particles: %s"
			% [get_path(), error_string(error)],
			&"LocalFx",
		)


func _exit_tree() -> void:
	_disconnect_volume()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var resolved_volume := volume

	if resolved_volume == null:
		resolved_volume = _find_volume_ancestor()

	if resolved_volume == null:
		warnings.append(
			"Assign volume or place this binding below a NucleusLocalFxVolume3D."
		)

	var resolved_particles := particles

	if resolved_particles == null and get_parent() is GPUParticles3D:
		resolved_particles = get_parent() as GPUParticles3D

	if resolved_particles == null:
		warnings.append(
			"Assign particles or make this binding a child of GPUParticles3D."
		)
	elif resolved_particles.one_shot:
		warnings.append(
			"Localized continuous FX normally require GPUParticles3D.one_shot = false."
		)

	return warnings


func apply_now() -> Error:
	if volume == null or particles == null:
		return ERR_UNCONFIGURED

	_capture_base_amount()

	var capacity_scale := (
		volume.get_particle_capacity_scale()
		if apply_quality_capacity
		else 1.0
	)
	var quality_enabled := capacity_scale > 0.0

	particles.amount = (
		maxi(1, int(round(float(_base_amount) * capacity_scale)))
		if quality_enabled
		else 1
	)

	var current_intensity := volume.get_current_intensity()
	particles.amount_ratio = current_intensity
	particles.emitting = (
		quality_enabled
		and current_intensity > emission_threshold
	)

	return OK


func _capture_base_amount() -> void:
	if _base_amount_captured:
		return

	_base_amount = (
		base_amount_override
		if base_amount_override > 0
		else maxi(particles.amount, 1)
	)
	_base_amount_captured = true


func _resolve_dependencies() -> void:
	if particles == null and get_parent() is GPUParticles3D:
		particles = get_parent() as GPUParticles3D

	if volume == null:
		volume = _find_volume_ancestor()


func _find_volume_ancestor() -> NucleusLocalFxVolume3D:
	var current := get_parent()

	while current != null:
		if current is NucleusLocalFxVolume3D:
			return current as NucleusLocalFxVolume3D

		current = current.get_parent()

	return null


func _connect_volume() -> void:
	if volume == null:
		return

	if not volume.intensity_changed.is_connected(_on_volume_intensity_changed):
		volume.intensity_changed.connect(_on_volume_intensity_changed)

	if not volume.quality_changed.is_connected(_on_volume_quality_changed):
		volume.quality_changed.connect(_on_volume_quality_changed)


func _disconnect_volume() -> void:
	if volume == null or not is_instance_valid(volume):
		return

	if volume.intensity_changed.is_connected(_on_volume_intensity_changed):
		volume.intensity_changed.disconnect(_on_volume_intensity_changed)

	if volume.quality_changed.is_connected(_on_volume_quality_changed):
		volume.quality_changed.disconnect(_on_volume_quality_changed)


func _on_volume_intensity_changed(
	_current_intensity: float,
) -> void:
	apply_now()


func _on_volume_quality_changed(
	_quality: int,
) -> void:
	apply_now()
