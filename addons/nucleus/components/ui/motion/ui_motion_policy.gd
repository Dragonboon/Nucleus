class_name NucleusUIMotionPolicy
extends RefCounted
## Resolves UI animation and flash accessibility preferences.
##
## Shared reduced-motion detection/amplitude policy lives in
## [NucleusMotionPolicy]. UI-specific duration scaling and flash settings remain
## here.

static func is_reduced_motion_enabled() -> bool:
	return NucleusMotionPolicy.is_reduced_motion_enabled()


static func get_motion_scale() -> float:
	if not NucleusSettings.is_initialized():
		return 1.0

	return clampf(
		NucleusSettings.get_float(
			NucleusSettingIds.ACCESSIBILITY_UI_MOTION_SCALE,
			1.0,
		),
		0.0,
		2.0,
	)


static func get_effective_duration(
	duration: float,
	respect_reduced_motion: bool = true,
	reduced_motion_scale: float = 0.0,
) -> float:
	var safe_duration: float = maxf(0.0, duration)
	var accessibility_scale := NucleusMotionPolicy.get_motion_scale(
		respect_reduced_motion,
		reduced_motion_scale,
	)

	return safe_duration * get_motion_scale() * accessibility_scale


static func get_effect_amplitude_scale(
	respect_reduced_motion: bool = true,
	reduced_motion_scale: float = 0.0,
) -> float:
	return NucleusMotionPolicy.get_motion_scale(
		respect_reduced_motion,
		reduced_motion_scale,
	)


static func get_screen_flash_intensity() -> float:
	# Preserve the existing flash policy: the OS seizure/motion preference can
	# disable flashes globally, while the project exposes an independent flash
	# intensity setting.
	if DisplayServer.accessibility_should_reduce_animation() == 1:
		return 0.0

	if not NucleusSettings.is_initialized():
		return 1.0

	return clampf(
		NucleusSettings.get_float(
			NucleusSettingIds.ACCESSIBILITY_SCREEN_FLASH_INTENSITY,
			1.0,
		),
		0.0,
		1.0,
	)
