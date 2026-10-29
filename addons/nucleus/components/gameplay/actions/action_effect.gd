class_name NucleusActionEffect
extends Node
## Base effect committed by NucleusGameplayAction.
##
## If [method can_apply] returns OK, [method apply] should be deterministic and
## should normally succeed. Effects are committed in scene-tree order.


func can_apply(_context: Dictionary) -> Error:
	return OK


func apply(_context: Dictionary) -> Error:
	return OK
