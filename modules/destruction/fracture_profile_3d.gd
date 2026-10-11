@tool
class_name NucleusFractureProfile3D
extends Resource
## Per-object limits. Runtime counters remain on the scene-owned component.

@export_range(0.0, 1000000.0, 0.1, "or_greater") var impulse_threshold: float = 5.0
@export_range(2, 256, 1) var max_fragments: int = 32
@export_range(0.0, 100.0, 0.01, "or_greater") var impulse_scale: float = 1.0
## Zero means fragments remain until restored or the component is freed.
@export_range(0.0, 3600.0, 0.1, "or_greater") var fragment_lifetime: float = 10.0
