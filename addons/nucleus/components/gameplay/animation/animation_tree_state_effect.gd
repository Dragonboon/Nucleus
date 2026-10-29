class_name NucleusAnimationTreeStateEffect
extends NucleusActionEffect
## GameplayAction effect that travels an AnimationTree state machine.

@export var animation_tree: AnimationTree
@export var playback_parameter: StringName = &"parameters/playback"
@export var target_state: StringName
@export var reset_on_teleport: bool = true


func can_apply(_context: Dictionary) -> Error:
	if animation_tree == null or target_state == &"":
		return ERR_UNCONFIGURED

	var playback: Variant = animation_tree.get(
		playback_parameter
	)

	return (
		OK
		if playback is AnimationNodeStateMachinePlayback
		else ERR_UNCONFIGURED
	)


func apply(context: Dictionary) -> Error:
	var error: Error = can_apply(context)

	if error != OK:
		return error

	var playback := animation_tree.get(
		playback_parameter
	) as AnimationNodeStateMachinePlayback

	playback.travel(
		target_state,
		reset_on_teleport,
	)

	return OK
