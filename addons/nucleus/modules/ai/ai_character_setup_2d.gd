@tool
class_name NucleusAICharacterSetup2D
extends Node
## Inspector wiring for AI actors that share CharacterMotor2D with players.
## Navigation geometry, decisions, states and combat actions remain game-owned.

@export_group("Actor")
@export var actor: CharacterBody2D
@export var motor: NucleusCharacterMotor2D
@export var navigation_agent: NavigationAgent2D
@export var navigation_follower: NucleusNavigationFollower2D
@export var navigation_motion_source: NucleusNavigationMotionSource2D

@export_group("Behavior")
@export var utility_brain: NucleusAIUtilityBrain
@export var state_machine: NucleusStateMachine
@export var state_bridge: NucleusAIStateMachineBridge
@export var targeting_agent: NucleusTargetingAgent

@export_group("Presentation")
@export var movement_facing: NucleusMovementFacing2D
@export var facing_visual_target: Node2D
@export var animation_velocity: NucleusAnimationVelocityBinding2D

@export_group("Creation")
@export var create_motor_if_missing: bool = true
@export var create_follower_if_missing: bool = true
@export var create_motion_source_if_missing: bool = true
@export var create_state_bridge_if_missing: bool = true
@export var create_facing_if_missing: bool = false

@export_group("Processing order")
@export var ensure_navigation_before_motor: bool = true

@export_tool_button("Auto Resolve 2D AI Character")
var resolve_action: Callable = auto_resolve

@export_tool_button("Wire 2D Navigation Locomotion")
var wire_action: Callable = wire_navigation_locomotion

@export_tool_button("Sync 2D Locomotion Speeds")
var sync_speed_action: Callable = sync_locomotion_speeds

@export_tool_button("Print 2D AI Character Report")
var report_action: Callable = print_character_report


func _ready() -> void:
	update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	return get_character_report().get("warnings", PackedStringArray())


func auto_resolve() -> Error:
	if actor == null:
		actor = get_parent() as CharacterBody2D
	if actor == null:
		update_configuration_warnings()
		return ERR_UNCONFIGURED
	for node: Node in NucleusNodeUtils.descendants(actor):
		if motor == null and node is NucleusCharacterMotor2D:
			motor = node as NucleusCharacterMotor2D
		elif navigation_agent == null and node is NavigationAgent2D:
			navigation_agent = node as NavigationAgent2D
		elif navigation_follower == null and node is NucleusNavigationFollower2D:
			navigation_follower = node as NucleusNavigationFollower2D
		elif (
			navigation_motion_source == null
			and node is NucleusNavigationMotionSource2D
		):
			navigation_motion_source = node as NucleusNavigationMotionSource2D
		elif utility_brain == null and node is NucleusAIUtilityBrain:
			utility_brain = node as NucleusAIUtilityBrain
		elif state_machine == null and node is NucleusStateMachine:
			state_machine = node as NucleusStateMachine
		elif state_bridge == null and node is NucleusAIStateMachineBridge:
			state_bridge = node as NucleusAIStateMachineBridge
		elif targeting_agent == null and node is NucleusTargetingAgent:
			targeting_agent = node as NucleusTargetingAgent
		elif movement_facing == null and node is NucleusMovementFacing2D:
			movement_facing = node as NucleusMovementFacing2D
		elif animation_velocity == null and node is NucleusAnimationVelocityBinding2D:
			animation_velocity = node as NucleusAnimationVelocityBinding2D
	notify_property_list_changed()
	update_configuration_warnings()
	return OK


func wire_navigation_locomotion() -> Error:
	var error: Error = auto_resolve()
	if error != OK:
		return error
	if motor == null and create_motor_if_missing:
		motor = _create_motor()
	if motor == null or navigation_agent == null:
		update_configuration_warnings()
		return ERR_UNCONFIGURED
	if navigation_follower == null and create_follower_if_missing:
		navigation_follower = _create_follower()
	if navigation_follower == null:
		update_configuration_warnings()
		return ERR_UNCONFIGURED
	if navigation_motion_source == null and create_motion_source_if_missing:
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
	var maximum_speed: float = motor.get_max_speed()
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
		warnings.append("No CharacterBody2D actor resolved.")
	if motor == null:
		warnings.append("No CharacterMotor2D resolved.")
	if navigation_agent == null:
		warnings.append("No NavigationAgent2D resolved.")
	if navigation_follower == null:
		warnings.append("No NavigationFollower2D resolved.")
	if navigation_motion_source == null:
		warnings.append("No NavigationMotionSource2D resolved.")
	if motor != null and motor.body != actor:
		warnings.append("CharacterMotor2D uses a different actor.")
	if motor != null and motor.motion_source != navigation_motion_source:
		warnings.append("CharacterMotor2D does not use the navigation motion source.")
	if navigation_follower != null and navigation_follower.agent != navigation_agent:
		warnings.append("NavigationFollower2D uses a different NavigationAgent2D.")
	if navigation_follower != null and navigation_follower.origin != actor:
		warnings.append("NavigationFollower2D origin differs from actor.")
	if (
		navigation_motion_source != null
		and navigation_motion_source.follower != navigation_follower
	):
		warnings.append("NavigationMotionSource2D uses a different follower.")
	if motor != null and navigation_follower != null:
		if not is_equal_approx(
			navigation_follower.movement_speed, motor.get_max_speed()
		):
			warnings.append("Navigation speed differs from CharacterMotor2D max speed.")
		if (
			ensure_navigation_before_motor
			and navigation_follower.process_physics_priority
			>= motor.process_physics_priority
		):
			warnings.append("NavigationFollower2D should process before CharacterMotor2D.")
	if movement_facing != null:
		if movement_facing.motor != motor:
			warnings.append("MovementFacing2D uses a different motor.")
		if movement_facing.target == null:
			warnings.append("MovementFacing2D has no visual pivot.")
	if animation_velocity != null and animation_velocity.body != actor:
		warnings.append("AnimationVelocityBinding2D reads a different actor.")
	if utility_brain != null and state_machine != null:
		if state_bridge == null:
			warnings.append("UtilityBrain/StateMachine require a state bridge.")
		else:
			if state_bridge.brain != utility_brain:
				warnings.append("AI state bridge uses a different UtilityBrain.")
			if state_bridge.state_machine != state_machine:
				warnings.append("AI state bridge uses a different StateMachine.")
			if state_bridge.bindings.is_empty():
				warnings.append("AI state bridge has no authored bindings.")
	if navigation_agent != null and navigation_agent.avoidance_enabled:
		notes.append("Native avoidance costs CPU; profile large crowds.")
	if (
		utility_brain != null
		and utility_brain.automatic_evaluation
		and utility_brain.evaluation_interval > 0.0
		and utility_brain.update_scheduler == null
	):
		notes.append("Consider UpdateScheduler for staggered UtilityBrain evaluation.")
	if actor != null and actor.motion_mode == CharacterBody2D.MOTION_MODE_GROUNDED:
		notes.append("Grounded motor discards vertical navigation intent.")
	return {"warnings": warnings, "performance_notes": notes}


func print_character_report() -> void:
	var report: Dictionary = get_character_report()
	var lines := PackedStringArray(["Nucleus 2D AI character report"])
	var warnings: PackedStringArray = report.get("warnings", PackedStringArray())
	var notes: PackedStringArray = report.get("performance_notes", PackedStringArray())
	if warnings.is_empty():
		lines.append("  warnings: none")
	else:
		for warning: String in warnings:
			lines.append("  warning: " + warning)
	for note: String in notes:
		lines.append("  note: " + note)
	print("\n".join(lines))


func _sync_processing_order() -> void:
	if (
		not ensure_navigation_before_motor
		or navigation_follower == null
		or motor == null
	):
		return
	if navigation_follower.process_physics_priority >= motor.process_physics_priority:
		navigation_follower.process_physics_priority = motor.process_physics_priority - 1


func _wire_state_bridge_if_possible() -> void:
	if utility_brain == null or state_machine == null:
		return
	if state_bridge == null and create_state_bridge_if_missing:
		state_bridge = NucleusAIStateMachineBridge.new()
		state_bridge.name = "AIStateMachineBridge"
		state_bridge.brain = utility_brain
		state_bridge.state_machine = state_machine
		actor.add_child(state_bridge)
		_set_editor_owner(state_bridge)
	if state_bridge != null:
		state_bridge.brain = utility_brain
		state_bridge.state_machine = state_machine


func _create_motor() -> NucleusCharacterMotor2D:
	var node := NucleusCharacterMotor2D.new()
	node.name = "CharacterMotor2D"
	node.body = actor
	actor.add_child(node)
	_set_editor_owner(node)
	return node


func _create_follower() -> NucleusNavigationFollower2D:
	var node := NucleusNavigationFollower2D.new()
	node.name = "NavigationFollower2D"
	node.agent = navigation_agent
	node.origin = actor
	actor.add_child(node)
	_set_editor_owner(node)
	return node


func _create_motion_source() -> NucleusNavigationMotionSource2D:
	var node := NucleusNavigationMotionSource2D.new()
	node.name = "NavigationMotionSource2D"
	node.follower = navigation_follower
	actor.add_child(node)
	_set_editor_owner(node)
	return node


func _create_facing() -> NucleusMovementFacing2D:
	if facing_visual_target == null:
		return null
	var node := NucleusMovementFacing2D.new()
	node.name = "MovementFacing2D"
	node.target = facing_visual_target
	node.motor = motor
	actor.add_child(node)
	_set_editor_owner(node)
	return node


func _set_editor_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return
	if get_tree() == null or get_tree().edited_scene_root == null:
		return
	node.owner = get_tree().edited_scene_root
