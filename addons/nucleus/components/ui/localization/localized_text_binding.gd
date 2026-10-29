class_name NucleusLocalizedTextBinding
extends Node
## One writer for a Control's localized property. Restores native auto-translation on exit.

@export var target: Control
@export_enum("text", "placeholder_text", "tooltip_text") var target_property: String = "text"
@export var message: NucleusLocalizedMessage
@export var count: int = 1
@export var arguments: Dictionary = {}
var _bound: Control
var _previous_auto_mode: Node.AutoTranslateMode


func _enter_tree() -> void:
	if is_node_ready():
		refresh()


func _ready() -> void:
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree() and is_node_ready():
		refresh()


func refresh() -> Error:
	var resolved := target if is_instance_valid(target) else get_parent() as Control
	if not is_instance_valid(resolved) or message == null:
		return ERR_UNCONFIGURED
	if target_property not in ["text", "placeholder_text", "tooltip_text"]:
		return ERR_INVALID_PARAMETER
	var found := false
	for property: Dictionary in resolved.get_property_list():
		if property.name == target_property and property.type == TYPE_STRING:
			found = true
	if not found:
		return ERR_INVALID_PARAMETER
	if _bound != resolved:
		_release()
		_bound = resolved
		_previous_auto_mode = _bound.auto_translate_mode
		_bound.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_bound.set(target_property, message.resolve(count, arguments))
	return OK


func set_values(value: int, replacements: Dictionary = {}) -> Error:
	count = value
	arguments = replacements.duplicate(true)
	return refresh()


func _exit_tree() -> void:
	_release()


func _release() -> void:
	if is_instance_valid(_bound):
		_bound.auto_translate_mode = _previous_auto_mode
	_bound = null
