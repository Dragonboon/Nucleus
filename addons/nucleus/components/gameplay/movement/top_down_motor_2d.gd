class_name NucleusTopDownMotor2D
extends Node
## Accelerated top-down locomotion for an existing CharacterBody2D.
##
## The motor owns velocity integration and move_and_slide(). Visual facing,
## animation, abilities, and camera behavior remain separate Components.

signal movement_updated(
	input_direction: Vector2,
	velocity: Vector2,
)

@export var body: CharacterBody2D
@export var motion_input: NucleusMotionInput

@export_group("Speed")
@export_range(0.0, 100000.0, 1.0, "or_greater")
var speed: float = 240.0
@export_range(0.0, 100000.0, 1.0, "or_greater")
var acceleration: float = 1800.0
@export_range(0.0, 100000.0, 1.0, "or_greater")
var deceleration: float = 2200.0
@export_range(0.0, 100.0, 0.01, "or_greater")
var speed_multiplier: float = 1.0

@export_group("Behavior")
@export var enabled: bool = true
@export var configure_floating_motion_mode: bool = true

var desired_direction: Vector2 = Vector2.ZERO
var desired_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	_resolve_dependencies()

	if body and configure_floating_motion_mode:
		body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	if not enabled or body == null or motion_input == null:
		return

	var input_direction: Vector2 = motion_input.get_move_vector()
	desired_direction = input_direction.limit_length(1.0)
	desired_velocity = (
		desired_direction
		* speed
		* maxf(0.0, speed_multiplier)
	)

	var rate: float = (
		acceleration
		if not desired_direction.is_zero_approx()
		else deceleration
	)

	body.velocity = body.velocity.move_toward(
		desired_velocity,
		maxf(0.0, rate) * delta,
	)
	body.move_and_slide()

	movement_updated.emit(
		desired_direction,
		body.velocity,
	)


func stop(immediate: bool = false) -> void:
	desired_direction = Vector2.ZERO
	desired_velocity = Vector2.ZERO

	if body == null:
		return

	if immediate:
		body.velocity = Vector2.ZERO


func set_speed_multiplier(multiplier: float) -> void:
	speed_multiplier = maxf(0.0, multiplier)


func _resolve_dependencies() -> void:
	if body == null:
		body = get_parent() as CharacterBody2D

	if motion_input == null:
		motion_input = _find_motion_input()

	if body == null:
		NucleusLog.error(
			"%s requires a CharacterBody2D." % get_path(),
			&"TopDownMotor2D",
		)

	if motion_input == null:
		NucleusLog.error(
			"%s requires a NucleusMotionInput." % get_path(),
			&"TopDownMotor2D",
		)


func _find_motion_input() -> NucleusMotionInput:
	var root: Node = body if body else get_parent()

	if root == null:
		return null

	for node: Node in NucleusNodeUtils.descendants(root):
		if node is NucleusMotionInput:
			return node as NucleusMotionInput

	return null
