class_name NucleusPlatformerMotor2D
extends Node
## Side-view CharacterBody2D motor with gravity, jump buffering, and coyote time.
##
## Jump input is optional. Set [member jump_action] to a project InputMap action,
## or call [method request_jump] from gameplay code/state logic.

signal movement_updated(
	input_axis: float,
	velocity: Vector2,
)
signal jumped
signal landed
signal left_ground

@export var body: CharacterBody2D
@export var motion_input: NucleusMotionInput

@export_group("Horizontal movement")
@export_range(0.0, 100000.0, 1.0, "or_greater")
var speed: float = 260.0
@export_range(0.0, 100000.0, 1.0, "or_greater")
var ground_acceleration: float = 2200.0
@export_range(0.0, 100000.0, 1.0, "or_greater")
var ground_deceleration: float = 2600.0
@export_range(0.0, 100000.0, 1.0, "or_greater")
var air_acceleration: float = 1100.0
@export_range(0.0, 100000.0, 1.0, "or_greater")
var air_deceleration: float = 800.0
@export_range(0.0, 100.0, 0.01, "or_greater")
var speed_multiplier: float = 1.0

@export_group("Gravity")
@export_range(0.0, 100.0, 0.01, "or_greater")
var gravity_scale: float = 1.0

@export_group("Jump")
@export var jump_action: StringName = &""
@export_range(0.0, 100000.0, 1.0, "or_greater")
var jump_speed: float = 420.0
@export_range(0.0, 2.0, 0.01, "or_greater")
var coyote_time: float = 0.10
@export_range(0.0, 2.0, 0.01, "or_greater")
var jump_buffer_time: float = 0.10
@export_range(0, 16, 1) var extra_air_jumps: int = 0
@export var shorten_jump_on_release: bool = true
@export_range(0.0, 1.0, 0.01)
var jump_release_multiplier: float = 0.5

@export_group("Behavior")
@export var enabled: bool = true

var desired_axis: float = 0.0

var _jump_buffer_remaining: float = 0.0
var _coyote_remaining: float = 0.0
var _air_jumps_used: int = 0
var _was_on_floor: bool = false


func _ready() -> void:
	_resolve_dependencies()

	if motion_input:
		motion_input.input_event_received.connect(
			_on_input_event
		)

	if body:
		_was_on_floor = body.is_on_floor()


func _exit_tree() -> void:
	if (
		motion_input
		and motion_input.input_event_received.is_connected(
			_on_input_event
		)
	):
		motion_input.input_event_received.disconnect(
			_on_input_event
		)


func _physics_process(delta: float) -> void:
	if not enabled or body == null or motion_input == null:
		return

	_update_ground_jump_state(delta)

	var input_direction: Vector2 = motion_input.get_move_vector()
	desired_axis = clampf(input_direction.x, -1.0, 1.0)

	_apply_horizontal_motion(delta)
	_try_consume_jump()
	_apply_gravity(delta)

	body.move_and_slide()
	_decay_jump_buffer(delta)
	_emit_ground_transitions()

	movement_updated.emit(
		desired_axis,
		body.velocity,
	)


func request_jump() -> void:
	if not enabled:
		return

	_jump_buffer_remaining = maxf(
		0.0001,
		jump_buffer_time,
	)


func set_speed_multiplier(multiplier: float) -> void:
	speed_multiplier = maxf(0.0, multiplier)


func _apply_horizontal_motion(delta: float) -> void:
	var up: Vector2 = _get_up_direction()
	var right: Vector2 = NucleusMotionMath.right_from_up_2d(up)

	var up_speed: float = body.velocity.dot(up)
	var current_speed: float = body.velocity.dot(right)
	var target_speed: float = (
		desired_axis
		* speed
		* maxf(0.0, speed_multiplier)
	)

	var rate: float

	if body.is_on_floor():
		rate = (
			ground_acceleration
			if not is_zero_approx(desired_axis)
			else ground_deceleration
		)
	else:
		rate = (
			air_acceleration
			if not is_zero_approx(desired_axis)
			else air_deceleration
		)

	current_speed = move_toward(
		current_speed,
		target_speed,
		maxf(0.0, rate) * delta,
	)

	body.velocity = (
		right * current_speed
		+ up * up_speed
	)


func _apply_gravity(delta: float) -> void:
	if body.is_on_floor():
		return

	body.velocity += (
		body.get_gravity()
		* maxf(0.0, gravity_scale)
		* delta
	)


func _try_consume_jump() -> void:
	if _jump_buffer_remaining <= 0.0:
		return

	var grounded_jump: bool = (
		body.is_on_floor()
		or _coyote_remaining > 0.0
	)
	var air_jump: bool = (
		not grounded_jump
		and _air_jumps_used < extra_air_jumps
	)

	if not grounded_jump and not air_jump:
		return

	var up: Vector2 = _get_up_direction()
	var horizontal: Vector2 = (
		body.velocity
		- up * body.velocity.dot(up)
	)

	body.velocity = (
		horizontal
		+ up * maxf(0.0, jump_speed)
	)

	if air_jump:
		_air_jumps_used += 1

	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	jumped.emit()


func _shorten_jump() -> void:
	if not shorten_jump_on_release or body == null:
		return

	var up: Vector2 = _get_up_direction()
	var upward_speed: float = body.velocity.dot(up)

	if upward_speed <= 0.0:
		return

	var clamped_multiplier: float = clampf(
		jump_release_multiplier,
		0.0,
		1.0,
	)

	body.velocity -= (
		up
		* upward_speed
		* (1.0 - clamped_multiplier)
	)


func _update_ground_jump_state(delta: float) -> void:
	if body.is_on_floor():
		_coyote_remaining = coyote_time
		_air_jumps_used = 0
	else:
		_coyote_remaining = maxf(
			0.0,
			_coyote_remaining - delta,
		)


func _decay_jump_buffer(delta: float) -> void:
	_jump_buffer_remaining = maxf(
		0.0,
		_jump_buffer_remaining - delta,
	)


func _emit_ground_transitions() -> void:
	var on_floor: bool = body.is_on_floor()

	if not _was_on_floor and on_floor:
		landed.emit()

	if _was_on_floor and not on_floor:
		left_ground.emit()

	_was_on_floor = on_floor


func _get_up_direction() -> Vector2:
	var up: Vector2 = body.up_direction.normalized()

	return Vector2.UP if up.is_zero_approx() else up


func _on_input_event(event: InputEvent) -> void:
	if (
		jump_action == &""
		or not InputMap.has_action(jump_action)
	):
		return

	if event.is_action_pressed(jump_action):
		request_jump()
	elif event.is_action_released(jump_action):
		_shorten_jump()


func _resolve_dependencies() -> void:
	if body == null:
		body = get_parent() as CharacterBody2D

	if motion_input == null:
		motion_input = _find_motion_input()

	if body == null:
		NucleusLog.error(
			"%s requires a CharacterBody2D." % get_path(),
			&"PlatformerMotor2D",
		)

	if motion_input == null:
		NucleusLog.error(
			"%s requires a NucleusMotionInput." % get_path(),
			&"PlatformerMotor2D",
		)


func _find_motion_input() -> NucleusMotionInput:
	var root: Node = body if body else get_parent()

	if root == null:
		return null

	for node: Node in NucleusNodeUtils.descendants(root):
		if node is NucleusMotionInput:
			return node as NucleusMotionInput

	return null
