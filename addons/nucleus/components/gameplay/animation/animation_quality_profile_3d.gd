@tool
class_name NucleusAnimationQualityProfile3D
extends Resource
## Reusable animation evaluation budgets for 3D characters.
##
## Quality affects presentation only. It must not change gameplay authority.

enum Quality {
	MINIMAL,
	REDUCED,
	FULL,
}

@export_group("Pose evaluation")
@export_range(1.0, 240.0, 1.0, "or_greater")
var reduced_update_hz: float = 30.0:
	set(value):
		reduced_update_hz = maxf(value, 1.0)
		emit_changed()

@export_range(1.0, 240.0, 1.0, "or_greater")
var minimal_update_hz: float = 15.0:
	set(value):
		minimal_update_hz = maxf(value, 1.0)
		emit_changed()


func get_update_hz(quality: int) -> float:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return maxf(minimal_update_hz, 1.0)
		Quality.REDUCED:
			return maxf(reduced_update_hz, 1.0)
		_:
			return 0.0


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if reduced_update_hz <= 0.0:
		errors.append("reduced_update_hz must be greater than zero")

	if minimal_update_hz <= 0.0:
		errors.append("minimal_update_hz must be greater than zero")

	if minimal_update_hz > reduced_update_hz:
		errors.append(
			"minimal_update_hz should not exceed reduced_update_hz"
		)

	return errors
