@tool
class_name NucleusFractureShard3D
extends Resource
## Precomputed fragment in the source MeshInstance3D local space.

@export var mesh: Mesh
@export var local_transform: Transform3D = Transform3D.IDENTITY
@export var collision_shape: Shape3D
@export_range(0.01, 100000.0, 0.01, "or_greater") var mass: float = 1.0
