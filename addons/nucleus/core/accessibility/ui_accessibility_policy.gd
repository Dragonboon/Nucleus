class_name NucleusUIAccessibilityPolicy
extends RefCounted
## Reads reusable UI accessibility intent without owning presentation.
##
## The consuming game remains responsible for applying scale to its Theme/layout
## and for defining what its high-contrast visual treatment looks like.

const MIN_UI_SCALE: float = 0.75
const MAX_UI_SCALE: float = 2.0


static func get_ui_scale() -> float:
	return clampf(
		NucleusSettings.get_float(
			NucleusSettingIds.ACCESSIBILITY_UI_SCALE,
			1.0,
		),
		MIN_UI_SCALE,
		MAX_UI_SCALE,
	)


static func is_high_contrast_enabled() -> bool:
	return NucleusSettings.get_bool(
		NucleusSettingIds.ACCESSIBILITY_HIGH_CONTRAST,
		false,
	)
