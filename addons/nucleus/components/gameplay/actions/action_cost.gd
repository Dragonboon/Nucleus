class_name NucleusActionCost
extends Node
## Base transactional cost for NucleusGameplayAction.
##
## [method can_pay] must be side-effect free. [method refund] is used only when
## a later cost fails during the same synchronous commit.

signal affordability_changed


func can_pay(_context: Dictionary) -> Error:
	return OK


func pay(_context: Dictionary) -> Error:
	return OK


func refund(_context: Dictionary) -> void:
	pass


func notify_affordability_changed() -> void:
	affordability_changed.emit()
