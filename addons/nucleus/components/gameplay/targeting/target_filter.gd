class_name NucleusTargetFilter
extends Node
## Base validation rule discovered by NucleusTargetingAgent.

signal rule_changed

@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return

		enabled = value

		if is_node_ready():
			rule_changed.emit()


func accepts(
	_agent: NucleusTargetingAgent,
	_target: NucleusTargetable,
	_context: Dictionary,
) -> bool:
	return true


func notify_rule_changed() -> void:
	rule_changed.emit()
