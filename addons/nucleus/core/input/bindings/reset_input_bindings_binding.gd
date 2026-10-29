class_name NucleusResetInputBindingsBinding
extends Node
## Binds a regular button to restoring project.godot input defaults.

@export var target: BaseButton
## Empty resets every tracked action; otherwise only this action is restored.
@export var action: StringName


func _ready() -> void:
	if target == null:
		target = get_parent() as BaseButton

	if target == null:
		NucleusLog.error(
			"%s requires a BaseButton target or parent." % get_path(),
			&"InputBinding",
		)
		return

	target.pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if action == &"":
		NucleusInput.reset_all_bindings()
	else:
		NucleusInput.reset_action(action)
