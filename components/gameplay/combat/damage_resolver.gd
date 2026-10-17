class_name NucleusDamageResolver
extends Node
## Optional ordered defense pipeline before the existing DamageReceiver.
## Do not also send the same hit directly to the receiver.

signal damage_resolved(payload: NucleusHitPayload, outcome: Dictionary)

@export var receiver: NucleusDamageReceiver
@export var shield_pools: Array[NucleusValuePool] = []
@export var rules: Array[NucleusDamageRule] = []


func resolve_hit(payload: NucleusHitPayload) -> Dictionary:
	if receiver == null or not is_instance_valid(receiver):
		return _failure(ERR_UNCONFIGURED, &"no_receiver")
	var reason: StringName = receiver.get_hit_rejection_reason(payload)
	if reason != &"":
		return _failure(ERR_UNAVAILABLE, reason)

	var amount: float = payload.amount
	# Insertion sort preserves authored order among equal-priority rules.
	var ordered: Array[NucleusDamageRule] = []
	for rule: NucleusDamageRule in rules:
		if rule == null:
			continue
		var index: int = 0
		while index < ordered.size() and ordered[index].priority <= rule.priority:
			index += 1
		ordered.insert(index, rule)

	for rule: NucleusDamageRule in ordered:
		amount = rule.transform_amount(payload, amount)
		if is_nan(amount) or is_inf(amount) or amount < 0.0:
			return _failure(ERR_INVALID_DATA, &"invalid_rule_result")

	var remaining: float = amount
	var absorbed: float = 0.0
	var visited: Dictionary = {}
	for pool: NucleusValuePool in shield_pools:
		if pool == null or not is_instance_valid(pool) or pool == receiver.target_pool:
			continue
		var key: int = pool.get_instance_id()
		if visited.has(key):
			continue
		visited[key] = true
		if remaining <= 0.0:
			break
		var consumed: float = maxf(0.0, -pool.decrease(remaining))
		absorbed += consumed
		remaining = maxf(0.0, remaining - consumed)

	var health_damage: float = 0.0
	if remaining > 0.0:
		var forwarded := NucleusHitPayload.new(
			remaining, payload.source, payload.hitbox, payload.tags, payload.metadata
		)
		health_damage = receiver.receive_hit(forwarded)

	var outcome: Dictionary = {
		"error": OK,
		"reason": &"",
		"requested": payload.amount,
		"modified": amount,
		"absorbed": absorbed,
		"health_damage": health_damage,
		"overkill": maxf(0.0, remaining - health_damage),
	}
	damage_resolved.emit(payload, outcome.duplicate(true))
	return outcome


func _failure(error: Error, reason: StringName) -> Dictionary:
	return {"error": error, "reason": reason, "requested": 0.0,
		"modified": 0.0, "absorbed": 0.0, "health_damage": 0.0, "overkill": 0.0}
