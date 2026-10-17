class_name NucleusProgressionTrack
extends Node
## Data-only advancement; game owns rewards and level-up consequences.

signal experience_changed(previous: int, current: int)
signal level_changed(previous: int, current: int)

@export var definition: NucleusProgressionDefinition
@export var initial_experience: int = 0

var experience: int = 0
var level: int = 1


func _ready() -> void:
	set_experience(initial_experience)


func set_experience(value: int) -> Error:
	if definition == null or not definition.is_valid() or value < 0:
		return ERR_INVALID_PARAMETER
	var old_xp: int = experience
	var old_level: int = level
	experience = value
	level = definition.level_for_experience(value)
	if old_xp != experience:
		experience_changed.emit(old_xp, experience)
	if old_level != level:
		level_changed.emit(old_level, level)
	return OK


func grant_experience(amount: int) -> Error:
	if amount < 0 or amount > 9223372036854775807 - experience:
		return ERR_INVALID_PARAMETER
	return set_experience(experience + amount)


func capture_state() -> Dictionary:
	return {"track_id": String(definition.track_id) if definition else "",
		"experience": experience}


func restore_state(data: Dictionary) -> Error:
	if definition == null or str(data.get("track_id", "")) != String(definition.track_id):
		return ERR_INVALID_DATA
	var value: Variant = data.get("experience", -1)
	if not (value is int):
		return ERR_INVALID_DATA
	return set_experience(value)
