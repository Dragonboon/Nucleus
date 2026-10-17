class_name NucleusMovementFacing2D
extends Node
## Rotates a 2D visual pivot without changing CharacterBody2D physics rotation.
## The pivot's unrotated front is +X; front_angle_offset adapts artwork.

enum Mode { MOVEMENT, TARGET, DIRECTION }

@export var target: Node2D
@export var motor: NucleusCharacterMotor2D

@export_group("Facing source")
@export var mode: Mode = Mode.MOVEMENT:
	set(value):
		mode = value
		_refresh_processing()

@export var facing_target: Node2D
@export var facing_direction: Vector2 = Vector2.RIGHT

@export_group("Response")
@export_range(0.0, 1000.0, 0.01, "or_greater")
var rotation_response: float = 12.0
@export var front_angle_offset: float = 0.0
@export var enabled: bool = true:
	set(value):
		enabled = value
		_refresh_processing()


func _ready() -> void:
	_resolve_dependencies()
	if motor != null and not motor.movement_updated.is_connected(_on_movement_updated):
		motor.movement_updated.connect(_on_movement_updated)
	_refresh_processing()


func _exit_tree() -> void:
	if is_instance_valid(motor):
		if motor.movement_updated.is_connected(_on_movement_updated):
			motor.movement_updated.disconnect(_on_movement_updated)


func _physics_process(delta: float) -> void:
	if enabled and mode != Mode.MOVEMENT:
		_apply_direction(get_desired_facing_direction(), delta)


func set_mode(value: Mode) -> void:
	mode = value


func set_facing_target(node: Node2D, switch_mode: bool = true) -> void:
	facing_target = node
	if switch_mode:
		mode = Mode.TARGET


func set_facing_direction(direction: Vector2, switch_mode: bool = true) -> void:
	facing_direction = direction
	if switch_mode:
		mode = Mode.DIRECTION


func get_desired_facing_direction() -> Vector2:
	if motor == null or not is_instance_valid(motor.body):
		return Vector2.ZERO
	var direction: Vector2 = Vector2.ZERO
	match mode:
		Mode.MOVEMENT:
			direction = motor.desired_velocity
		Mode.TARGET:
			if is_instance_valid(facing_target):
				direction = (
					facing_target.global_position - motor.body.global_position
				)
		Mode.DIRECTION:
			direction = facing_direction
	return direction.normalized() if not direction.is_zero_approx() else Vector2.ZERO


func _on_movement_updated(
	desired_velocity: Vector2,
	_actual_velocity: Vector2,
) -> void:
	if mode == Mode.MOVEMENT:
		_apply_direction(desired_velocity, get_physics_process_delta_time())


func _apply_direction(direction: Vector2, delta: float) -> void:
	if (
		not enabled
		or not is_instance_valid(target)
		or direction.is_zero_approx()
	):
		return
	var desired_angle: float = direction.angle() + front_angle_offset
	var weight: float = NucleusMotionMath.exponential_weight(
		rotation_response, maxf(0.0, delta)
	)
	target.global_rotation = lerp_angle(
		target.global_rotation, desired_angle, weight
	)


func _refresh_processing() -> void:
	if is_inside_tree():
		set_physics_process(enabled and mode != Mode.MOVEMENT)


func _resolve_dependencies() -> void:
	if motor != null:
		return
	var root: Node = get_parent()
	if root == null:
		return
	for node: Node in NucleusNodeUtils.descendants(root):
		if node is NucleusCharacterMotor2D:
			motor = node as NucleusCharacterMotor2D
			break
