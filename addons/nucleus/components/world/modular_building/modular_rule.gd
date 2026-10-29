@tool
class_name NucleusModularRule
extends Resource
## One authored cardinal connection pattern and its stable asset variant.
## Rotating the mask changes the output orientation, never the board's cells.

@export_flags("North", "East", "South", "West") var neighbor_mask: int = 0
@export var variant_id: StringName = &""
@export var priority: int = 0
## When true, this pattern may be rotated in quarter turns to match a mask.
@export var allow_rotations: bool = false
