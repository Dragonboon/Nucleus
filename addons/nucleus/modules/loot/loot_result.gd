class_name NucleusLootResult
extends RefCounted
## One immutable-by-convention result produced from a loot entry.

var entry: NucleusLootEntry
var entry_id: StringName
var payload: Resource
var amount: int


func _init(
	source_entry: NucleusLootEntry = null,
	result_amount: int = 0,
) -> void:
	entry = source_entry
	entry_id = (
		source_entry.entry_id
		if source_entry != null
		else &""
	)
	payload = (
		source_entry.payload
		if source_entry != null
		else null
	)
	amount = maxi(
		0,
		result_amount,
	)


func has_tag(tag: StringName) -> bool:
	return (
		entry != null
		and entry.has_tag(tag)
	)
