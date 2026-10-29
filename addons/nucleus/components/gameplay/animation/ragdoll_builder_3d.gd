class_name NucleusRagdollBuilder3D
extends RefCounted
## Non-destructive authoring builder for native Godot humanoid ragdolls.
##
## The builder creates ordinary PhysicalBoneSimulator3D/PhysicalBone3D content.
## It refuses to overwrite an existing simulator.

static func build_humanoid(
	skeleton: Skeleton3D,
	profile: NucleusHumanoidRagdollProfile3D,
	bone_map: BoneMap = null,
	manual_overrides: Dictionary = {},
	scene_owner: Node = null,
) -> Error:
	if skeleton == null or profile == null:
		return ERR_INVALID_PARAMETER

	if NucleusRagdollRigInspector3D.find_simulator(skeleton) != null:
		return ERR_ALREADY_EXISTS

	var mapping: Dictionary = (
		NucleusRagdollRigInspector3D.resolve_humanoid_mapping(
			skeleton,
			bone_map,
			manual_overrides,
			profile,
		)
	)

	if not _has_required_mapping(profile, mapping):
		return ERR_UNCONFIGURED

	var measurements: Dictionary = _compute_measurements(
		skeleton,
		mapping,
		profile,
	)

	if measurements.is_empty():
		return ERR_CANT_CREATE

	var total_fraction: float = _mapped_mass_fraction(
		profile,
		mapping,
	)

	if total_fraction <= 0.0001:
		return ERR_CANT_CREATE

	var simulator: PhysicalBoneSimulator3D = (
		PhysicalBoneSimulator3D.new()
	)
	simulator.name = "PhysicalBoneSimulator3D"
	skeleton.add_child(simulator)

	var resolved_owner: Node = _resolve_scene_owner(
		skeleton,
		scene_owner,
	)
	_set_owner_if_valid(simulator, resolved_owner)

	var shape_cache: Dictionary = {}
	var created_count: int = 0

	for profile_bone: StringName in profile.get_profile_bones():
		if not mapping.has(profile_bone):
			continue

		if not measurements.has(profile_bone):
			continue

		var skeleton_name: StringName = StringName(
			str(mapping[profile_bone])
		)
		var measurement_value: Variant = measurements[profile_bone]
		var measurement: Dictionary = {}

		if measurement_value is Dictionary:
			measurement = measurement_value
		else:
			continue

		var mass_fraction: float = (
			profile.get_mass_fraction(profile_bone)
			/ total_fraction
		)
		var physical_bone: PhysicalBone3D = _create_physical_bone(
			skeleton,
			skeleton_name,
			profile_bone,
			measurement,
			profile,
			shape_cache,
			mass_fraction,
		)

		simulator.add_child(physical_bone)
		_set_owner_if_valid(physical_bone, resolved_owner)

		for child: Node in physical_bone.get_children():
			_set_owner_if_valid(child, resolved_owner)

		created_count += 1

	if created_count <= 0:
		skeleton.remove_child(simulator)
		simulator.free()
		return ERR_CANT_CREATE

	return OK


static func _has_required_mapping(
	profile: NucleusHumanoidRagdollProfile3D,
	mapping: Dictionary,
) -> bool:
	for profile_bone: StringName in profile.get_required_profile_bones():
		if not mapping.has(profile_bone):
			return false

	return true


static func _mapped_mass_fraction(
	profile: NucleusHumanoidRagdollProfile3D,
	mapping: Dictionary,
) -> float:
	var total_fraction: float = 0.0

	for profile_bone: StringName in profile.get_profile_bones():
		if mapping.has(profile_bone):
			total_fraction += profile.get_mass_fraction(profile_bone)

	return total_fraction


static func _compute_measurements(
	skeleton: Skeleton3D,
	mapping: Dictionary,
	profile: NucleusHumanoidRagdollProfile3D,
) -> Dictionary:
	var results: Dictionary = {}
	var hip_width: float = _pair_width(
		skeleton,
		mapping,
		NucleusHumanoidRagdollProfile3D.LEFT_UPPER_LEG,
		NucleusHumanoidRagdollProfile3D.RIGHT_UPPER_LEG,
	)
	var shoulder_width: float = _pair_width(
		skeleton,
		mapping,
		NucleusHumanoidRagdollProfile3D.LEFT_SHOULDER,
		NucleusHumanoidRagdollProfile3D.RIGHT_SHOULDER,
	)

	if shoulder_width <= 0.001:
		shoulder_width = _pair_width(
			skeleton,
			mapping,
			NucleusHumanoidRagdollProfile3D.LEFT_UPPER_ARM,
			NucleusHumanoidRagdollProfile3D.RIGHT_UPPER_ARM,
		)

	for profile_bone: StringName in profile.get_profile_bones():
		if not mapping.has(profile_bone):
			continue

		var skeleton_name: StringName = StringName(
			str(mapping[profile_bone])
		)
		var bone_index: int = skeleton.find_bone(
			String(skeleton_name)
		)

		if bone_index < 0:
			continue

		var target: Dictionary = _get_bone_target(
			skeleton,
			bone_index,
			profile_bone,
			mapping,
			profile,
		)
		var target_length: float = float(
			target.get("length", 0.0)
		)

		if target_length <= 0.0:
			continue

		results[profile_bone] = {
			"bone_index": bone_index,
			"length": target_length,
			"target_global": target.get(
				"target_global",
				Vector3.ZERO,
			),
			"hip_width": hip_width,
			"shoulder_width": shoulder_width,
		}

	return results


static func _pair_width(
	skeleton: Skeleton3D,
	mapping: Dictionary,
	left_profile_bone: StringName,
	right_profile_bone: StringName,
) -> float:
	if (
		not mapping.has(left_profile_bone)
		or not mapping.has(right_profile_bone)
	):
		return 0.0

	var left_name: String = str(mapping[left_profile_bone])
	var right_name: String = str(mapping[right_profile_bone])
	var left_index: int = skeleton.find_bone(left_name)
	var right_index: int = skeleton.find_bone(right_name)

	if left_index < 0 or right_index < 0:
		return 0.0

	var left_position: Vector3 = (
		skeleton.get_bone_global_rest(left_index).origin
	)
	var right_position: Vector3 = (
		skeleton.get_bone_global_rest(right_index).origin
	)
	return left_position.distance_to(right_position)


static func _get_bone_target(
	skeleton: Skeleton3D,
	bone_index: int,
	profile_bone: StringName,
	mapping: Dictionary,
	profile: NucleusHumanoidRagdollProfile3D,
) -> Dictionary:
	var bone_position: Vector3 = (
		skeleton.get_bone_global_rest(bone_index).origin
	)

	if profile_bone in [
		NucleusHumanoidRagdollProfile3D.LEFT_HAND,
		NucleusHumanoidRagdollProfile3D.RIGHT_HAND,
	]:
		var hand_target: Dictionary = _get_hand_target(
			skeleton,
			bone_index,
		)

		if float(hand_target.get("length", 0.0)) > 0.001:
			return hand_target

	for target_profile_bone: StringName in (
		profile.get_target_candidates(profile_bone)
	):
		if not mapping.has(target_profile_bone):
			continue

		var target_name: String = str(
			mapping[target_profile_bone]
		)
		var target_index: int = skeleton.find_bone(target_name)

		if target_index < 0:
			continue

		var target_position: Vector3 = (
			skeleton.get_bone_global_rest(target_index).origin
		)
		var child_target: Dictionary = _target_through_child_chain(
			skeleton,
			bone_index,
			target_index,
			bone_position,
			target_position,
		)

		if not child_target.is_empty():
			return child_target

	if profile_bone == NucleusHumanoidRagdollProfile3D.HEAD:
		return _estimate_from_parent(
			skeleton,
			bone_index,
			0.65,
			profile.minimum_bone_length,
		)

	var children: PackedInt32Array = skeleton.get_bone_children(
		bone_index
	)

	if not children.is_empty():
		var child_index: int = children[0]
		var child_position: Vector3 = (
			skeleton.get_bone_global_rest(child_index).origin
		)
		var child_length: float = bone_position.distance_to(
			child_position
		)

		if child_length > 0.001:
			return {
				"length": child_length,
				"target_global": child_position,
			}

	return _estimate_from_parent(
		skeleton,
		bone_index,
		0.6,
		profile.minimum_bone_length,
	)


static func _target_through_child_chain(
	skeleton: Skeleton3D,
	bone_index: int,
	target_index: int,
	bone_position: Vector3,
	target_position: Vector3,
) -> Dictionary:
	var children: PackedInt32Array = skeleton.get_bone_children(
		bone_index
	)

	if children.has(target_index):
		return {
			"length": bone_position.distance_to(target_position),
			"target_global": target_position,
		}

	for child_index: int in children:
		if not _is_ancestor_of(
			skeleton,
			child_index,
			target_index,
		):
			continue

		var child_position: Vector3 = (
			skeleton.get_bone_global_rest(child_index).origin
		)
		var child_length: float = bone_position.distance_to(
			child_position
		)

		if child_length > 0.001:
			return {
				"length": child_length,
				"target_global": child_position,
			}

	return {}


static func _estimate_from_parent(
	skeleton: Skeleton3D,
	bone_index: int,
	length_scale: float,
	minimum_length: float,
) -> Dictionary:
	var bone_position: Vector3 = (
		skeleton.get_bone_global_rest(bone_index).origin
	)
	var parent_index: int = skeleton.get_bone_parent(bone_index)

	if parent_index >= 0:
		var parent_position: Vector3 = (
			skeleton.get_bone_global_rest(parent_index).origin
		)
		var parent_direction: Vector3 = (
			bone_position - parent_position
		)
		var parent_length: float = parent_direction.length()

		if parent_length > 0.001:
			var estimated_length: float = maxf(
				parent_length * length_scale,
				minimum_length,
			)
			return {
				"length": estimated_length,
				"target_global": (
					bone_position
					+ parent_direction.normalized()
					* estimated_length
				),
			}

	return {
		"length": minimum_length,
		"target_global": bone_position + Vector3.UP * minimum_length,
	}


static func _get_hand_target(
	skeleton: Skeleton3D,
	hand_index: int,
) -> Dictionary:
	var hand_position: Vector3 = (
		skeleton.get_bone_global_rest(hand_index).origin
	)
	var leaf_indices: Array[int] = []
	_collect_leaf_bones(skeleton, hand_index, leaf_indices)

	var best_distance: float = 0.0
	var best_tip: Vector3 = hand_position

	for leaf_index: int in leaf_indices:
		var leaf_position: Vector3 = (
			skeleton.get_bone_global_rest(leaf_index).origin
		)
		var leaf_distance: float = hand_position.distance_to(
			leaf_position
		)

		if leaf_distance > best_distance:
			best_distance = leaf_distance
			best_tip = leaf_position

	return {
		"length": best_distance,
		"target_global": best_tip,
	}


static func _collect_leaf_bones(
	skeleton: Skeleton3D,
	bone_index: int,
	result: Array[int],
) -> void:
	var children: PackedInt32Array = skeleton.get_bone_children(
		bone_index
	)

	if children.is_empty():
		result.append(bone_index)
		return

	for child_index: int in children:
		_collect_leaf_bones(skeleton, child_index, result)


static func _is_ancestor_of(
	skeleton: Skeleton3D,
	ancestor_index: int,
	descendant_index: int,
) -> bool:
	var current_index: int = descendant_index

	while current_index >= 0:
		current_index = skeleton.get_bone_parent(current_index)

		if current_index == ancestor_index:
			return true

	return false


static func _create_physical_bone(
	skeleton: Skeleton3D,
	skeleton_name: StringName,
	profile_bone: StringName,
	measurement: Dictionary,
	profile: NucleusHumanoidRagdollProfile3D,
	shape_cache: Dictionary,
	mass_fraction: float,
) -> PhysicalBone3D:
	var physical_bone: PhysicalBone3D = PhysicalBone3D.new()
	var bone_index: int = int(measurement.get("bone_index", -1))
	var bone_length: float = float(measurement.get("length", 0.0))
	var target_value: Variant = measurement.get(
		"target_global",
		Vector3.ZERO,
	)
	var target_global: Vector3 = Vector3.ZERO

	if target_value is Vector3:
		target_global = target_value

	physical_bone.set("bone_name", String(skeleton_name))
	physical_bone.name = "Physical Bone %s" % String(skeleton_name)
	physical_bone.body_offset = _compute_body_offset(
		skeleton,
		bone_index,
		target_global,
		profile.flip_forward,
	)
	physical_bone.mass = maxf(
		profile.total_mass * mass_fraction,
		0.01,
	)
	physical_bone.linear_damp = profile.linear_damp
	physical_bone.angular_damp = profile.angular_damp
	physical_bone.friction = profile.friction

	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"

	var mirrored_bone: StringName = (
		profile.get_mirrored_profile_bone(profile_bone)
	)

	if (
		profile.share_mirrored_shapes
		and mirrored_bone != &""
		and shape_cache.has(mirrored_bone)
	):
		collision_shape.shape = shape_cache[mirrored_bone] as Shape3D
	else:
		var generated_shape: Shape3D = _create_shape(
			profile_bone,
			bone_length,
			measurement,
			profile,
		)
		collision_shape.shape = generated_shape
		shape_cache[profile_bone] = generated_shape

	physical_bone.add_child(collision_shape)
	_configure_joint(
		physical_bone,
		profile_bone,
		profile,
	)
	return physical_bone


static func _compute_body_offset(
	skeleton: Skeleton3D,
	bone_index: int,
	target_global: Vector3,
	flip_forward: bool,
) -> Transform3D:
	if bone_index < 0:
		return Transform3D.IDENTITY

	var bone_global: Transform3D = skeleton.get_bone_global_rest(
		bone_index
	)
	var bone_position: Vector3 = bone_global.origin
	var global_direction: Vector3 = target_global - bone_position
	var bone_length: float = global_direction.length()

	if bone_length < 0.001:
		return Transform3D.IDENTITY

	var direction_local: Vector3 = (
		bone_global.basis.inverse()
		* global_direction.normalized()
	).normalized()
	var center_local: Vector3 = direction_local * (
		bone_length * 0.5
	)

	var y_axis: Vector3 = direction_local
	var z_axis: Vector3

	if absf(y_axis.dot(Vector3.UP)) < 0.95:
		z_axis = y_axis.cross(Vector3.UP).normalized()
	elif absf(y_axis.dot(Vector3.RIGHT)) < 0.95:
		z_axis = y_axis.cross(Vector3.RIGHT).normalized()
	else:
		z_axis = y_axis.cross(Vector3.FORWARD).normalized()

	var x_axis: Vector3 = y_axis.cross(z_axis).normalized()
	z_axis = x_axis.cross(y_axis).normalized()

	if flip_forward:
		x_axis = -x_axis
		z_axis = -z_axis

	return Transform3D(
		Basis(x_axis, y_axis, z_axis),
		center_local,
	)


static func _create_shape(
	profile_bone: StringName,
	bone_length: float,
	measurement: Dictionary,
	profile: NucleusHumanoidRagdollProfile3D,
) -> Shape3D:
	if (
		profile.get_shape_kind(profile_bone)
		== NucleusHumanoidRagdollProfile3D.ShapeKind.BOX
	):
		return _create_box_shape(
			profile_bone,
			bone_length,
			measurement,
			profile,
		)

	return _create_capsule_shape(
		bone_length,
		profile.get_radius_factor(profile_bone),
		profile,
	)


static func _create_capsule_shape(
	bone_length: float,
	radius_factor: float,
	profile: NucleusHumanoidRagdollProfile3D,
) -> CapsuleShape3D:
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	var effective_length: float = maxf(
		bone_length,
		profile.minimum_bone_length,
	)
	capsule.radius = maxf(
		effective_length * radius_factor,
		profile.minimum_radius,
	)
	capsule.height = maxf(
		effective_length,
		capsule.radius * 2.0 + profile.minimum_radius,
	)
	return capsule


static func _create_box_shape(
	profile_bone: StringName,
	bone_length: float,
	measurement: Dictionary,
	profile: NucleusHumanoidRagdollProfile3D,
) -> BoxShape3D:
	var box: BoxShape3D = BoxShape3D.new()
	var hip_width: float = float(
		measurement.get("hip_width", 0.0)
	)
	var shoulder_width: float = float(
		measurement.get("shoulder_width", 0.0)
	)
	var effective_length: float = maxf(
		bone_length,
		profile.minimum_bone_length,
	)

	if profile_bone == NucleusHumanoidRagdollProfile3D.HIPS:
		var hips_width: float = (
			hip_width
			if hip_width > 0.01
			else effective_length
		)
		box.size = Vector3(
			hips_width * profile.torso_width_scale,
			effective_length,
			hips_width * 0.5 * profile.torso_width_scale,
		)
	elif profile_bone in [
		NucleusHumanoidRagdollProfile3D.SPINE,
		NucleusHumanoidRagdollProfile3D.CHEST,
		NucleusHumanoidRagdollProfile3D.UPPER_CHEST,
	]:
		var torso_width: float = _torso_width(
			profile_bone,
			hip_width,
			shoulder_width,
			effective_length,
		)
		box.size = Vector3(
			torso_width * profile.torso_width_scale,
			effective_length,
			torso_width * 0.55 * profile.torso_width_scale,
		)
	elif profile_bone in [
		NucleusHumanoidRagdollProfile3D.LEFT_HAND,
		NucleusHumanoidRagdollProfile3D.RIGHT_HAND,
	]:
		box.size = Vector3(
			effective_length * 0.60,
			effective_length,
			effective_length * 0.30,
		)
	else:
		box.size = Vector3(
			effective_length * 0.45,
			effective_length * 0.80,
			effective_length * 0.25,
		)

	return box


static func _torso_width(
	profile_bone: StringName,
	hip_width: float,
	shoulder_width: float,
	fallback_length: float,
) -> float:
	if profile_bone == NucleusHumanoidRagdollProfile3D.SPINE:
		if hip_width > 0.01:
			return hip_width * 0.90
		return fallback_length

	if profile_bone == NucleusHumanoidRagdollProfile3D.CHEST:
		if shoulder_width > 0.01 and hip_width > 0.01:
			return lerpf(hip_width, shoulder_width, 0.5)
		if shoulder_width > 0.01:
			return shoulder_width * 0.70
		if hip_width > 0.01:
			return hip_width
		return fallback_length

	if shoulder_width > 0.01:
		return shoulder_width * 0.85

	if hip_width > 0.01:
		return hip_width * 1.10

	return fallback_length


static func _configure_joint(
	physical_bone: PhysicalBone3D,
	profile_bone: StringName,
	profile: NucleusHumanoidRagdollProfile3D,
) -> void:
	var joint_type: int = profile.get_joint_type(profile_bone)
	physical_bone.joint_type = joint_type

	if joint_type == PhysicalBone3D.JOINT_TYPE_NONE:
		return

	if joint_type == PhysicalBone3D.JOINT_TYPE_HINGE:
		_configure_hinge(
			physical_bone,
			profile_bone,
			profile,
		)
		return

	if joint_type == PhysicalBone3D.JOINT_TYPE_6DOF:
		for axis: int in range(3):
			_configure_6dof_axis(
				physical_bone,
				axis,
				profile.get_6dof_limits_degrees(
					profile_bone,
					axis,
				),
				profile,
			)


static func _configure_hinge(
	physical_bone: PhysicalBone3D,
	profile_bone: StringName,
	profile: NucleusHumanoidRagdollProfile3D,
) -> void:
	var hinge_axis: int = profile.get_hinge_axis(profile_bone)
	var limits: Vector2 = profile.get_hinge_limits_degrees(
		profile_bone
	)
	physical_bone.joint_offset = _compute_hinge_joint_offset(
		physical_bone.body_offset,
		hinge_axis,
		profile.flip_forward,
	)
	physical_bone.set(
		"joint_constraints/angular_limit_enabled",
		true,
	)
	physical_bone.set(
		"joint_constraints/angular_limit_lower",
		limits.x,
	)
	physical_bone.set(
		"joint_constraints/angular_limit_upper",
		limits.y,
	)
	physical_bone.set(
		"joint_constraints/angular_limit_bias",
		profile.hinge_bias,
	)
	physical_bone.set(
		"joint_constraints/angular_limit_softness",
		profile.hinge_softness,
	)
	physical_bone.set(
		"joint_constraints/angular_limit_relaxation",
		profile.hinge_relaxation,
	)


static func _compute_hinge_joint_offset(
	body_offset: Transform3D,
	hinge_axis: int,
	flip_forward: bool,
) -> Transform3D:
	var joint_basis: Basis

	match hinge_axis:
		NucleusHumanoidRagdollProfile3D.Axis.X:
			joint_basis = Basis(Vector3.UP, PI * 0.5)
		NucleusHumanoidRagdollProfile3D.Axis.Y:
			joint_basis = Basis(Vector3.RIGHT, -PI * 0.5)
		_:
			joint_basis = Basis.IDENTITY

	if flip_forward:
		joint_basis = joint_basis.rotated(Vector3.UP, PI)

	return Transform3D(
		body_offset.basis * joint_basis,
		Vector3.ZERO,
	)


static func _configure_6dof_axis(
	physical_bone: PhysicalBone3D,
	axis: int,
	limits: Vector2,
	profile: NucleusHumanoidRagdollProfile3D,
) -> void:
	var axis_name: String

	match axis:
		NucleusHumanoidRagdollProfile3D.Axis.X:
			axis_name = "x"
		NucleusHumanoidRagdollProfile3D.Axis.Y:
			axis_name = "y"
		_:
			axis_name = "z"

	var property_prefix: String = (
		"joint_constraints/%s/" % axis_name
	)

	physical_bone.set(
		property_prefix + "linear_limit_enabled",
		true,
	)
	physical_bone.set(
		property_prefix + "linear_limit_lower",
		0.0,
	)
	physical_bone.set(
		property_prefix + "linear_limit_upper",
		0.0,
	)
	physical_bone.set(
		property_prefix + "angular_limit_enabled",
		true,
	)
	physical_bone.set(
		property_prefix + "angular_limit_lower",
		limits.x,
	)
	physical_bone.set(
		property_prefix + "angular_limit_upper",
		limits.y,
	)
	physical_bone.set(
		property_prefix + "angular_limit_softness",
		profile.dof_angular_softness,
	)
	physical_bone.set(
		property_prefix + "angular_restitution",
		0.0,
	)
	physical_bone.set(
		property_prefix + "angular_damping",
		profile.dof_angular_damping,
	)
	physical_bone.set(
		property_prefix + "erp",
		0.5,
	)


static func _resolve_scene_owner(
	skeleton: Skeleton3D,
	requested_owner: Node,
) -> Node:
	if requested_owner != null:
		return requested_owner

	if skeleton.owner != null:
		return skeleton.owner

	return skeleton


static func _set_owner_if_valid(
	generated_node: Node,
	scene_owner: Node,
) -> void:
	if generated_node == null or scene_owner == null:
		return

	generated_node.owner = scene_owner
