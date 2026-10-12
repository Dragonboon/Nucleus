@tool
class_name NucleusAdaptiveWorldWorkloadProfile
extends Resource
## Minimum fractions of AUTHORED background budgets at maximum pressure.
## Essential gameplay/physics queues are never registered with this profile.

@export_group("Optional Work Minimums")
@export_range(0.1, 1.0, 0.05) var queue_fraction: float = 0.25
@export_range(0.1, 1.0, 0.05) var scatter_fraction: float = 0.40
@export_range(0.1, 1.0, 0.05) var background_load_fraction: float = 0.50
@export_range(0.1, 1.0, 0.05) var terrain_build_fraction: float = 0.50
@export_range(50, 10000, 50) var minimum_queue_usec: int = 250


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for fraction: float in [
		queue_fraction, scatter_fraction, background_load_fraction,
		terrain_build_fraction,
	]:
		if not is_finite(fraction) or fraction < 0.1 or fraction > 1.0:
			errors.append("Budget fractions must be finite and in [0.1, 1].")
			break
	if minimum_queue_usec < 50 or minimum_queue_usec > 10000:
		errors.append("Minimum queue time budget must be in [50, 10000] usec.")
	return errors
