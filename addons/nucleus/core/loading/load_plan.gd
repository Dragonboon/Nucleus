@tool
class_name NucleusLoadPlan
extends Resource
## Declarative resource batch for bootstrap and runtime preloading.
##
## Entries are intentionally explicit. Nucleus does not crawl scenes, scan
## directories, or infer what a game may need next.

@export var display_name: String = ""
@export var entries: Array[NucleusLoadEntry] = []


func get_item_count() -> int:
	return entries.size()


func get_total_weight() -> float:
	var total := 0.0

	for entry: NucleusLoadEntry in entries:
		if entry != null and is_finite(entry.weight) and entry.weight > 0.0:
			total += entry.weight

	return total


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_paths: Dictionary = {}

	if entries.is_empty():
		errors.append("Load plan requires at least one entry.")
		return errors

	for index: int in range(entries.size()):
		var entry: NucleusLoadEntry = entries[index]

		if entry == null:
			errors.append("Entry %d is null." % index)
			continue

		var entry_errors := entry.get_validation_errors()

		for message: String in entry_errors:
			errors.append("Entry %d: %s" % [index, message])

		var normalized := entry.path.strip_edges()

		if normalized.is_empty():
			continue

		if seen_paths.has(normalized):
			errors.append(
				"Duplicate resource path '%s' is not allowed in one plan."
				% normalized
			)
		else:
			seen_paths[normalized] = true

	return errors
