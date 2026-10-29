class_name NucleusSurfaceQuery3D
extends RefCounted
## Runtime collision context supplied to 3D surface sources.

var collider: Object
var world_position: Vector3 = Vector3.ZERO
var surface_normal: Vector3 = Vector3.ZERO
var shape_index: int = -1
var face_index: int = -1
var metadata: Dictionary = {}


func _init(
	query_collider: Object = null,
	query_world_position: Vector3 = Vector3.ZERO,
	query_surface_normal: Vector3 = Vector3.ZERO,
	query_shape_index: int = -1,
	query_face_index: int = -1,
	query_metadata: Dictionary = {},
) -> void:
	collider = query_collider
	world_position = query_world_position
	surface_normal = query_surface_normal
	shape_index = query_shape_index
	face_index = query_face_index
	metadata = query_metadata.duplicate(true)


func is_valid() -> bool:
	return collider != null and is_instance_valid(collider)


func get_collider_node() -> Node:
	if collider is Node:
		return collider as Node

	return null
