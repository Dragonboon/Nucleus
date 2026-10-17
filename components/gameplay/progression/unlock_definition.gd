class_name NucleusUnlockDefinition
extends Resource
## One ranked unlock with prerequisite ranks and mutually exclusive groups.

@export var unlock_id: StringName
@export_range(1, 999, 1, "or_greater") var max_rank: int = 1
@export var required_ranks: Dictionary = {}
@export var exclusive_group: StringName
@export var minimum_level: int = 1
@export_range(0, 99999, 1, "or_greater") var cost_per_rank: int = 1
