@tool
class_name NucleusCharacterAnimationSetup3D
extends Node
## Editor-oriented bootstrap helper for imported 3D character animation.
##
## Generated AnimationTree data remains normal editable Godot content.

@export_group("Imported visual")
@export var visual_root: Node
@export var skeleton: Skeleton3D
@export var animation_player: AnimationPlayer

@export_group("Runtime integration")
@export var animation_tree: AnimationTree
@export var velocity_binding: NucleusAnimationVelocityBinding3D
@export var state_binding: NucleusAnimationTreeStateBinding

@export_group("Starter graph")
@export var starter_profile: NucleusAnimationStarterProfile3D
@export var create_animation_tree_if_missing: bool = true
@export var create_velocity_binding_if_missing: bool = true
@export var replace_existing_tree: bool = false

@export_group("Directional locomotion")
@export var directional_profile: NucleusDirectionalAnimationProfile3D

@export_tool_button("Auto Resolve Rig")
var resolve_rig_action: Callable = auto_resolve

@export_tool_button("Suggest Common Clips")
var suggest_clips_action: Callable = suggest_common_clips

@export_tool_button("Build Starter Tree")
var build_tree_action: Callable = build_starter_tree

@export_tool_button("Suggest Directional Clips")
var suggest_directional_action: Callable = suggest_directional_clips

@export_tool_button("Upgrade Locomotion To Directional")
var upgrade_directional_action: Callable = upgrade_directional_locomotion

@export_tool_button("Print Rig Report")
var print_report_action: Callable = print_rig_report


func _ready() -> void:
	update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var scope := _get_visual_scope()

	if scope == null:
		warnings.append(
			"Assign visual_root or place this setup helper below the character scene."
		)
		return warnings

	var report := NucleusAnimationRigInspector3D.inspect(
		scope,
		starter_profile,
	)

	for warning: String in report.get("warnings", PackedStringArray()):
		warnings.append(warning)

	if animation_tree == null:
		warnings.append(
			"No AnimationTree assigned. Build Starter Tree can create one."
		)

	if starter_profile == null:
		warnings.append(
			"No starter profile assigned. Suggest Common Clips can create one."
		)

	if (
		directional_profile != null
		and animation_player != null
	):
		for error: String in directional_profile.get_validation_errors(
			animation_player
		):
			warnings.append("Directional profile: %s" % error)

	return warnings


func auto_resolve() -> Error:
	var scope := _get_visual_scope()

	if scope == null:
		return ERR_UNCONFIGURED

	if skeleton == null:
		skeleton = NucleusAnimationRigInspector3D.find_skeleton(scope)

	if animation_player == null:
		animation_player = (
			NucleusAnimationRigInspector3D.find_animation_player(scope)
		)

	var scene_scope := get_parent()

	if scene_scope != null:
		if animation_tree == null:
			animation_tree = _find_descendant_animation_tree(
				scene_scope
			)

		if velocity_binding == null:
			velocity_binding = _find_descendant_velocity_binding(
				scene_scope
			)

		if state_binding == null:
			state_binding = _find_descendant_state_binding(
				scene_scope
			)

	if starter_profile == null:
		starter_profile = NucleusAnimationStarterProfile3D.new()

	notify_property_list_changed()
	update_configuration_warnings()

	return (
		OK
		if animation_player != null and skeleton != null
		else ERR_UNCONFIGURED
	)


func suggest_common_clips() -> int:
	auto_resolve()

	if animation_player == null:
		return 0

	if starter_profile == null:
		starter_profile = NucleusAnimationStarterProfile3D.new()

	var changed := starter_profile.suggest_common_clips(
		animation_player
	)

	notify_property_list_changed()
	update_configuration_warnings()
	return changed


func suggest_directional_clips() -> int:
	auto_resolve()

	if animation_player == null:
		return 0

	if directional_profile == null:
		directional_profile = NucleusDirectionalAnimationProfile3D.new()

	var changed := directional_profile.suggest_common_clips(
		animation_player
	)

	notify_property_list_changed()
	update_configuration_warnings()
	return changed


func build_starter_tree() -> Error:
	auto_resolve()

	if animation_player == null:
		return ERR_UNCONFIGURED

	if starter_profile == null:
		starter_profile = NucleusAnimationStarterProfile3D.new()

	starter_profile.suggest_common_clips(animation_player)

	if animation_tree == null and create_animation_tree_if_missing:
		animation_tree = _create_animation_tree()

	if animation_tree == null:
		return ERR_UNCONFIGURED

	var error := NucleusAnimationTreeBuilder3D.build_starter_tree(
		animation_tree,
		animation_player,
		starter_profile,
		replace_existing_tree,
	)

	if error != OK:
		update_configuration_warnings()
		return error

	if (
		velocity_binding == null
		and create_velocity_binding_if_missing
	):
		velocity_binding = _create_velocity_binding()

	if velocity_binding != null:
		NucleusAnimationTreeBuilder3D.configure_velocity_binding(
			velocity_binding,
			animation_tree,
		)

	if state_binding != null:
		NucleusAnimationTreeBuilder3D.configure_state_binding(
			state_binding,
			animation_tree,
		)

	notify_property_list_changed()
	update_configuration_warnings()
	return OK


func upgrade_directional_locomotion() -> Error:
	auto_resolve()

	if (
		animation_tree == null
		or animation_player == null
	):
		return ERR_UNCONFIGURED

	if directional_profile == null:
		directional_profile = NucleusDirectionalAnimationProfile3D.new()

	directional_profile.suggest_common_clips(animation_player)

	var error := (
		NucleusAnimationTreeBuilder3D.upgrade_to_directional_locomotion(
			animation_tree,
			animation_player,
			directional_profile,
		)
	)

	if error != OK:
		update_configuration_warnings()
		return error

	if (
		velocity_binding == null
		and create_velocity_binding_if_missing
	):
		velocity_binding = _create_velocity_binding()

	if velocity_binding != null:
		NucleusAnimationTreeBuilder3D.configure_directional_velocity_binding(
			velocity_binding,
			animation_tree,
			directional_profile,
		)

	notify_property_list_changed()
	update_configuration_warnings()
	return OK


func get_rig_report() -> Dictionary:
	var report := NucleusAnimationRigInspector3D.inspect(
		_get_visual_scope(),
		starter_profile,
	)
	report["animation_tree"] = animation_tree
	report["velocity_binding"] = velocity_binding
	report["state_binding"] = state_binding
	report["starter_profile"] = starter_profile
	report["directional_profile"] = directional_profile
	return report


func print_rig_report() -> void:
	var report := get_rig_report()
	var lines := PackedStringArray([
		"Nucleus character animation report",
		"  skeletons: %d" % int(report.get("skeleton_count", 0)),
		"  bones: %d" % int(report.get("bone_count", 0)),
		"  animation players: %d"
		% int(report.get("animation_player_count", 0)),
		"  clips: %s" % str(report.get("animations", [])),
	])

	var warnings: PackedStringArray = report.get(
		"warnings",
		PackedStringArray(),
	)

	if warnings.is_empty():
		lines.append("  warnings: none")
	else:
		lines.append("  warnings:")
		for warning: String in warnings:
			lines.append("    - " + warning)

	print("\n".join(lines))


func _get_visual_scope() -> Node:
	if visual_root != null:
		return visual_root

	return get_parent()


func _create_animation_tree() -> AnimationTree:
	var parent := get_parent()

	if parent == null:
		return null

	var tree := AnimationTree.new()
	tree.name = "AnimationTree"
	parent.add_child(tree)
	_set_editor_owner(tree)
	return tree


func _create_velocity_binding() -> NucleusAnimationVelocityBinding3D:
	var body := _find_character_body()

	if body == null:
		return null

	var binding := NucleusAnimationVelocityBinding3D.new()
	binding.name = "AnimationVelocity3D"
	binding.body = body
	binding.animation_tree = animation_tree
	body.add_child(binding)
	_set_editor_owner(binding)
	return binding


func _find_character_body() -> CharacterBody3D:
	var current := get_parent()

	while current != null:
		if current is CharacterBody3D:
			return current as CharacterBody3D
		current = current.get_parent()

	return null


func _find_descendant_animation_tree(root: Node) -> AnimationTree:
	for node: Node in NucleusNodeUtils.descendants(root):
		if node is AnimationTree:
			return node as AnimationTree
	return null


func _find_descendant_velocity_binding(
	root: Node,
) -> NucleusAnimationVelocityBinding3D:
	for node: Node in NucleusNodeUtils.descendants(root):
		if node is NucleusAnimationVelocityBinding3D:
			return node as NucleusAnimationVelocityBinding3D
	return null


func _find_descendant_state_binding(
	root: Node,
) -> NucleusAnimationTreeStateBinding:
	for node: Node in NucleusNodeUtils.descendants(root):
		if node is NucleusAnimationTreeStateBinding:
			return node as NucleusAnimationTreeStateBinding
	return null


func _set_editor_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return

	if (
		get_tree() == null
		or get_tree().edited_scene_root == null
	):
		return

	node.owner = get_tree().edited_scene_root
