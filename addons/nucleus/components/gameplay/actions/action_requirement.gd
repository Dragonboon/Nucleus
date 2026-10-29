class_name NucleusActionRequirement
extends Node
## Base requirement evaluated before a gameplay action commits.
##
## Requirements are side-effect free. Emit [signal availability_changed] when
## external state changes so UI/action availability can refresh.

signal availability_changed


func check(_context: Dictionary) -> Error:
	return OK


func notify_availability_changed() -> void:
	availability_changed.emit()
