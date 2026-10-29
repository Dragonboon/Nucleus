@tool
class_name NucleusScatterVariant3D
extends Resource
## One visual-only variant. The consumer owns content, collision and gameplay.

@export var mesh: Mesh
@export var material_override: Material
@export_range(0.0, 10000.0, 0.01, "or_greater") var weight: float = 1.0
@export var cast_shadows: bool = false
@export_range(0.0, 100000.0, 1.0, "or_greater") var visibility_end: float = 0.0


func is_usable() -> bool:
	return mesh != null and weight > 0.0 and is_finite(weight)
