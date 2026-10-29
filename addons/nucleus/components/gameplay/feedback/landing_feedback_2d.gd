class_name NucleusLandingFeedback2D
extends Node
## Converts CharacterBody2D landing impact into a camera feedback impulse.

@export var body: CharacterBody2D
@export var feedback: NucleusCameraFeedback2D
@export var profile: NucleusCameraImpulseProfile2D
@export var physics_process_priority: int = 100
@export_range(0.0, 100000.0, 0.01, "or_greater")
var minimum_impact_speed: float = 150.0
@export_range(0.01, 100000.0, 0.01, "or_greater")
var full_strength_speed: float = 600.0

var _was_on_floor: bool = false
var _previous_fall_speed: float = 0.0


func _ready() -> void:
	process_physics_priority = physics_process_priority
	_resolve_dependencies()

	if body == null or feedback == null or profile == null:
		NucleusLog.error(
			"%s requires body, feedback, and profile." % get_path(),
			&"LandingFeedback2D",
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
