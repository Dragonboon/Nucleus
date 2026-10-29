@tool
class_name NucleusRagdollSetup3D
extends Node
## Editor-oriented humanoid ragdoll bootstrap helper.
##
## The helper creates normal editable Godot physical-bone content and refuses to
## overwrite an existing PhysicalBoneSimulator3D.

@export_group("Rig")
@export var visual_root: Node
@export var skeleton: Skeleton3D
## Optional preferred mapping source. Use the same humanoid BoneMap authored
## during import/retarget setup when convenient.
@export var bone_map: BoneMap
## Optional profile-bone -> skeleton-bone overrides.
@export var manual_bone_overrides: Dictionary = {}

@export_group("Authoring")
@export var ragdoll_profile: NucleusHumanoidRagdollProfile3D
@export var simulator: PhysicalBoneSimulator3D

@export_group("Runtime wiring")
@export var ragdoll_controller: NucleusRagdollController3D
@export var animation_tree: AnimationTree
@export var create_runtime_controller_if_missing: bool = true

@export_tool_button("Auto Resolve Ragdoll Rig")
var resolve_action: Callable = auto_resolve

@export_tool_button("Build Starter Ragdoll")
var build_action: Callable = build_starter_ragdoll

@export_tool_button("Wire Runtime Controller")
var wire_controller_action: Callable = wire_runtime_controller

@export_tool_button("Print Ragdoll Report")
var print_report_action: Callable = print_ragdoll_report


func _ready() -> void:
	update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	var scope: Node = _get_visual_scope()

	if scope == null:
		warnings.append(
			"Assign visual_root or place this helper near the character visual."
		)
		return warnings

	var resolved_skeleton: Skeleton3D = skeleton

	if resolved_skeleton == null:
		resolved_skeleton = (
			NucleusAnimationRigInspector3D.find_skeleton(scope)
		)

	if resolved_skeleton == null:
		warnings.append("No Skeleton3D found for ragdoll authoring.")
		return warnings

	var resolved_profile: NucleusHumanoidRagdollProfile3D = (
		ragdoll_profile
	)

	if resolved_profile == null:
		resolved_profile = NucleusHumanoidRagdollProfile3D.new()

	var report: Dictionary = NucleusRagdollRigInspector3D.inspect(
		resolved_skeleton,
		bone_map,
		manual_bone_overrides,
		resolved_profile,
	)
	var report_warnings: PackedStringArray = PackedStringArray(
		report.get(
			"warnings",
			PackedStringArray(),
		)
	)

	for warning_text: String in report_warnings:
		warnings.append(warning_text)

	var existing_simulator: PhysicalBoneSimulator3D = (
		report.get("simulator") as PhysicalBoneSimulator3D
	)

	if existing_simulator != null:
		warnings.append(
			"A PhysicalBoneSimulator3D already exists. Build Starter Ragdoll "
			+ "will not overwrite it."
		)

	return warnings


func auto_resolve() -> Error:
	var scope: Node = _get_visual_scope()

	if scope == null:
		return ERR_UNCONFIGURED

	if skeleton == null:
		skeleton = NucleusAnimationRigInspector3D.find_skeleton(scope)

	if skeleton == null:
		update_configuration_warnings()
		return ERR_UNCONFIGURED

	if ragdoll_profile == null:
		ragdoll_profile = NucleusHumanoidRagdollProfile3D.new()

	simulator = NucleusRagdollRigInspector3D.find_simulator(
		skeleton
	)

	var scene_scope: Node = get_parent()

	if scene_scope != null:
		if ragdoll_controller == null:
			ragdoll_controller = _find_ragdoll_controller(
				scene_scope
			)

		if animation_tree == null:
			animation_tree = _find_animation_tree(scene_scope)

	notify_property_list_changed()
	update_configuration_warnings()
	return OK


func build_starter_ragdoll() -> Error:
	var resolve_error: Error = auto_resolve()

	if resolve_error != OK or skeleton == null:
		return ERR_UNCONFIGURED

	if simulator != null:
		return ERR_ALREADY_EXISTS

	var scene_owner: Node = _get_editor_scene_owner()
	var build_error: Error = NucleusRagdollBuilder3D.build_humanoid(
		skeleton,
		ragdoll_profile,
		bone_map,
		manual_bone_overrides,
		scene_owner,
	)

	if build_error != OK:
		update_configuration_warnings()
		return build_error

	simulator = NucleusRagdollRigInspector3D.find_simulator(
		skeleton
	)

	if create_runtime_controller_if_missing:
		wire_runtime_controller()

	notify_property_list_changed()
	update_configuration_warnings()
	return OK


func wire_runtime_controller() -> Error:
	auto_resolve()

	if simulator == null:
		return ERR_UNCONFIGURED

	if ragdoll_controller == null:
		if not create_runtime_controller_if_missing:
			return ERR_UNCONFIGURED

		var controller_parent: Node = get_parent()

		if controller_parent == null:
			return ERR_UNCONFIGURED

		ragdoll_controller = NucleusRagdollController3D.new()
		ragdoll_controller.name = "RagdollController3D"
		controller_parent.add_child(ragdoll_controller)
		_set_editor_owner(ragdoll_controller)

	ragdoll_controller.simulator = simulator

	if animation_tree != null:
		ragdoll_controller.animation_tree = animation_tree

	notify_property_list_changed()
	update_configuration_warnings()
	return OK


func get_ragdoll_report() -> Dictionary:
	auto_resolve()

	if skeleton == null:
		return {
			"warnings": PackedStringArray([
				"No Skeleton3D resolved.",
			]),
		}

	return NucleusRagdollRigInspector3D.inspect(
		skeleton,
		bone_map,
		manual_bone_overrides,
		ragdoll_profile,
	)


func print_ragdoll_report() -> void:
	var report: Dictionary = get_ragdoll_report()
	var lines: PackedStringArray = PackedStringArray([
		"Nucleus humanoid ragdoll report",
		"  skeleton bones: %d"
		% int(report.get("bone_count", 0)),
		"  required mapping: %d/%d"
		% [
			int(report.get("mapped_required_count", 0)),
			int(report.get("required_count", 0)),
		],
		"  mapped starter parts: %d"
		% int(report.get("mapped_count", 0)),
		"  existing physical bones: %d"
		% int(report.get("physical_bone_count", 0)),
		"  existing physical mass: %.2f"
		% float(report.get("total_physical_mass", 0.0)),
	])

	var mapping_value: Variant = report.get("mapping", {})
	var mapping: Dictionary = {}

	if mapping_value is Dictionary:
		mapping = mapping_value

	var source_value: Variant = report.get("mapping_sources", {})
	var mapping_sources: Dictionary = {}

	if source_value is Dictionary:
		mapping_sources = source_value

	if not mapping.is_empty():
		lines.append("  mapping:")

		for profile_bone: StringName in (
			ragdoll_profile.get_profile_bones()
		):
			if not mapping.has(profile_bone):
				continue

			lines.append(
				"    %s -> %s (%s)"
				% [
					String(profile_bone),
					str(mapping[profile_bone]),
					str(mapping_sources.get(
						profile_bone,
						&"unknown",
					)),
				]
			)

	var warning_values: PackedStringArray = PackedStringArray(
		report.get(
			"warnings",
			PackedStringArray(),
		)
	)

	if warning_values.is_empty():
		lines.append("  warnings: none")
	else:
		lines.append("  warnings:")

		for warning_text: String in warning_values:
			lines.append("    - " + warning_text)

	print("\n".join(lines))


func _get_visual_scope() -> Node:
	if visual_root != null:
		return visual_root

	return get_parent()


func _find_ragdoll_controller(
	root: Node,
) -> NucleusRagdollController3D:
	if root is NucleusRagdollController3D:
		return root as NucleusRagdollController3D

	for node: Node in NucleusNodeUtils.descendants(root):
		if node is NucleusRagdollController3D:
			return node as NucleusRagdollController3D

	return null


func _find_animation_tree(root: Node) -> AnimationTree:
	if root is AnimationTree:
		return root as AnimationTree

	for node: Node in NucleusNodeUtils.descendants(root):
		if node is AnimationTree:
			return node as AnimationTree

	return null


func _get_editor_scene_owner() -> Node:
	if not Engine.is_editor_hint():
		return null

	if get_tree() == null:
		return null

	return get_tree().edited_scene_root


func _set_editor_owner(generated_node: Node) -> void:
	var scene_owner: Node = _get_editor_scene_owner()

	if scene_owner == null:
		return

	generated_node.owner = scene_owner
