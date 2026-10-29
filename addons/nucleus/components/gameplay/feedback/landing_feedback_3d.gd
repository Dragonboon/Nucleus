class_name NucleusLandingFeedback3D
extends Node
## Converts CharacterBody3D landing impact into a camera feedback impulse.

@export var body: CharacterBody3D
@export var feedback: NucleusCameraFeedback3D
@export var profile: NucleusCameraImpulseProfile3D
@export var physics_process_priority: int = 100
@export_range(0.0, 100000.0, 0.01, "or_greater")
var minimum_impact_speed: float = 4.0
@export_range(0.01, 100000.0, 0.01, "or_greater")
var full_strength_speed: float = 14.0

var _was_on_floor: bool = false
var _previous_fall_speed: float = 0.0


func _ready() -> void:
	process_physics_priority = physics_process_priority
	_resolve_dependencies()

	if body == null or feedback == null or profile == null:
		NucleusLog.error(
			"%s requires body, feedback, and profile." % get_path(),
			&"LandingFeedback3D",
		)
		set_physics_process(false)
		return

	_was_on_floor = body.is_on_floor()


func _physics_process(_delta: float) -> void:
	var on_floor: bool = body.is_on_floor()

	if on_floor and not _was_on_floor:
		var strength: float = inverse_lerp(
			minimum_impact_speed,
			maxf(full_strength_speed, minimum_impact_speed + 0.01),
			_previous_fall_speed,
		)

		if strength > 0.0:
			feedback.play_impulse(
				profile,
				clampf(strength, 0.0, 1.0),
			)

	_previous_fall_speed = maxf(
		0.0,
		-body.velocity.dot(body.up_direction),
	)
	_was_on_floor = on_floor


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
