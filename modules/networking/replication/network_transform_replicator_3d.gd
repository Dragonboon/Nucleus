@tool
class_name NucleusNetworkTransformReplicator3D
extends Node
## Server/authority transform snapshots with remote interpolation.
##
## Do not synchronize the same transform through MultiplayerSynchronizer at the
## same time.
## Example: assign the remote visual root to target and leave the authority's
## motor in charge of physics. Teleports pass the same validation as normal updates.

@export var target: Node3D:
	set(value):
		target = value
		update_configuration_warnings()

@export_group("Snapshots")
@export_range(0.0, 10.0, 0.001, "or_greater")
var snapshot_interval: float = 0.05
@export_range(0.0, 2.0, 0.001, "or_greater")
var interpolation_delay: float = 0.10
@export_range(0.0, 1000000.0, 0.01, "or_greater")
var teleport_distance: float = 8.0
@export var synchronize_rotation: bool = true

@export_group("Behavior")
@export var active: bool = true:
	set(value):
		active = value

		if is_node_ready() and not Engine.is_editor_hint():
			set_physics_process(active)

var _sequence: int = 0
var _elapsed: float = 0.0
var _buffer := NucleusTransformSnapshotBuffer3D.new()


func _ready() -> void:
	if target == null:
		target = get_parent() as Node3D

	if Engine.is_editor_hint():
		set_physics_process(false)
		return

	set_physics_process(active)


func _physics_process(delta: float) -> void:
	if not active or target == null:
		return

	if is_multiplayer_authority():
		_process_authority(delta)
	else:
		_process_remote()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var resolved: Node3D = (
		target
		if target != null
		else get_parent() as Node3D
	)

	if resolved == null:
		warnings.append(
			"Assign a Node3D target or parent the replicator under one."
		)

	return warnings


func clear_remote_buffer() -> void:
	_buffer.clear()


func _process_authority(delta: float) -> void:
	if multiplayer.get_peers().is_empty():
		return

	_elapsed += delta

	if (
		snapshot_interval > 0.0
		and _elapsed < snapshot_interval
	):
		return

	_elapsed = 0.0
	_sequence += 1

	_receive_snapshot.rpc(
		_sequence,
		target.global_position,
		target.global_basis.get_rotation_quaternion(),
	)


func _process_remote() -> void:
	var now: float = float(
		Time.get_ticks_usec()
	) / 1000000.0
	var state: Dictionary = _buffer.sample(
		now - interpolation_delay
	)

	if state.is_empty():
		return

	_apply_state(state)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _receive_snapshot(
	sequence: int,
	position: Vector3,
	rotation: Quaternion,
) -> void:
	if target == null or is_multiplayer_authority():
		return

	var now: float = float(
		Time.get_ticks_usec()
	) / 1000000.0
	if not _buffer.push(sequence, now, position, rotation):
		return

	if (
		teleport_distance > 0.0
		and target.global_position.distance_to(position)
		> teleport_distance
	):
		_buffer.clear()
		_buffer.push(
			sequence,
			now,
			position,
			rotation,
		)
		_apply_state(
			{
				"position": position,
				"rotation": rotation,
			}
		)
		return


func _apply_state(state: Dictionary) -> void:
	var position: Vector3 = state["position"]
	var rotation: Quaternion = state["rotation"]

	if not synchronize_rotation:
		target.global_position = position
		return

	var scale: Vector3 = target.global_basis.get_scale()
	target.global_transform = Transform3D(
		Basis(rotation).scaled(scale),
		position,
	)
