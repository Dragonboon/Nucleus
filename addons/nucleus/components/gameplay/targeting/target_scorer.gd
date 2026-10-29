class_name NucleusTargetScorer
extends Node
## Base ranking rule discovered by NucleusTargetingAgent.
##
## Higher total score wins.

signal rule_changed

@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return

		enabled = value

		if is_node_ready():
			rule_changed.emit()

@export var weight: float = 1.0:
	set(value):
		if is_equal_approx(weight, value):
			return

		weight = value

		if is_node_ready():
			rule_changed.emit()


func score(
	_agent: NucleusTargetingAgent,
	_target: NucleusTargetable,
	_context: Dictionary,
) -> float:
	return 0.0


func get_weighted_score(
	agent: NucleusTargetingAgent,
	target: NucleusTargetable,
	context: Dictionary,
) -> float:
	if not enabled:
		return 0.0

	return score(
		agent,
		target,
		context,
	) * weight


func notify_rule_changed() -> void:
	rule_changed.emit()
