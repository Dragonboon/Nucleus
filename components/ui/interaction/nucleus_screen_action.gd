extends Resource
class_name NucleusScreenAction
## Optional data-driven action. Rule and content IDs are defined by each game.

@export var required_flags: Array[StringName] = []
@export var forbidden_flags: Array[StringName] = []
@export var required_item: StringName
@export var consume_item := false
@export var give_item: StringName
@export var set_flags: Array[StringName] = []
@export var clear_flags: Array[StringName] = []
@export var next_screen: StringName
@export var message_key: StringName
@export var one_shot := false


func is_valid_action() -> bool:
	if consume_item and required_item == &"":
		return false
	for flag in required_flags:
		if flag == &"" or flag in forbidden_flags:
			return false
	for flag in forbidden_flags:
		if flag == &"":
			return false
	for flag in set_flags:
		if flag == "" or flag in clear_flags:
			return false
	for flag in clear_flags:
		if flag == "":
			return false
	return true
