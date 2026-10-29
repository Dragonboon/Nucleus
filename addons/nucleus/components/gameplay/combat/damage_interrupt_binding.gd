class_name NucleusDamageInterruptBinding
extends Node
## Optional bridge: applied damage requests an action channel interruption.

@export var resolver: NucleusDamageResolver
@export var channel: NucleusActionChannel
@export_range(0.0, 1.0e12, 0.01, "or_greater") var minimum_damage: float = 1.0
@export var count_shield_damage: bool = false
@export var interrupt_priority: int = 1


func _ready() -> void:
	if resolver == null or channel == null:
		NucleusLog.warning(
			"%s needs a DamageResolver and ActionChannel." % get_path(),
			&"DamageInterrupt",
		)
		return
	if not resolver.damage_resolved.is_connected(_on_damage_resolved):
		resolver.damage_resolved.connect(_on_damage_resolved)


func _exit_tree() -> void:
	if is_instance_valid(resolver):
		if resolver.damage_resolved.is_connected(_on_damage_resolved):
			resolver.damage_resolved.disconnect(_on_damage_resolved)


func _on_damage_resolved(
	_payload: NucleusHitPayload,
	outcome: Dictionary,
) -> void:
	if not is_instance_valid(channel) or not channel.is_running():
		return
	if outcome.get("error", ERR_BUG) != OK:
		return
	var applied: float = float(outcome.get("health_damage", 0.0))
	if count_shield_damage:
		applied += float(outcome.get("absorbed", 0.0))
	if applied > 0.0 and applied >= minimum_damage:
		channel.interrupt_action(interrupt_priority, &"damage")
