class_name NucleusAnimationTreeBuilder3D
extends RefCounted
## Builds editable native starter AnimationTree structures for 3D characters.
##
## This is intentionally not a general graph authoring framework.

const LOCOMOTION_STATE: StringName = &"Locomotion"
const JUMP_STATE: StringName = &"Jump"
const FALL_STATE: StringName = &"Fall"
const LAND_STATE: StringName = &"Land"

const PLAYBACK_PARAMETER: StringName = &"parameters/playback"
const SPEED_PARAMETER: StringName = &"parameters/Locomotion/blend_position"
const DIRECTION_PARAMETER: StringName = &"parameters/Locomotion/blend_position"


static func build_starter_tree(
	animation_tree: AnimationTree,
	animation_player: AnimationPlayer,
	profile: NucleusAnimationStarterProfile3D,
	replace_existing: bool = false,
) -> Error:
	if animation_tree == null or animation_player == null or profile == null:
		return ERR_UNCONFIGURED

	if not profile.get_validation_errors(animation_player).is_empty():
		return ERR_INVALID_DATA

	if animation_tree.tree_root != null and not replace_existing:
		return ERR_ALREADY_EXISTS

	if (
		not animation_tree.is_inside_tree()
		or not animation_player.is_inside_tree()
		or animation_tree.get_tree() != animation_player.get_tree()
	):
		return ERR_UNCONFIGURED

	var state_machine := AnimationNodeStateMachine.new()
	var locomotion := _build_locomotion(profile)

	state_machine.add_node(
		LOCOMOTION_STATE,
		locomotion,
		Vector2(0.0, 0.0),
	)

	var state_names: Array[StringName] = [LOCOMOTION_STATE]

	_add_optional_state(
		state_machine,
		state_names,
		JUMP_STATE,
		profile.jump_animation,
		Vector2(280.0, -120.0),
	)
	_add_optional_state(
		state_machine,
		state_names,
		FALL_STATE,
		profile.fall_animation,
		Vector2(520.0, 0.0),
	)
	_add_optional_state(
		state_machine,
		state_names,
		LAND_STATE,
		profile.land_animation,
		Vector2(280.0, 120.0),
	)

	_connect_all_states(
		state_machine,
		state_names,
		profile.crossfade_time,
	)

	animation_tree.tree_root = state_machine
	animation_tree.anim_player = animation_tree.get_path_to(
		animation_player
	)

	return OK


static func upgrade_to_directional_locomotion(
	animation_tree: AnimationTree,
	animation_player: AnimationPlayer,
	profile: NucleusDirectionalAnimationProfile3D,
) -> Error:
	if animation_tree == null or animation_player == null or profile == null:
		return ERR_UNCONFIGURED

	if not profile.get_validation_errors(animation_player).is_empty():
		return ERR_INVALID_DATA

	var state_machine := (
		animation_tree.tree_root as AnimationNodeStateMachine
	)

	if (
		state_machine == null
		or not state_machine.has_node(LOCOMOTION_STATE)
	):
		return ERR_UNAVAILABLE

	state_machine.replace_node(
		LOCOMOTION_STATE,
		_build_directional_locomotion(profile),
	)
	return OK


static func configure_velocity_binding(
	binding: NucleusAnimationVelocityBinding3D,
	animation_tree: AnimationTree,
) -> Error:
	if binding == null or animation_tree == null:
		return ERR_INVALID_PARAMETER

	binding.animation_tree = animation_tree
	binding.speed_parameter = SPEED_PARAMETER
	binding.blend_parameter = &""
	binding.blend_magnitude_reference = 0.0
	return OK


static func configure_directional_velocity_binding(
	binding: NucleusAnimationVelocityBinding3D,
	animation_tree: AnimationTree,
	profile: NucleusDirectionalAnimationProfile3D,
) -> Error:
	if (
		binding == null
		or animation_tree == null
		or profile == null
	):
		return ERR_INVALID_PARAMETER

	binding.animation_tree = animation_tree
	binding.speed_parameter = &""
	binding.blend_parameter = DIRECTION_PARAMETER
	binding.normalize_blend_direction = false
	binding.blend_magnitude_reference = profile.reference_speed
	return OK


static func configure_state_binding(
	binding: NucleusAnimationTreeStateBinding,
	animation_tree: AnimationTree,
) -> Error:
	if binding == null or animation_tree == null:
		return ERR_INVALID_PARAMETER

	binding.animation_tree = animation_tree
	binding.playback_parameter = PLAYBACK_PARAMETER
	return OK


static func _build_locomotion(
	profile: NucleusAnimationStarterProfile3D,
) -> AnimationNodeBlendSpace1D:
	var blend_space := AnimationNodeBlendSpace1D.new()
	blend_space.min_space = 0.0
	blend_space.max_space = maxf(profile.run_speed, 0.01)
	blend_space.snap = 0.1
	blend_space.value_label = "Speed"
	blend_space.sync_mode = (
		AnimationNodeBlendSpace1D.SYNC_MODE_INDEPENDENT
	)

	blend_space.add_blend_point(
		_animation_node(profile.idle_animation),
		0.0,
		-1,
		&"Idle",
	)
	blend_space.add_blend_point(
		_animation_node(profile.walk_animation),
		profile.walk_speed,
		-1,
		&"Walk",
	)
	blend_space.add_blend_point(
		_animation_node(profile.run_animation),
		profile.run_speed,
		-1,
		&"Run",
	)
	return blend_space


static func _build_directional_locomotion(
	profile: NucleusDirectionalAnimationProfile3D,
) -> AnimationNodeBlendSpace2D:
	var blend_space := AnimationNodeBlendSpace2D.new()
	blend_space.min_space = Vector2(-1.0, -1.0)
	blend_space.max_space = Vector2(1.0, 1.0)
	blend_space.snap = Vector2(0.1, 0.1)
	blend_space.x_label = "Right"
	blend_space.y_label = "Forward"
	blend_space.auto_triangles = true
	blend_space.sync_mode = (
		AnimationNodeBlendSpace2D.SYNC_MODE_INDEPENDENT
	)

	_add_directional_point(
		blend_space,
		profile.idle_animation,
		Vector2.ZERO,
		&"Idle",
	)
	_add_directional_point(
		blend_space,
		profile.forward_animation,
		Vector2(0.0, 1.0),
		&"Forward",
	)
	_add_directional_point(
		blend_space,
		profile.backward_animation,
		Vector2(0.0, -1.0),
		&"Backward",
	)
	_add_directional_point(
		blend_space,
		profile.left_animation,
		Vector2(-1.0, 0.0),
		&"Left",
	)
	_add_directional_point(
		blend_space,
		profile.right_animation,
		Vector2(1.0, 0.0),
		&"Right",
	)

	const DIAGONAL: float = 0.70710678
	_add_optional_directional_point(
		blend_space,
		profile.forward_left_animation,
		Vector2(-DIAGONAL, DIAGONAL),
		&"ForwardLeft",
	)
	_add_optional_directional_point(
		blend_space,
		profile.forward_right_animation,
		Vector2(DIAGONAL, DIAGONAL),
		&"ForwardRight",
	)
	_add_optional_directional_point(
		blend_space,
		profile.backward_left_animation,
		Vector2(-DIAGONAL, -DIAGONAL),
		&"BackwardLeft",
	)
	_add_optional_directional_point(
		blend_space,
		profile.backward_right_animation,
		Vector2(DIAGONAL, -DIAGONAL),
		&"BackwardRight",
	)

	return blend_space


static func _add_directional_point(
	blend_space: AnimationNodeBlendSpace2D,
	animation_name: StringName,
	position: Vector2,
	point_name: StringName,
) -> void:
	blend_space.add_blend_point(
		_animation_node(animation_name),
		position,
		-1,
		point_name,
	)


static func _add_optional_directional_point(
	blend_space: AnimationNodeBlendSpace2D,
	animation_name: StringName,
	position: Vector2,
	point_name: StringName,
) -> void:
	if animation_name == &"":
		return

	_add_directional_point(
		blend_space,
		animation_name,
		position,
		point_name,
	)


static func _add_optional_state(
	state_machine: AnimationNodeStateMachine,
	state_names: Array[StringName],
	state_name: StringName,
	animation_name: StringName,
	position: Vector2,
) -> void:
	if animation_name == &"":
		return

	state_machine.add_node(
		state_name,
		_animation_node(animation_name),
		position,
	)
	state_names.append(state_name)


static func _connect_all_states(
	state_machine: AnimationNodeStateMachine,
	state_names: Array[StringName],
	crossfade_time: float,
) -> void:
	for from_state: StringName in state_names:
		for to_state: StringName in state_names:
			if from_state == to_state:
				continue

			var transition := AnimationNodeStateMachineTransition.new()
			transition.advance_mode = (
				AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
			)
			transition.xfade_time = maxf(crossfade_time, 0.0)
			transition.reset = true
			state_machine.add_transition(
				from_state,
				to_state,
				transition,
			)


static func _animation_node(
	animation_name: StringName,
) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = animation_name
	return node
