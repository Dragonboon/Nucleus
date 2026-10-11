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

@export_group("Roadbed")
## Keep disabled for the historical two-vertex-per-section flat ribbon.
@export var roadbed_enabled: bool = false
@export_range(0.0, 10.0, 0.05, "or_greater") var shoulder_width: float = 0.4
@export_range(0.0, 2.0, 0.01, "or_greater") var crown_height: float = 0.12
@export_range(0.0, 2.0, 0.01, "or_greater") var shoulder_drop: float = 0.06
@export_range(0.02, 5.0, 0.01, "or_greater") var roadbed_thickness: float = 0.3


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
	if not is_finite(shoulder_width) or shoulder_width < 0.0 or shoulder_width > 10.0:
		errors.append("Shoulder width must be within [0, 10].")
	if not is_finite(crown_height) or crown_height < 0.0 or crown_height > 2.0:
		errors.append("Road crown must be within [0, 2].")
	if not is_finite(shoulder_drop) or shoulder_drop < 0.0 or shoulder_drop > 2.0:
		errors.append("Shoulder drop must be within [0, 2].")
	if not is_finite(roadbed_thickness) or roadbed_thickness < 0.02:
		errors.append("Roadbed thickness must be at least 0.02.")
	return errors
