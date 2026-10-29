class_name NucleusEncounterReward
extends Node
## Optional exactly-once reward bridge for one director lifecycle.
## A successful award is marked before emitting notifications.

signal rewards_granted(encounter_id: StringName)

@export var director: NucleusEncounterDirector
@export var experience_track: NucleusProgressionTrack
@export_range(0, 2147483647, 1, "or_greater") var experience: int = 0
@export var loot_roller: NucleusLootRoller

var _granted: bool = false
var _encounter_id: StringName


func _ready() -> void:
	if director == null:
		return
	director.encounter_started.connect(_on_started)
	director.encounter_completed.connect(_on_completed)


func _on_started(_id: StringName) -> void:
	# A claimed reward stays claimed until an explicit new lifecycle is set up.
	if _encounter_id != _id:
		_granted = false
	_encounter_id = _id


func _on_completed(id: StringName) -> void:
	if _granted:
		return
	if experience > 0:
		if experience_track == null or experience_track.grant_experience(experience) != OK:
			return
	_granted = true
	_encounter_id = id
	if loot_roller != null:
		loot_roller.generate({"encounter_id": id})
	rewards_granted.emit(id)


func capture_state() -> Dictionary:
	return {
		"encounter_id": String(_encounter_id),
		"granted": _granted,
	}


func restore_state(data: Dictionary) -> Error:
	if director == null or director.definition == null:
		return ERR_UNCONFIGURED
	if str(data.get("encounter_id", "")) != String(director.definition.encounter_id):
		return ERR_INVALID_DATA
	var granted: Variant = data.get("granted", false)
	if not (granted is bool):
		return ERR_INVALID_DATA
	_encounter_id = director.definition.encounter_id
	_granted = granted
	return OK
