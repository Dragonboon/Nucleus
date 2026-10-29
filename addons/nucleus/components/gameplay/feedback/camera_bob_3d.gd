class_name NucleusCameraBob3D
extends Node
## Optional grounded locomotion bob feeding one continuous 3D feedback source.

@export var body: CharacterBody3D
@export var feedback: NucleusCameraFeedback3D
@export_range(0.01, 1000.0, 0.01, "or_greater")
var reference_speed: float = 5.0
@export_range(0.01, 30.0, 0.01, "or_greater")
var frequency: float = 1.8
@export var position_amplitude: Vector3 = Vector3(0.025, 0.045, 0.0)
@export var rotation_degrees: Vector3 = Vector3(0.35, 0.2, 0.6)
@export_range(0.0, 100.0, 0.01, "or_greater")
var response: float = 10.0
@export var require_floor: bool = true
@export var respect_reduced_motion: bool = true
@export_range(0.0, 1.0, 0.01)
var reduced_motion_scale: float = 0.15

var _source_id: StringName
var _phase: float = 0.0
var _weight: float = 0.0


func _ready() -> void:
	_resolve_dependencies()

	if body == null or feedback == null:
		NucleusLog.error(
			"%s requires CharacterBody3D and CameraFeedback3D." % get_path(),
			&"CameraBob3D",
		)
		set_process(false)
		return

	_source_id = StringName(
		"camera_bob:%s" % get_instance_id()
	)


func _exit_tree() -> void:
	if feedback and _source_id != &"":
		feedback.remove_offset_source(_source_id)


func _process(delta: float) -> void:
	var horizontal_speed: float = Vector2(
		body.velocity.x,
		body.velocity.z,
	).length()
	var valid_motion: bool = (
		not require_floor
		or body.is_on_floor()
	)
	var target_weight: float = (
		clampf(
			horizontal_speed / maxf(reference_speed, 0.01),
			0.0,
			1.0,
		)
		if valid_motion
		else 0.0
	)
	var response_weight: float = NucleusMotionMath.exponential_weight(
		response,
		delta,
	)
	_weight = lerpf(
		_weight,
		target_weight,
		response_weight,
	)

	_phase += delta * frequency * maxf(target_weight, 0.15) * TAU

	var position := Vector3(
		cos(_phase * 0.5) * position_amplitude.x,
		sin(_phase) * position_amplitude.y,
		sin(_phase * 0.5) * position_amplitude.z,
	) * _weight
	var rotation := Vector3(
		deg_to_rad(rotation_degrees.x) * sin(_phase),
		deg_to_rad(rotation_degrees.y) * cos(_phase * 0.5),
		deg_to_rad(rotation_degrees.z) * sin(_phase * 0.5),
	) * _weight

	feedback.set_offset_source(
		_source_id,
		position,
		rotation,
		0.0,
		respect_reduced_motion,
		reduced_motion_scale,
	)


func _resolve_dependencies() -> void:
	var root: Node = get_parent()

	while root and (body == null or feedback == null):
		if body == null and root is CharacterBody3D:
			body = root as CharacterBody3D

		if feedback == null and root is NucleusCameraFeedback3D:
			feedback = root as NucleusCameraFeedback3D

		for node: Node in NucleusNodeUtils.descendants(root):
			if body == null and node is CharacterBody3D:
				body = node as CharacterBody3D

			if feedback == null and node is NucleusCameraFeedback3D:
				feedback = node as NucleusCameraFeedback3D

		root = root.get_parent()
