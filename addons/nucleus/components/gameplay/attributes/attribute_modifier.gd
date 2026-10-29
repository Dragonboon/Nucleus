class_name NucleusAttributeModifier
extends Resource
## One reusable modifier applied by a named source in NucleusAttributeSet.
##
## Evaluation order is fixed:
## ADD -> ADD_PERCENT -> MULTIPLY -> OVERRIDE -> attribute clamp.

enum Operation {
	ADD,
	ADD_PERCENT,
	MULTIPLY,
	OVERRIDE,
}

@export var attribute_id: StringName
@export var operation: Operation = Operation.ADD
@export var value: float = 0.0
@export var scale_with_stacks: bool = true

## Only used by OVERRIDE. Higher priority wins.
@export var priority: int = 0


func get_effective_value(stack_count: int) -> float:
	var stacks: int = maxi(1, stack_count)

	match operation:
		Operation.ADD, Operation.ADD_PERCENT:
			return (
				value * stacks
				if scale_with_stacks
				else value
			)

		Operation.MULTIPLY:
			return (
				pow(value, stacks)
				if scale_with_stacks
				else value
			)

		Operation.OVERRIDE:
			return value

	return value
