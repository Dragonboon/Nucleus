class_name NucleusMovementFacing3D
extends Node
## Smoothly faces a unit-scale visual pivot toward movement, target, or direction.
##
## Use a dedicated Node3D pivot above imported/scaled art. This keeps model
## import transforms out of locomotion code.

enum Mode {
	MOVEMENT,
	TARGET,
	DIRECTION,
}

@export var target: Node3D
@export var motor: NucleusCharacterMotor3D

@export_group("Facing source")
@export var mode: Mode = Mode.MOVEMENT:
	set(value):
		mode = value
		_refresh_processing()

@export var facing_target: Node3D
@export var facing_direction: Vector3 = Vector3.FORWARD

@export_group("Response")
@export_range(0.0, 1000.0, 0.01, "or_greater")
var rotation_response: float = 12.0
@export var use_model_front: bool = false
@export var enabled: bool = true:
	set(value):
		enabled = value
		_refresh_processing()


func _ready() -> void:
	_resolve_dependencies()

	if motor:
		motor.movement_updated.connect(
			_on_movement_updated
		)

	_refresh_processing()


func _exit_tree() -> void:
	if (
		motor
		and motor.movement_updated.is_connected(
			_on_movement_updated
		)
	):
		motor.movement_updated.disconnect(
			_on_movement_updated
		)


func _physics_process(delta: float) -> void:
	if not enabled or mode == Mode.MOVEMENT:
		return

	_apply_direction(
		get_desired_facing_direction(),
		delta,
	)


func set_mode(value: Mode) -> void:
	mode = value


func set_facing_target(
	node: Node3D,
	switch_mode: bool = true,
) -> void:
	facing_target = node

	if switch_mode:
		mode = Mode.TARGET


func set_facing_direction(
	direction: Vector3,
	switch_mode: bool = true,
) -> void:
	facing_direction = direction

	if switch_mode:
		mode = Mode.DIRECTION


func get_desired_facing_direction() -> Vector3:
	if motor == null or motor.body == null:
		return Vector3.ZERO

	var direction := Vector3.ZERO

	match mode:
		Mode.MOVEMENT:
			direction = motor.desired_direction

		Mode.TARGET:
			if (
				facing_target != null
				and is_instance_valid(facing_target)
			):
				direction = (
					facing_target.global_position
					- motor.body.global_position
				)

		Mode.DIRECTION:
			direction = facing_direction

	direction = NucleusMotionMath.planar_component_3d(
		direction,
		motor.body.up_direction,
	)

	return (
		direction.normalized()
		if not direction.is_zero_approx()
		else Vector3.ZERO
	)


func _on_movement_updated(
	direction: Vector3,
	_velocity: Vector3,
) -> void:
	if mode != Mode.MOVEMENT:
		return

	_apply_direction(
		direction,
		get_physics_process_delta_time(),
	)


func _apply_direction(
	direction: Vector3,
	delta: float,
) -> void:
	if (
		not enabled
		or target == null
		or motor == null
		or motor.body == null
		or direction.is_zero_approx()
	):
		return

	var up: Vector3 = motor.body.up_direction.normalized()

	if up.is_zero_approx():
		up = Vector3.UP

	var target_scale: Vector3 = target.global_basis.get_scale()
	var desired_basis: Basis = Basis.looking_at(
		direction,
		up,
		use_model_front,
	)
	var current_basis: Basis = target.global_basis.orthonormalized()
	var weight: float = NucleusMotionMath.exponential_weight(
		rotation_response,
		delta,
	)
	var rotated_basis: Basis = current_basis.slerp(
		desired_basis,
		weight,
	)

	target.global_basis = rotated_basis.scaled(target_scale)


func _refresh_processing() -> void:
	if not is_inside_tree():
		return

	set_physics_process(
		enabled and mode != Mode.MOVEMENT
	)


func _resolve_dependencies() -> void:
	if motor == null:
		var parent: Node = get_parent()

		if parent:
			for node: Node in NucleusNodeUtils.descendants(parent):
				if node is NucleusCharacterMotor3D:
					motor = node as NucleusCharacterMotor3D
					break

	if motor == null:
		NucleusLog.error(
			"%s requires a NucleusCharacterMotor3D." % get_path(),
			&"MovementFacing3D",
		)

	if target == null:
		NucleusLog.error(
			"%s requires a Node3D target." % get_path(),
			&"MovementFacing3D",
		)
