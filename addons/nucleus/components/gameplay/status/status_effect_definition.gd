class_name NucleusStatusEffectDefinition
extends Resource
## Design-time definition for one reusable status effect.

enum DurationUnit { SECONDS, TURNS }

enum ReapplyPolicy {
	REFRESH,
	ADD_STACK_REFRESH,
	ADD_STACK_INDEPENDENT,
	EXTEND_DURATION,
}

@export var effect_id: StringName
@export var tags: Array[StringName] = []

@export_group("Lifetime")
@export_range(0.0, 86400.0, 0.01, "or_greater")
var duration: float = 5.0
@export var duration_unit: DurationUnit = DurationUnit.SECONDS
@export var ignore_time_scale: bool = false
@export var persist: bool = true

@export_group("Stacking")
@export var reapply_policy: ReapplyPolicy = ReapplyPolicy.REFRESH
@export_range(1, 999, 1, "or_greater")
var maximum_stacks: int = 1

@export_group("Ticking")
@export_range(0.0, 86400.0, 0.01, "or_greater")
var tick_interval: float = 0.0
@export var tick_on_apply: bool = false

@export_group("Attributes")
@export var modifiers: Array[NucleusAttributeModifier] = []


func is_permanent() -> bool:
	return duration <= 0.0


func has_tag(tag: StringName) -> bool:
	return tag in tags
