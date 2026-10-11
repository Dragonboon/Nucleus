@tool
class_name NucleusModularRule
extends Resource
## One connectivity mask, stable variant ID; no mesh or placement ownership.
@export_flags("North", "East", "South", "West") var neighbor_mask: int = 0
@export var variant_id: StringName = &""
@export var priority: int = 0
