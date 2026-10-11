class_name NucleusCharacterMotor3D
extends Node
## Ground/air locomotion for an existing CharacterBody3D.
##
## Player-controlled actors may keep using NucleusMotionInput. AI/autopilot/
## replay actors can provide world-space planar intent through
## NucleusPlanarMotionSource3D without duplicating physical locomotion.

signal movement_updated(
	direction: Vector3,
	velocity: Vector3,
)
signal jumped
signal landed
signal left_ground

@export var body: CharacterBody3D
@export var motion_input: NucleusMotionInput
@export var motion_source: NucleusPlanarMotionSource3D
@export var orientation_source: Node3D

@export_group("Planar movement")
@export_range(0.0, 10000.0, 0.01, "or_greater")
var speed: float = 5.0
@export_range(0.0, 10000.0, 0.01, "or_greater")
var ground_acceleration: float = 20.0
@export_range(0.0, 10000.0, 0.01, "or_greater")
var ground_deceleration: float = 24.0
@export_range(0.0, 10000.0, 0.01, "or_greater")
var air_acceleration: float = 8.0
@export_range(0.0, 10000.0, 0.01, "or_greater")
var air_deceleration: float = 4.0
@export_range(0.0, 100.0, 0.01, "or_greater")
var speed_multiplier: float = 1.0

@export_group("Gravity")
@export_range(0.0, 100.0, 0.01, "or_greater")
var gravity_scale: float = 1.0

@export_group("Jump")
@export var jump_action: StringName = &""
@export_range(0.0, 1000.0, 0.01, "or_greater")
var jump_speed: float = 5.0
@export_range(0.0, 2.0, 0.01, "or_greater")
var coyote_time: float = 0.10
@export_range(0.0, 2.0, 0.01, "or_greater")
var jump_buffer_time: float = 0.10
@export_range(0, 16, 1) var extra_air_jumps: int = 0
@export var shorten_jump_on_release: bool = true
@export_range(0.0, 1.0, 0.01)
var jump_release_multiplier: float = 0.5

@export_group("Behavior")
@export var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled:
			_jump_buffer_remaining = 0.0
			_jump_release_pending = false

var desired_direction: Vector3 = Vector3.ZERO
var desired_velocity: Vector3 = Vector3.ZERO

var _jump_buffer_remaining: float = 0.0
var _jump_release_pending: bool = false
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
	if not enabled or body == null:
		return

	if motion_source == null and motion_input == null:
		return

	_update_ground_jump_state(delta)
	_update_planar_intent()

	_apply_planar_motion(delta)
	_try_consume_jump()
	if _jump_release_pending and _jump_buffer_remaining <= 0.0:
		_shorten_jump()
		_jump_release_pending = false
	_apply_gravity(delta)

	body.move_and_slide()
	_decay_jump_buffer(delta)
	_emit_ground_transitions()

	movement_updated.emit(
		desired_direction,
		body.velocity,
	)


func request_jump() -> void:
	if not enabled:
		return

	_jump_release_pending = false
	_jump_buffer_remaining = maxf(
		0.0001,
		jump_buffer_time,
	)


func set_speed_multiplier(multiplier: float) -> void:
	speed_multiplier = maxf(0.0, multiplier)


func get_max_planar_speed() -> float:
	return maxf(speed, 0.0) * maxf(speed_multiplier, 0.0)


func get_ground_speed() -> float:
	if body == null:
		return 0.0

	return NucleusMotionMath.planar_component_3d(
		body.velocity,
		body.up_direction,
	).length()


func stop_planar(immediate: bool = false) -> void:
	desired_direction = Vector3.ZERO
	desired_velocity = Vector3.ZERO

	if not immediate or body == null:
		return

	body.velocity = NucleusMotionMath.vertical_component_3d(
		body.velocity,
		body.up_direction,
	)


func _update_planar_intent() -> void:
	if motion_source != null and motion_source.enabled:
		_update_motion_source_intent()
		return

	_update_input_intent()


func _update_motion_source_intent() -> void:
	var maximum_speed := get_max_planar_speed()
	var requested := motion_source.get_desired_velocity(
		body,
		maximum_speed,
	)

	if not requested.is_finite():
		requested = Vector3.ZERO

	requested = NucleusMotionMath.planar_component_3d(
		requested,
		body.up_direction,
	)

	if maximum_speed <= 0.0:
		requested = Vector3.ZERO
	elif requested.length() > maximum_speed:
		requested = requested.normalized() * maximum_speed

	desired_velocity = requested
	desired_direction = (
		requested.normalized()
		if not requested.is_zero_approx()
		else Vector3.ZERO
	)


func _update_input_intent() -> void:
	if motion_input == null:
		desired_direction = Vector3.ZERO
		desired_velocity = Vector3.ZERO
		return

	var input_direction: Vector2 = motion_input.get_move_vector()
	var source_basis: Basis = (
		orientation_source.global_basis
		if orientation_source
		else body.global_basis
	)

	desired_direction = NucleusMotionMath.planar_direction_3d(
		input_direction,
		source_basis,
		body.up_direction,
	)
	desired_velocity = (
		desired_direction
		* get_max_planar_speed()
	)


func _apply_planar_motion(delta: float) -> void:
	var vertical: Vector3 = NucleusMotionMath.vertical_component_3d(
		body.velocity,
		body.up_direction,
	)
	var planar: Vector3 = NucleusMotionMath.planar_component_3d(
		body.velocity,
		body.up_direction,
	)

	var rate: float

	if body.is_on_floor():
		rate = (
			ground_acceleration
			if not desired_direction.is_zero_approx()
			else ground_deceleration
		)
	else:
		rate = (
			air_acceleration
			if not desired_direction.is_zero_approx()
			else air_deceleration
		)

	planar = planar.move_toward(
		desired_velocity,
		maxf(0.0, rate) * delta,
	)

	body.velocity = planar + vertical


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

	var up: Vector3 = _get_up_direction()
	var planar: Vector3 = NucleusMotionMath.planar_component_3d(
		body.velocity,
		up,
	)

	body.velocity = (
		planar
		+ up * maxf(0.0, jump_speed)
	)

	if air_jump:
		_air_jumps_used += 1

	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	jumped.emit()


func _shorten_jump() -> void:
	if not enabled or not shorten_jump_on_release or body == null:
		return

	var up: Vector3 = _get_up_direction()
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
	if _jump_buffer_remaining <= 0.0:
		_jump_release_pending = false


func _emit_ground_transitions() -> void:
	var on_floor: bool = body.is_on_floor()

	if not _was_on_floor and on_floor:
		landed.emit()

	if _was_on_floor and not on_floor:
		left_ground.emit()

	_was_on_floor = on_floor


func _get_up_direction() -> Vector3:
	var up: Vector3 = body.up_direction.normalized()

	return Vector3.UP if up.is_zero_approx() else up


func _on_input_event(event: InputEvent) -> void:
	if (
		not enabled
		or jump_action == &""
		or not InputMap.has_action(jump_action)
	):
		return

	if event.is_action_pressed(jump_action):
		request_jump()
	elif event.is_action_released(jump_action):
		_jump_release_pending = true


func _resolve_dependencies() -> void:
	if body == null:
		body = get_parent() as CharacterBody3D

	if motion_input == null:
		motion_input = _find_motion_input()

	if orientation_source == null and body != null:
		orientation_source = body

	if body == null:
		NucleusLog.error(
			"%s requires a CharacterBody3D." % get_path(),
			&"CharacterMotor3D",
		)

	if motion_source == null and motion_input == null:
		NucleusLog.error(
			"%s requires MotionInput or PlanarMotionSource3D."
			% get_path(),
			&"CharacterMotor3D",
		)


func _find_motion_input() -> NucleusMotionInput:
	var root: Node = body if body else get_parent()

	if root == null:
		return null

	for node: Node in NucleusNodeUtils.descendants(root):
		if node is NucleusMotionInput:
			return node as NucleusMotionInput

	return null
