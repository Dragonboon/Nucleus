class_name NucleusMotionPolicy
extends RefCounted
## Shared motion-accessibility policy for UI and gameplay presentation.
##
## Combines the operating-system preference with Nucleus Settings without
## coupling callers to either backend.

static func is_reduced_motion_enabled() -> bool:
	if DisplayServer.accessibility_should_reduce_animation() == 1:
		return true

	if not NucleusSettings.is_initialized():
		return false

	return NucleusSettings.get_bool(
		NucleusSettingIds.ACCESSIBILITY_REDUCED_MOTION,
		false,
	)


static func get_motion_scale(
	respect_reduced_motion: bool = true,
	reduced_motion_scale: float = 0.25,
) -> float:
	if (
		respect_reduced_motion
		and is_reduced_motion_enabled()
	):
		return clampf(
			reduced_motion_scale,
			0.0,
			1.0,
		)

	return 1.0


static func scale_float(
	value: float,
	respect_reduced_motion: bool = true,
	reduced_motion_scale: float = 0.25,
) -> float:
	return value * get_motion_scale(
		respect_reduced_motion,
		reduced_motion_scale,
	)


static func scale_vector2(
	value: Vector2,
	respect_reduced_motion: bool = true,
	reduced_motion_scale: float = 0.25,
) -> Vector2:
	return value * get_motion_scale(
		respect_reduced_motion,
		reduced_motion_scale,
	)


static func scale_vector3(
	value: Vector3,
	respect_reduced_motion: bool = true,
	reduced_motion_scale: float = 0.25,
) -> Vector3:
	return value * get_motion_scale(
		respect_reduced_motion,
		reduced_motion_scale,
	)
