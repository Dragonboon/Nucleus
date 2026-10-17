class_name NucleusApplyDamageEffect
extends NucleusActionEffect
## ActionEffect adapter to DamageResolver; scene/game owns target selection.

signal hit_processed(payload: NucleusHitPayload, result: Dictionary)

@export var target_resolver: NucleusDamageResolver
@export var resolve_from_context: bool = false
@export var context_target_key: StringName = &"target"
@export_range(0.0, 1.0e12, 0.01, "or_greater") var amount: float = 1.0
@export var tags: Array[StringName] = []


func can_apply(context: Dictionary) -> Error:
	if is_nan(amount) or is_inf(amount) or amount <= 0.0:
		return ERR_INVALID_PARAMETER
	return OK if _resolve_target(context) != null else ERR_UNCONFIGURED


func apply(context: Dictionary) -> Error:
	var resolver: NucleusDamageResolver = _resolve_target(context)
	if resolver == null:
		return ERR_UNCONFIGURED
	var source: Node = context.get(&"source") as Node
	if source == null:
		source = get_parent()
	var payload := NucleusHitPayload.new(
		amount, source, null, tags, {}
	)
	var result: Dictionary = resolver.resolve_hit(payload)
	hit_processed.emit(payload, result.duplicate(true))
	# Immunities are a valid, paid combat outcome, not an execution failure.
	if result.get("error", ERR_BUG) == ERR_UNAVAILABLE:
		return OK
	return result.get("error", ERR_BUG)


func _resolve_target(context: Dictionary) -> NucleusDamageResolver:
	if not resolve_from_context:
		return target_resolver if is_instance_valid(target_resolver) else null
	var candidate: Variant = context.get(context_target_key)
	if candidate is NucleusDamageResolver and is_instance_valid(candidate):
		return candidate as NucleusDamageResolver
	if not (candidate is Node) or not is_instance_valid(candidate):
		return null
	var match_resolver: NucleusDamageResolver
	for node: Node in NucleusNodeUtils.descendants(candidate, true):
		if not (node is NucleusDamageResolver):
			continue
		if match_resolver != null:
			return null # Ambiguous: never silently choose a target.
		match_resolver = node as NucleusDamageResolver
	return match_resolver
