class_name NucleusAnimationVelocityBinding2D
extends Node
## Pushes CharacterBody2D motion into configured AnimationTree parameters.

@export var body: CharacterBody2D
@export var animation_tree: AnimationTree
@export var orientation_source: Node2D

@export_group("Parameters")
@export var speed_parameter: StringName
@export var direction_parameter: StringName
@export var moving_parameter: StringName

@export_group("Values")
@export var use_local_direction: bool = true
@export var normalize_direction: bool = true
@export_range(0.0, 100000.0, 0.01, "or_greater")
var moving_threshold: float = 0.05


func _ready() -> void:
	_resolve_dependencies()

	if body == null or animation_tree == null:
		NucleusLog.error(
			"%s requires CharacterBody2D and AnimationTree." % get_path(),
			&"AnimationVelocity2D",
		)
		set_process(false)
		return

	if orientation_source == null:
		orientation_source = body


func _process(_delta: float) -> void:
	var velocity: Vector2 = body.velocity
	var speed: float = velocity.length()
	var direction: Vector2 = velocity

	if use_local_direction and orientation_source:
		direction = orientation_source.global_transform.basis_xform_inv(
			velocity
		)

	if normalize_direction and not direction.is_zero_approx():
		direction = direction.normalized()

	if speed_parameter != &"":
		animation_tree.set(speed_parameter, speed)

	if direction_parameter != &"":
		animation_tree.set(direction_parameter, direction)

	if moving_parameter != &"":
		animation_tree.set(
			moving_parameter,
			speed > moving_threshold,
		)


func _resolve_dependencies() -> void:
	var root: Node = get_parent()

	while root and (body == null or animation_tree == null):
		if body == null and root is CharacterBody2D:
			body = root as CharacterBody2D

		if animation_tree == null and root is AnimationTree:
			animation_tree = root as AnimationTree

		for node: Node in NucleusNodeUtils.descendants(root):
			if body == null and node is CharacterBody2D:
				body = node as CharacterBody2D

			if animation_tree == null and node is AnimationTree:
				animation_tree = node as AnimationTree

		root = root.get_parent()
