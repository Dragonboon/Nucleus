class_name NucleusLookRig3D
extends Node
## Applies mouse and gamepad look to separate yaw/pitch Node3D targets.
##
## Mouse delta is measured in physical screen pixels through
## InputEventMouseMotion.screen_relative. Gamepad look is angular speed per
## second, so its result is multiplied by delta.

signal look_applied(
	yaw_delta: float,
	pitch_delta: float,
)

enum ProcessCallback {
	IDLE,
	PHYSICS,
}

@export var motion_input: NucleusMotionInput
@export var yaw_target: Node3D
@export var pitch_target: Node3D

@export_group("Mouse")
@export_range(0.001, 5.0, 0.001, "or_greater")
var mouse_sensitivity_degrees_per_pixel: float = 0.10

@export_group("Gamepad")
@export_range(0.0, 1440.0, 1.0, "or_greater")
var gamepad_degrees_per_second: float = 180.0

@export_group("Axes")
@export var invert_x: bool = false
@export var invert_y: bool = false
@export_range(-89.9, 0.0, 0.1, "radians_as_degrees")
var minimum_pitch: float = deg_to_rad(-89.0)
@export_range(0.0, 89.9, 0.1, "radians_as_degrees")
var maximum_pitch: float = deg_to_rad(89.0)

@export_group("Processing")
@export var process_callback: ProcessCallback = ProcessCallback.IDLE
@export var enabled: bool = true


func _ready() -> void:
	_resolve_dependencies()
	_refresh_processing()


func _process(delta: float) -> void:
	if process_callback == ProcessCallback.IDLE:
		apply_look(delta)


func _physics_process(delta: float) -> void:
	if process_callback == ProcessCallback.PHYSICS:
		apply_look(delta)


func set_enabled(active: bool) -> void:
	enabled = active

	if not enabled and motion_input:
		motion_input.clear_pointer_delta()

	_refresh_processing()


func apply_look(delta: float) -> void:
	if (
		not enabled
		or motion_input == null
		or yaw_target == null
		or pitch_target == null
	):
		return

	var mouse_delta: Vector2 = motion_input.consume_pointer_delta()
	var stick: Vector2 = motion_input.get_look_vector()

	var mouse_scale: float = deg_to_rad(
		mouse_sensitivity_degrees_per_pixel
		* NucleusInputAccessibilityPolicy.get_mouse_look_sensitivity_scale()
	)
	var gamepad_scale: float = deg_to_rad(
		gamepad_degrees_per_second
		* NucleusInputAccessibilityPolicy.get_gamepad_look_sensitivity_scale()
	)

	var yaw_delta: float = (
		-mouse_delta.x * mouse_scale
		- stick.x * gamepad_scale * delta
	)
	var pitch_delta: float = (
		-mouse_delta.y * mouse_scale
		- stick.y * gamepad_scale * delta
	)

	if invert_x:
		yaw_delta *= -1.0

	if invert_y:
		pitch_delta *= -1.0

	if (
		is_zero_approx(yaw_delta)
		and is_zero_approx(pitch_delta)
	):
		return

	var yaw_rotation: Vector3 = yaw_target.rotation
	yaw_rotation.y = wrapf(
		yaw_rotation.y + yaw_delta,
		-PI,
		PI,
	)
	yaw_target.rotation = yaw_rotation

	var pitch_rotation: Vector3 = pitch_target.rotation
	pitch_rotation.x = clampf(
		pitch_rotation.x + pitch_delta,
		minimum_pitch,
		maximum_pitch,
	)
	pitch_target.rotation = pitch_rotation

	look_applied.emit(
		yaw_delta,
		pitch_delta,
	)


func set_angles(
	yaw: float,
	pitch: float,
) -> void:
	if yaw_target:
		var yaw_rotation: Vector3 = yaw_target.rotation
		yaw_rotation.y = wrapf(yaw, -PI, PI)
		yaw_target.rotation = yaw_rotation

	if pitch_target:
		var pitch_rotation: Vector3 = pitch_target.rotation
		pitch_rotation.x = clampf(
			pitch,
			minimum_pitch,
			maximum_pitch,
		)
		pitch_target.rotation = pitch_rotation


func _refresh_processing() -> void:
	set_process(
		enabled
		and process_callback == ProcessCallback.IDLE
	)
	set_physics_process(
		enabled
		and process_callback == ProcessCallback.PHYSICS
	)


func _resolve_dependencies() -> void:
	if motion_input == null:
		var parent: Node = get_parent()

		if parent:
			for node: Node in NucleusNodeUtils.descendants(parent):
				if node is NucleusMotionInput:
					motion_input = node as NucleusMotionInput
					break

	if yaw_target == null:
		yaw_target = get_parent() as Node3D

	if pitch_target == null:
		pitch_target = yaw_target

	if motion_input == null:
		NucleusLog.error(
			"%s requires a NucleusMotionInput." % get_path(),
			&"LookRig3D",
		)

	if yaw_target == null or pitch_target == null:
		NucleusLog.error(
			"%s requires yaw and pitch Node3D targets." % get_path(),
			&"LookRig3D",
		)
