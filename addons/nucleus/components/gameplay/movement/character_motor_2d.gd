@tool
class_name NucleusCharacterMotor2D
extends Node
## Single CharacterBody2D movement owner for player, AI, and scripted intent.
##
## Uses native CharacterBody2D.motion_mode to select the physics contract:
## GROUNDED controls tangent motion and preserves the gravity-axis velocity;
## FLOATING controls the full 2D velocity. The game owns jump rules, abilities,
## animation, combat and content. Do not run another motor on the same body.
## Example: a MotionSource2D requests world velocity; grounded mode discards its
## up-axis component before speed limiting, so off-plane intent cannot slow a walk.

signal movement_updated(desired_velocity: Vector2, actual_velocity: Vector2)

@export var body: CharacterBody2D:
	set(value):
		body = value
		update_configuration_warnings()
@export var motion_input: NucleusMotionInput
@export var motion_source: NucleusMotionSource2D

@export_group("Movement")
@export_range(0.0, 100000.0, 0.1, "or_greater")
var speed: float = 240.0
@export_range(0.0, 100000.0, 0.1, "or_greater")
var acceleration: float = 1800.0
@export_range(0.0, 100000.0, 0.1, "or_greater")
var deceleration: float = 2200.0
@export_range(0.0, 100.0, 0.01, "or_greater")
var speed_multiplier: float = 1.0

@export_group("Grounded physics")
## Applied only for native MOTION_MODE_GROUNDED while airborne.
@export_range(0.0, 100.0, 0.01, "or_greater")
var gravity_scale: float = 1.0

@export_group("Behavior")
@export var enabled: bool = true

var desired_velocity: Vector2 = Vector2.ZERO
var _pending_impulse: Vector2 = Vector2.ZERO


func _ready() -> void:
	if body == null:
		body = get_parent() as CharacterBody2D
	if motion_input == null and body != null:
		for node: Node in NucleusNodeUtils.descendants(body):
			if node is NucleusMotionInput:
				motion_input = node as NucleusMotionInput
				break
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	if body == null:
		NucleusLog.error("CharacterMotor2D requires a CharacterBody2D.", &"CharacterMotor2D")
		set_physics_process(false)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null and not (get_parent() is CharacterBody2D):
		warnings.append("Assign a CharacterBody2D or parent under one.")
	if motion_input == null and motion_source == null:
		warnings.append("Assign MotionInput or MotionSource2D for active movement.")
	return warnings


func _physics_process(delta: float) -> void:
	if not enabled or body == null or not is_instance_valid(body):
		return

	desired_velocity = _read_desired_velocity()
	var dt: float = maxf(delta, 0.0)
	if body.motion_mode == CharacterBody2D.MOTION_MODE_GROUNDED:
		_integrate_grounded(dt)
	else:
		_integrate_floating(dt)

	# Impulses are applied after intent integration so they are not overwritten.
	body.velocity += _pending_impulse
	_pending_impulse = Vector2.ZERO
	body.move_and_slide()
	movement_updated.emit(desired_velocity, body.velocity)


func get_max_speed() -> float:
	return maxf(0.0, speed) * maxf(0.0, speed_multiplier)


func set_speed_multiplier(multiplier: float) -> void:
	speed_multiplier = maxf(0.0, multiplier)


## Queues a velocity delta for the next physics tick. The game decides the
## impulse direction and validity (jump, knockback, dash, etc.).
func request_velocity_impulse(velocity_delta: Vector2) -> Error:
	if not enabled or body == null or not is_instance_valid(body):
		return ERR_UNAVAILABLE
	if not velocity_delta.is_finite():
		return ERR_INVALID_PARAMETER
	_pending_impulse += velocity_delta
	return OK


func _read_desired_velocity() -> Vector2:
	var maximum: float = get_max_speed()
	var requested := Vector2.ZERO
	if motion_source != null and is_instance_valid(motion_source) and motion_source.enabled:
		requested = motion_source.get_desired_velocity(body, maximum)
	elif motion_input != null and is_instance_valid(motion_input):
		requested = motion_input.get_move_vector() * maximum
	if not requested.is_finite():
		return Vector2.ZERO
	if body.motion_mode == CharacterBody2D.MOTION_MODE_GROUNDED:
		var tangent: Vector2 = NucleusMotionMath.right_from_up_2d(body.up_direction)
		requested = tangent * requested.dot(tangent)
	return requested.limit_length(maximum)


func _integrate_floating(delta: float) -> void:
	var rate: float = (
		acceleration if not desired_velocity.is_zero_approx() else deceleration
	)
	body.velocity = body.velocity.move_toward(
		desired_velocity, maxf(rate, 0.0) * delta
	)


func _integrate_grounded(delta: float) -> void:
	var tangent: Vector2 = NucleusMotionMath.right_from_up_2d(body.up_direction)
	var current: float = body.velocity.dot(tangent)
	var target: float = desired_velocity.dot(tangent)
	var rate: float = acceleration if not is_zero_approx(target) else deceleration
	var next: float = move_toward(current, target, maxf(rate, 0.0) * delta)
	body.velocity += tangent * (next - current)
	if not body.is_on_floor():
		body.velocity += body.get_gravity() * maxf(gravity_scale, 0.0) * delta
