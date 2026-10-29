class_name NucleusWorldStamp3D
extends RefCounted
## Runtime world-space mark stored by NucleusWorldStampBuffer3D.
##
## Stamps are presentation data. They never participate in collision, physics,
## persistence, or authoritative gameplay state.

var world_position: Vector3 = Vector3.ZERO
var dimensions: Vector2 = Vector2.ONE
var rotation: float = 0.0
var strength: float = 1.0
var lifetime: float = 1.0
var born_time: float = 0.0
var drift: Vector3 = Vector3.ZERO
var growth: Vector2 = Vector2.ZERO
var metadata: Dictionary = {}


func _init(
	position: Vector3 = Vector3.ZERO,
	stamp_dimensions: Vector2 = Vector2.ONE,
	stamp_rotation: float = 0.0,
	stamp_strength: float = 1.0,
	stamp_lifetime: float = 1.0,
	stamp_born_time: float = 0.0,
	stamp_drift: Vector3 = Vector3.ZERO,
	stamp_growth: Vector2 = Vector2.ZERO,
	stamp_metadata: Dictionary = {},
) -> void:
	world_position = position
	dimensions = Vector2(
		maxf(absf(stamp_dimensions.x), 0.001),
		maxf(absf(stamp_dimensions.y), 0.001),
	)
	rotation = stamp_rotation
	strength = clampf(stamp_strength, 0.0, 1.0)
	lifetime = maxf(stamp_lifetime, 0.001)
	born_time = maxf(stamp_born_time, 0.0)
	drift = stamp_drift
	growth = Vector2(
		maxf(stamp_growth.x, -0.99),
		maxf(stamp_growth.y, -0.99),
	)
	metadata = stamp_metadata.duplicate(true)


func get_age(at_time: float) -> float:
	return maxf(at_time - born_time, 0.0)


func get_normalized_age(at_time: float) -> float:
	return clampf(get_age(at_time) / lifetime, 0.0, 1.0)


func is_alive(at_time: float) -> bool:
	return at_time >= born_time and at_time - born_time < lifetime


func get_world_position(at_time: float) -> Vector3:
	return world_position + drift * get_age(at_time)


func get_dimensions(at_time: float) -> Vector2:
	var t := get_normalized_age(at_time)
	return dimensions * Vector2(
		maxf(0.001, 1.0 + growth.x * t),
		maxf(0.001, 1.0 + growth.y * t),
	)
