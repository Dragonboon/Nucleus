class_name NucleusRagdollRigInspector3D
extends RefCounted
## Non-destructive humanoid ragdoll inspection/mapping helpers.
##
## BoneMap is preferred. Conservative name heuristics are only a fallback.

static func inspect(
	skeleton: Skeleton3D,
	bone_map: BoneMap = null,
	manual_overrides: Dictionary = {},
	profile: NucleusHumanoidRagdollProfile3D = null,
) -> Dictionary:
	var resolved_profile: NucleusHumanoidRagdollProfile3D = profile

	if resolved_profile == null:
		resolved_profile = NucleusHumanoidRagdollProfile3D.new()

	var warnings: PackedStringArray = PackedStringArray()
	var mapping_sources: Dictionary = {}
	var mapping: Dictionary = resolve_humanoid_mapping(
		skeleton,
		bone_map,
		manual_overrides,
		resolved_profile,
		mapping_sources,
	)
	var missing_required: Array[StringName] = []

	if skeleton == null:
		warnings.append("No Skeleton3D assigned.")
	else:
		for profile_bone: StringName in (
			resolved_profile.get_required_profile_bones()
		):
			if not mapping.has(profile_bone):
				missing_required.append(profile_bone)

		if not missing_required.is_empty():
			warnings.append(
				"Required humanoid ragdoll bones are missing: %s"
				% _string_name_array_text(missing_required)
			)

		for profile_bone: StringName in (
			resolved_profile.get_profile_bones()
		):
			if (
				mapping_sources.get(profile_bone, &"")
				== &"manual_invalid"
			):
				warnings.append(
					(
						"Manual ragdoll override for %s does not name "
						+ "a Skeleton3D bone."
					)
					% String(profile_bone)
				)

	var simulator: PhysicalBoneSimulator3D = find_simulator(skeleton)
	var physical_bone_count: int = 0
	var physical_bones_without_shapes: int = 0
	var invalid_physical_bones: int = 0
	var total_physical_mass: float = 0.0

	if simulator != null:
		for child: Node in simulator.get_children():
			if not child is PhysicalBone3D:
				continue

			var physical_bone: PhysicalBone3D = child as PhysicalBone3D
			physical_bone_count += 1
			total_physical_mass += physical_bone.mass

			if not _has_collision_shape(physical_bone):
				physical_bones_without_shapes += 1

			if (
				skeleton == null
				or skeleton.find_bone(
					str(physical_bone.get("bone_name"))
				) < 0
			):
				invalid_physical_bones += 1

	if physical_bones_without_shapes > 0:
		warnings.append(
			"%d PhysicalBone3D nodes have no CollisionShape3D."
			% physical_bones_without_shapes
		)

	if invalid_physical_bones > 0:
		warnings.append(
			"%d PhysicalBone3D nodes reference missing skeleton bones."
			% invalid_physical_bones
		)

	var required_count: int = (
		resolved_profile.get_required_profile_bones().size()
	)
	var mapped_required_count: int = (
		required_count - missing_required.size()
	)

	return {
		"skeleton": skeleton,
		"bone_count": (
			skeleton.get_bone_count()
			if skeleton != null
			else 0
		),
		"mapping": mapping,
		"mapping_sources": mapping_sources,
		"mapped_count": mapping.size(),
		"mapped_required_count": mapped_required_count,
		"required_count": required_count,
		"missing_required": missing_required,
		"simulator": simulator,
		"physical_bone_count": physical_bone_count,
		"physical_bones_without_shapes": (
			physical_bones_without_shapes
		),
		"invalid_physical_bones": invalid_physical_bones,
		"total_physical_mass": total_physical_mass,
		"warnings": warnings,
	}


static func resolve_humanoid_mapping(
	skeleton: Skeleton3D,
	bone_map: BoneMap = null,
	manual_overrides: Dictionary = {},
	profile: NucleusHumanoidRagdollProfile3D = null,
	mapping_sources: Dictionary = {},
) -> Dictionary:
	var result: Dictionary = {}

	if skeleton == null:
		return result

	var resolved_profile: NucleusHumanoidRagdollProfile3D = profile

	if resolved_profile == null:
		resolved_profile = NucleusHumanoidRagdollProfile3D.new()

	for profile_bone: StringName in resolved_profile.get_profile_bones():
		if _has_manual_override(
			manual_overrides,
			profile_bone,
		):
			var manual_name: StringName = _manual_override_name(
				manual_overrides,
				profile_bone,
			)

			if _is_valid_skeleton_bone(skeleton, manual_name):
				result[profile_bone] = manual_name
				mapping_sources[profile_bone] = &"manual"
			else:
				mapping_sources[profile_bone] = &"manual_invalid"

			continue

		if bone_map != null:
			var mapped_name: StringName = (
				bone_map.get_skeleton_bone_name(profile_bone)
			)

			if _is_valid_skeleton_bone(skeleton, mapped_name):
				result[profile_bone] = mapped_name
				mapping_sources[profile_bone] = &"bone_map"
				continue

	var heuristic_mapping: Dictionary = _heuristic_mapping(
		skeleton,
		resolved_profile,
	)

	for profile_bone: StringName in resolved_profile.get_profile_bones():
		if result.has(profile_bone):
			continue

		var heuristic_value: Variant = heuristic_mapping.get(
			profile_bone,
			&"",
		)
		var heuristic_name: StringName = StringName(
			str(heuristic_value)
		)

		if not _is_valid_skeleton_bone(skeleton, heuristic_name):
			continue

		result[profile_bone] = heuristic_name
		mapping_sources[profile_bone] = &"heuristic"

	return result


static func find_simulator(
	skeleton: Skeleton3D,
) -> PhysicalBoneSimulator3D:
	if skeleton == null:
		return null

	for child: Node in skeleton.get_children():
		if child is PhysicalBoneSimulator3D:
			return child as PhysicalBoneSimulator3D

	return null


static func _heuristic_mapping(
	skeleton: Skeleton3D,
	profile: NucleusHumanoidRagdollProfile3D,
) -> Dictionary:
	var candidates: Dictionary = {}

	for profile_bone: StringName in profile.get_profile_bones():
		candidates[profile_bone] = []

	for bone_index: int in range(skeleton.get_bone_count()):
		var skeleton_bone: StringName = skeleton.get_bone_name(
			bone_index
		)
		var profile_bone: StringName = _classify_profile_bone(
			String(skeleton_bone)
		)

		if profile_bone == &"" or not candidates.has(profile_bone):
			continue

		var candidate_value: Variant = candidates[profile_bone]
		var candidate_list: Array = []

		if candidate_value is Array:
			candidate_list = candidate_value
		else:
			continue

		candidate_list.append({
			"bone": skeleton_bone,
			"score": _score_match(
				String(skeleton_bone),
				profile_bone,
			),
		})

	var result: Dictionary = {}

	for profile_bone: StringName in profile.get_profile_bones():
		var candidate_value: Variant = candidates.get(
			profile_bone,
			[],
		)
		var candidate_list: Array = []

		if candidate_value is Array:
			candidate_list = candidate_value
		else:
			continue

		if candidate_list.is_empty():
			continue

		candidate_list.sort_custom(
			func(first: Dictionary, second: Dictionary) -> bool:
				return int(first.get("score", 0)) > int(
					second.get("score", 0)
				)
		)

		var best_value: Variant = candidate_list[0]
		var best: Dictionary = {}

		if best_value is Dictionary:
			best = best_value
		else:
			continue

		result[profile_bone] = StringName(
			str(best.get("bone", ""))
		)

	return result


static func _classify_profile_bone(
	skeleton_bone_name: String,
) -> StringName:
	var lower_name: String = skeleton_bone_name.to_lower()
	var side: int = _detect_side(lower_name)
	var clean_name: String = _clean_bone_name(lower_name)

	if side == 0:
		match clean_name:
			"hips", "hip", "pelvis":
				return NucleusHumanoidRagdollProfile3D.HIPS
			"spine", "spine0", "spine00", "abdomen":
				return NucleusHumanoidRagdollProfile3D.SPINE
			"spine1", "spine01", "chest", "torso":
				return NucleusHumanoidRagdollProfile3D.CHEST
			"spine2", "spine02", "upperchest":
				return NucleusHumanoidRagdollProfile3D.UPPER_CHEST
			"head", "skull", "cranium":
				return NucleusHumanoidRagdollProfile3D.HEAD
		return &""

	var left_side: bool = side < 0

	match clean_name:
		"shoulder", "clavicle":
			return (
				NucleusHumanoidRagdollProfile3D.LEFT_SHOULDER
				if left_side
				else NucleusHumanoidRagdollProfile3D.RIGHT_SHOULDER
			)
		"upperarm", "uparm", "arm", "humerus":
			return (
				NucleusHumanoidRagdollProfile3D.LEFT_UPPER_ARM
				if left_side
				else NucleusHumanoidRagdollProfile3D.RIGHT_UPPER_ARM
			)
		"lowerarm", "forearm", "elbow", "radius", "ulna":
			return (
				NucleusHumanoidRagdollProfile3D.LEFT_LOWER_ARM
				if left_side
				else NucleusHumanoidRagdollProfile3D.RIGHT_LOWER_ARM
			)
		"hand", "wrist", "palm":
			return (
				NucleusHumanoidRagdollProfile3D.LEFT_HAND
				if left_side
				else NucleusHumanoidRagdollProfile3D.RIGHT_HAND
			)
		"upperleg", "upleg", "thigh", "femur":
			return (
				NucleusHumanoidRagdollProfile3D.LEFT_UPPER_LEG
				if left_side
				else NucleusHumanoidRagdollProfile3D.RIGHT_UPPER_LEG
			)
		"lowerleg", "leg", "knee", "calf", "shin", "tibia":
			return (
				NucleusHumanoidRagdollProfile3D.LEFT_LOWER_LEG
				if left_side
				else NucleusHumanoidRagdollProfile3D.RIGHT_LOWER_LEG
			)
		"foot", "ankle", "heel":
			return (
				NucleusHumanoidRagdollProfile3D.LEFT_FOOT
				if left_side
				else NucleusHumanoidRagdollProfile3D.RIGHT_FOOT
			)

	return &""


static func _detect_side(lower_name: String) -> int:
	if "left" in lower_name:
		return -1

	if "right" in lower_name:
		return 1

	for marker: String in ["_l_", ".l.", " l "]:
		if marker in lower_name:
			return -1

	for marker: String in ["_r_", ".r.", " r "]:
		if marker in lower_name:
			return 1

	if (
		lower_name.ends_with("_l")
		or lower_name.ends_with(".l")
		or lower_name.ends_with(" l")
	):
		return -1

	if (
		lower_name.ends_with("_r")
		or lower_name.ends_with(".r")
		or lower_name.ends_with(" r")
	):
		return 1

	if (
		lower_name.begins_with("l_")
		or lower_name.begins_with("l.")
		or lower_name.begins_with("l ")
	):
		return -1

	if (
		lower_name.begins_with("r_")
		or lower_name.begins_with("r.")
		or lower_name.begins_with("r ")
	):
		return 1

	return 0


static func _clean_bone_name(lower_name: String) -> String:
	var value: String = lower_name
	var namespace_index: int = value.rfind(":")

	if namespace_index >= 0:
		value = value.substr(namespace_index + 1)

	value = value.replace("-", "_")
	value = value.replace(".", "_")
	value = value.replace(" ", "_")

	for prefix: String in [
		"cc_base_",
		"bip001_",
		"bip01_",
		"deform_",
		"def_",
		"metarig_",
		"rig_",
		"bone_",
		"jnt_",
		"j_",
	]:
		if value.begins_with(prefix):
			value = value.substr(prefix.length())
			break

	value = value.replace("left", "")
	value = value.replace("right", "")

	if value.begins_with("l_") or value.begins_with("r_"):
		value = value.substr(2)

	if value.ends_with("_l") or value.ends_with("_r"):
		value = value.substr(0, value.length() - 2)

	return value.replace("_", "")


static func _score_match(
	skeleton_bone_name: String,
	profile_bone: StringName,
) -> int:
	var lower_name: String = skeleton_bone_name.to_lower()
	var score: int = 10

	if profile_bone == NucleusHumanoidRagdollProfile3D.HIPS:
		if "pelvis" in lower_name or "hips" in lower_name:
			score += 40

	if profile_bone == NucleusHumanoidRagdollProfile3D.SPINE:
		if (
			"spine" in lower_name
			and "spine1" not in lower_name
			and "spine2" not in lower_name
		):
			score += 40

	if profile_bone == NucleusHumanoidRagdollProfile3D.CHEST:
		if (
			"spine1" in lower_name
			or "spine01" in lower_name
			or "chest" in lower_name
		):
			score += 40

	if profile_bone == NucleusHumanoidRagdollProfile3D.UPPER_CHEST:
		if (
			"spine2" in lower_name
			or "spine02" in lower_name
			or "upperchest" in lower_name
		):
			score += 40

	if profile_bone in [
		NucleusHumanoidRagdollProfile3D.LEFT_HAND,
		NucleusHumanoidRagdollProfile3D.RIGHT_HAND,
	]:
		if (
			"hand" in lower_name
			and "thumb" not in lower_name
			and "finger" not in lower_name
			and "index" not in lower_name
			and "ring" not in lower_name
			and "pinky" not in lower_name
		):
			score += 40

	return score


static func _has_manual_override(
	manual_overrides: Dictionary,
	profile_bone: StringName,
) -> bool:
	return (
		manual_overrides.has(profile_bone)
		or manual_overrides.has(String(profile_bone))
	)


static func _manual_override_name(
	manual_overrides: Dictionary,
	profile_bone: StringName,
) -> StringName:
	if manual_overrides.has(profile_bone):
		return StringName(
			str(manual_overrides[profile_bone])
		)

	var string_key: String = String(profile_bone)

	if manual_overrides.has(string_key):
		return StringName(
			str(manual_overrides[string_key])
		)

	return &""


static func _is_valid_skeleton_bone(
	skeleton: Skeleton3D,
	bone_name: StringName,
) -> bool:
	return (
		bone_name != &""
		and skeleton.find_bone(String(bone_name)) >= 0
	)


static func _has_collision_shape(
	physical_bone: PhysicalBone3D,
) -> bool:
	for child: Node in physical_bone.get_children():
		if child is CollisionShape3D:
			return true

	return false


static func _string_name_array_text(
	values: Array[StringName],
) -> String:
	var strings: PackedStringArray = PackedStringArray()

	for value: StringName in values:
		strings.append(String(value))

	return ", ".join(strings)
