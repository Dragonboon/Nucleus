class_name NucleusInputPromptBinding
extends Node
## Keeps a Label synchronized with an action binding and active input source.

@export var action: StringName
@export var target: Label
@export_range(0, 8, 1, "or_greater") var binding_index: int = 0
@export var follow_active_source: bool = true
@export_enum("Keyboard & Mouse:1", "Gamepad:2")
var fixed_source: int = NucleusInputTypes.Source.KEYBOARD_MOUSE
@export var unbound_text: String = ""


func _ready() -> void:
	if target == null:
		target = get_parent() as Label

	if target == null:
		NucleusLog.error(
			"%s requires a Label target or parent." % get_path(),
			&"InputPrompt",
		)
		return

	NucleusInput.input_source_changed.connect(_on_input_source_changed)
	NucleusInput.active_gamepad_changed.connect(
		_on_active_gamepad_changed
	)
	NucleusInput.action_binding_changed.connect(
		_on_action_binding_changed
	)

	_update_text()


func _update_text() -> void:
	var source: int = (
		NucleusInput.active_source
		if follow_active_source
		else fixed_source
	)
	var binding_text: String = NucleusInput.get_binding_text(
		action,
		source,
		binding_index,
	)

	target.text = unbound_text if binding_text.is_empty() else binding_text


func _on_input_source_changed(
	_source: int,
	_previous_source: int,
) -> void:
	if follow_active_source:
		_update_text()


func _on_active_gamepad_changed(
	_device_id: int,
	_family: int,
) -> void:
	var source: int = (
		NucleusInput.active_source
		if follow_active_source
		else fixed_source
	)

	if source == NucleusInputTypes.Source.GAMEPAD:
		_update_text()


func _on_action_binding_changed(changed_action: StringName) -> void:
	if changed_action == action:
		_update_text()
