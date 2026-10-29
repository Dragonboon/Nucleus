class_name NucleusSurfaceSample3D
extends RefCounted
## One spatial sample returned by a NucleusSurfaceSampler3D.
##
## The sample describes where a surface is, how it is oriented, and how it is
## moving at the queried X/Z position. It does not describe material semantics,
## fluid density, collision, or gameplay response.

var position: Vector3 = Vector3.ZERO
var normal: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var sampled_time: float = -1.0
var metadata: Dictionary = {}


func _init(
	surface_position: Vector3 = Vector3.ZERO,
	surface_normal: Vector3 = Vector3.ZERO,
	surface_velocity: Vector3 = Vector3.ZERO,
	at_time: float = -1.0,
	sample_metadata: Dictionary = {},
) -> void:
	set_values(
		surface_position,
		surface_normal,
		surface_velocity,
		at_time,
		sample_metadata,
	)


func set_values(
	surface_position: Vector3,
	surface_normal: Vector3,
	surface_velocity: Vector3 = Vector3.ZERO,
	at_time: float = -1.0,
	sample_metadata: Dictionary = {},
) -> void:
	position = surface_position
	normal = (
		surface_normal.normalized()
		if not surface_normal.is_zero_approx()
		else Vector3.ZERO
	)
	velocity = surface_velocity
	sampled_time = at_time
	metadata = sample_metadata.duplicate(true)


func clear() -> void:
	position = Vector3.ZERO
	normal = Vector3.ZERO
	velocity = Vector3.ZERO
	sampled_time = -1.0
	metadata.clear()


func is_valid() -> bool:
	return (
		_vector_is_finite(position)
		and _vector_is_finite(normal)
		and not normal.is_zero_approx()
		and _vector_is_finite(velocity)
		and is_finite(sampled_time)
	)


func get_height() -> float:
	return position.y


func get_vertical_delta(query_position: Vector3) -> float:
	return position.y - query_position.y


static func _vector_is_finite(value: Vector3) -> bool:
	return (
		is_finite(value.x)
		and is_finite(value.y)
		and is_finite(value.z)
	)
