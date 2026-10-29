class_name NucleusResetSettingsBinding
extends Node
## Binds a button to reset all settings or one settings section.

@export var target: BaseButton
## Empty resets all settings. Otherwise only this ConfigFile section is reset.
@export var section: StringName


func _ready() -> void:
	if target == null:
		target = get_parent() as BaseButton

	if target == null:
		NucleusLog.error(
			"%s requires a BaseButton target or parent." % get_path(),
			&"SettingsBinding",
		)
		return

	target.pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if section == &"":
		NucleusSettings.reset_all()
	else:
		NucleusSettings.reset_section(section)
