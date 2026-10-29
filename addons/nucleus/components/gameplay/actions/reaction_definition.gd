class_name NucleusReactionDefinition
extends Resource
## Mapping of an explicit event and optional window to a registered action.

@export var event_id: StringName
@export var action_id: StringName
@export var window_id: StringName
@export var priority: int = 0
@export var interrupt_priority: int = 0
