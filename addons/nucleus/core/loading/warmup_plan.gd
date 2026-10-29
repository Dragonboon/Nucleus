class_name NucleusWarmupPlan
extends Resource
## Explicit set of first-use scene warmups owned by a loading/bootstrap scene.

@export var entries: Array[NucleusWarmupEntry] = []


func get_total_instances() -> int:
	var total: int = 0
	for entry: NucleusWarmupEntry in entries:
		if entry != null:
			total += maxi(entry.instance_count, 0)
	return total


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for index: int in range(entries.size()):
		var entry: NucleusWarmupEntry = entries[index]
		if entry == null:
			errors.append("entries[%d] cannot be null" % index)
			continue
		for entry_error: String in entry.get_validation_errors():
			errors.append("entries[%d]: %s" % [index, entry_error])
	return errors
