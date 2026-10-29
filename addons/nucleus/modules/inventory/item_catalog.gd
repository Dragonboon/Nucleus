class_name NucleusItemCatalog
extends Resource
## Explicit item-definition lookup used by inventory/equipment persistence.
##
## The catalog is a normal Resource. It is not a registry Autoload.

@export var items: Array[NucleusItemDefinition] = []


func has_item(item_id: StringName) -> bool:
	return get_item(item_id) != null


func get_item(item_id: StringName) -> NucleusItemDefinition:
	if item_id == &"":
		return null

	for item: NucleusItemDefinition in items:
		if item != null and item.item_id == item_id:
			return item

	return null


func get_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []

	for item: NucleusItemDefinition in items:
		if item == null or item.item_id == &"":
			continue

		if item.item_id not in result:
			result.append(item.item_id)

	return result


func find_by_tag(tag: StringName) -> Array[NucleusItemDefinition]:
	var result: Array[NucleusItemDefinition] = []

	if tag == &"":
		return result

	for item: NucleusItemDefinition in items:
		if item != null and item.has_tag(tag):
			result.append(item)

	return result


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var known_ids: Dictionary[StringName, bool] = {}

	for index: int in range(items.size()):
		var item: NucleusItemDefinition = items[index]

		if item == null:
			errors.append("Catalog item %d is null." % index)
			continue

		if item.item_id == &"":
			errors.append("Catalog item %d has an empty item_id." % index)
			continue

		if known_ids.has(item.item_id):
			errors.append("Duplicate item_id '%s'." % item.item_id)
			continue

		known_ids[item.item_id] = true

	return errors
