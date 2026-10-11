@tool
class_name NucleusSplinePathProfile3D
extends Resource
## Runtime mesh budget and UV policy for a planar-width path ribbon.
## Curve control points remain owned by Godot Path3D/Curve3D.

@export_range(0.1, 100.0, 0.1, "or_greater") var width: float = 3.0
@export_range(0.1, 10.0, 0.05, "or_greater") var sample_spacing: float = 0.75
@export_range(0.1, 100.0, 0.1, "or_greater") var uv_repeat_meters: float = 4.0
@export_range(-10.0, 10.0, 0.01) var surface_offset: float = 0.08
@export_range(2, 2048, 1) var max_sections: int = 512


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(width) or width <= 0.0 or width > 100.0:
		errors.append("Road width must be within (0, 100].")
	if not is_finite(sample_spacing) or sample_spacing < 0.1:
		errors.append("Sample spacing must be at least 0.1.")
	if not is_finite(uv_repeat_meters) or uv_repeat_meters <= 0.0:
		errors.append("UV repeat length must be positive.")
	if not is_finite(surface_offset) or absf(surface_offset) > 10.0:
		errors.append("Surface offset must be finite and within [-10, 10].")
	if max_sections < 2 or max_sections > 2048:
		errors.append("The section budget must be within [2, 2048].")
	return errors
