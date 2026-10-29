class_name NucleusLootEntry
extends Resource
## Immutable design-time candidate in a NucleusLootTable.
##
## [member payload] may reference any Resource, including PackedScene or an
## optional module's item definition. Loot itself does not depend on Inventory.

@export var entry_id: StringName
@export var payload: Resource
@export var enabled: bool = true

@export_group("Selection")
@export var guaranteed: bool = false
@export_range(0.0, 1.0, 0.001)
var chance: float = 1.0
@export_range(0.0, 1.0e12, 0.001, "or_greater")
var weight: float = 1.0
@export var unique: bool = false

@export_group("Amount")
@export_range(1, 1000000, 1, "or_greater")
var minimum_amount: int = 1
@export_range(1, 1000000, 1, "or_greater")
var maximum_amount: int = 1

@export_group("Metadata")
@export var tags: Array[StringName] = []
@export var conditions: Array[NucleusLootCondition] = []


func is_eligible(
	context: Dictionary,
	state: NucleusLootState = null,
) -> bool:
	if not enabled or entry_id == &"":
		return false

	if (
		unique
		and state != null
		and state.has_consumed(entry_id)
	):
		return false

	for condition: NucleusLootCondition in conditions:
		if condition != null and not condition.check(context):
			return false

	return true


func roll_amount(rng: RandomNumberGenerator) -> int:
	if rng == null:
		return 0

	var minimum: int = maxi(1, minimum_amount)
	var maximum: int = maxi(
		minimum,
		maximum_amount,
	)

	if minimum == maximum:
		return minimum

	return rng.randi_range(
		minimum,
		maximum,
	)


func has_tag(tag: StringName) -> bool:
	return tag != &"" and tag in tags


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if entry_id == &"":
		errors.append("entry_id must not be empty.")

	if chance < 0.0 or chance > 1.0:
		errors.append("chance must be between 0.0 and 1.0.")

	if weight < 0.0:
		errors.append("weight must not be negative.")

	if minimum_amount < 1:
		errors.append("minimum_amount must be at least 1.")

	if maximum_amount < minimum_amount:
		errors.append(
			"maximum_amount must be greater than or equal to minimum_amount."
		)

	return errors
