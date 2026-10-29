@tool
class_name NucleusAICharacterSetup3D
extends Node
## Editor-oriented wiring helper for a reusable 3D AI character composition.
##
## It creates/wires plumbing only. Behavior states, utility options, targeting
## rules, action semantics, and animation content remain game-owned.

@export_group("Actor")
@export var actor: CharacterBody3D
@export var motor: NucleusCharacterMotor3D
@export var navigation_agent: NavigationAgent3D
@export var navigation_follower: NucleusNavigationFollower3D
@export var navigation_motion_source: NucleusNavigationMotionSource3D

@export_group("Behavior")
@export var utility_brain: NucleusAIUtilityBrain
@export var state_machine: NucleusStateMachine
@export var state_bridge: NucleusAIStateMachineBridge
@export var targeting_agent: NucleusTargetingAgent

@export_group("Presentation")
@export var movement_facing: NucleusMovementFacing3D
@export var facing_visual_target: Node3D
@export var animation_velocity: NucleusAnimationVelocityBinding3D

@export_group("Creation")
@export var create_motor_if_missing: bool = true
@export var create_follower_if_missing: bool = true
@export var create_motion_source_if_missing: bool = true
@export var create_state_bridge_if_missing: bool = true
@export var create_facing_if_missing: bool = false

@export_group("Processing order")
@export var ensure_navigation_before_motor: bool = true

@export_tool_button("Auto Resolve AI Character")
var resolve_action: Callable = auto_resolve

@export_tool_button("Wire Navigation Locomotion")
var wire_action: Callable = wire_navigation_locomotion

@export_tool_button("Sync Locomotion Speeds")
var sync_speed_action: Callable = sync_locomotion_speeds

@export_tool_button("Print AI Character Report")
var report_action: Callable = print_character_report


func _ready() -> void:
	update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var report := get_character_report()

	for warning: String in report.get(
		"warnings",
		PackedStringArray(),
	):
		warnings.append(warning)

	return warnings


func auto_resolve() -> Error:
	if actor == null:
		actor = get_parent() as CharacterBody3D

	if actor == null:
		update_configuration_warnings()
		return ERR_UNCONFIGURED

	for node: Node in NucleusNodeUtils.descendants(actor):
		if motor == null and node is NucleusCharacterMotor3D:
			motor = node as NucleusCharacterMotor3D
		elif navigation_agent == null and node is NavigationAgent3D:
			navigation_agent = node as NavigationAgent3D
		elif (
			navigation_follower == null
			and node is NucleusNavigationFollower3D
		):
			navigation_follower = node as NucleusNavigationFollower3D
		elif (
			navigation_motion_source == null
			and node is NucleusNavigationMotionSource3D
		):
			navigation_motion_source = (
				node as NucleusNavigationMotionSource3D
			)
		elif utility_brain == null and node is NucleusAIUtilityBrain:
			utility_brain = node as NucleusAIUtilityBrain
		elif state_machine == null and node is NucleusStateMachine:
			state_machine = node as NucleusStateMachine
		elif (
			state_bridge == null
			and node is NucleusAIStateMachineBridge
		):
			state_bridge = node as NucleusAIStateMachineBridge
		elif targeting_agent == null and node is NucleusTargetingAgent:
			targeting_agent = node as NucleusTargetingAgent
		elif (
			movement_facing == null
			and node is NucleusMovementFacing3D
		):
			movement_facing = node as NucleusMovementFacing3D
		elif (
			animation_velocity == null
			and node is NucleusAnimationVelocityBinding3D
		):
			animation_velocity = (
				node as NucleusAnimationVelocityBinding3D
			)

	notify_property_list_changed()
	update_configuration_warnings()
	return OK


func wire_navigation_locomotion() -> Error:
	var error := auto_resolve()

	if error != OK:
		return error

	if motor == null and create_motor_if_missing:
		motor = _create_motor()

	if motor == null or navigation_agent == null:
		update_configuration_warnings()
		return ERR_UNCONFIGURED

	if (
		navigation_follower == null
		and create_follower_if_missing
	):
		navigation_follower = _create_follower()

	if navigation_follower == null:
		update_configuration_warnings()
		return ERR_UNCONFIGURED

	if (
		navigation_motion_source == null
		and create_motion_source_if_missing
	):
		navigation_motion_source = _create_motion_source()

	if navigation_motion_source == null:
		update_configuration_warnings()
		return ERR_UNCONFIGURED

	motor.body = actor
	navigation_follower.agent = navigation_agent
	navigation_follower.origin = actor
	navigation_motion_source.follower = navigation_follower
	motor.motion_source = navigation_motion_source

	if movement_facing == null and create_facing_if_missing:
		movement_facing = _create_facing()

	if movement_facing != null:
		movement_facing.motor = motor

	if animation_velocity != null:
		animation_velocity.body = actor

	_wire_state_bridge_if_possible()
	_sync_processing_order()
	sync_locomotion_speeds()

	notify_property_list_changed()
	update_configuration_warnings()
	return OK


func sync_locomotion_speeds() -> Error:
	if motor == null or navigation_follower == null:
		return ERR_UNCONFIGURED

	var maximum_speed := motor.get_max_planar_speed()
	navigation_follower.movement_speed = maximum_speed

	if (
		navigation_follower.agent != null
		and navigation_follower.synchronize_agent_max_speed
	):
		navigation_follower.agent.max_speed = maximum_speed

	return OK


func get_character_report() -> Dictionary:
	var warnings := PackedStringArray()
	var notes := PackedStringArray()

	if actor == null:
		warnings.append("No CharacterBody3D actor resolved.")

	if motor == null:
		warnings.append("No NucleusCharacterMotor3D resolved.")

	if navigation_agent == null:
		warnings.append("No NavigationAgent3D resolved.")

	if navigation_follower == null:
		warnings.append("No NucleusNavigationFollower3D resolved.")

	if navigation_motion_source == null:
		warnings.append(
			"No NucleusNavigationMotionSource3D resolved."
		)

	if (
		motor != null
		and navigation_motion_source != null
		and motor.motion_source != navigation_motion_source
	):
		warnings.append(
			"CharacterMotor3D is not wired to the resolved navigation "
			+ "motion source."
		)

	if (
		navigation_follower != null
		and navigation_agent != null
		and navigation_follower.agent != navigation_agent
	):
		warnings.append(
			"NavigationFollower3D does not use the resolved NavigationAgent3D."
		)

	if (
		navigation_follower != null
		and actor != null
		and navigation_follower.origin != actor
	):
		warnings.append(
			"NavigationFollower3D origin is not the CharacterBody3D actor."
		)

	if (
		motor != null
		and navigation_follower != null
		and not is_equal_approx(
			navigation_follower.movement_speed,
			motor.get_max_planar_speed(),
		)
	):
		warnings.append(
			"Navigation speed differs from CharacterMotor3D max planar speed."
		)

	if (
		ensure_navigation_before_motor
		and motor != null
		and navigation_follower != null
		and navigation_follower.process_physics_priority
		>= motor.process_physics_priority
	):
		warnings.append(
			"NavigationFollower3D should process before CharacterMotor3D "
			+ "to avoid one-frame intent latency."
		)

	if (
		movement_facing != null
		and motor != null
		and movement_facing.motor != motor
	):
		warnings.append(
			"MovementFacing3D is wired to a different motor."
		)

	if (
		animation_velocity != null
		and actor != null
		and animation_velocity.body != actor
	):
		warnings.append(
			"AnimationVelocityBinding3D reads a different CharacterBody3D."
		)

	if utility_brain != null and state_machine != null:
		if state_bridge == null:
			warnings.append(
				"UtilityBrain and StateMachine exist but no AI state bridge "
				+ "is resolved."
			)
		else:
			if state_bridge.brain != utility_brain:
				warnings.append(
					"AI state bridge uses a different UtilityBrain."
				)
			if state_bridge.state_machine != state_machine:
				warnings.append(
					"AI state bridge uses a different StateMachine."
				)
			if state_bridge.bindings.is_empty():
				warnings.append(
					"AI state bridge has no utility-to-state bindings."
				)

	if (
		navigation_agent != null
		and navigation_agent.avoidance_enabled
	):
		notes.append(
			"Navigation avoidance is enabled. Profile RVO cost for large crowds."
		)

	if (
		utility_brain != null
		and utility_brain.automatic_evaluation
		and utility_brain.evaluation_interval > 0.0
		and utility_brain.update_scheduler == null
	):
		notes.append(
			"UtilityBrain is interval-driven without UpdateScheduler staggering."
		)

	return {
		"warnings": warnings,
		"performance_notes": notes,
	}


func print_character_report() -> void:
	var report := get_character_report()
	var warnings: PackedStringArray = report.get(
		"warnings",
		PackedStringArray(),
	)
	var notes: PackedStringArray = report.get(
		"performance_notes",
		PackedStringArray(),
	)
	var lines := PackedStringArray([
		"Nucleus AI character report",
		"  actor: %s" % str(actor),
		"  motor: %s" % str(motor),
		"  navigation agent: %s" % str(navigation_agent),
		"  navigation follower: %s" % str(navigation_follower),
		"  motion source: %s" % str(navigation_motion_source),
	])

	if warnings.is_empty():
		lines.append("  warnings: none")
	else:
		lines.append("  warnings:")
		for warning: String in warnings:
			lines.append("    - " + warning)

	if not notes.is_empty():
		lines.append("  performance notes:")
		for note: String in notes:
			lines.append("    - " + note)

	print("\n".join(lines))


func _sync_processing_order() -> void:
	if (
		not ensure_navigation_before_motor
		or navigation_follower == null
		or motor == null
	):
		return

	if (
		navigation_follower.process_physics_priority
		>= motor.process_physics_priority
	):
		navigation_follower.process_physics_priority = (
			motor.process_physics_priority - 1
		)


func _wire_state_bridge_if_possible() -> void:
	if utility_brain == null or state_machine == null:
		return

	if state_bridge == null and create_state_bridge_if_missing:
		state_bridge = NucleusAIStateMachineBridge.new()
		state_bridge.name = "AIStateMachineBridge"
		actor.add_child(state_bridge)
		_set_editor_owner(state_bridge)

	if state_bridge != null:
		state_bridge.brain = utility_brain
		state_bridge.state_machine = state_machine


func _create_motor() -> NucleusCharacterMotor3D:
	var node := NucleusCharacterMotor3D.new()
	node.name = "CharacterMotor3D"
	node.body = actor
	actor.add_child(node)
	_set_editor_owner(node)
	return node


func _create_follower() -> NucleusNavigationFollower3D:
	var node := NucleusNavigationFollower3D.new()
	node.name = "NavigationFollower3D"
	node.agent = navigation_agent
	node.origin = actor
	actor.add_child(node)
	_set_editor_owner(node)
	return node


func _create_motion_source() -> NucleusNavigationMotionSource3D:
	var node := NucleusNavigationMotionSource3D.new()
	node.name = "NavigationMotionSource3D"
	node.follower = navigation_follower
	actor.add_child(node)
	_set_editor_owner(node)
	return node


func _create_facing() -> NucleusMovementFacing3D:
	if facing_visual_target == null:
		return null

	var node := NucleusMovementFacing3D.new()
	node.name = "MovementFacing3D"
	node.target = facing_visual_target
	node.motor = motor
	actor.add_child(node)
	_set_editor_owner(node)
	return node


func _set_editor_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return

	if (
		get_tree() == null
		or get_tree().edited_scene_root == null
	):
		return

	node.owner = get_tree().edited_scene_root
