@tool
class_name NucleusFxQualityProfile
extends Resource
## Reusable quality multipliers for localized world FX.
##
## Particle capacity scales continuous GPUParticles counts. Event rate scales
## project-owned sparse secondary work such as impact probes or debris bursts.

enum Quality {
	LOW,
	MEDIUM,
	HIGH,
}

@export_group("Particle capacity")
@export_range(0.0, 4.0, 0.01, "or_greater")
var low_particle_capacity_scale: float = 0.35:
	set(value):
		if is_equal_approx(low_particle_capacity_scale, value):
			return
		low_particle_capacity_scale = value
		emit_changed()

@export_range(0.0, 4.0, 0.01, "or_greater")
var medium_particle_capacity_scale: float = 0.65:
	set(value):
		if is_equal_approx(medium_particle_capacity_scale, value):
			return
		medium_particle_capacity_scale = value
		emit_changed()

@export_range(0.0, 4.0, 0.01, "or_greater")
var high_particle_capacity_scale: float = 1.0:
	set(value):
		if is_equal_approx(high_particle_capacity_scale, value):
			return
		high_particle_capacity_scale = value
		emit_changed()

@export_group("Secondary event rate")
@export_range(0.0, 4.0, 0.01, "or_greater")
var low_event_rate_scale: float = 0.45:
	set(value):
		if is_equal_approx(low_event_rate_scale, value):
			return
		low_event_rate_scale = value
		emit_changed()

@export_range(0.0, 4.0, 0.01, "or_greater")
var medium_event_rate_scale: float = 0.72:
	set(value):
		if is_equal_approx(medium_event_rate_scale, value):
			return
		medium_event_rate_scale = value
		emit_changed()

@export_range(0.0, 4.0, 0.01, "or_greater")
var high_event_rate_scale: float = 1.0:
	set(value):
		if is_equal_approx(high_event_rate_scale, value):
			return
		high_event_rate_scale = value
		emit_changed()


func get_particle_capacity_scale(quality: int) -> float:
	match clampi(quality, Quality.LOW, Quality.HIGH):
		Quality.LOW:
			return maxf(low_particle_capacity_scale, 0.0)
		Quality.MEDIUM:
			return maxf(medium_particle_capacity_scale, 0.0)
		_:
			return maxf(high_particle_capacity_scale, 0.0)


func get_event_rate_scale(quality: int) -> float:
	match clampi(quality, Quality.LOW, Quality.HIGH):
		Quality.LOW:
			return maxf(low_event_rate_scale, 0.0)
		Quality.MEDIUM:
			return maxf(medium_event_rate_scale, 0.0)
		_:
			return maxf(high_event_rate_scale, 0.0)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var values := [
		low_particle_capacity_scale,
		medium_particle_capacity_scale,
		high_particle_capacity_scale,
		low_event_rate_scale,
		medium_event_rate_scale,
		high_event_rate_scale,
	]

	for value: float in values:
		if value < 0.0:
			errors.append("Quality scales must be greater than or equal to zero.")
			break

	return errors
