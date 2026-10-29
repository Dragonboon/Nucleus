class_name NucleusCameraBob2D
extends Node
## Optional locomotion bob that contributes one continuous feedback source.

@export var body: CharacterBody2D
@export var feedback: NucleusCameraFeedback2D
@export_range(0.01, 1000.0, 0.01, "or_greater")
var reference_speed: float = 200.0
@export_range(0.01, 30.0, 0.01, "or_greater")
var frequency: float = 1.8
@export var position_amplitude: Vector2 = Vector2(2.5, 4.0)
@export_range(0.0, 30.0, 0.01, "or_greater")
var rotation_degrees: float = 0.5
@export_range(0.0, 100.0, 0.01, "or_greater")
var response: float = 10.0
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
			"%s requires CharacterBody2D and CameraFeedback2D." % get_path(),
			&"CameraBob2D",
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
	var speed: float = body.velocity.length()
	var target_weight: float = clampf(
		speed / maxf(reference_speed, 0.01),
		0.0,
		1.0,
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

	var position := Vector2(
		cos(_phase * 0.5) * position_amplitude.x,
		sin(_phase) * position_amplitude.y,
	) * _weight
	var rotation: float = (
		deg_to_rad(rotation_degrees)
		* sin(_phase * 0.5)
		* _weight
	)

	feedback.set_offset_source(
		_source_id,
		position,
		rotation,
		respect_reduced_motion,
		reduced_motion_scale,
	)


func _resolve_dependencies() -> void:
	var root: Node = get_parent()

	while root and (body == null or feedback == null):
		if body == null and root is CharacterBody2D:
			body = root as CharacterBody2D

		if feedback == null and root is NucleusCameraFeedback2D:
			feedback = root as NucleusCameraFeedback2D

		for node: Node in NucleusNodeUtils.descendants(root):
			if body == null and node is CharacterBody2D:
				body = node as CharacterBody2D

			if feedback == null and node is NucleusCameraFeedback2D:
				feedback = node as NucleusCameraFeedback2D

		root = root.get_parent()
