class_name NucleusUnlockRequirement
extends NucleusActionRequirement
## Checks a learned rank without coupling GameplayAction to progression.

@export var unlock_graph: NucleusUnlockGraph
@export var unlock_id: StringName
@export_range(1, 999, 1, "or_greater") var minimum_rank: int = 1


func _ready() -> void:
	if unlock_graph == null:
		NucleusLog.warning(
			"%s requires an UnlockGraph." % get_path(),
			&"UnlockRequirement",
		)
		return
	if not unlock_graph.unlock_changed.is_connected(_on_unlock_changed):
		unlock_graph.unlock_changed.connect(_on_unlock_changed)


func _exit_tree() -> void:
	if is_instance_valid(unlock_graph):
		if unlock_graph.unlock_changed.is_connected(_on_unlock_changed):
			unlock_graph.unlock_changed.disconnect(_on_unlock_changed)


func check(_context: Dictionary) -> Error:
	if unlock_graph == null or unlock_id == &"":
		return ERR_UNCONFIGURED
	return (
		OK if unlock_graph.get_rank(unlock_id) >= minimum_rank
		else ERR_UNAVAILABLE
	)


func _on_unlock_changed(_id: StringName, _rank: int) -> void:
	notify_availability_changed()
