class_name NucleusAnimationTreeOneShotEffect
extends NucleusActionEffect
## GameplayAction effect that fires one AnimationTree OneShot node.

@export var animation_tree: AnimationTree
@export var request_parameter: StringName


func can_apply(_context: Dictionary) -> Error:
	if animation_tree == null or request_parameter == &"":
		return ERR_UNCONFIGURED

	return OK


func apply(context: Dictionary) -> Error:
	var error: Error = can_apply(context)

	if error != OK:
		return error

	animation_tree.set(
		request_parameter,
		AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE,
	)

	return OK
