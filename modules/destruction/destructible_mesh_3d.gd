@tool
class_name NucleusDestructibleMesh3D
extends Node
## Replaces an intact visual with authored physical fragments on an admitted impact.

signal fractured(fragments: Array[RigidBody3D])
signal fracture_rejected(reason: StringName)
signal restored

@export var source_body: PhysicsBody3D
@export var source_mesh: MeshInstance3D
@export var fragment_parent: Node3D
@export var pattern: NucleusFracturePattern3D
@export var profile: NucleusFractureProfile3D

var is_broken: bool = false
var _fragments: Array[RigidBody3D] = []
var _layer: int = 0
var _mask: int = 0
var _was_visible: bool = true


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if source_body == null:
		source_body = get_parent() as PhysicsBody3D
	if source_body != null:
		_layer = source_body.collision_layer
		_mask = source_body.collision_mask
	if source_mesh != null:
		_was_visible = source_mesh.visible


func _exit_tree() -> void:
	_clear_fragments()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if source_body == null and not get_parent() is PhysicsBody3D:
		warnings.append("Assign a physics body or parent this node under one.")
	if source_mesh == null:
		warnings.append("Assign the intact MeshInstance3D.")
	if pattern == null or not pattern.is_usable():
		warnings.append("Assign at least two valid prefractured shards.")
	return warnings


func fracture(hit_position: Vector3, impulse: Vector3) -> bool:
	if is_broken:
		return _reject(&"already_broken")
	if not is_inside_tree() or not hit_position.is_finite() or not impulse.is_finite():
		return _reject(&"invalid_impact")
	if not is_instance_valid(source_body) or not is_instance_valid(source_mesh):
		return _reject(&"missing_source")
	if pattern == null or not pattern.is_usable():
		return _reject(&"invalid_pattern")
	var policy := profile if profile != null else NucleusFractureProfile3D.new()
	if impulse.length() < policy.impulse_threshold:
		return _reject(&"below_threshold")
	if pattern.shards.size() > policy.max_fragments:
		return _reject(&"fragment_budget")
	var root: Node3D = fragment_parent
	if root == null:
		root = source_body.get_parent() as Node3D
	if root == null or not root.is_inside_tree():
		return _reject(&"missing_parent")

	var shapes: Array[Shape3D] = []
	for shard: NucleusFractureShard3D in pattern.shards:
		if not shard.local_transform.is_finite():
			return _reject(&"invalid_transform")
		var shape: Shape3D = shard.collision_shape
		if shape == null:
			shape = shard.mesh.create_convex_shape()
		if shape == null:
			return _reject(&"invalid_collision")
		shapes.append(shape)

	var basis_transform: Transform3D = source_mesh.global_transform
	var inherited_velocity := Vector3.ZERO
	if source_body is RigidBody3D:
		inherited_velocity = (source_body as RigidBody3D).linear_velocity
	for i in range(pattern.shards.size()):
		var shard: NucleusFractureShard3D = pattern.shards[i]
		var rigid := RigidBody3D.new()
		rigid.mass = shard.mass
		rigid.collision_layer = _layer
		rigid.collision_mask = _mask
		var visual := MeshInstance3D.new()
		visual.mesh = shard.mesh
		var collider := CollisionShape3D.new()
		collider.shape = shapes[i]
		rigid.add_child(visual)
		rigid.add_child(collider)
		root.add_child(rigid)
		rigid.global_transform = basis_transform * shard.local_transform
		rigid.linear_velocity = inherited_velocity
		rigid.apply_central_impulse(impulse * maxf(0.0, policy.impulse_scale))
		_fragments.append(rigid)
		if policy.fragment_lifetime > 0.0:
			_schedule_cleanup(rigid, policy.fragment_lifetime)
	is_broken = true
	source_mesh.hide()
	source_body.set_deferred("collision_layer", 0)
	source_body.set_deferred("collision_mask", 0)
	fractured.emit(_fragments.duplicate())
	return true


func restore() -> void:
	_clear_fragments()
	if not is_broken:
		return
	is_broken = false
	if is_instance_valid(source_mesh):
		source_mesh.visible = _was_visible
	if is_instance_valid(source_body):
		source_body.set_deferred("collision_layer", _layer)
		source_body.set_deferred("collision_mask", _mask)
	restored.emit()


func get_fragments() -> Array[RigidBody3D]:
	var result: Array[RigidBody3D] = []
	for rigid: RigidBody3D in _fragments:
		if is_instance_valid(rigid) and not rigid.is_queued_for_deletion():
			result.append(rigid)
	return result


func _schedule_cleanup(rigid: RigidBody3D, seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(rigid):
			rigid.queue_free()
	)


func _clear_fragments() -> void:
	for rigid: RigidBody3D in _fragments:
		if is_instance_valid(rigid):
			rigid.queue_free()
	_fragments.clear()


func _reject(reason: StringName) -> bool:
	fracture_rejected.emit(reason)
	return false
