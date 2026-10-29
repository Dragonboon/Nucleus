@tool
class_name NucleusHumanoidRagdollProfile3D
extends Resource
## Authoring recipe for generating a native humanoid physical skeleton.
##
## The generated PhysicalBone3D nodes become ordinary editable Godot content.
## This profile is not a runtime ragdoll owner.

enum ShapeKind {
	BOX,
	CAPSULE,
}

enum Axis {
	X,
	Y,
	Z,
}

const HIPS: StringName = &"Hips"
const SPINE: StringName = &"Spine"
const CHEST: StringName = &"Chest"
const UPPER_CHEST: StringName = &"UpperChest"
const HEAD: StringName = &"Head"

const LEFT_SHOULDER: StringName = &"LeftShoulder"
const LEFT_UPPER_ARM: StringName = &"LeftUpperArm"
const LEFT_LOWER_ARM: StringName = &"LeftLowerArm"
const LEFT_HAND: StringName = &"LeftHand"

const RIGHT_SHOULDER: StringName = &"RightShoulder"
const RIGHT_UPPER_ARM: StringName = &"RightUpperArm"
const RIGHT_LOWER_ARM: StringName = &"RightLowerArm"
const RIGHT_HAND: StringName = &"RightHand"

const LEFT_UPPER_LEG: StringName = &"LeftUpperLeg"
const LEFT_LOWER_LEG: StringName = &"LeftLowerLeg"
const LEFT_FOOT: StringName = &"LeftFoot"

const RIGHT_UPPER_LEG: StringName = &"RightUpperLeg"
const RIGHT_LOWER_LEG: StringName = &"RightLowerLeg"
const RIGHT_FOOT: StringName = &"RightFoot"

@export_group("Body")
@export_range(1.0, 500.0, 0.5, "or_greater")
var total_mass: float = 70.0:
	set(value):
		total_mass = maxf(value, 1.0)
		emit_changed()

@export_range(0.0, 20.0, 0.05, "or_greater")
var linear_damp: float = 0.5:
	set(value):
		linear_damp = maxf(value, 0.0)
		emit_changed()

@export_range(0.0, 20.0, 0.05, "or_greater")
var angular_damp: float = 3.0:
	set(value):
		angular_damp = maxf(value, 0.0)
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var friction: float = 1.0:
	set(value):
		friction = clampf(value, 0.0, 1.0)
		emit_changed()

@export_group("Generated parts")
@export var include_shoulders: bool = false:
	set(value):
		include_shoulders = value
		emit_changed()

@export var include_hands: bool = true:
	set(value):
		include_hands = value
		emit_changed()

@export var include_feet: bool = true:
	set(value):
		include_feet = value
		emit_changed()

@export var share_mirrored_shapes: bool = false:
	set(value):
		share_mirrored_shapes = value
		emit_changed()

@export_group("Shape fitting")
@export_range(0.25, 3.0, 0.01)
var limb_thickness_scale: float = 1.0:
	set(value):
		limb_thickness_scale = clampf(value, 0.25, 3.0)
		emit_changed()

@export_range(0.25, 3.0, 0.01)
var torso_width_scale: float = 1.6:
	set(value):
		torso_width_scale = clampf(value, 0.25, 3.0)
		emit_changed()

@export_range(0.001, 0.5, 0.001, "or_greater")
var minimum_bone_length: float = 0.02:
	set(value):
		minimum_bone_length = maxf(value, 0.001)
		emit_changed()

@export_range(0.001, 0.25, 0.001, "or_greater")
var minimum_radius: float = 0.005:
	set(value):
		minimum_radius = maxf(value, 0.001)
		emit_changed()

@export var flip_forward: bool = false:
	set(value):
		flip_forward = value
		emit_changed()

@export_group("Joint limits")
@export_range(0.25, 2.0, 0.01)
var joint_limit_scale: float = 1.0:
	set(value):
		joint_limit_scale = clampf(value, 0.25, 2.0)
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var hinge_bias: float = 0.3:
	set(value):
		hinge_bias = clampf(value, 0.0, 1.0)
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var hinge_softness: float = 0.9:
	set(value):
		hinge_softness = clampf(value, 0.0, 1.0)
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var hinge_relaxation: float = 1.0:
	set(value):
		hinge_relaxation = clampf(value, 0.0, 1.0)
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var dof_angular_softness: float = 0.5:
	set(value):
		dof_angular_softness = clampf(value, 0.0, 1.0)
		emit_changed()

@export_range(0.0, 10.0, 0.05, "or_greater")
var dof_angular_damping: float = 1.0:
	set(value):
		dof_angular_damping = maxf(value, 0.0)
		emit_changed()


func get_profile_bones() -> Array[StringName]:
	var profile_bones: Array[StringName] = [
		HIPS,
		SPINE,
		CHEST,
		UPPER_CHEST,
		HEAD,
		LEFT_UPPER_ARM,
		LEFT_LOWER_ARM,
		RIGHT_UPPER_ARM,
		RIGHT_LOWER_ARM,
		LEFT_UPPER_LEG,
		LEFT_LOWER_LEG,
		RIGHT_UPPER_LEG,
		RIGHT_LOWER_LEG,
	]

	if include_shoulders:
		profile_bones.insert(5, LEFT_SHOULDER)
		profile_bones.insert(8, RIGHT_SHOULDER)

	if include_hands:
		profile_bones.append(LEFT_HAND)
		profile_bones.append(RIGHT_HAND)

	if include_feet:
		profile_bones.append(LEFT_FOOT)
		profile_bones.append(RIGHT_FOOT)

	return profile_bones


func get_required_profile_bones() -> Array[StringName]:
	return [
		HIPS,
		SPINE,
		HEAD,
		LEFT_UPPER_ARM,
		LEFT_LOWER_ARM,
		RIGHT_UPPER_ARM,
		RIGHT_LOWER_ARM,
		LEFT_UPPER_LEG,
		LEFT_LOWER_LEG,
		RIGHT_UPPER_LEG,
		RIGHT_LOWER_LEG,
	]


func get_mass_fraction(profile_bone: StringName) -> float:
	match profile_bone:
		HIPS:
			return 0.1420
		SPINE:
			return 0.1306
		CHEST:
			return 0.0979
		UPPER_CHEST:
			return 0.0979
		HEAD:
			return 0.0826
		LEFT_SHOULDER, RIGHT_SHOULDER:
			return 0.0155
		LEFT_UPPER_ARM, RIGHT_UPPER_ARM:
			return 0.0270
		LEFT_LOWER_ARM, RIGHT_LOWER_ARM:
			return 0.0187
		LEFT_HAND, RIGHT_HAND:
			return 0.0065
		LEFT_UPPER_LEG, RIGHT_UPPER_LEG:
			return 0.1050
		LEFT_LOWER_LEG, RIGHT_LOWER_LEG:
			return 0.0475
		LEFT_FOOT, RIGHT_FOOT:
			return 0.0143
		_:
			return 0.0


func get_shape_kind(profile_bone: StringName) -> int:
	match profile_bone:
		HIPS, SPINE, CHEST, UPPER_CHEST:
			return ShapeKind.BOX
		LEFT_HAND, RIGHT_HAND, LEFT_FOOT, RIGHT_FOOT:
			return ShapeKind.BOX
		_:
			return ShapeKind.CAPSULE


func get_radius_factor(profile_bone: StringName) -> float:
	match profile_bone:
		HEAD:
			return 0.50 * limb_thickness_scale
		LEFT_SHOULDER, RIGHT_SHOULDER:
			return 0.30 * limb_thickness_scale
		LEFT_UPPER_ARM, RIGHT_UPPER_ARM:
			return 0.22 * limb_thickness_scale
		LEFT_LOWER_ARM, RIGHT_LOWER_ARM:
			return 0.20 * limb_thickness_scale
		LEFT_UPPER_LEG, RIGHT_UPPER_LEG:
			return 0.22 * limb_thickness_scale
		LEFT_LOWER_LEG, RIGHT_LOWER_LEG:
			return 0.18 * limb_thickness_scale
		_:
			return 0.20 * limb_thickness_scale


func get_joint_type(profile_bone: StringName) -> int:
	if profile_bone == HIPS:
		return PhysicalBone3D.JOINT_TYPE_NONE

	if profile_bone in [
		LEFT_LOWER_ARM,
		RIGHT_LOWER_ARM,
		LEFT_LOWER_LEG,
		RIGHT_LOWER_LEG,
	]:
		return PhysicalBone3D.JOINT_TYPE_HINGE

	return PhysicalBone3D.JOINT_TYPE_6DOF


func get_hinge_axis(profile_bone: StringName) -> int:
	if profile_bone in [LEFT_LOWER_LEG, RIGHT_LOWER_LEG]:
		return Axis.X

	return Axis.Z


func get_hinge_limits_degrees(
	profile_bone: StringName,
) -> Vector2:
	if profile_bone in [
		LEFT_LOWER_ARM,
		RIGHT_LOWER_ARM,
		LEFT_LOWER_LEG,
		RIGHT_LOWER_LEG,
	]:
		return Vector2(-5.0, 140.0) * joint_limit_scale

	return Vector2.ZERO


func get_6dof_limits_degrees(
	profile_bone: StringName,
	axis: int,
) -> Vector2:
	var limits: Vector2 = Vector2.ZERO

	match profile_bone:
		SPINE:
			limits = Vector2(-20.0, 20.0)
		CHEST, UPPER_CHEST:
			limits = (
				Vector2(-10.0, 10.0)
				if axis == Axis.Y
				else Vector2(-15.0, 15.0)
			)
		HEAD:
			match axis:
				Axis.X:
					limits = Vector2(-40.0, 40.0)
				Axis.Y:
					limits = Vector2(-50.0, 50.0)
				_:
					limits = Vector2(-30.0, 30.0)
		LEFT_SHOULDER, RIGHT_SHOULDER:
			limits = Vector2(-10.0, 10.0)
		LEFT_UPPER_ARM, RIGHT_UPPER_ARM:
			limits = (
				Vector2(-45.0, 45.0)
				if axis == Axis.Y
				else Vector2(-70.0, 70.0)
			)
		LEFT_HAND, RIGHT_HAND:
			limits = (
				Vector2(-15.0, 15.0)
				if axis == Axis.Y
				else Vector2(-25.0, 25.0)
			)
		LEFT_UPPER_LEG, RIGHT_UPPER_LEG:
			limits = (
				Vector2(-30.0, 30.0)
				if axis == Axis.Y
				else Vector2(-50.0, 50.0)
			)
		LEFT_FOOT, RIGHT_FOOT:
			limits = (
				Vector2(-15.0, 15.0)
				if axis == Axis.Y
				else Vector2(-25.0, 25.0)
			)

	return limits * joint_limit_scale


func get_target_candidates(
	profile_bone: StringName,
) -> Array[StringName]:
	match profile_bone:
		HIPS:
			return [SPINE, CHEST, UPPER_CHEST, HEAD]
		SPINE:
			return [CHEST, UPPER_CHEST, HEAD]
		CHEST:
			return [UPPER_CHEST, HEAD]
		UPPER_CHEST:
			return [HEAD]
		LEFT_SHOULDER:
			return [LEFT_UPPER_ARM]
		LEFT_UPPER_ARM:
			return [LEFT_LOWER_ARM]
		LEFT_LOWER_ARM:
			return [LEFT_HAND]
		RIGHT_SHOULDER:
			return [RIGHT_UPPER_ARM]
		RIGHT_UPPER_ARM:
			return [RIGHT_LOWER_ARM]
		RIGHT_LOWER_ARM:
			return [RIGHT_HAND]
		LEFT_UPPER_LEG:
			return [LEFT_LOWER_LEG]
		LEFT_LOWER_LEG:
			return [LEFT_FOOT]
		RIGHT_UPPER_LEG:
			return [RIGHT_LOWER_LEG]
		RIGHT_LOWER_LEG:
			return [RIGHT_FOOT]
		_:
			return []


func get_mirrored_profile_bone(
	profile_bone: StringName,
) -> StringName:
	match profile_bone:
		RIGHT_SHOULDER:
			return LEFT_SHOULDER
		RIGHT_UPPER_ARM:
			return LEFT_UPPER_ARM
		RIGHT_LOWER_ARM:
			return LEFT_LOWER_ARM
		RIGHT_HAND:
			return LEFT_HAND
		RIGHT_UPPER_LEG:
			return LEFT_UPPER_LEG
		RIGHT_LOWER_LEG:
			return LEFT_LOWER_LEG
		RIGHT_FOOT:
			return LEFT_FOOT
		_:
			return &""
