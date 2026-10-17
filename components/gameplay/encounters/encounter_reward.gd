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


func _ready() -> void:
	if director == null:
		return
	director.encounter_started.connect(_on_started)
	director.encounter_completed.connect(_on_completed)


func _on_started(_id: StringName) -> void:
	_granted = false


func _on_completed(id: StringName) -> void:
	if _granted:
		return
	if experience > 0:
		if experience_track == null or experience_track.grant_experience(experience) != OK:
			return
	_granted = true
	if loot_roller != null:
		loot_roller.generate({"encounter_id": id})
	rewards_granted.emit(id)
