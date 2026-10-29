class_name NucleusEncounterCombatant
extends Node
## Binds a unique encounter instance to a pool; no actor or turn assumptions.

signal defeated(instance_id: StringName, participant_id: StringName)

@export var instance_id: StringName
@export var participant_id: StringName
@export var health: NucleusValuePool

var _reported: bool = false


func _ready() -> void:
	if health != null:
		health.depleted.connect(_on_depleted)
		if health.is_depleted():
			_on_depleted()


func _exit_tree() -> void:
	if is_instance_valid(health) and health.depleted.is_connected(_on_depleted):
		health.depleted.disconnect(_on_depleted)


func reset_defeat() -> void:
	_reported = false


func _on_depleted() -> void:
	if _reported or instance_id == &"" or participant_id == &"":
		return
	_reported = true
	defeated.emit(instance_id, participant_id)
