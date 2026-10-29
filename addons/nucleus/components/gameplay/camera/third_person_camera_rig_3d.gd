class_name NucleusThirdPersonCameraRig3D
extends Node3D
## Collision-aware third-person orbit camera built around SpringArm3D.
##
## Camera3D should be a direct child of SpringArm3D so Godot owns collision
## shortening. The rig follows an interpolated gameplay target in render frames.

signal target_changed(
	target: Node3D,
	previous_target: Node3D,
)
signal distance_changed(distance: float)

@export var target: Node3D
@export var motion_input: NucleusMotionInput

@export_group("Rig nodes")
@export var spring_arm: SpringArm3D
@export var camera: Camera3D
@export var look_rig: NucleusLookRig3D

@export_group("Following")
@export var target_offset: Vector3 = Vector3(0.0, 1.5, 0.0)
@export var use_interpolated_target: bool = true
@export_range(0.0, 1000.0, 0.01, "or_greater")
var follow_response: float = 0.0
@export var reset_interpolation_on_snap: bool = true

@export_group("Distance")
@export_range(0.0, 1000.0, 0.01, "or_greater")
var minimum_distance: float = 1.5
@export_range(0.0, 1000.0, 0.01, "or_greater")
var maximum_distance: float = 8.0
@export_range(0.0, 1000.0, 0.01, "or_greater")
var initial_distance: float = 4.0
@export_range(0.01, 1000.0, 0.01, "or_greater")
var zoom_step: float = 0.5
@export_range(0.0, 1000.0, 0.01, "or_greater")
var zoom_response: float = 14.0
@export var zoom_in_action: StringName = &""
@export var zoom_out_action: StringName = &""

@export_group("Collision")
@export var exclude_target_physics_body: bool = true

@export_group("Activation")
@export var make_current_on_ready: bool = true
@export var enabled: bool = true

var target_distance: float = 4.0

var _excluded_target_rid: RID


func _ready() -> void:
	_resolve_dependencies()
	_validate_rig()

	# This is a render-frame camera object. It follows interpolated physics
	# targets manually and should not be interpolated a second time.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	target_distance = clampf(
		initial_distance,
		minimum_distance,
		maximum_distance,
	)

	if spring_arm:
		spring_arm.spring_length = target_distance

	if look_rig:
		look_rig.motion_input = motion_input
		look_rig.yaw_target = self
		look_rig.pitch_target = self

	if motion_input:
		motion_input.input_event_received.connect(
			_on_input_event
		)

	_refresh_target_exclusion()

	if camera and make_current_on_ready:
		camera.make_current()

	if target:
		snap_to_target()


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

	_clear_target_exclusion()


func _process(delta: float) -> void:
	if not enabled:
		return

	_follow_target(delta)
	_update_distance(delta)


func set_enabled(active: bool) -> void:
	enabled = active

	if look_rig:
		look_rig.set_enabled(active)

	if not active and motion_input:
		motion_input.clear_pointer_delta()


func set_target(
	new_target: Node3D,
	snap: bool = true,
) -> void:
	if target == new_target:
		return

	var previous_target: Node3D = target

	_clear_target_exclusion()
	target = new_target
	_refresh_target_exclusion()

	if snap and target:
		snap_to_target()

	target_changed.emit(
		target,
		previous_target,
	)


func snap_to_target() -> void:
	if target == null:
		return

	global_position = _get_target_position()

	if reset_interpolation_on_snap:
		reset_physics_interpolation()


func set_distance(
	distance: float,
	instant: bool = false,
) -> void:
	var lower: float = minf(
		minimum_distance,
		maximum_distance,
	)
	var upper: float = maxf(
		minimum_distance,
		maximum_distance,
	)

	target_distance = clampf(
		distance,
		lower,
		upper,
	)

	if instant and spring_arm:
		spring_arm.spring_length = target_distance

	distance_changed.emit(target_distance)


func zoom_in() -> void:
	set_distance(
		target_distance - zoom_step,
	)


func zoom_out() -> void:
	set_distance(
		target_distance + zoom_step,
	)


func _follow_target(delta: float) -> void:
	if target == null:
		return

	var target_position: Vector3 = _get_target_position()

	if follow_response <= 0.0:
		global_position = target_position
		return

	var weight: float = NucleusMotionMath.exponential_weight(
		follow_response,
		delta,
	)

	global_position = global_position.lerp(
		target_position,
		weight,
	)


func _update_distance(delta: float) -> void:
	if spring_arm == null:
		return

	if is_equal_approx(
		spring_arm.spring_length,
		target_distance,
	):
		return

	var weight: float = NucleusMotionMath.exponential_weight(
		zoom_response,
		delta,
	)

	spring_arm.spring_length = lerpf(
		spring_arm.spring_length,
		target_distance,
		weight,
	)


func _get_target_position() -> Vector3:
	if target == null:
		return global_position

	var transform: Transform3D = (
		target.get_global_transform_interpolated()
		if use_interpolated_target
		else target.global_transform
	)

	return transform.origin + target_offset


func _on_input_event(event: InputEvent) -> void:
	if not enabled:
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton

		if not mouse_button.pressed:
			return

		match mouse_button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom_in()

			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()

	if (
		zoom_in_action != &""
		and InputMap.has_action(zoom_in_action)
		and event.is_action_pressed(zoom_in_action)
	):
		zoom_in()
	elif (
		zoom_out_action != &""
		and InputMap.has_action(zoom_out_action)
		and event.is_action_pressed(zoom_out_action)
	):
		zoom_out()


func _refresh_target_exclusion() -> void:
	if (
		not exclude_target_physics_body
		or spring_arm == null
		or not (target is PhysicsBody3D)
	):
		return

	_excluded_target_rid = (target as PhysicsBody3D).get_rid()
	spring_arm.add_excluded_object(
		_excluded_target_rid
	)


func _clear_target_exclusion() -> void:
	if (
		spring_arm
		and _excluded_target_rid.is_valid()
	):
		spring_arm.remove_excluded_object(
			_excluded_target_rid
		)

	_excluded_target_rid = RID()


func _validate_rig() -> void:
	if spring_arm == null:
		NucleusLog.error(
			"%s requires a SpringArm3D." % get_path(),
			&"ThirdPersonCamera",
		)

	if camera == null:
		NucleusLog.error(
			"%s requires a Camera3D." % get_path(),
			&"ThirdPersonCamera",
		)

	if (
		spring_arm
		and camera
		and camera.get_parent() != spring_arm
	):
		NucleusLog.warning(
			"Camera3D should be a direct SpringArm3D child in %s."
			% get_path(),
			&"ThirdPersonCamera",
		)

	if motion_input == null:
		NucleusLog.warning(
			"%s has no NucleusMotionInput; orbit input is disabled."
			% get_path(),
			&"ThirdPersonCamera",
		)


func _resolve_dependencies() -> void:
	if spring_arm == null:
		for node: Node in NucleusNodeUtils.descendants(self):
			if node is SpringArm3D:
				spring_arm = node as SpringArm3D
				break

	if camera == null and spring_arm:
		for node: Node in NucleusNodeUtils.descendants(spring_arm):
			if node is Camera3D:
				camera = node as Camera3D
				break

	if look_rig == null:
		for node: Node in NucleusNodeUtils.descendants(self):
			if node is NucleusLookRig3D:
				look_rig = node as NucleusLookRig3D
				break
