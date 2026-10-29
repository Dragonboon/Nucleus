@tool
class_name NucleusRagdollController3D
extends Node
## Small lifecycle wrapper around Godot's PhysicalBoneSimulator3D.
##
## Godot remains responsible for physical bones, joints, collisions, Skeleton3D,
## and simulation. This component coordinates full/partial ragdoll transitions,
## optional AnimationTree ownership, and reusable collision exceptions.

signal ragdoll_started(
	full_body: bool,
	bones: Array[StringName],
)
signal ragdoll_stopped

@export var simulator: PhysicalBoneSimulator3D:
	set(value):
		simulator = value
		update_configuration_warnings()

		if is_inside_tree() and not Engine.is_editor_hint():
			sync_collision_exceptions()

@export var animation_tree: AnimationTree:
	set(value):
		animation_tree = value
		update_configuration_warnings()

@export_group("Full body")
@export var disable_animation_tree_on_full_ragdoll: bool = true

@export_group("Partial ragdoll")
@export var default_partial_bones: Array[StringName] = []

@export_group("Physics integration")
## Physics bodies that should not collide with generated physical bones.
## A common entry is the character's authoritative CharacterBody3D.
@export var collision_exceptions: Array[PhysicsBody3D] = []

var _disabled_animation_tree: bool = false
var _animation_tree_was_active: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_resolve_dependencies()
	sync_collision_exceptions()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()

	if simulator == null:
		warnings.append(
			"Assign a PhysicalBoneSimulator3D or place one near this component."
		)
		return warnings

	if not simulator.get_parent() is Skeleton3D:
		warnings.append(
			"PhysicalBoneSimulator3D should be a direct child of Skeleton3D."
		)

	if not _has_physical_bones():
		warnings.append(
			"PhysicalBoneSimulator3D has no PhysicalBone3D children."
		)

	for exception_body: PhysicsBody3D in collision_exceptions:
		if exception_body == null:
			warnings.append(
				"collision_exceptions contains an empty PhysicsBody3D entry."
			)
			break

	return warnings


func start_full_ragdoll() -> Error:
	var prepare_error: Error = _prepare_start()

	if prepare_error != OK:
		return prepare_error

	_capture_and_disable_animation_tree()
	simulator.physical_bones_start_simulation()
	var simulated_bones: Array[StringName] = []
	ragdoll_started.emit(true, simulated_bones)
	return OK


func start_partial_ragdoll(
	bones: Array[StringName] = [],
) -> Error:
	var requested_bones: Array[StringName] = []

	if bones.is_empty():
		requested_bones.assign(default_partial_bones)
	else:
		requested_bones.assign(bones)

	if requested_bones.is_empty():
		return ERR_INVALID_PARAMETER

	var prepare_error: Error = _prepare_start()

	if prepare_error != OK:
		return prepare_error

	var validation_error: Error = _validate_bones(
		requested_bones
	)

	if validation_error != OK:
		return validation_error

	simulator.physical_bones_start_simulation(requested_bones)
	ragdoll_started.emit(false, requested_bones)
	return OK


func stop_ragdoll() -> void:
	if simulator != null:
		simulator.physical_bones_stop_simulation()

	_restore_animation_tree()
	ragdoll_stopped.emit()


func is_ragdolling() -> bool:
	return (
		simulator != null
		and simulator.is_simulating_physics()
	)


func set_ragdoll_influence(value: float) -> void:
	if simulator == null:
		return

	simulator.influence = clampf(value, 0.0, 1.0)


func get_ragdoll_influence() -> float:
	if simulator == null:
		return 0.0

	return simulator.influence


func add_collision_exception(
	body: PhysicsBody3D,
) -> Error:
	if body == null:
		return ERR_INVALID_PARAMETER

	if not collision_exceptions.has(body):
		collision_exceptions.append(body)

	if simulator == null:
		_resolve_dependencies()

	if simulator == null:
		return ERR_UNCONFIGURED

	simulator.physical_bones_add_collision_exception(
		body.get_rid()
	)
	return OK


func remove_collision_exception(
	body: PhysicsBody3D,
) -> Error:
	if body == null:
		return ERR_INVALID_PARAMETER

	collision_exceptions.erase(body)

	if simulator == null:
		return ERR_UNCONFIGURED

	simulator.physical_bones_remove_collision_exception(
		body.get_rid()
	)
	return OK


func sync_collision_exceptions() -> Error:
	if simulator == null:
		return ERR_UNCONFIGURED

	for exception_body: PhysicsBody3D in collision_exceptions:
		if exception_body == null:
			continue

		simulator.physical_bones_add_collision_exception(
			exception_body.get_rid()
		)

	return OK


func _prepare_start() -> Error:
	if simulator == null:
		_resolve_dependencies()

	if simulator == null or not _has_physical_bones():
		return ERR_UNCONFIGURED

	sync_collision_exceptions()

	if simulator.is_simulating_physics():
		simulator.physical_bones_stop_simulation()

	_restore_animation_tree()
	simulator.active = true
	return OK


func _validate_bones(
	bones: Array[StringName],
) -> Error:
	var skeleton: Skeleton3D = simulator.get_skeleton()

	if skeleton == null:
		return ERR_UNCONFIGURED

	for bone_name: StringName in bones:
		if (
			bone_name == &""
			or skeleton.find_bone(String(bone_name)) < 0
		):
			return ERR_INVALID_PARAMETER

	return OK


func _capture_and_disable_animation_tree() -> void:
	if (
		animation_tree == null
		or not disable_animation_tree_on_full_ragdoll
	):
		return

	_animation_tree_was_active = animation_tree.active
	_disabled_animation_tree = true
	animation_tree.active = false


func _restore_animation_tree() -> void:
	if not _disabled_animation_tree:
		return

	if animation_tree != null:
		animation_tree.active = _animation_tree_was_active

	_disabled_animation_tree = false


func _has_physical_bones() -> bool:
	if simulator == null:
		return false

	for child: Node in simulator.get_children():
		if child is PhysicalBone3D:
			return true

	return false


func _resolve_dependencies() -> void:
	var current_root: Node = get_parent()

	while (
		current_root != null
		and (simulator == null or animation_tree == null)
	):
		if (
			simulator == null
			and current_root is PhysicalBoneSimulator3D
		):
			simulator = current_root as PhysicalBoneSimulator3D

		if animation_tree == null and current_root is AnimationTree:
			animation_tree = current_root as AnimationTree

		for node: Node in NucleusNodeUtils.descendants(
			current_root
		):
			if (
				simulator == null
				and node is PhysicalBoneSimulator3D
			):
				simulator = node as PhysicalBoneSimulator3D

			if animation_tree == null and node is AnimationTree:
				animation_tree = node as AnimationTree

		current_root = current_root.get_parent()
