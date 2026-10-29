class_name NucleusTargetActionContext
extends NucleusActionContextProvider
## Adds the TargetingAgent's current selection to GameplayAction context.

@export var agent: NucleusTargetingAgent
@export var target_key: StringName = &"target"
@export var targetable_key: StringName = &"targetable"
@export var include_target_node: bool = true
@export var include_targetable: bool = true


func _ready() -> void:
	if agent == null:
		agent = NucleusTargetResolver.find_agent(self)

	if agent == null:
		NucleusLog.error(
			"%s requires a NucleusTargetingAgent." % get_path(),
			&"TargetActionContext",
		)


func contribute(context: Dictionary) -> void:
	if agent == null or agent.current == null:
		return

	if include_target_node:
		context[target_key] = agent.current.get_target_node()

	if include_targetable:
		context[targetable_key] = agent.current
